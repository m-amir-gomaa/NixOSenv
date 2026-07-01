#!/usr/bin/env bash

# Rofi Custom Script Mode: Recursive Home Search
# ────────────────────────────────────────────────────────────────────────────
# This script is called twice by Rofi:
#   1. Without arguments: It outputs the list of all files in $HOME.
#   2. With an argument: It receives the user's selection and opens it.
# ────────────────────────────────────────────────────────────────────────────

# Define directories to ignore (junk/system/cluttered)
# NOTE: We use --no-ignore-vcs so that .gitignore files in sub-repos
# (e.g. ~/Learning_medical which ignores input-library/) do NOT hide
# real user files from search. Our manual EXCLUDES list handles noise.
EXCLUDES=(
    ".git"
    ".cache"
    ".mozilla"
    ".npm"
    ".cargo"
    ".rustup"
    "node_modules"
    ".local/share"
    ".local/state"
    ".config/google-chrome"
    ".config/Code"
    ".local/share/direnv"
    ".claude"
    ".claude-flow"
    ".stfolder"
    ".kaggle_tmp"
    "/nix/store"
    ".terraform"
    "__pycache__"
    ".venv"
    "venv"
    "target"
    "result"
    ".direnv"
    ".antigravity"
    ".gemini"
    ".sov-memory"
    ".mempalace"
    ".flow-nexus"
    ".gitlawb"
    ".opencode"
    ".kaggle"
    ".nix-defexpr"
    ".pki"
    ".ssh"
    "NixOSenv.bak"
    ".config/Antigravity"
    ".config/discord"
    ".config/Microsoft"
    ".config/wasistlos"
    ".config/Ultralytics"
    ".config/obs-studio"
    ".config/syncthing"
    ".config/dconf"
    ".config/pulse"
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".config/fontconfig"
    ".config/systemd"
    ".config/matplotlib"
    ".local/share/Trash"
    ".local/share/gvfs-metadata"
    ".local/share/tracker"
    ".local/share/webkitgtk"
)

# Build the 'fd' command dynamically
# -L:              follow symlinks (essential for many NixOS home patterns)
# --type f:        only files
# --hidden:        include dotfiles
# --no-ignore-vcs: do NOT respect .gitignore/.git/info/exclude rules;
#                  prevents sub-repos (e.g. Learning_medical) from hiding
#                  their own files (input-library/ is gitignored there).
CMD="/run/current-system/sw/bin/fd -L --type f --hidden --no-ignore-vcs --exclude '*.log'"
for item in "${EXCLUDES[@]}"; do
    CMD+=" --exclude '$item'"
done
CMD+=" . '/home/qwerty'"

# Exec 'fd' with the built command
eval "$CMD"
