#!/usr/bin/env bash
# feature-branch extension: ensure-feature-branch.sh
#
# Make sure the right git branch for the active Spec Kit feature is checked out
# before a Spec Kit step runs. The active feature is resolved exactly like the
# core scripts do (SPECIFY_FEATURE_DIRECTORY, then .specify/feature.json).
#
# Which branch depends on the session (docs/delivery-plan.md §5.1):
#   - a lane session (B1, B2, A, M) -> d<NN>-<lane>, e.g. d01-b1, cut from the base branch
#   - the planning session          -> the feature directory name, e.g. 001-d01-foundation, cut from HEAD
#
# The lane comes from MADAR_LANE, else the worktree folder (madar-b1, madar-b2,
# madar-a, madar-m), else a current branch named d<NN>-<lane>. No lane means the
# planning session. SPECIFY_FEATURE never names the branch here: in this repo it
# holds the spec name, not a branch name.
#
# Then:
#   - already on the branch          -> nothing to do       (unchanged)
#   - branch exists locally          -> git checkout        (checked_out)
#   - branch exists only on a remote -> local tracking copy (tracked)
#   - branch does not exist anywhere -> create it           (created)
#
# It never fetches, stashes, resets or discards changes. If git refuses the
# switch, it exits non-zero so the calling command stops.
#
# Usage: ensure-feature-branch.sh [--json]

set -e

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "Check out the active spec's branch (d<NN>-<lane> in a lane session, the spec name otherwise), or create it."
            exit 0
            ;;
        *)
            echo "Error: unknown argument '$arg'" >&2
            exit 2
            ;;
    esac
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
    echo "[specify] Warning: Git repository not detected; skipped feature branch check" >&2
    exit 0
fi

# get_feature_paths prints its own error when no feature is active.
if ! feature_paths="$(get_feature_paths --no-persist)"; then
    echo "Error: no active feature. Run /speckit-specify first, or set SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name>." >&2
    exit 1
fi
eval "$feature_paths"

FEATURE_DIR_REL="${FEATURE_DIR#"$PROJECT_ROOT/"}"
FEATURE_NAME="${FEATURE_DIR##*/}"
PREVIOUS_BRANCH="$(git symbolic-ref --short -q HEAD || echo HEAD)"

# Prints the lane (b1, b2, a or m) this checkout works for, or nothing for the planning session.
resolve_lane() {
    local lane
    if [ -n "${MADAR_LANE:-}" ]; then
        lane="$(printf '%s' "$MADAR_LANE" | tr '[:upper:]' '[:lower:]')"
        case "$lane" in
            b1|b2|a|m) printf '%s\n' "$lane" ;;
            *)
                echo "Error: MADAR_LANE='$MADAR_LANE' is not a lane (b1, b2, a or m)" >&2
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
    if [[ "${PREVIOUS_BRANCH##*/}" =~ ^d[0-9]{2}-(b1|b2|a|m)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# The branch a new lane branch is cut from: main once the D0 rename is done, master until then.
find_base() {
    local ref
    for ref in origin/main main origin/master master; do
        if git rev-parse --verify -q "$ref^{commit}" >/dev/null; then
            printf '%s\n' "$ref"
            return 0
        fi
    done
    return 1
}

LANE="$(resolve_lane)" || exit 1
if [ -n "$LANE" ]; then
    if [[ ! "$FEATURE_NAME" =~ ^[0-9]{3}-(d[0-9]{2})- ]]; then
        echo "Error: feature '$FEATURE_NAME' is not named 0NN-dNN-<name>, so lane $LANE has no branch for it." >&2
        exit 1
    fi
    WANTED="${BASH_REMATCH[1]}-$LANE"
else
    WANTED="$FEATURE_NAME"
fi

# A ref matches when it equals WANTED or its last path segment equals WANTED,
# so "feat/d01-b1" matches the lane branch "d01-b1".
_matches() {
    [ "$1" = "$WANTED" ] || [ "${1##*/}" = "$WANTED" ]
}

find_local_branch() {
    local ref
    while IFS= read -r ref; do
        if _matches "$ref"; then
            printf '%s\n' "$ref"
            return 0
        fi
    done < <(git for-each-ref --format='%(refname:lstrip=2)' refs/heads)
    return 1
}

# Prints "<remote>/<branch>" for the first remote branch that matches.
find_remote_branch() {
    local ref branch
    while IFS= read -r ref; do
        branch="${ref#*/}"
        [ "$branch" = "HEAD" ] && continue
        if _matches "$branch"; then
            printf '%s\n' "$ref"
            return 0
        fi
    done < <(git for-each-ref --format='%(refname:lstrip=2)' refs/remotes)
    return 1
}

TARGET=""
switch_or_fail() {
    local err
    if ! err="$("$@" 2>&1)"; then
        echo "Error: could not switch from '$PREVIOUS_BRANCH' to branch '$TARGET'." >&2
        [ -n "$err" ] && printf '%s\n' "$err" >&2
        echo "Fix the cause above (local changes in the way, or the branch is checked out in another worktree), then rerun the command." >&2
        exit 1
    fi
}

REMOTE_REF=""
CREATED_FROM=""
if LOCAL_REF="$(find_local_branch)"; then
    TARGET="$LOCAL_REF"
    if [ "$PREVIOUS_BRANCH" = "$TARGET" ]; then
        ACTION="unchanged"
    else
        switch_or_fail git checkout -q "$TARGET"
        ACTION="checked_out"
    fi
elif REMOTE_REF="$(find_remote_branch)"; then
    TARGET="${REMOTE_REF#*/}"
    switch_or_fail git checkout -q --track "$REMOTE_REF"
    ACTION="tracked"
else
    TARGET="$WANTED"
    if [ -n "$LANE" ]; then
        # Lanes cut their branch from the base each morning (delivery-plan §5.2), never from HEAD.
        CREATED_FROM="$(find_base)" || {
            echo "Error: no base branch (origin/main, main, origin/master or master) to cut lane branch '$TARGET' from." >&2
            exit 1
        }
        switch_or_fail git checkout -q --no-track -b "$TARGET" "$CREATED_FROM"
    else
        CREATED_FROM="$PREVIOUS_BRANCH"
        switch_or_fail git checkout -q -b "$TARGET"
    fi
    ACTION="created"
fi

if $JSON_MODE; then
    printf '{"BRANCH_NAME":"%s","ACTION":"%s","PREVIOUS_BRANCH":"%s","LANE":"%s","CREATED_FROM":"%s","FEATURE_DIR":"%s"}\n' \
        "$(json_escape "$TARGET")" "$ACTION" "$(json_escape "$PREVIOUS_BRANCH")" "$LANE" \
        "$(json_escape "$CREATED_FROM")" "$(json_escape "$FEATURE_DIR_REL")"
else
    case "$ACTION" in
        unchanged)   echo "✓ Already on branch: $TARGET" ;;
        checked_out) echo "✓ Switched from $PREVIOUS_BRANCH to branch: $TARGET" ;;
        tracked)     echo "✓ Created local branch $TARGET tracking $REMOTE_REF" ;;
        created)     echo "✓ Created branch $TARGET from $CREATED_FROM" ;;
    esac
fi
