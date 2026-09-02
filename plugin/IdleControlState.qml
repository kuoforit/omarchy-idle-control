pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared reactive state for the Idle Control bar widget + its dropdown panel.
// Three independently-controllable idle behaviors, each backed by a flag file
// on disk so they compose with the mechanisms Omarchy/ac-power-idle-sync
// already use, rather than inventing a new state store:
//   - stayAwake:    ~/.local/state/omarchy/indicators/stay-awake
//                    (native Omarchy flag; also driven automatically by the
//                    ac-power-idle-sync systemd user service on plug/unplug)
//   - screensaverOn: inverse of ~/.local/state/omarchy/toggles/screensaver-off
//                    (native Omarchy toggle, same one `omarchy toggle screensaver` uses)
//   - lockOn:        inverse of ~/.local/state/omarchy/toggles/lock-off
//                    (new flag, respected by a one-line patch in the system
//                    idle Service.qml's lockSystem() -- see CUSTOMIZATIONS.md)
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string indicatorsDir: home + "/.local/state/omarchy/indicators"
  readonly property string togglesDir: home + "/.local/state/omarchy/toggles"

  property bool stayAwake: false
  property bool screensaverOn: true
  property bool lockOn: true
  property bool acOnline: false
  property bool loaded: false
  property int screensaverMinutes: 10
  property int lockMinutes: 20

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  function setStayAwake(value) {
    root.stayAwake = value
    applyProcess.command = ["bash", "-c",
      value
        ? "mkdir -p '" + root.indicatorsDir + "' && touch '" + root.indicatorsDir + "/stay-awake'"
        : "rm -f '" + root.indicatorsDir + "/stay-awake'"]
    applyProcess.running = true
  }

  function setScreensaverOn(value) {
    root.screensaverOn = value
    applyProcess.command = ["omarchy-toggle", "screensaver-off", value ? "off" : "on"]
    applyProcess.running = true
  }

  function setLockOn(value) {
    root.lockOn = value
    applyProcess.command = ["omarchy-toggle", "lock-off", value ? "off" : "on"]
    applyProcess.running = true
  }

  // These rewrite shell.json's idle.screensaver/idle.lock (in seconds) and
  // restart the Omarchy shell -- required, not optional: the Wayland
  // ext-idle-notify-v1 timeout is fixed when the notify object is created,
  // so a bare config edit would leave the old timeout listening forever.
  // The restart tears down and relaunches the whole shell (this panel
  // included), which is expected -- see omarchy_idle_sleep_config.md Bug 3.
  function setScreensaverMinutes(minutes) {
    root.screensaverMinutes = minutes
    timeoutProcess.command = ["idle-control-set-timeout", "screensaver", String(minutes)]
    timeoutProcess.running = true
  }

  function setLockMinutes(minutes) {
    root.lockMinutes = minutes
    timeoutProcess.command = ["idle-control-set-timeout", "lock", String(minutes)]
    timeoutProcess.running = true
  }

  Process {
    id: applyProcess
    onExited: root.refresh()
  }

  Process {
    id: timeoutProcess
  }

  Process {
    id: statusProbe
    command: ["idle-control-status"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(String(line).trim())
          root.stayAwake = data.stayAwake === true
          root.screensaverOn = data.screensaverOff !== true
          root.lockOn = data.lockOff !== true
          root.acOnline = data.acOnline === true
          root.screensaverMinutes = Math.max(1, Math.round((data.screensaverSeconds || 600) / 60))
          root.lockMinutes = Math.max(1, Math.round((data.lockSeconds || 1200) / 60))
          root.loaded = true
        } catch (e) {
        }
      }
    }
  }

  FileView {
    id: indicatorsWatcher
    path: root.indicatorsDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  FileView {
    id: togglesWatcher
    path: root.togglesDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
