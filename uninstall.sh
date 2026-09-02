#!/bin/bash
# Removes everything install.sh added, including restoring Service.qml from
# its backup if the Lock Screen patch was applied.
set -euo pipefail

PLUGIN_DIR="$HOME/.config/omarchy/plugins/stevenkuo.idle-control"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_QML="/usr/share/omarchy/shell/plugins/services/idle/Service.qml"
SERVICE_QML_BACKUP="${SERVICE_QML}.bak-pre-lock-off"

echo "==> Stopping and removing ac-power-idle-sync service"
systemctl --user disable --now ac-power-idle-sync.service 2>/dev/null || true
rm -f "$SYSTEMD_DIR/ac-power-idle-sync.service"
systemctl --user daemon-reload

echo "==> Removing scripts from $BIN_DIR"
rm -f "$BIN_DIR/idle-control-status" "$BIN_DIR/idle-control-set-timeout" "$BIN_DIR/ac-power-idle-sync"

echo "==> Removing plugin dir $PLUGIN_DIR"
rm -rf "$PLUGIN_DIR"

# Idle-related state flags. Only remove the ones this project owns; lock-off
# and stay-awake/screensaver-off are shared with native Omarchy toggles so
# leaving them behind is harmless (they just stop being reachable from a UI).
if [[ -f $SERVICE_QML_BACKUP ]]; then
  echo
  read -r -p "Restore the original Service.qml from backup? [y/N] " restore
  if [[ "$restore" =~ ^[Yy]$ ]]; then
    pkexec bash -c "cp '$SERVICE_QML_BACKUP' '$SERVICE_QML' && rm '$SERVICE_QML_BACKUP'"
    echo "Restored."
  else
    echo "Left in place. The backup is still at $SERVICE_QML_BACKUP if you change your mind."
  fi
fi

if command -v omarchy >/dev/null 2>&1; then
  echo "==> Restarting Omarchy shell"
  omarchy restart shell
fi

echo "Done."
