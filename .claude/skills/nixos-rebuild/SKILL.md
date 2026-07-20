---
name: nixos-rebuild
description: Review NixOS changes then rebuild. Trigger on: rebuild, nr, apply changes, after editing .nix files.
invoke: both
output: full
---

## Pre-flight
!`cd ~/NixOSenv && git diff --stat HEAD`
!`cd ~/NixOSenv && git status --short`

## Steps
1. `nix flake check path:/home/qwerty/NixOSenv --extra-experimental-features "nix-command flakes"`
2. Review diff — flag: new ports, UUID changes, stateVersion, boot loader edits
3. Warn if any new files aren't `git add`'d (flake ignores untracked)
4. If clean: `sudo nixos-rebuild switch --flake ~/NixOSenv#nixos`
5. If fail: identify error + line, suggest fix, do NOT retry blindly
