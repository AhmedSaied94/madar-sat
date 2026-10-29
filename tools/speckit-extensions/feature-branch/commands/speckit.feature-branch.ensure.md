---
description: "Check out the active spec's git branch (the lane branch in a lane session, the spec branch in the planning session), or create it if it does not exist"
---

# Ensure Feature Branch

Make sure the right git branch for the active spec is checked out before the calling Spec Kit
command does any work. The active spec is the one recorded in `.specify/feature.json` (or set with
`SPECIFY_FEATURE_DIRECTORY`), which `__SPECKIT_COMMAND_SPECIFY__` writes when it creates a spec.

## Which branch

The day's spec lives on `master` (the default branch), and each lane works on its own branch (`docs/delivery-plan.md`
§5.1), so the branch depends on the session:

| Session | Detected by | Branch | Created from |
| --- | --- | --- | --- |
| Lane B1, B2, A or M | `MADAR_LANE`, else the worktree folder (`madar-b1`, `madar-b2`, `madar-a`, `madar-m`), else a current branch named `dNN-<lane>` | `dNN-<lane>`, e.g. `d01-b1` for spec `001-d01-foundation` | the base: `origin/master`, else `master` |
| Planning (no lane) | none of the above | the spec folder name, e.g. `001-d01-foundation` | the current HEAD |

`SPECIFY_FEATURE` never names the branch here: in this repo it holds the spec name, not a branch.

## Execution

Run from the repository root:

```bash
.specify/extensions/feature-branch/scripts/bash/ensure-feature-branch.sh --json
```

The script resolves the spec the same way the core scripts do, then:

- does nothing if the branch is already checked out (`ACTION` = `unchanged`);
- checks it out if it exists locally (`checked_out`);
- creates a local tracking branch if it exists only on a remote (`tracked`);
- otherwise creates it (`created`).

A branch matches when its name equals the wanted name or ends with `/<wanted name>`. The script
never fetches, stashes, resets or discards changes. It does not reset an existing lane branch to the
base either; `git switch -C` in the daily loop stays the user's call.

## Output

On success the script prints one JSON line with `BRANCH_NAME`, `ACTION`, `PREVIOUS_BRANCH`, `LANE`
(empty for the planning session), `CREATED_FROM` (empty unless created) and `FEATURE_DIR`. Report it
to the user in one line, for example:
`Switched to lane branch d01-b1 (was master).` or `Created spec branch 001-d01-foundation from master.`

## On failure

If the script exits non-zero:

- **Stop the calling command.** Do not continue its work on the wrong branch.
- Show the script's error output to the user.
- Do not stash, reset, check out or discard anything yourself to get past the error. Let the user
  decide. A common cause is a branch already checked out in another worktree.

If Git is not installed or this is not a Git repository, the script prints a warning and exits 0.
Continue normally in that case.
