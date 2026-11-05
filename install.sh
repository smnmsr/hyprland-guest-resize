#!/usr/bin/env bash
# Install sync-guest-display for the current user.
set -euo pipefail

SCRIPT_NAME="sync-guest-display"
SRC_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

command -v hyprctl >/dev/null 2>&1 || { echo "error: hyprctl not found (is this a Hyprland session?)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq not found (install it with your package manager)" >&2; exit 1; }
command -v udevadm >/dev/null 2>&1 || { echo "error: udevadm not found (systemd-udev)" >&2; exit 1; }

install -Dm755 "$SRC_DIR/$SCRIPT_NAME" "$BIN_DIR/$SCRIPT_NAME"
install -Dm644 "$SRC_DIR/$SCRIPT_NAME.service" "$UNIT_DIR/$SCRIPT_NAME.service"

systemctl --user daemon-reload
systemctl --user enable --now "$SCRIPT_NAME.service"

echo "Installed $SCRIPT_NAME."
echo "  binary: $BIN_DIR/$SCRIPT_NAME"
echo "  unit:   $UNIT_DIR/$SCRIPT_NAME.service"
echo
echo "Check logs with: journalctl --user -u $SCRIPT_NAME -f"
