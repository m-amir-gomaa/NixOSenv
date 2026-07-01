# Home Manager

Home Manager is the user-space layer of the declarative stack. While `configuration.nix` owns the OS (kernel, system services, hardware), **Home Manager owns everything inside `/home/qwerty/`** — shell config, GUI themes, dotfiles, session variables, and user packages.

---

## 📐 How It Plugs Into the Flake

Home Manager is wired directly into `flake.nix` as a NixOS module, **not** run as a standalone tool. This means it is applied automatically every time you run `nr` (nixos-rebuild switch) — no separate `home-manager switch` command is needed.

```
flake.nix
 └── nixosConfigurations.nixos
       └── modules
             └── home-manager.nixosModules.home-manager
                   └── home-manager.users.qwerty = ./home.nix  ← entry point
```

Because it runs as a NixOS module, the entire system (OS + user environment) rebuilds atomically in one step.

---

## 🏠 Entry Point: `home.nix`

[`home.nix`](../home.nix) is the root Home Manager configuration file for the `qwerty` user. It pulls in all user-facing modules via `imports`:

```nix
imports = [
  ./nvim.nix       # Neovim + LSPs
  ./kitty.nix      # Terminal emulator config
  ./hyprland.nix   # Wayland compositor + keybinds
  ./waybar.nix     # Status bar
  ./swaync.nix     # Notification daemon
];
```

Each of those files uses Home Manager options (`programs.*`, `services.*`, `home.file.*`) to declaratively manage its piece of the user environment.

---

## ⚙️ Key Configuration Areas

### 1. Session Variables (`home.sessionVariables`)

Environment variables exported into every login shell. Currently sets:

| Variable | Value | Purpose |
|---|---|---|
| `XDG_SESSION_TYPE` | `wayland` | Enforces Wayland protocol |
| `MOZ_ENABLE_WAYLAND` | `1` | Firefox native Wayland |
| `GTK_THEME` | `Adwaita:dark` | GTK dark mode |
| `OPENAI_API_KEY` | `ollama` | Dummy auth key for local Ollama |
| `OPENAI_BASE_URL` | `http://localhost:11434/v1` | Local Ollama endpoint |
| `OPENAI_MODEL` | `qwen2.5-coder:14b` | Default local model (used by Ollama and aliases) |

> **Important**: These variables are written into the shell init file during activation. They are **not** live-editable — changes require a rebuild (`nr`).

---

### 2. Shell Aliases (`programs.zsh.shellAliases`)

All shell aliases are declared here, not in a hand-edited `.zshrc`. Key aliases:

| Alias | Command | Purpose |
|---|---|---|
| `nr` | `age -d ... && sudo nixos-rebuild switch --flake ...` | Full system + HM rebuild |
| `nrb` | Same, with `boot` | Stage changes for next boot |
| `vs` | `cd ~/NixOSenv/ && nvim` | Quick config editor |
| `ai` | `opencode -m ollama/qwen2.5-coder:14b` | Local AI agent |
| `ai-gemma` | LM Studio Wayland-wrapped command | LM Studio backend launcher |
| `lmstudio` | `lm-studio --ozone-platform-hint=auto` | LM Studio under Wayland |

---

### 3. Dotfile Symlinks (`home.file`)

Home Manager can place files anywhere under `$HOME` by declaring them as `home.file` entries. These become **immutable symlinks** into the Nix store:

```nix
# Example from home.nix:
home.file.".p10k.zsh".source = ./dotfiles/zsh/.p10k.zsh;
home.file.".config/sioyek/prefs_user.config".text = ''…'';
```

> **Never edit these files directly.** They are owned by the Nix store. Edit the source in `~/NixOSenv/` and run `nr`.

---

### 4. GUI Theming

Home Manager drives the full dark-mode theme stack declaratively:

- **GTK 3/4** (`gtk.*`): `adw-gtk3-dark` theme, `Adwaita` icons/cursor.
- **Qt** (`qt.*`): `adwaita-dark` style via `adwaita-qt` package, platform theme bridged to GTK3.
- **dconf** (`dconf.settings`): Forces GNOME's `prefer-dark` colour scheme so libadwaita apps pick it up automatically.

---

### 5. Managed Programs

Programs declared under `programs.*` are fully managed: Home Manager installs the package **and** writes its config. Currently managed:

| Program | Config Location |
|---|---|
| `programs.zsh` | Shell init, plugins, aliases, history |
| `programs.oh-my-zsh` | Plugins: `sudo`, `git`, `colored-man-pages`, `bgnotify` |
| `programs.fzf` | Fuzzy finder with Zsh integration (Ctrl+R, Ctrl+T, Alt+C) |
| `programs.rofi` | App launcher with custom dark theme |
| `programs.vscode` | Extensions + user settings |
| `programs.home-manager` | Enables HM to manage itself |

---

## 🔄 Applying Changes

All Home Manager changes go through the same single command as system changes:

```bash
nr
```

This alias (defined in `home.nix` itself) expands to:

```bash
age -d -i ~/.age-key.txt ~/NixOSenv/secrets.nix.age > ~/NixOSenv/secrets.nix \
  && cd ~/NixOSenv \
  && git add . \
  && sudo nixos-rebuild switch --flake path:/home/qwerty/NixOSenv#nixos
```

The rebuild will:
1. Decrypt secrets.
2. Stage all changes.
3. Evaluate `flake.nix`, which pulls in `home.nix` and all its imports.
4. Rewrite all managed symlinks and config files atomically.
5. Activate the new user generation.

---

## ⚠️ The Golden Rules

1. **Never edit `~/.zshrc` directly.** It is a symlink into the Nix store and will be overwritten on the next rebuild. Put shell customisation in `programs.zsh` in `home.nix`, or in `~/NixOSenv/dotfiles/zsh/.zshrc` (which is sourced at the end of the generated init file).

2. **Never edit `~/.config/` files that are Nix-managed.** Same reason — they are store symlinks. Identify the `home.file` or `programs.*` entry in `home.nix` that owns the file and edit it there.

3. **Adding a package?** User packages belong in `home.packages` inside `home.nix`, not in `environment.systemPackages` in `configuration.nix` (which is for system-wide, root-accessible tools).

4. **Checking the active generation**: Run `home-manager generations` to list all past builds and roll back if needed.

---

## 🗂️ Related Docs

- [System Overview](./system-overview.md) — OS-level architecture and the rebuild mechanism.
- [Secrets Management](./secrets-management.md) — How `age`-encrypted secrets flow through the build.
- [Providers](./providers.md) — Local AI provider aliases defined in `shellAliases`.
