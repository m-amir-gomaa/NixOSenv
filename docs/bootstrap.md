# Bootstrap a New Machine from this Repo

Full-system reproduction guide. The repo is the single source of truth for the
NixOS config, dotfiles, Claude Code config (`dotfiles/claude`), UTCP bridge
config (`dotfiles/utcp`), and disk layout (`disko.nix`). Secret material is
**never** in the repo — it is transferred out-of-band (see [Secrets](#secrets)).

> ⚠️ **disko wipes the target disk.** This guide targets a **brand-new** machine.
> Never run the disko step against a machine you want to keep.

## Machine-specific things to regenerate (NOT in the repo)

| Item | What to do |
|---|---|
| `hardware-configuration.nix` | Regenerate: `nixos-generate-config --root /mnt` (installer) or on a booted system `nixos-generate-config` |
| hostname | `configuration.nix` has `networking.hostName = "nixos"` — change if wanted |
| `/THE_VAULT` data disk | `sda` mount is in `hardware-configuration.nix` by UUID — re-mount after install |
| username `qwerty` | UTCP manuals + `instascript.nix` hardcode `/home/qwerty/...` — keep the user `qwerty`, or sed-replace |
| NVIDIA PCI bus IDs | `configuration.nix` prime settings — verify against the new laptop |

## Full flow (from the NixOS installer ISO)

```bash
# 0. Partition + format the OS disk (nvme0n1) — sda/THE_VAULT untouched
#    (run inside the cloned repo so the pinned disko is used)
sudo nix run .#disko -- --mode disko ./disko.nix

# 1. Generate hardware config for the mounted system
sudo nixos-generate-config --root /mnt

# 2. Install
sudo nixos-install --flake ~/NixOSenv#nixos
```

If you need the repo on the ISO first:
`git clone git@github.com:m-amir-gomaa/NixOSenv.git ~/NixOSenv`
(no SSH keys yet? `gh repo clone m-amir-gomaa/NixOSenv` via HTTPS, or copy the
repo over USB.)

## After first boot

```bash
# 3. Place secrets first (they are NOT in the repo). If you have a backup dir
#    from the old machine (e.g. a USB stick), restore everything at once:
bash ~/NixOSenv/scripts/bootstrap.sh --secrets-dir /mnt/usb/my-backup

#    …or restore secrets manually, then provision configs:
bash ~/NixOSenv/scripts/bootstrap.sh
```

`bootstrap.sh` does, idempotently and safely (existing files → `.bak`):

- Symlinks `~/.claude/{settings.json,settings.local.json,CLAUDE.md,keybindings.json,agents,commands,plugins/*}` → `dotfiles/claude/`
- Symlinks `~/.utcp/{.utcp_config.json,manuals}` → `dotfiles/utcp/`; creates `~/.utcp/.env` + `~/.utcp/igintel-mcp.json`
- Registers the `utcp` and `agent-vision` MCP servers in Claude Code (`claude mcp add`)
- Restores `~/.zshrc_secrets`, `~/.age-key.txt`, `~/.ssh/` from `--secrets-dir` (chmod 600)
- Decrypts `secrets.nix.age` → `secrets.nix` using the age key

```bash
# 4. Rebuild
nr    # sudo nixos-rebuild switch --flake ~/NixOSenv#nixos
```

## Secrets

What a new machine needs, transferred **out-of-band** (USB / encrypted), and
never committed:

| File | Contents | Restored by bootstrap from |
|---|---|---|
| `~/.zshrc_secrets` | `DEEPSEEK_API_KEY`, `TAVILY_API_KEY` | `--secrets-dir/zshrc_secrets` |
| `~/.age-key.txt` | age private key — decrypts `secrets.nix.age` | `--secrets-dir/age-key.txt` |
| `~/.ssh/id_ed25519` (+`.pub`, `id_ed25519_anon`) | GitHub push keys | `--secrets-dir/ssh/` |
| `~/.utcp/.env` | GitHub/GitLab/Figman tokens | `--secrets-dir/utcp.env` |
| `~/.config/autocommit/secrets.env` | auto-commit OpenAI key (optional) | manual |

Everything else is public in the repo: `secrets.nix.age` (encrypted vault),
`dotfiles/zsh/.zshrc_secrets.example`, UTCP templates, all Nix config.

## Neovim

`nvim.nix` symlinks to `~/nvim`, which is its **own git repo**
(`github.com:m-amir-gomaa/nvim`). After install:

```bash
git clone git@github.com:m-amir-gomaa/nvim.git ~/nvim
```

## Deferred security work

The private age key was previously committed to this repo's git history
(2026-08-06: scrubbed via history rewrite; working copy + `~/.age-key.txt`
still valid). Because the key briefly lived in a pushed repo, **rotate the 12
API keys in `secrets.nix.age` and the OpenRouter/Tavily/GitHub tokens at your
earliest convenience.** Procedure:
1. Decrypt: `age -d -i ~/.age-key.txt secrets.nix.age > secrets.nix`
2. Edit keys → rotate each on its provider dashboard
3. Re-encrypt: `age -r $(age-keygen -y ~/.age-key.txt) secrets.nix > secrets.nix.age`
4. Rebuild. `secrets.nix` stays gitignored.
