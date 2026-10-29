# tools/speckit-extensions/

Sources of the project's own Spec Kit extensions: `feature-branch` (the lane-aware branch hook)
and `review` (`/speckit-review-implementation`).

To change an extension, edit `tools/speckit-extensions/<name>/`, never the installed copy in
`.specify/extensions/`. Then, from the repo root:

```bash
specify extension add --dev tools/speckit-extensions/<name> --force
specify integration use opencode && specify integration use claude   # registers for both integrations
chmod +x .specify/scripts/bash/*.sh                                   # the switch drops the bit
```

The install regenerates `.claude/skills/speckit-*` and `.opencode/commands/speckit.*`; commit
those with the source change. A running session keeps the old command until it restarts.
