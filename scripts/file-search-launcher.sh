#!/usr/bin/env bash

# File Search Launcher (with logging)
# ----------------------------------------------------------------------------
LOG_FILE="/home/qwerty/NixOSenv/scripts/file-search-launcher.log"
echo "--- Search Started $(date) ---" >> "$LOG_FILE"

# Paths to dependencies (Hardcoded for maximum reliability)
ROFI_BIN="/etc/profiles/per-user/qwerty/bin/rofi"
XDG_OPEN_BIN="/run/current-system/sw/bin/xdg-open"
SETSID_BIN="/run/current-system/sw/bin/setsid"
XARGS_BIN="/run/current-system/sw/bin/xargs"
FIND_SCRIPT="/home/qwerty/NixOSenv/scripts/rofi-find.sh"

# 1. Run the find script
# 2. Rofi selection
# 3. Handle selection and log errors
SELECTED=$("$FIND_SCRIPT" | "$ROFI_BIN" -dmenu -i -p "Open file")

if [ -n "$SELECTED" ]; then
    echo "Selected: $SELECTED" >> "$LOG_FILE"
    # Use setsid to detach
    "$SETSID_BIN" "$XDG_OPEN_BIN" "$SELECTED" >/dev/null 2>&1 &
    disown
else
    echo "No selection made." >> "$LOG_FILE"
fi
