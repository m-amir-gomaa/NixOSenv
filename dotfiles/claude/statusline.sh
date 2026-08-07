#!/bin/bash
# Combined Claude Code statusline: caveman badge + live model + DeepSeek balance.
#
# Reads statusline JSON from stdin — model.id is the RESOLVED live model
# (deepseek-v4-pro[1m] during plan mode, deepseek-v4-flash otherwise).
# Caveman badge logic inlined from the caveman plugin (decoupled from its
# plugin-cache path, which is not stable across updates).
# Balance polled from DeepSeek API once per cache TTL, then served from
# ${CLAUDE_CONFIG_DIR:-~/.claude}/.deepseek-balance — never per keystroke.
#
# Wire-up (settings.local.json):
#   "statusLine": {
#     "type": "command",
#     "command": "bash ~/NixOSenv/dotfiles/claude/statusline.sh",
#     "refreshInterval": 300
#   }

set -u

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
out=""

# --- Caveman badge (inlined) ---
FLAG="${CONFIG_DIR}/.caveman-active"
if [ ! -L "$FLAG" ] && [ -f "$FLAG" ]; then
  MODE=$(head -c 64 "$FLAG" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]')
  MODE=$(printf '%s' "$MODE" | tr -cd 'a-z0-9-')
  case "$MODE" in
    off|lite|full|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra|commit|review|compress) ;;
    *) MODE="" ;;
  esac
  if [ -n "$MODE" ]; then
    if [ "$MODE" = "full" ]; then
      out="${out}\033[38;5;172m[CAVEMAN]\033[0m"
    else
      out="${out}\033[38;5;172m[CAVEMAN:$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')]\033[0m"
    fi
  fi
fi

# --- Live model from stdin JSON ---
MODEL_ID=$(python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    m = d.get("model") or {}
    print(m.get("id", ""))
except Exception:
    print("")' 2>/dev/null)

case "$MODEL_ID" in
  *deepseek-v4-pro*)   MODEL_LABEL="\033[38;5;203m[PRO]\033[0m" ;;
  *deepseek-v4-flash*) MODEL_LABEL="\033[38;5;114m[FLASH]\033[0m" ;;
  "")                  MODEL_LABEL="" ;;
  *)                   MODEL_LABEL="[${MODEL_ID}]" ;;
esac

# --- DeepSeek balance (cached) ---
BAL=""
BAL_FILE="${CONFIG_DIR}/.deepseek-balance"
CACHE_TTL=300
now=$(date +%s)
if [ -f "$BAL_FILE" ]; then
  read -r ts b < "$BAL_FILE" 2>/dev/null
  if [ $((now - ts)) -lt $CACHE_TTL ] && [ -n "$b" ]; then
    BAL="$b"
  fi
fi
if [ -z "$BAL" ] && [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  RESP=$(curl -s -m 8 https://api.deepseek.com/user/balance \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
    -H "Accept: application/json")
  BAL=$(printf '%s' "$RESP" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin)["balance_infos"][0]["total_balance"])
except Exception:
    print("")' 2>/dev/null)
  if [ -n "$BAL" ]; then
    printf '%s %s' "$(date +%s)" "$BAL" > "$BAL_FILE"
  fi
fi

# --- Render one line ---
[ -n "$out" ] && printf '%b' "$out"
[ -n "$MODEL_LABEL" ] && printf ' %b' "$MODEL_LABEL"
[ -n "$BAL" ] && printf ' \033[38;5;220m$%s\033[0m' "$BAL"
printf '\n'
