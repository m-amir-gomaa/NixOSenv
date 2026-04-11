#!/usr/bin/env bash
# update-ruflo.sh — Sovereign Orchestration Update Script
# Updates Ruflo via NPM.

set -e

# Use the same prefix as home.nix defines for the user
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

echo "🚀 Updating Ruflo to latest..."
npm install -g ruflo

echo "✅ Ruflo updated."
ruflo --version
