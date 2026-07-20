---
name: flake-check
description: Validate NixOS flake syntax and evaluation. Use when user asks to check flake, validate config, or before rebuild.
invoke: both
output: full
---

Run `nix flake check path:/home/qwerty/NixOSenv --extra-experimental-features "nix-command flakes"`.

If it passes: confirm success, show any warnings.
If it fails: show exact error, identify file and line, suggest fix. Do NOT retry — let user decide.
