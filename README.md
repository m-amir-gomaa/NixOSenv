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
│   └── providers.md             # OpenCode provider & model guide
│
├── dotfiles/                    # Dotfiles symlinked by Home Manager
└── scripts/                     # Utility scripts
```

## Applying Changes

```bash
nr    # Decrypt secrets, stage changes, run nixos-rebuild switch
```

## AI Agent (OpenCode)

`opencode` is installed globally via npm (`opencode-ai`). Config lives in
`~/.config/opencode/config.json` — providers, MCP servers and the agent prompt
are all declared there.

```bash
ai               # Launch with default model (qwen2.5-coder:14b via Ollama)
ai-gemini        # Google Gemini 2.5 Flash
ai-groq          # Groq  — llama3-70b-8192
oc-qwen          # same as ai, opencode -m ollama/qwen2.5-coder:14b
oc-deepseek      # opencode -m ollama/deepseek-r1:14b
oc-models        # list all locally available Ollama + LM Studio models
```

See [docs/providers.md](./docs/providers.md) for the full provider and model reference.

## Secrets

All API keys live in `secrets.nix` (decrypted from `secrets.nix.age` via age).
Edit `home.nix` to add or update keys, then run `nr`.

See [docs/secrets-management.md](./docs/secrets-management.md) for details.

---
*NixOS Environment — April 2026*
