#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# systemd-audit.sh  —  Surface every running, enabled, and masked unit
#                       so you know exactly what is active on your system.
#
# Usage:
#   chmod +x ~/.config/scripts/systemd-audit.sh
#   ~/.config/scripts/systemd-audit.sh          # full system audit
#   ~/.config/scripts/systemd-audit.sh --user   # user session only
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCOPE=""
SCOPE_DESC="SYSTEM"
if [[ "${1:-}" == "--user" ]]; then
  SCOPE="--user"
  SCOPE_DESC="USER SESSION"
fi

HR() { printf '\n%s\n' "══════════════════════════════════════════════════════"; }
H()  { HR; printf '  %s\n' "$*"; HR; }

H "systemd Audit — $SCOPE_DESC — $(date)"

echo
H "① Active & Running services"
# shellcheck disable=SC2086
systemctl $SCOPE list-units --type=service --state=running \
  --no-legend --no-pager \
  | awk '{printf "  %-50s %s\n", $1, $4}'

echo
H "② Enabled (will start at boot / login)"
# shellcheck disable=SC2086
systemctl $SCOPE list-unit-files --type=service --state=enabled \
  --no-legend --no-pager \
  | awk '{printf "  %-50s %s\n", $1, $2}'

echo
H "③ Masked (permanently disabled)"
# shellcheck disable=SC2086
systemctl $SCOPE list-unit-files --type=service --state=masked \
  --no-legend --no-pager \
  | awk '{printf "  %-50s %s\n", $1, $2}'

echo
H "④ Failed units"
# shellcheck disable=SC2086
systemctl $SCOPE list-units --state=failed --no-legend --no-pager \
  | awk '{printf "  %-50s %s %s\n", $1, $3, $4}'

echo
H "⑤ Boot & startup time breakdown"
systemd-analyze
echo
systemd-analyze blame --no-pager | head -20

echo
H "⑥ Critical dependency graph (text)"
# Shows what a given unit needs/wants — change the target as needed
TARGET="${SYSTEMD_AUDIT_TARGET:-multi-user.target}"
if [[ "$SCOPE" != "--user" ]]; then
  echo "  Dependencies of: $TARGET"
  systemctl list-dependencies "$TARGET" --no-pager
fi

echo
H "⑦ Tips"
cat <<'EOF'
  • Disable a service:  sudo systemctl disable --now <unit>
  • Mask a service:     sudo systemctl mask <unit>
  • User-level equiv:   systemctl --user disable --now <unit>
  • Check why enabled:  systemctl cat <unit>     (shows the unit file)
  • Reverse-deps:       systemctl list-dependencies --reverse <unit>
  • Show full state:    systemctl status <unit>
EOF

echo
