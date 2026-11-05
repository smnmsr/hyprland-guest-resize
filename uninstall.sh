#!/usr/bin/env bash
# Remove sync-guest-display for the current user.
set -euo pipefail

SCRIPT_NAME="sync-guest-display"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

systemctl --user disable --now "$SCRIPT_NAME.service" 2>/dev/null || true
rm -f "$BIN_DIR/$SCRIPT_NAME" "$UNIT_DIR/$SCRIPT_NAME.service"
systemctl --user daemon-reload
systemctl --user reset-failed "$SCRIPT_NAME.service" 2>/dev/null || true

echo "Removed $SCRIPT_NAME."
