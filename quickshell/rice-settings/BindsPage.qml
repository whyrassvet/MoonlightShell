import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: page
    property var ctl
    property var custom: []
    property var active: []
    property bool showActive: true
    spacing: 10

    Process {
        id: bindsProc
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" binds"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    page.custom = j.custom
                    page.active = j.active
                } catch (e) { }
            }
        }
    }

    Timer { id: refresh; interval: 700; onTriggered: bindsProc.running = true }

    T { text: I18n.t("Your own keybinds"); font.pixelSize: 15; font.bold: true }
    T {
        width: parent.width
        text: Quickshell.env("NIRI_SOCKET") ? I18n.t("Run any command with a key combination. niri takes changes at once.") : I18n.t("Run any command with a key combination. Removing one takes effect after Reload Hyprland.")
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
            T { x: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData.keys; font.bold: true; font.pixelSize: 13 }
            T {
                x: 190
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 190 - 56
                text: modelData.cmd
                elide: Text.ElideRight
                color: "#a0a0a0"
                font.pixelSize: 12
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
                    onClicked: { page.ctl.hrun(["bind-del", index], "Removed (reload to apply)"); refresh.restart() }
                }
            }
        }
    }

    T {
        visible: page.custom.length === 0
        text: I18n.t("No custom keybinds yet.")
        color: M3.inkDim
        font.pixelSize: 13
    }

    Row {
        width: parent.width
        spacing: 8
        Field { id: keysField; width: 170; placeholder: I18n.t("SUPER + X") }
        Field {
            id: cmdField
            width: parent.width - 170 - addPill.width - 16
            placeholder: I18n.t("Command, e.g. kitty")
            onAccepted: addPill.clicked()
        }
        Pill {
            id: addPill
            label: I18n.t("Add")
            onClicked: {
                const k = keysField.text.trim()
                const c = cmdField.text.trim()
                if (k.length === 0 || c.length === 0) { page.ctl.status = I18n.t("Type keys and a command"); return }
                page.ctl.hrun(["bind-add", k, c], "Added: " + k)
                keysField.text = ""
                cmdField.text = ""
                refresh.restart()
            }
        }
    }

    T { visible: page.showActive; text: I18n.t("Active keybinds"); font.pixelSize: 15; font.bold: true; topPadding: 12 }
    Column {
        visible: page.showActive
        width: parent.width
        spacing: 3
        Repeater {
            model: page.active
            delegate: T { width: parent.width; text: modelData; font.pixelSize: 11; color: "#a0a0a0"; elide: Text.ElideRight }
        }
    }
}
