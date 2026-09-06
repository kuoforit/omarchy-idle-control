#!/bin/bash
# Installs the Idle Control bar widget for Omarchy:
#   - *.qml, manifest.json, qmldir -> ~/.config/omarchy/plugins/stevenkuo.idle-control/
#   - bin/*               -> ~/.local/bin/
#   - systemd/*.service   -> ~/.config/systemd/user/ (enabled + started)
#   - optional patch to the system idle Service.qml, so the Lock Screen
#     toggle actually has something to switch (see README "The system patch").
#
# Safe to re-run; each step is idempotent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/stevenkuo.idle-control"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_QML="/usr/share/omarchy/shell/plugins/services/idle/Service.qml"
SERVICE_QML_BACKUP="${SERVICE_QML}.bak-pre-lock-off"
ORIGINAL_LINE='    runProcess(lockProcess, "lock", "omarchy-system-lock")'
PATCHED_LINE='    runProcess(lockProcess, "lock", "omarchy-toggle-enabled lock-off || omarchy-system-lock")'

command -v omarchy >/dev/null 2>&1 || { echo "omarchy command not found -- this is built for Omarchy, not a generic Linux desktop." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed." >&2; exit 1; }
command -v upower >/dev/null 2>&1 || { echo "upower is required but not installed." >&2; exit 1; }

echo "==> Installing plugin to $PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp "$SCRIPT_DIR"/*.qml "$SCRIPT_DIR"/manifest.json "$SCRIPT_DIR"/qmldir "$PLUGIN_DIR/"

echo "==> Installing scripts to $BIN_DIR"
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR"/bin/* "$BIN_DIR/"
chmod +x "$BIN_DIR"/idle-control-status "$BIN_DIR"/idle-control-set-timeout "$BIN_DIR"/ac-power-idle-sync

echo "==> Installing ac-power-idle-sync systemd user service"
mkdir -p "$SYSTEMD_DIR"
cp "$SCRIPT_DIR/systemd/ac-power-idle-sync.service" "$SYSTEMD_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now ac-power-idle-sync.service

echo
echo "==> Optional: independent Lock Screen toggle"
echo "    This patches a *system* file (Service.qml, owned by the omarchy"
echo "    package) with a one-line change, so idle-triggered lock respects"
echo "    a toggle the same way idle-triggered screensaver already does."
echo "    Manual lock (menu / keybind) is NOT affected either way."
echo "    A backup of the original is kept at:"
echo "      $SERVICE_QML_BACKUP"
echo "    An 'omarchy update' may overwrite this file and silently drop the"
echo "    patch -- if that happens, Lock Screen just always locks on idle"
echo "    again (not broken, just back to stock behavior); re-run this"
echo "    installer to reapply."
echo
read -r -p "Apply the Lock Screen patch now? [y/N] " apply_patch
if [[ "$apply_patch" =~ ^[Yy]$ ]]; then
  if [[ ! -f $SERVICE_QML ]]; then
    echo "!! $SERVICE_QML not found -- your Omarchy version may have restructured this file. Skipping." >&2
  elif grep -qF 'lock-off' "$SERVICE_QML"; then
    echo "Already patched, nothing to do."
  elif ! grep -qF "$ORIGINAL_LINE" "$SERVICE_QML"; then
    echo "!! The expected line wasn't found in $SERVICE_QML -- this Omarchy" >&2
    echo "   version's idle Service.qml doesn't match what this patch expects." >&2
    echo "   Skipping to avoid corrupting the file. Lock Screen toggle will" >&2
    echo "   be visible but won't do anything." >&2
  else
    pkexec bash -c "cp '$SERVICE_QML' '$SERVICE_QML_BACKUP' && sed -i 's|$ORIGINAL_LINE|$PATCHED_LINE|' '$SERVICE_QML'"
    echo "Patched. Backup saved at $SERVICE_QML_BACKUP."
  fi
else
  echo "Skipped. Lock Screen toggle will be visible but won't do anything until you re-run this installer and accept the patch."
fi

if command -v omarchy >/dev/null 2>&1 && omarchy plugin validate >/dev/null 2>&1; then
  echo "==> Plugin validated"
fi

echo "==> Restarting Omarchy shell to load the widget"
omarchy restart shell

echo
echo "Done. Look for the stay-awake icon in the bar."
