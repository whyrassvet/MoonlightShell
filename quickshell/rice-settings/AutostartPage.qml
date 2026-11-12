import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: page
    property var ctl
    property var main: []
    property var custom: []
    spacing: 10

    Process {
        id: autoProc
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" autostart"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    page.main = j.main
                    page.custom = j.custom
                } catch (e) { }
            }
        }
    }

    Timer { id: refresh; interval: 700; onTriggered: autoProc.running = true }

    T { text: I18n.t("Custom commands"); font.pixelSize: 15; font.bold: true }
    T {
        width: parent.width
        text: I18n.t("Programs started when ") + (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(" starts. They run at your next login.")
        color: M3.inkDim
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: page.custom
        delegate: Rectangle {
            width: page.width
            height: 44
            radius: 10
            color: M3.surfaceC
            T {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70
                text: modelData
                elide: Text.ElideRight
                font.pixelSize: 13
            }
            Rectangle {
                width: 28
                height: 28
                radius: 14
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: delMouse.containsMouse ? "#3a2020" : "transparent"
                T { anchors.centerIn: parent; text: "\u00d7"; font.pixelSize: 18 }
                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { page.ctl.hrun(["autostart-del", index], "Removed"); refresh.restart() }
                }
            }
        }
    }

    Row {
        width: parent.width
        spacing: 8
        Field {
            id: cmdField
            width: parent.width - addPill.width - 8
            placeholder: I18n.t("Command, e.g. discord")
            onAccepted: addPill.clicked()
        }
        Pill {
            id: addPill
            label: I18n.t("Add")
            onClicked: {
                const c = cmdField.text.trim()
                if (c.length === 0) { page.ctl.status = I18n.t("Type a command first"); return }
                page.ctl.hrun(["autostart-add", c], "Added: " + c)
                cmdField.text = ""
                refresh.restart()
            }
        }
    }

    T { text: I18n.t("From hyprland.lua"); font.pixelSize: 15; font.bold: true; topPadding: 12 }
    T {
        width: parent.width
        text: I18n.t("Switch off an entry to comment it out in your config (a backup is kept). Changes apply at the next login.")
        color: M3.inkDim
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: page.main
        delegate: SettingRow {
            width: page.width
            height: 48
            label: modelData.cmd
            Tog {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: modelData.enabled
                onToggled: function(v) {
                    page.ctl.hrun(["autostart-toggle", modelData.line], "Autostart updated")
                    refresh.restart()
                }
            }
        }
    }
}