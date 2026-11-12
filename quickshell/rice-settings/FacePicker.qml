import Quickshell
import Quickshell.Io
import QtQuick

// Your profile picture (the sidebar, Home, the lock screen): pick one of your pictures right here (Pictures,
// Downloads, Desktop, your wallpapers), or any file with Browse. It is cut to a square and saved as ~/.face
// (and ~/.face.icon, which login screens use).
Item {
    id: fp
    anchors.fill: parent
    z: 80
    property bool open: false
    signal changed()
    property var pics: []
    property string busy: ""
    visible: t > 0.01
    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    function show() { open = true; listP.running = true }
    function hide() { open = false }
    function use(p) {
        if (!p || busy) return
        busy = p
        saveP.command = ["bash", "-c",
            "src=\"$1\"; tmp=\"$HOME/.face.new.png\"; " +
            "if command -v magick >/dev/null; then magick \"$src\"[0] -auto-orient -thumbnail '512x512^' -gravity center -extent 512x512 \"$tmp\"; " +
            "elif command -v convert >/dev/null; then convert \"$src\"[0] -auto-orient -thumbnail '512x512^' -gravity center -extent 512x512 \"$tmp\"; " +
            "else cp -f \"$src\" \"$tmp\"; fi && [ -s \"$tmp\" ] && mv -f \"$tmp\" \"$HOME/.face\" && cp -f \"$HOME/.face\" \"$HOME/.face.icon\"", "_", p]
        saveP.running = true
    }
    Process {
        id: saveP
        onExited: function(code) {
            fp.busy = ""
            if (code === 0) { fp.changed(); fp.hide() }
        }
    }
    Process {
        id: listP
        command: ["bash", "-c",
            "pics=\"$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")\"; " +
            "for d in \"$pics\" \"$HOME/Pictures\" \"$HOME/Downloads\" \"$HOME/Desktop\"; do [ -d \"$d\" ] && echo \"$d\"; done | sort -u | " +
            "while read -r d; do find \"$d\" -maxdepth 3 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) " +
            "-size +4k -printf '%T@\\t%p\\n' 2>/dev/null; done | sort -rn | cut -f2- | awk '!s[$0]++' | head -n 240"]
        stdout: StdioCollector { onStreamFinished: fp.pics = text.split("\n").filter(function(x) { return x.length > 0 }) }
    }
    Process {
        id: browseP
        command: ["zenity", "--file-selection", "--title=" + I18n.t("Choose a profile picture"), "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p.length) fp.use(p) } }
    }
    Process { id: removeP; command: ["bash", "-c", "rm -f \"$HOME/.face\" \"$HOME/.face.icon\""]; onExited: { fp.changed(); fp.hide() } }

    // the dim behind it: a click there closes it
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45 * fp.t)
        MouseArea { anchors.fill: parent; onClicked: fp.hide() }
    }
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 700)
        height: Math.min(parent.height - 80, 560)
        radius: M3.rXL
        color: M3.surfaceC
        border.width: 1; border.color: M3.outlineVariant
        opacity: fp.t
        scale: 0.94 + 0.06 * fp.t
        MouseArea { anchors.fill: parent }          // clicks inside do not close it
        Keys.onEscapePressed: fp.hide()

        Column {
            x: 24; y: 22; width: parent.width - 48
            spacing: 4
            T { kind: "title"; text: I18n.t("Profile picture"); font.pixelSize: 22; font.weight: Font.Medium }
            T { text: I18n.t("Shown in Settings, on Home and on the lock screen. Pick a picture, it is cut to a square."); font.pixelSize: 12; color: M3.inkDim
                width: parent.width; wrapMode: Text.WordWrap }
        }
        GridView {
            id: grid
            x: 20; y: 92; width: parent.width - 40; height: parent.height - 92 - 76
            clip: true
            readonly property int cols: Math.max(3, Math.floor(width / 120))
            cellWidth: Math.floor(width / cols); cellHeight: cellWidth
            model: fp.pics
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll { flick: grid }
            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight
                Item {
                    anchors.fill: parent; anchors.margins: 6
                    scale: cm.pressed ? 0.94 : (cm.containsMouse ? 1.04 : 1)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                    RoundImage { anchors.fill: parent; source: "file://" + modelData; res: 200; cornerRadius: 18 * M3.shapeK }
                    Rectangle { anchors.fill: parent; radius: 18 * M3.shapeK; color: "transparent"
                        border.width: cm.containsMouse || fp.busy === modelData ? 3 : 0; border.color: M3.primary }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fp.use(modelData) }
                }
            }
            T {
                visible: fp.pics.length === 0 && !listP.running
                anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: I18n.t("No pictures in Pictures, Downloads or Desktop. Use Browse to pick one anywhere.")
                color: M3.inkDim; font.pixelSize: 13
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            spacing: 8
            Btn { text: I18n.t("Remove picture"); sym: "delete"; icon: ""; variant: "text"; onClicked: removeP.running = true }
            Btn { text: I18n.t("Browse..."); sym: "folder_open"; icon: ""; onClicked: browseP.running = true }
            Btn { text: I18n.t("Close"); sym: "close"; icon: ""; primary: true; onClicked: fp.hide() }
        }
        T {
            visible: fp.busy !== ""
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.bottom: parent.bottom; anchors.bottomMargin: 30
            text: I18n.t("Saving..."); color: M3.primary; font.pixelSize: 12
        }
    }
}
