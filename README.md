# NixOS Environment

Declarative NixOS configuration for a Hyprland-based laptop (NVIDIA Prime + Intel iGPU).

## Repository Layout

```
~/NixOSenv/
├── flake.nix                    # Flake entrypoint
├── configuration.nix            # System-level config (boot, services, packages)
├── hardware-configuration.nix   # Auto-generated — do not edit
├── home.nix                     # User config (shell, aliases, env vars, API keys)
│
├── modules/                     # Reusable Nix modules
│   ├── auto-git-nixosenv.nix
│   ├── autocommit-pkg.nix
│   └── mineru.nix
│
├── hyprland.nix                 # Hyprland compositor + keybinds
├── waybar.nix                   # Status bar
├── kitty.nix                    # Terminal config
├── swaync.nix                   # Notification center
├── nvim.nix                     # Neovim + LSPs
│
├── docs/
│   ├── system-overview.md       # NixOS architecture reference
│   ├── secrets-management.md    # API key handling
│   └── providers.md             # OpenClaude provider & model guide
│
├── dotfiles/                    # Dotfiles symlinked by Home Manager
└── scripts/                     # Utility scripts
```

## Applying Changes

```bash
nr    # Decrypt secrets, stage changes, run nixos-rebuild switch
```

## AI Agent (OpenClaude)

OpenClaude (`openclaude`) is installed globally via npm. It uses the OpenAI-compatible
provider mode — no patching required.

```bash
oc               # Launch with default provider (Gemini 2.5 Flash)
oc-groq          # Launch with Groq (Llama 3.3 70B)
oc-cerebras      # Launch with Cerebras (Qwen 3 235B)
oc-gemini-pro    # Launch with Gemini 2.5 Pro
oc-nemotron      # Launch with OpenRouter / Nvidia Nemotron
```

See [docs/providers.md](./docs/providers.md) for the full provider and model reference.

## Secrets

All API keys live in `secrets.nix` (decrypted from `secrets.nix.age` via age).
Edit `home.nix` to add or update keys, then run `nr`.

See [docs/secrets-management.md](./docs/secrets-management.md) for details.

---
*NixOS Environment — April 2026*
