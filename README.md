# NixOS System Configuration ❄️

A fully declarative, reproducible NixOS environment managed with Nix flakes and Home Manager. The entire system — from bootloader to dotfiles to background services — is defined in version-controlled Nix expressions. Rebuilding from scratch on new hardware requires a single command.

## What This Demonstrates

- **Declarative infrastructure**: System state is fully described in code. No manual `apt install`, no configuration drift, no "works on my machine."
- **Nix flakes**: All external dependencies (nixpkgs, Home Manager, third-party packages) are pinned to exact git revisions in `flake.lock` for reproducible builds.
- **Custom Nix packaging**: Third-party tools not in nixpkgs are packaged from source with proper dependency declaration and patching (`modules/autocommit-pkg.nix`).
- **systemd service authoring**: Background services written as Nix modules with secrets handling, environment variable overrides, and restart logic.
- **Hardware-specific configuration**: NVIDIA Prime offload (hybrid GPU), PipeWire audio, TLP battery management, and Wayland compositor setup.

---

## Stack

| Layer | Technology |
| :--- | :--- |
| OS | NixOS (nixos-unstable) |
| Package management | Nix flakes + Home Manager |
| Wayland compositor | Hyprland |
| Audio | PipeWire + WirePlumber |
| Terminal | Kitty |
| Editor | Neovim (LSPs managed via Nix) |
| Shell | Zsh + Oh-My-Zsh + Powerlevel10k |
| Status bar | Waybar |
| Notifications | Mako |
| Rust toolchain | Fenix (stable, via overlay) |
| Networking | systemd-networkd + iwd + DNS-over-HTTPS |

---

## Repository Structure

| Path | Purpose |
| :--- | :--- |
| `flake.nix` | Entrypoint. Pins all inputs and defines system outputs. |
| `configuration.nix` | System-level: boot, networking, GPU, audio, fonts, power management. |
| `home.nix` | User environment via Home Manager: shell, theme, session variables. |
| `hyprland.nix` | Wayland compositor keybinds and monitor configuration. |
| `nvim.nix` | Neovim: declares LSP servers and plugins via Nix, then symlinks into [kickstart.nvim](https://github.com/m-amir-gomaa/kickstart.nvim) — keeping Neovim config in its own repo, separate from the system config. |
| `waybar.nix` | Status bar configuration. |
| `modules/autocommit-pkg.nix` | Custom Nix package: builds the `autocommit` Python tool from source. |
| `modules/auto-git-nixosenv.nix` | systemd user service: AI-powered git autocommit with meaningful-change detection. |
| `dotfiles/` | Raw config files (`.zshrc`, `.p10k.zsh`, kitty theme) symlinked into `~` via Nix. |
| `cachix/` | Binary cache configuration to avoid recompiling heavy packages. |

---

## Notable: AI-Powered Autocommit Service

`modules/auto-git-nixosenv.nix` defines a systemd user service that monitors this repository for changes and automatically commits them using an AI-generated commit message (via the OpenAI API).

Key design decisions:
- **Meaningful-change filter**: Only commits if at least 2 files or 5 lines changed — prevents noisy single-character commits.
- **Secrets never touch the Nix store**: The API key is read from `~/.config/autocommit/secrets.env` at runtime. The Nix store is world-readable, so hardcoding secrets there would be a security issue.
- **Dual push support**: Pushes via HTTPS (GitHub token) or SSH, configurable via environment variable — makes credential rotation easy without a rebuild.
- **Resilient loop**: Push failures are logged but do not crash the service. systemd restarts on hard failures with a 10-second backoff.

---

## Applying Changes

```bash
# Rebuild and switch (alias defined in dotfiles/zsh/.zshrc)
nr

# Or explicitly:
sudo nixos-rebuild switch --flake ~/NixOSenv#nixos
```

---

## Previous AI Integration

This repo previously included [Jarvis](https://github.com/m-amir-gomaa/Jarvis) — a local AI assistant with a hierarchical RAG database, episodic memory, and background learning services, all managed as Nix modules. It was deprecated in favour of using hosted AI APIs directly. The repository is archived and left public as a reference.
