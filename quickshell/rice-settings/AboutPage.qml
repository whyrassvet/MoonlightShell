import Quickshell
import Quickshell.Io
import QtQuick

// Settings > About: the version of DarkShadow's Shell, updates, this computer and what it is made with.
Item {
    id: page
    property var ctl

    property var info: ({})
    Process {
        id: infoProc
        running: true
        command: ["bash", "-c", [
            ". /etc/os-release 2>/dev/null; echo \"os=${PRETTY_NAME:-Linux}\"",
            "echo \"kernel=$(uname -r)\"",
            "echo \"version=$(cat \"$HOME/.config/rice/version\" 2>/dev/null)\"",
            "v=$(\"$HOME/.local/bin/rice-wm\" version 2>/dev/null); echo \"wm=${v%% *}\"; echo \"hypr=${v#* }\"",
            "echo \"qs=$(qs --version 2>/dev/null | head -1 | sed 's/^quickshell *//I')\"",
            "echo \"cpu=$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)\"",
            "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //; s/ (rev.*//')\"",
            "echo \"mem=$(awk '/MemTotal/ {printf \"%.1f GB\", $2/1048576}' /proc/meminfo)\"",
            "echo \"up=$(uptime -p 2>/dev/null | sed 's/^up //')\"",
            "echo \"host=$(cat /etc/hostname 2>/dev/null || hostname)\""
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                text.split("\n").forEach(function(l) { const i = l.indexOf("="); if (i > 0) o[l.substring(0, i)] = l.substring(i + 1).trim() })
                page.info = o
            }
        }
    }
    property string upd: ""
    Process {
        id: updProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-update\" check 2>&1 | tail -1"]
        stdout: StdioCollector { onStreamFinished: { page.upd = text.trim() || "Up to date"; page.ctl.status = page.upd } }
    }
    function open(url) { Quickshell.execDetached(["xdg-open", url]) }

    PageScroll {
        anchors.fill: parent

        // ---------- who we are ----------
        Rectangle {
            width: parent.width
            height: 200
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Rectangle { width: 220; height: 220; radius: 110; x: parent.width - 280; y: -80; color: M3.alpha(M3.primary, 0.16) }
            Rectangle { width: 110; height: 110; radius: 36; rotation: 18; x: parent.width - 170; y: 120; color: M3.alpha(M3.primary, 0.12) }
            MoonLogo { x: 18; anchors.verticalCenter: parent.verticalCenter; size: 190; running: page.visible }
            Column {
                x: 212; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 212 - 24
                spacing: 6
                T { kind: "title"; text: I18n.t("DarkShadow's Shell"); font.pixelSize: 28; font.weight: Font.Medium; color: M3.inkPrimaryC }
                Row {
                    spacing: 8
                    Rectangle { width: vt.implicitWidth + 20; height: 26; radius: 13; color: M3.primary
                        T { id: vt; anchors.centerIn: parent; text: "V" + (page.info.version || "?"); font.pixelSize: 12; font.bold: true; color: M3.inkPrimary } }
                    Rectangle { width: lt.implicitWidth + 20; height: 26; radius: 13; color: M3.alpha(M3.ink, 0.1)
                        T { id: lt; anchors.centerIn: parent; text: I18n.t("MIT license"); font.pixelSize: 12; color: M3.inkPrimaryC } }
                }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.inkPrimaryC
                    text: I18n.t("A Hyprland and niri desktop with its own bar with a dynamic island, launcher, dock, widgets and this Settings app. Made by shadow.") }
                Row {
                    spacing: 8
                    topPadding: 4
                    Btn { text: I18n.t("Update Center"); sym: "system_update_alt"; icon: "\uf021"; primary: true; onClicked: page.ctl.page = 35 }
                    Btn { text: I18n.t("GitHub"); sym: "code"; icon: ""; onClicked: page.open("https://github.com/shadowww-dev/DarkShadowShell") }
                }
            }
        }

        // ---------- this computer ----------
        SectionTitle { text: I18n.t("This computer"); sub: I18n.t("What DarkShadow's Shell runs on.") }
        Grid {
            id: grid
            width: parent.width
            columns: width > 640 ? 2 : 1
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: [
                    { k: "os", n: "System", g: "" }, { k: "kernel", n: "Kernel", g: "" },
                    { k: "hypr", n: page.info.wm || "Hyprland", g: "" }, { k: "qs", n: "Quickshell", g: "" },
                    { k: "cpu", n: "Processor", g: "" }, { k: "gpu", n: "Graphics", g: "" },
                    { k: "mem", n: "Memory", g: "" }, { k: "up", n: "Up for", g: "" }
                ]
                delegate: Rectangle {
                    width: (grid.width - (grid.columns - 1) * 10) / grid.columns
                    height: 64
                    radius: M3.rM
                    color: M3.surfaceC
                    Rectangle {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 38; radius: 19; color: M3.secondaryContainer
                        T { kind: "icon"; anchors.centerIn: parent; text: modelData.g; font.pixelSize: 15; color: M3.inkSecondaryC }
                    }
                    Column {
                        x: 64; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 64 - 14
                        spacing: 2
                        T { text: I18n.t(modelData.n); font.pixelSize: 11; color: M3.inkDim }
                        T { text: page.info[modelData.k] || "—"; font.pixelSize: 14; font.weight: Font.Medium; width: parent.width; elide: Text.ElideRight }
                    }
                }
            }
        }

        // ---------- made with ----------
        SectionTitle { text: I18n.t("Made with"); sub: I18n.t("Open source projects that make this possible.") }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { n: "Hyprland", u: "https://hypr.land" }, { n: "niri", u: "https://github.com/niri-wm/niri" }, { n: "Quickshell", u: "https://quickshell.org" },
                    { n: "Qt", u: "https://www.qt.io" }, { n: "swaync", u: "https://github.com/ErikReider/SwayNotificationCenter" },
                    { n: "matugen", u: "https://github.com/InioX/matugen" }, { n: "cava", u: "https://github.com/karlstav/cava" },
                    { n: "awww", u: "https://codeberg.org/LGFae/awww" },
                    { n: "Sarods2D: hyprland-infinite-desktop-v2", u: "https://github.com/sarodscommits/hyprland-infinitie-desktop-v2" },
                    { n: "fedyaqq34356: hyprdots", u: "https://github.com/fedyaqq34356/hyprdots" }
                ]
                delegate: Rectangle {
                    width: mt.implicitWidth + 34; height: 38; radius: 19
                    color: mm.containsMouse ? M3.surfaceHigh : "transparent"
                    border.width: 1; border.color: M3.outlineVariant
                    Behavior on color { ColorAnimation { duration: 140 } }
                    T { id: mt; anchors.centerIn: parent; text: modelData.n + "  ↗"; font.pixelSize: 13 }
                    MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.open(modelData.u) }
                }
            }
        }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim; topPadding: 8
            text: I18n.t("Settings follow the ideas of Material 3 (tonal colors from your theme, round shapes, calm motion), drawn our own way.") }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim; topPadding: 4
            text: I18n.t("Infinite Desktop comes from Sarods2D's hyprland-infinite-desktop-v2, and the redesign was inspired by his Iridium shell. The island idea comes from hyprdots by fedyaqq34356. Thank you!") }
    }
}
