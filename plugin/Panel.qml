import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "." as IdleControl

Panel {
  id: root
  moduleName: "stevenkuo.idle-control"
  ipcTarget: "stevenkuo.idle-control"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string statusMeta: IdleControl.IdleControlState.acOnline
    ? "Plugged in · auto stay-awake"
    : "On battery · normal idle"

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  Component {
    id: idleIcon
    Text {
      text: "󰅶"
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.display
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          iconComponent: idleIcon
          title: "Idle Control"
          meta: root.statusMeta
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          Toggle {
            width: parent.width
            label: "Stay Awake"
            description: "Skip idle entirely -- no screensaver, no lock"
            checked: IdleControl.IdleControlState.stayAwake
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: IdleControl.IdleControlState.setStayAwake(!IdleControl.IdleControlState.stayAwake)
          }

          Toggle {
            width: parent.width
            label: "Screensaver"
            description: "Launch the screensaver when idle"
            checked: IdleControl.IdleControlState.screensaverOn
            enabled: !IdleControl.IdleControlState.stayAwake
            opacity: enabled ? 1 : 0.5
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (enabled) IdleControl.IdleControlState.setScreensaverOn(!IdleControl.IdleControlState.screensaverOn)
          }

          Toggle {
            width: parent.width
            label: "Lock Screen"
            description: "Lock the screen when idle"
            checked: IdleControl.IdleControlState.lockOn
            enabled: !IdleControl.IdleControlState.stayAwake
            opacity: enabled ? 1 : 0.5
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (enabled) IdleControl.IdleControlState.setLockOn(!IdleControl.IdleControlState.lockOn)
          }
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "TIMING"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(14)

            NumberField {
              width: (parent.width - parent.spacing) / 2
              fieldWidth: width
              label: "Screensaver (min)"
              from: 1
              to: 180
              value: IdleControl.IdleControlState.screensaverMinutes
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: !IdleControl.IdleControlState.stayAwake
              opacity: enabled ? 1 : 0.5
              onModified: function(value) { IdleControl.IdleControlState.setScreensaverMinutes(value) }
            }

            NumberField {
              width: (parent.width - parent.spacing) / 2
              fieldWidth: width
              label: "Lock (min)"
              from: 1
              to: 180
              value: IdleControl.IdleControlState.lockMinutes
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: !IdleControl.IdleControlState.stayAwake
              opacity: enabled ? 1 : 0.5
              onModified: function(value) { IdleControl.IdleControlState.setLockMinutes(value) }
            }
          }
        }

        PanelSeparator {
          foreground: root.contentForeground
        }

        Text {
          width: parent.width
          text: "Plugging in defaults Stay Awake on; unplugging turns it back off."
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
