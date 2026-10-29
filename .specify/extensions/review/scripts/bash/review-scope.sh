#!/usr/bin/env bash
# review extension: review-scope.sh
#
# Print what /speckit-review-implementation has to review for one lane: the
# active spec, the lane and its branch (d<NN>-<lane>), whether that branch is
# checked out, the base it is compared with, the commits since the merge base,
# and every file that differs from the merge base, committed or not (staged,
# unstaged and untracked files included), each with the lane that owns it.
#
# The lane comes from --lane, else MADAR_LANE, else the worktree folder
# (madar-b1, madar-b2, madar-a, madar-m), else a current branch named
# d<NN>-<lane>. A review always covers exactly one lane.
#
# Renames are listed as a deletion and an addition. Binary files have no line
# counts. It only reads; it never changes the working tree or the index.
#
# Usage: review-scope.sh [--json] [--base <ref>] [--lane <b1|b2|a|m>]

set -e

JSON_MODE=false
BASE=""
LANE_ARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --json)
            JSON_MODE=true
            ;;
        --base)
            shift
            BASE="${1:-}"
            if [ -z "$BASE" ]; then
                echo "Error: --base needs a ref" >&2
                exit 2
            fi
            ;;
        --lane)
            shift
            LANE_ARG="${1:-}"
            if [ -z "$LANE_ARG" ]; then
                echo "Error: --lane needs b1, b2, a or m" >&2
                exit 2
            fi
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--base <ref>] [--lane <b1|b2|a|m>]"
            echo "List one lane's change set against the merge base with <ref> (default: origin/master, then master)."
            exit 0
            ;;
        *)
            echo "Error: unknown argument '$1'" >&2
            exit 2
            ;;
    esac
    shift
done

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The project root is the first directory above this script that contains .specify/.
_find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.specify" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT="$(_find_project_root "$SCRIPT_DIR")" || {
    echo "Error: could not find the project root (.specify/) above $SCRIPT_DIR" >&2
    exit 1
}
CORE_COMMON="$PROJECT_ROOT/.specify/scripts/bash/common.sh"
if [ ! -f "$CORE_COMMON" ]; then
    echo "Error: core Spec Kit scripts not found at $CORE_COMMON" >&2
    exit 1
fi

cd "$PROJECT_ROOT"
# shellcheck source=/dev/null
source "$CORE_COMMON"

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: a git repository is required to review an implementation" >&2
    exit 1
fi

# get_feature_paths prints its own error when no feature is active.
if ! feature_paths="$(get_feature_paths --no-persist)"; then
    echo "Error: no active feature. Run /speckit-specify first, or set SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name>." >&2
    exit 1
fi
eval "$feature_paths"

FEATURE_DIR_REL="${FEATURE_DIR#"$REPO_ROOT/"}"
FEATURE_NAME="${FEATURE_DIR##*/}"
BRANCH="$(git symbolic-ref --short -q HEAD || echo HEAD)"

# Prints the lane (b1, b2, a or m) under review, or nothing when none can be found.
resolve_lane() {
    local lane="${LANE_ARG:-${MADAR_LANE:-}}"
    if [ -n "$lane" ]; then
        lane="$(printf '%s' "$lane" | tr '[:upper:]' '[:lower:]')"
        case "$lane" in
            b1|b2|a|m) printf '%s\n' "$lane" ;;
            *)
                echo "Error: '$lane' is not a lane (b1, b2, a or m)" >&2
                return 1
                ;;
        esac
        return 0
    fi
    case "$(basename "$(git rev-parse --show-toplevel)")" in
        madar-b1) echo b1; return 0 ;;
        madar-b2) echo b2; return 0 ;;
        madar-a)  echo a;  return 0 ;;
        madar-m)  echo m;  return 0 ;;
    esac
    if [[ "${BRANCH##*/}" =~ ^d[0-9]{2}-(b1|b2|a|m)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# The lane that owns a path (docs/delivery-plan.md §4): b1, b2, a, m, shared (spec
# and doc files any lane may touch) or none (files no lane owns, such as the design
# package and agent tooling).
path_owner() {
    case "$1" in
        backend/app/adapters/*) echo b2 ;;
        backend/*) echo b1 ;;
        infra/*|.github/*|codemagic.yaml) echo b2 ;;
        admin/*) echo a ;;
        app/*) echo m ;;
        specs/*|docs/*|CLAUDE.md|AGENTS.md|README.md) echo shared ;;
        *) echo none ;;
    esac
}

LANE="$(resolve_lane)" || exit 1
if [ -z "$LANE" ]; then
    echo "Error: no lane to review. Pass --lane <b1|b2|a|m>, set MADAR_LANE, or run from a madar-<lane> worktree." >&2
    exit 1
fi
if [[ ! "$FEATURE_NAME" =~ ^[0-9]{3}-(d[0-9]{2})- ]]; then
    echo "Error: feature '$FEATURE_NAME' is not named 0NN-dNN-<name>, so lane $LANE has no branch for it." >&2
    exit 1
fi
LANE_BRANCH="${BASH_REMATCH[1]}-$LANE"
if [ "$BRANCH" = "$LANE_BRANCH" ] || [ "${BRANCH##*/}" = "$LANE_BRANCH" ]; then
    ON_LANE_BRANCH=true
else
    ON_LANE_BRANCH=false
fi

if [ -z "$BASE" ]; then
    for candidate in origin/master master; do
        if git rev-parse --verify -q "$candidate^{commit}" >/dev/null; then
            BASE="$candidate"
            break
        fi
    done
fi
if [ -z "$BASE" ] || ! git rev-parse --verify -q "$BASE^{commit}" >/dev/null; then
    echo "Error: base ref '${BASE:-<none found>}' does not exist. Pass --base <ref>." >&2
    exit 1
fi
MERGE_BASE="$(git merge-base "$BASE" HEAD)"
HEAD_SHA="$(git rev-parse HEAD)"

GIT=(git -c core.quotePath=false)
declare -A STATUS ADDED DELETED COMMITTED UNCOMMITTED

# Net change from the merge base to the working tree.
while IFS=$'\t' read -r st path; do
    STATUS["$path"]="$st"
done < <("${GIT[@]}" diff --no-renames --name-status "$MERGE_BASE")
while IFS=$'\t' read -r added deleted path; do
    ADDED["$path"]="$added"
    DELETED["$path"]="$deleted"
done < <("${GIT[@]}" diff --no-renames --numstat "$MERGE_BASE")
while IFS=$'\t' read -r _ path; do
    COMMITTED["$path"]=1
done < <("${GIT[@]}" diff --no-renames --name-status "$MERGE_BASE" HEAD)
while IFS=$'\t' read -r _ path; do
    UNCOMMITTED["$path"]=1
done < <("${GIT[@]}" diff --no-renames --name-status HEAD)
while IFS= read -r path; do
    STATUS["$path"]="U"
    UNCOMMITTED["$path"]=1
    read -r added deleted _ < <("${GIT[@]}" diff --no-index --numstat -- /dev/null "$path" || true)
    ADDED["$path"]="${added:--}"
    DELETED["$path"]="${deleted:--}"
done < <("${GIT[@]}" ls-files --others --exclude-standard)

FILE_COUNT=0
UNCOMMITTED_COUNT=0
OTHER_LANE_COUNT=0
TOTAL_ADDED=0
TOTAL_DELETED=0
files_json=""
files_text=""
while IFS= read -r path; do
    [ -z "$path" ] && continue
    FILE_COUNT=$((FILE_COUNT + 1))
    added="${ADDED[$path]:--}"
    deleted="${DELETED[$path]:--}"
    owner="$(path_owner "$path")"
    case "$owner" in
        "$LANE"|shared|none) ;;
        *) OTHER_LANE_COUNT=$((OTHER_LANE_COUNT + 1)) ;;
    esac
    committed=false
    uncommitted=false
    [ -n "${COMMITTED[$path]:-}" ] && committed=true
    if [ -n "${UNCOMMITTED[$path]:-}" ]; then
        uncommitted=true
        UNCOMMITTED_COUNT=$((UNCOMMITTED_COUNT + 1))
    fi
    if [ "$added" = "-" ]; then
        lines='"added":null,"deleted":null,"binary":true'
    else
        lines="\"added\":$added,\"deleted\":$deleted,\"binary\":false"
        TOTAL_ADDED=$((TOTAL_ADDED + added))
        TOTAL_DELETED=$((TOTAL_DELETED + deleted))
    fi
    [ -n "$files_json" ] && files_json+=","
    files_json+="{\"path\":\"$(json_escape "$path")\",\"status\":\"${STATUS[$path]}\",\"owner\":\"$owner\",$lines,\"committed\":$committed,\"uncommitted\":$uncommitted}"
    flag=""
    $uncommitted && flag=" (uncommitted)"
    files_text+="  ${STATUS[$path]}  $(printf '%-6s' "$owner") +$added -$deleted  $path$flag"$'\n'
done < <(printf '%s\n' "${!STATUS[@]}" | LC_ALL=C sort)

commits_json=""
commits_text=""
COMMIT_COUNT=0
while IFS=$'\t' read -r sha author subject; do
    [ -z "$sha" ] && continue
    COMMIT_COUNT=$((COMMIT_COUNT + 1))
    [ -n "$commits_json" ] && commits_json+=","
    commits_json+="{\"sha\":\"$sha\",\"author\":\"$(json_escape "$author")\",\"subject\":\"$(json_escape "$subject")\"}"
    commits_text+="  $sha $subject ($author)"$'\n'
done < <(git log --reverse --format='%h%x09%an%x09%s' "$MERGE_BASE..HEAD")

if $JSON_MODE; then
    printf '{"FEATURE_DIR":"%s","LANE":"%s","LANE_BRANCH":"%s","BRANCH":"%s","ON_LANE_BRANCH":%s,' \
        "$(json_escape "$FEATURE_DIR_REL")" "$LANE" "$LANE_BRANCH" \
        "$(json_escape "$BRANCH")" "$ON_LANE_BRANCH"
    printf '"BASE":"%s","MERGE_BASE":"%s","HEAD":"%s",' \
        "$(json_escape "$BASE")" "$MERGE_BASE" "$HEAD_SHA"
    printf '"TOTALS":{"commits":%d,"files":%d,"uncommitted_files":%d,"other_lane_files":%d,"added":%d,"deleted":%d},' \
        "$COMMIT_COUNT" "$FILE_COUNT" "$UNCOMMITTED_COUNT" "$OTHER_LANE_COUNT" "$TOTAL_ADDED" "$TOTAL_DELETED"
    printf '"COMMITS":[%s],"FILES":[%s]}\n' "$commits_json" "$files_json"
else
    echo "Feature:   $FEATURE_DIR_REL"
    echo "Lane:      $LANE (branch $LANE_BRANCH)"
    echo "Checked out: $BRANCH$($ON_LANE_BRANCH || echo '  <-- not the lane branch')"
    echo "Base:      $BASE (merge base ${MERGE_BASE:0:12}, head ${HEAD_SHA:0:12})"
    echo "Commits ($COMMIT_COUNT):"
    printf '%s' "$commits_text"
    echo "Files ($FILE_COUNT, $UNCOMMITTED_COUNT uncommitted, $OTHER_LANE_COUNT in another lane's folders, +$TOTAL_ADDED -$TOTAL_DELETED):"
    printf '%s' "$files_text"
fi
