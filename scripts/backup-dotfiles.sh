#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:-/THE_VAULT/backups/dotfiles}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "Backing up ~/.config..."
tar -czf "$BACKUP_DIR/config_${TIMESTAMP}.tar.gz" -C ~ .config
echo "  -> $BACKUP_DIR/config_${TIMESTAMP}.tar.gz"

echo "Backing up ~/NixOSenv/dotfiles..."
tar -czf "$BACKUP_DIR/nixosenv_dotfiles_${TIMESTAMP}.tar.gz" -C ~/NixOSenv dotfiles
echo "  -> $BACKUP_DIR/nixosenv_dotfiles_${TIMESTAMP}.tar.gz"

echo "Done. Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}.tar.gz
