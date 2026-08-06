# NixOS Environment

Flake-based [NixOS](https://nixos.org) + [Home Manager](https://github.com/nix-community/home-manager) configuration. Declarative end-to-end: system, user home, dotfiles, secrets, and disk layout are all defined in Nix and reproducible from a blank disk.

**Stack:** NixOS (unstable) · Home Manager · Hyprland (Wayland) · Neovim · Kitty · Zsh · SDDM
**Hardware:** Intel iGPU + NVIDIA MX350 (Prime offload) · Hyprland
**Toolchains:** Go · Python (NumPy / SciPy / PyTorch) · Rust (stable via fenix)

## Highlights

- **Reproducible from zero.** `disko.nix` declares the OS-disk layout; `docs/bootstrap.md` walks a fresh machine from installer ISO → `disko` → `nixos-install` → `scripts/bootstrap.sh`. No manual partitioning, no forgotten config.
- **Age-encrypted secrets.** `secrets.nix.age` (API keys, SSH keys) lives in-repo encrypted; the private key stays out-of-band. `bootstrap.sh` decrypts and provisions on install.
- **Declarative everything.** Home Manager manages `home.nix`; dotfiles live in `dotfiles/` as live symlinks (edit → applies without rebuild); system services, DNS (blocky), lock screen, and idle are all `.nix`.
- **Engineering setup.** Reproducible builds, pinned inputs, git identity + SSH managed per-host, CI-checkable with `nix flake check`.

## Repository layout

```
.
├── flake.nix                  # Flake entrypoint — inputs, outputs, overlays
├── configuration.nix          # System config: boot, services, packages
├── hardware-configuration.nix # Auto-generated per machine — do not edit
├── disko.nix                  # Declarative OS-disk layout (fresh installs only)
├── home.nix                   # Home Manager user config
├── home-root.nix              # Home Manager config for root
├── hyprland.nix               # Hyprland compositor + keybinds
├── hyprlock.nix / hypridle.nix# Lock screen / idle
├── waybar.nix / swaync.nix / mako.nix  # Status bar / notifications
├── kitty.nix / nvim.nix       # Terminal / editor (+ LSPs)
├── blocky.nix                 # DNS content blocker (port 5300)
├── sddm-kwin-numlock.nix      # SDDM numlock state
├── cachix.nix                 # Binary cache subscriptions
├── modules/                   # Reusable packages + services
│   ├── auto-git-nixosenv.nix  #   systemd autocommit service (config sync)
│   ├── autocommit-pkg.nix     #   AI commit-message generator
│   ├── instascript.nix        #   InstaScript package
│   ├── antigravity-hub.nix    #   Antigravity agent hub
│   └── mineru.nix             #   MinerU (PDF → Markdown) tool
├── dotfiles/                  # Versioned dotfiles (symlinked / sourced)
│   ├── claude/                #   Claude Code global config
│   ├── utcp/                  #   UTCP MCP bridge config + templates
│   ├── kitty/ nvim/ zsh/ hypr/
├── scripts/
│   ├── bootstrap.sh           # Fresh-machine provisioning (configs, secrets, MCP)
│   ├── record.sh              # Screen recording (wl-screenrec)
│   └── ...
├── secrets.nix.age            # Age-encrypted secrets vault (committed)
└── docs/
    ├── bootstrap.md           # New-machine setup guide
    ├── secrets-management.md  # Age vault workflow
    ├── system-overview.md     # Architecture reference
    ├── home-manager.md        # Home Manager integration notes
    └── providers.md           # LLM provider/model reference
```

## Toolchains

- **Go** — `golang.go` via Home Manager; Neovim LSP (`gopls`) editor support.
- **Python** — `python3.withPackages`: numpy, pandas, scipy, scikit-learn, sympy, matplotlib, PyTorch (`torch`/`torchaudio`/`torchvision`), manim.
- **Rust** — stable toolchain from `fenix`: `cargo`, `clippy`, `rust-src`, `rustfmt`, `rust-docs`; nightly available on demand.
- **Extras** — Docker, `gh` CLI, Neovim + LSPs (see `nvim.nix`, `dotfiles/nvim`).

## LLM provider integration

This machine is set up for working with LLM APIs end-to-end — provider abstraction, key isolation, and local models:

- **Provider-agnostic backend switcher** in `dotfiles/zsh/.zshrc` (`deepseek`, `claude-status`, …). Swaps `ANTHROPIC_BASE_URL` / model envs at shell runtime; keys live only in `~/.zshrc_secrets`, never in the repo.
- **MCP bridge** (`dotfiles/utcp/`) exposes nix, system, security, and web-search tooling to Claude Code via a config-driven bridge; secrets in `~/.utcp/.env`, versioned only as `.example` templates.
- **Local models** — Ollama + LM Studio for offline inference; OpenCode wired for provider routing (see `docs/providers.md`).

## Secrets

API + SSH keys live in the **age-encrypted vault** `secrets.nix.age` (committed) and the local `~/.zshrc_secrets` / `~/.utcp/.env` (never committed). Private material is never in git.

```bash
# decrypt the vault (manual edit flow — see docs/secrets-management.md)
age -d -i ~/.age-key.txt secrets.nix.age > secrets.nix

# key rotation: edit secrets.nix, re-encrypt
age -r "$(age-keygen -y ~/.age-key.txt)" secrets.nix > secrets.nix.age
```

## Applying changes

```bash
nr    # sudo nixos-rebuild switch --flake ~/NixOSenv#nixos
```

## New machine setup

Full guide: **[docs/bootstrap.md](./docs/bootstrap.md)** — blank disk → `disko` → install → `scripts/bootstrap.sh` (Claude/UTCP configs, secrets, SSH keys, MCP registration).

```bash
bash ~/NixOSenv/scripts/bootstrap.sh --secrets-dir /path/to/usb-backup
nr
```

## Docs

- [bootstrap.md](./docs/bootstrap.md) — new-machine setup
- [secrets-management.md](./docs/secrets-management.md) — age vault workflow
- [system-overview.md](./docs/system-overview.md) — architecture
- [home-manager.md](./docs/home-manager.md) — Home Manager notes
- [providers.md](./docs/providers.md) — LLM providers / models

---

_NixOS Environment_
