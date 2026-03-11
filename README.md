# NixOS & Jarvis Ecosystem Guide ❄️🦾

Welcome to your declarative NixOS environment. This repository (`~/NixOSenv`) manages your entire system state, user applications, and the Jarvis AI ecosystem.

---

## 📂 Repository Structure

| Path | Purpose |
| :--- | :--- |
| `flake.nix` | The entrypoint for the entire system. Pins versions and defines inputs. |
| `configuration.nix` | System-level settings: Bootloader, Hardware, Networking, and Core packages. |
| `home.nix` | **Your Personal Environment**: Managed via Home Manager. Covers Zsh, Hyprland, and theming. |
| `modules/jarvis.nix` | Declarative service definition for all Jarvis background processes. |
| `dotfiles/` | Raw configuration files (e.g., `.p10k.zsh`) symlinked into your home directory via Nix. |
| `Jarvis/` | The core Jarvis codebase (synced to GitHub). |

---

## 🐚 How to Edit Zsh Configuration (Declarative)

Your Zsh environment is now **100% managed via Nix**. Do **NOT** edit `~/.zshrc` directly, as it will be overwritten on the next rebuild.

### 1. Adding Aliases
Open `home.nix` and find the `programs.zsh.shellAliases` block. Add your alias there:
```nix
shellAliases = {
  myalias = "command --flag";
};
```

### 2. Adding Oh-My-Zsh Plugins
Find the `programs.zsh.oh-my-zsh.plugins` list in `home.nix`:
```nix
plugins = [ "sudo" "git" "fzf-tab" "my-new-plugin" ];
```

### 3. Environment Variables & PATH
Add logic to the `programs.zsh.initContent` block (Nix multiline string):
```nix
initContent = ''
  export MY_VAR="value"
  export PATH="$PATH:/my/custom/path"
'';
```

### 4. Applying Changes
After editing `home.nix`, run the system rebuild alias:
```bash
nr
```
*Note: `nr` is a custom alias defined in `home.nix` that commits your changes and runs `nixos-rebuild switch`.*

---

## 🤖 Jarvis Integration

Jarvis is integrated into your Nix system as a background service.

- **Dashboard**: Run `jarvis dashboard` to see system health and AI activity in high-contrast.
- **Learning**: `jarvis learn <url> --category my-topic` to ingest knowledge.
- **Autocomplete**: Use `<Tab>` with any `jarvis` command to use the fuzzy `fzf` selector for subcommands and database entries.

### Manual Data Backups
Large files (indexes and results) are **NOT** in the Nix repository. See the **[Backup Guide](file:///THE_VAULT/jarvis/docs/BACKUP_GUIDE.md)** for detailed locations of:
- Hierarchical RAG Database
- Episodic Indexed Files
- Episodic Memory Logs

---

## 🚀 Common Maintenance Commands

- `nr`: Rebuild and switch to the latest configuration.
- `lysander-git`: Configure local git for Lysandercodes profile.
- `hb` / `hn` / `hp`: Hugo blog build, new post, and deploy shortcuts.

---
## 📚 Git Repository Management

The NixOS configuration repository and the Jarvis codebase are version‑controlled with Git.

### NixOS Configuration (root of the repository)

- The top‑level directory (`/home/qwerty/NixOSenv`) is a regular Git repository.
- Use the provided `lysander-git` alias for common actions (adds, commits, pushes) with your Lysandercodes profile.
- Example workflow:
  ```bash
  lysander-git status
  lysander-git add .
  lysander-git commit -m "Update NixOS config"
  lysander-git push
  ```

### Jarvis Sub‑repository

The `Jarvis/` directory is a separate Git repository that lives inside the NixOS repo.

- It has its own remote and history, allowing independent development.
- Typical commands:
  ```bash
  cd Jarvis
  git status
  git add .
  git commit -m "Improve Jarvis feature"
  git push origin main
  ```
- When making changes to both repositories, commit them separately to keep histories clean.

### Keeping the two repos in sync

- After committing changes in `Jarvis/`, return to the root and commit the updated submodule pointer (if you use submodules) or simply commit the updated `Jarvis/` directory if it’s a regular folder.
- Example:
  ```bash
  cd /home/qwerty/NixOSenv
  lysander-git add Jarvis
  lysander-git commit -m "Update Jarvis subdirectory"
  lysander-git push
  ```

Following these steps ensures a clean history for both the NixOS configuration and the Jarvis codebase.

*Created and maintained by Jarvis with an Antigravity-like AI layer.*
