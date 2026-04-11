#!/usr/bin/env bash
# update-openclaude.sh — Update OpenClaude to latest version
# ────────────────────────────────────────────────────────────────────────────
# No patching required — openclaude natively supports all providers via
# CLAUDE_CODE_USE_OPENAI=1 + OPENAI_* env vars. See home.nix for the full
# provider alias list (oc-gemini, oc-groq, oc-cerebras, etc.).
# ────────────────────────────────────────────────────────────────────────────

set -e

echo "🚀 Updating OpenClaude..."
npm install -g --prefix ~/.npm-global @gitlawb/openclaude

echo "✅ OpenClaude updated. Current version:"
openclaude --version 2>/dev/null || true
