# NixOS Environment

Declarative NixOS configuration for a Hyprland-based laptop (NVIDIA Prime + Intel iGPU).

## Repository Layout

```
~/NixOSenv/
├── flake.nix                    # Flake entrypoint
├── configuration.nix            # System-level config (boot, services, packages)
├── hardware-configuration.nix   # Auto-generated — do not edit
├── disko.nix                    # Declarative disk layout (fresh installs ONLY)
├── home.nix                     # User config (shell, aliases, env vars)
│
├── modules/                     # Reusable Nix modules
│   ├── auto-git-nixosenv.nix
│   ├── autocommit-pkg.nix
│   ├── instascript.nix
│   └── mineru.nix
│
├── hyprland.nix                 # Hyprland compositor + keybinds
├── waybar.nix                   # Status bar
├── kitty.nix                    # Terminal config
├── swaync.nix                   # Notification center
├── nvim.nix                     # Neovim + LSPs
│
├── docs/
│   ├── bootstrap.md             # ★ New-machine setup guide
│   ├── system-overview.md       # NixOS architecture reference
│   └── providers.md             # OpenCode provider & model guide
│
├── dotfiles/                    # Dotfiles symlinked by Home Manager
│   ├── claude/                  # Global Claude Code config (settings, agents, keybindings)
│   ├── utcp/                    # UTCP MCP bridge config + .env.example + igintel-mcp example
│   └── zsh/
│       ├── .zshrc               # Shell aliases + Claude Code backend switchers
│       └── .zshrc_secrets.example  # Template — copy to ~/.zshrc_secrets
└── scripts/
    ├── bootstrap.sh             # ★ Provision a fresh machine (configs, secrets, MCP)
    └── ...
```

## Applying Changes

```bash
nr    # nixos-rebuild switch --flake ~/NixOSenv#nixos
```

## Claude Code — Model Backend

Direct DeepSeek API via Anthropic-compatible endpoint.
Key stored in `~/.zshrc_secrets` (outside repo, never committed).

```bash
deepseek                # Enable DeepSeek (auto-called on shell start)
claude-status           # Show current backend URL + model
```

### Adding a New Backend

Add a function to `dotfiles/zsh/.zshrc` following this pattern:

```bash
my-backend() {
  export ANTHROPIC_BASE_URL="https://api.provider.com/anthropic"
  export ANTHROPIC_AUTH_TOKEN="$MY_API_KEY"     # from ~/.zshrc_secrets
  export ANTHROPIC_API_KEY="$MY_API_KEY"
  export ANTHROPIC_MODEL="model-id"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="model-id"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="model-id"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="fast-model-id"
  export CLAUDE_CODE_SUBAGENT_MODEL="fast-model-id"
  export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS="1"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
  echo "✅ Switched to My Backend"
}
```

Then add the key to `~/.zshrc_secrets`.

## Secrets

API keys live in `~/.zshrc_secrets` — a file **outside** the NixOSenv repo.
It is never committed, never tracked by git, never read by `nixos-rebuild`.

### Initial Setup

```bash
# Copy the template
cp ~/NixOSenv/dotfiles/zsh/.zshrc_secrets.example ~/.zshrc_secrets

# Edit with real keys
nvim ~/.zshrc_secrets
```

### Layout

```bash
# ~/.zshrc_secrets — NEVER commit this file
export DEEPSEEK_API_KEY="sk-..."    # Primary AI backend
export TAVILY_API_KEY="tvly-..."    # Web search for MCP tools
```

`.zshrc` sources this file at shell init:

```bash
[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets
```

### Key Rotation

```bash
# Edit the file, replace old key with new key
nvim ~/.zshrc_secrets

# Delete old key from provider dashboard
# DeepSeek:  https://platform.deepseek.com/api_keys
# OpenRouter: https://openrouter.ai/keys
# Fireworks:  https://fireworks.ai/api-keys
# Tavily:     https://tavily.com
```

### New Machine Setup

**Full guide: [docs/bootstrap.md](./docs/bootstrap.md)** — from blank disk (disko)
through secrets transfer, `scripts/bootstrap.sh`, and first rebuild.

TL;DR:
```bash
# on the fresh machine, after install + first boot:
bash ~/NixOSenv/scripts/bootstrap.sh --secrets-dir /path/to/usb-backup
nr
```

Secrets (`~/.zshrc_secrets`, `~/.age-key.txt`, `~/.ssh/`, `~/.utcp/.env`) are
the only state not derivable from the repo — transfer them out-of-band (USB,
encrypted transfer). Claude Code + UTCP configs are versioned in
`dotfiles/claude/` and `dotfiles/utcp/` and provisioned by the script.

## AI Agent (OpenCode)

`opencode` is installed globally via npm (`opencode-ai`). Config lives in
`~/.config/opencode/config.json` — providers, MCP servers and the agent prompt
are all declared there.

```bash
ai               # Launch with default model (qwen2.5-coder:14b via Ollama)
ai-gemini        # Google Gemini 2.5 Flash
ai-groq          # Groq — llama3-70b-8192
oc-qwen          # same as ai, opencode -m ollama/qwen2.5-coder:14b
oc-deepseek      # opencode -m ollama/deepseek-r1:14b
oc-models        # list all locally available Ollama + LM Studio models
```

See [docs/providers.md](./docs/providers.md) for the full provider and model reference.

---

_NixOS Environment — July 2026_
