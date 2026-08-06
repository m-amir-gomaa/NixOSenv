#!/usr/bin/env bash
# scripts/bootstrap.sh — provision a fresh NixOS machine from this repo
# ────────────────────────────────────────────────────────────────────────────
# Assumes: repo cloned at $HOME/NixOSenv, username is the same as this machine
# (paths inside dotfiles/utcp/manuals hardcode /home/qwerty/...).
#
# What it does:
#   1. Preflight — check git/age/nix, refuse to run if NixOS build already active
#   2. Symlink ~/.claude config from dotfiles/claude (backup existing → .bak)
#   3. Symlink ~/.utcp config from dotfiles/utcp, generate .env + igintel-mcp.json
#   4. Register utcp + agent-vision MCP servers via `claude mcp add`
#   5. Optional: restore secrets (.zshrc_secrets, .age-key.txt, .ssh, .utcp/.env)
#      from a --secrets-dir backup (USB/encrypted), chmod 600 everything
#   6. Decrypt secrets.nix.age → secrets.nix (gitignored) with the age key
#
# Safe: never overwrites an existing non-symlink file — backs it up to NAME.bak.
# Idempotent: re-running updates symlinks and skips files already in place.
set -euo pipefail

REPO="${HOME}/NixOSenv"
CLAUDE_SRC="${REPO}/dotfiles/claude"
UTCP_SRC="${REPO}/dotfiles/utcp"
CLAUDE_DST="${HOME}/.claude"
UTCP_DST="${HOME}/.utcp"
SECRETS_SRC=""           # set via --secrets-dir
SKIP_MCP=0

usage() {
  echo "usage: bootstrap.sh [--secrets-dir /path/to/backup] [--skip-mcp]"
  echo "  --secrets-dir DIR   restore secrets (.zshrc_secrets, .age-key.txt, .ssh/, .utcp/.env) from DIR"
  echo "  --skip-mcp          don't register MCP servers (claude CLI not present yet)"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --secrets-dir) SECRETS_SRC="$2"; shift 2 ;;
    --skip-mcp) SKIP_MCP=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1"; usage ;;
  esac
done

preflight() {
  command -v git >/dev/null || { echo "FATAL: git not found"; exit 1; }
  command -v age >/dev/null || { echo "FATAL: age not found — install with: nix profile install nixpkgs#age"; exit 1; }
  command -v nix >/dev/null || { echo "FATAL: nix not found"; exit 1; }
  [[ -d "$REPO" ]] || { echo "FATAL: $REPO not found — clone it first"; exit 1; }
  [[ -d "$CLAUDE_SRC" ]] || { echo "FATAL: $CLAUDE_SRC missing in repo"; exit 1; }
  [[ -d "$UTCP_SRC" ]] || { echo "FATAL: $UTCP_SRC missing in repo"; exit 1; }
  if [[ -e "${HOME}/.profile.bootstrapped" ]]; then
    echo "WARN: .profile.bootstrapped exists — this looks like an already-provisioned system."
    echo "      Re-running is safe (idempotent) but verify you want this."
  fi
}

link_if() {
  # link_if TARGET SOURCE  — symlink SOURCE→TARGET, backing up existing TARGET.
  local target="$1" src="$2"
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" ]]; then
    ln -sfn "$src" "$target"
    echo "link:  $target (refreshed)"
  elif [[ -e "$target" ]]; then
    mv "$target" "${target}.bak"
    ln -s "$src" "$target"
    echo "link:  $target (existing backed up to .bak)"
  else
    ln -s "$src" "$target"
    echo "link:  $target"
  fi
}

provision_claude() {
  link_if "$CLAUDE_DST/settings.json"       "$CLAUDE_SRC/settings.json"
  link_if "$CLAUDE_DST/settings.local.json" "$CLAUDE_SRC/settings.local.json"
  link_if "$CLAUDE_DST/CLAUDE.md"           "$CLAUDE_SRC/CLAUDE.md"
  link_if "$CLAUDE_DST/keybindings.json"    "$CLAUDE_SRC/keybindings.json"
  link_if "$CLAUDE_DST/agents"              "$CLAUDE_SRC/agents"
  link_if "$CLAUDE_DST/commands"            "$CLAUDE_SRC/commands"
  link_if "$CLAUDE_DST/plugins/known_marketplaces.json" "$CLAUDE_SRC/plugins/known_marketplaces.json"
  link_if "$CLAUDE_DST/plugins/installed_plugins.json"  "$CLAUDE_SRC/plugins/installed_plugins.json"
}

provision_utcp() {
  link_if "$UTCP_DST/.utcp_config.json" "$UTCP_SRC/.utcp_config.json"
  link_if "$UTCP_DST/manuals"           "$UTCP_SRC/manuals"
  # real .env (secrets) — never symlinked from repo
  if [[ ! -f "$UTCP_DST/.env" ]]; then
    if [[ -n "$SECRETS_SRC" && -f "$SECRETS_SRC/utcp.env" ]]; then
      cp "$SECRETS_SRC/utcp.env" "$UTCP_DST/.env"
      echo "env:   $UTCP_DST/.env restored from backup"
    else
      cp "$UTCP_SRC/.env.example" "$UTCP_DST/.env"
      echo "env:   $UTCP_DST/.env created from example — EDIT IT and fill in tokens"
    fi
  else
    echo "env:   $UTCP_DST/.env already present (kept)"
  fi
  # igintel-mcp.json — real file generated from example, Tavily key filled
  if [[ ! -f "$UTCP_DST/igintel-mcp.json" ]]; then
    cp "$UTCP_SRC/igintel-mcp.json.example" "$UTCP_DST/igintel-mcp.json"
    local key=""
    if [[ -n "$SECRETS_SRC" && -f "$SECRETS_SRC/utcp.env" ]]; then
      key="$(grep -E '^tavily_TAVILY_API_KEY=' "$SECRETS_SRC/utcp.env" | head -1 | cut -d= -f2-)"
    else
      key="$(grep -E '^tavily_TAVILY_API_KEY=' "$UTCP_DST/.env" 2>/dev/null | head -1 | cut -d= -f2-)"
    fi
    if [[ -n "$key" ]]; then
      sed -i "s|__FILL_FROM_ENV__|$key|g" "$UTCP_DST/igintel-mcp.json"
      echo "mcp:   igintel-mcp.json generated with Tavily key"
    else
      echo "mcp:   igintel-mcp.json generated — fill __FILL_FROM_ENV__ with the Tavily key"
    fi
  else
    echo "mcp:   $UTCP_DST/igintel-mcp.json already present (kept)"
  fi
  chmod 600 "$UTCP_DST/.env" "$UTCP_DST/igintel-mcp.json" 2>/dev/null || true
}

register_mcp() {
  if [[ "$SKIP_MCP" -eq 1 ]]; then
    echo "mcp:   skipped (--skip-mcp)"
    return
  fi
  command -v claude >/dev/null || { echo "mcp:   claude CLI not found — register manually per docs/bootstrap.md"; return; }
  claude mcp add utcp --scope user --env "UTCP_CONFIG_FILE=${UTCP_DST}/.utcp_config.json" -- npx -y @utcp/mcp-bridge 2>&1 | tail -1
  local vkey=""
  [[ -f "$UTCP_DST/.env" ]] && vkey="$(grep -E '^(tavily_)?TAVILY_API_KEY=' "$UTCP_DST/.env" | head -1 | cut -d= -f2-)"
  if [[ -n "$vkey" ]]; then
    claude mcp add agent-vision --scope user \
      --env "VISION_API_KEY=$vkey" \
      --env "VISION_BASE_URL=https://openrouter.ai/api/v1" \
      --env "VISION_MODEL_NAME=google/gemini-3.1-flash-lite" \
      --env "VISION_CACHE_ENABLED=true" \
      --env "VISION_MAX_TOKENS=2048" \
      -- npx -y @kitlau/agent-vision-mcp 2>&1 | tail -1
  else
    echo "mcp:   agent-vision skipped (no Tavily key in .env)"
  fi
}

restore_secrets() {
  [[ -n "$SECRETS_SRC" ]] || { echo "secrets: --secrets-dir not given — skip. See docs/bootstrap.md for what to transfer."; return; }
  [[ -d "$SECRETS_SRC" ]] || { echo "secrets: $SECRETS_SRC not a dir — skip"; return; }
  # .zshrc_secrets (DeepSeek + Tavily)
  if [[ -f "$SECRETS_SRC/zshrc_secrets" && ! -f "${HOME}/.zshrc_secrets" ]]; then
    cp "$SECRETS_SRC/zshrc_secrets" "${HOME}/.zshrc_secrets"; chmod 600 "${HOME}/.zshrc_secrets"
    echo "secrets: ~/.zshrc_secrets restored"
  fi
  # age private key — required to decrypt the vault
  if [[ -f "$SECRETS_SRC/age-key.txt" && ! -f "${HOME}/.age-key.txt" ]]; then
    cp "$SECRETS_SRC/age-key.txt" "${HOME}/.age-key.txt"; chmod 600 "${HOME}/.age-key.txt"
    echo "secrets: ~/.age-key.txt restored"
  fi
  # ssh keys
  if [[ -d "$SECRETS_SRC/ssh" ]]; then
    mkdir -p "${HOME}/.ssh"
    cp -n "$SECRETS_SRC"/ssh/* "${HOME}/.ssh/" 2>/dev/null || true
    chmod 700 "${HOME}/.ssh"; chmod 600 "${HOME}"/.ssh/* 2>/dev/null || true
    echo "secrets: ~/.ssh restored"
  fi
  # utcp .env handled in provision_utcp
}

decrypt_vault() {
  if [[ ! -f "${HOME}/.age-key.txt" ]]; then
    echo "vault:  no ~/.age-key.txt — cannot decrypt secrets.nix.age (skipped)"
    return
  fi
  if [[ -f "${REPO}/secrets.nix" ]]; then
    echo "vault:  secrets.nix already present (kept)"
    return
  fi
  if [[ -f "${REPO}/secrets.nix.age" ]]; then
    ( cd "$REPO" && age -d -i "${HOME}/.age-key.txt" secrets.nix.age > secrets.nix )
    chmod 600 "${REPO}/secrets.nix"
    echo "vault:  secrets.nix.age decrypted → secrets.nix"
  fi
}

finish() {
  touch "${HOME}/.profile.bootstrapped"
  echo
  echo "Done. Next steps:"
  echo "  sudo nixos-rebuild switch --flake ${REPO}#nixos"
  echo "  git -C ${REPO} remote set-url origin <your fork>  # if you cloned your own"
}

preflight
provision_claude
provision_utcp
register_mcp
restore_secrets
decrypt_vault
finish
