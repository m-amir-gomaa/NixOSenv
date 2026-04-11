---

# NixOS Environment Overview

Welcome to the root of your declarative NixOS architecture. While specific agentic features (like OpenClaude) occupy dedicated documentation, this guide covers the structural mapping of the core OS elements. 

## 🏗️ Repository Layout

The flake strictly separates the system layer from the user layer (`home.nix`):

```
~/NixOSenv/
├── flake.nix                  # Flake entrypoint matching 'qwerty'
├── configuration.nix          # System-level root settings (Boot, Services)
├── hardware-configuration.nix # Auto-generated hardware specifics
├── home.nix                   # User-level Home Manager entrypoint
│
├── modules/                   # Reusable Nix components
│   ├── auto-git-nixosenv.nix  # Autocommit systemd service definition
│   ├── autocommit-pkg.nix     # Python dependency wrapping for autocommit
│   └── mineru.nix             # Local MinerU integration
│
├── hyprland.nix               # Hyprland Wayland compositor configuration
├── waybar.nix                 # Custom Status Bar
├── swaync.nix                 # Notification Daemon
├── kitty.nix                  # GPU-accelerated Wayland terminal
└── nvim.nix                   # Strict multi-LSP Neovim setup
```

## ⚙️ Core Desktop Ecosystem

### 1. Hyprland & Wayland UI
Your stack eliminates all X11 legacy overhead using pure Wayland:
- **Hyprland** (`hyprland.nix`): The core window manager. It dictates window tiling rules, workspace animations, and critical Wayland environment variables. 
- **Waybar** (`waybar.nix`): Handles the top-bar HUD, pulling network, audio, and battery statuses natively.
- **SwayNC** (`swaync.nix`): Processes all D-Bus notifications securely.

### 2. Standard Applications & Knowledge
- **Obsidian**: The primary knowledge vault and second brain. Configured under `environment.systemPackages` as `obsidian`.
- **Nautilus**: File browser with full GNOME integration.
- **Firefox/Chrome**: Standard browsers with Wayland support.

### 3. The Development Layer
- **Neovim** (`nvim.nix`): Hardened via `nixpkgs`. It symlinks into custom `.config/nvim` dynamically and pre-loads dependencies like `tree-sitter` and standard Language Servers (like Harpers for markdown, rust-analyzer, etc.).
- **Zsh & Starship**: (`home.nix`) The core login shell is heavily outfitted with custom `oh-my-zsh` plugins (`fzf-tab`, colored man pages) and instant prompts initialized natively from standard dotfiles in `~/NixOSenv/dotfiles`.

## 🔄 The Rebuild Mechanism
Rebuilding the environment is controlled through the global `nr` alias. 

**Execution Cycle:**
1. Decrypts `secrets.nix.age` for local usage (See [Secrets Management](./secrets-management.md)).
2. Stages uncommitted module changes (excluding the plaintext secrets!).
3. Runs `sudo nixos-rebuild switch --flake path:/home/qwerty/NixOSenv#nixos`.
4. The system evaluates the `flake.nix` to trace all imported modules.
5. Symlinks for terminal configurations (`.zshrc`, `.fzf.zsh`, `kitty.conf`) are rewritten centrally into `~/.config/`.

## 🧹 System Maintenance (Lean Memory)

As NixOS and Home Manager build new generations, your disk space ("memory") will fill up. To maintain a lean system space, the environment now includes **Automated Maintenance**:

### 1. Automated Profile Purge
The `nix-profile-maintenance` systemd service runs **weekly**, executing `nix profile wipe-history --older-than 7d` natively for the `qwerty` user.

### 2. Automated Store Optimization
The Nix store is configured with:
- `nix.gc.automatic`: Weekly garbage collection of the store.
- `nix.optimise.automatic`: Weekly deduplication of files.
- `min-free` / `max-free`: The system dynamically clears the store when disk space drops below 10GB.

### 3. Manual Override (The Ultimate Purge)
If you need to free space immediately, use the standard manual commands:
```bash
nix profile wipe-history --older-than 0d
nix store gc
```

---
