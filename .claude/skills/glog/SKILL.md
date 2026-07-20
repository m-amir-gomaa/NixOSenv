---
name: glog
description: Summarize recent git commits with impact analysis. Use when user asks about recent changes, git log, or commit history.
invoke: both
argument-hint: "[N]"
output: full
---

## Recent commits

!`cd ~/NixOSenv && git log --oneline -${ARGUMENTS:-5}`

For each commit show:
- Files changed and subsystem affected
- Risk: safe / moderate / risky
- Flag: boot, kernel, or security changes

Keep it terse. One line per commit.
