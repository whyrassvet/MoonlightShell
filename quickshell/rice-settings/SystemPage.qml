import Quickshell
import Quickshell.Io
import QtQuick

// Settings > System > System: this computer at a glance. The shell and your distro, the power profile, the
// processor, graphics, memory, swap and disk with how full they are, the system and your session.
Item {
    id: page
    property var ctl
    property var info: ({})
    Process {
        id: infoProc
        running: true
        command: ["bash", "-c", [
            ". /etc/os-release 2>/dev/null; echo \"os=${PRETTY_NAME:-Linux}\"; echo \"osid=${ID:-linux}\"",
            "echo \"kernel=$(uname -r)\"",
            "echo \"version=$(cat \"$HOME/.config/rice/version\" 2>/dev/null)\"",
            "v=$(\"$HOME/.local/bin/rice-wm\" version 2>/dev/null); echo \"wm=${v%% *}\"; echo \"hypr=${v#* }\"",
            "echo \"qs=$(qs --version 2>/dev/null | head -1 | sed 's/^quickshell *//I')\"",
            "echo \"cpu=$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)\"",
            "echo \"cores=$(nproc 2>/dev/null)\"",
            "echo \"gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //; s/ (rev.*//')\"",
            "awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} /SwapTotal/ {st=$2} /SwapFree/ {sf=$2} END {printf \"memu=%d\\nmemt=%d\\nswapu=%d\\nswapt=%d\\n\", (t-a)/1024, t/1024, (st-sf)/1024, st/1024}' /proc/meminfo",
            "df -BM --output=used,size \"$HOME\" 2>/dev/null | tail -1 | awk '{gsub(\"M\",\"\"); printf \"disku=%d\\ndiskt=%d\\n\", $1, $2}'",
            "echo \"up=$(uptime -p 2>/dev/null | sed 's/^up //')\"",
            "echo \"user=$USER\"; echo \"shell=$(basename \"${SHELL:-sh}\")\"; echo \"host=$(cat /etc/hostname 2>/dev/null || hostname)\"",
            "command -v powerprofilesctl >/dev/null && echo \"pp=$(powerprofilesctl get 2>/dev/null)\""
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                text.split("\n").forEach(function(l) { const i = l.indexOf("="); if (i > 0) o[l.substring(0, i)] = l.substring(i + 1).trim() })
                page.info = o
            }
        }
    }
    onVisibleChanged: if (visible && !infoProc.running) infoProc.running = true
    function n(k) { const v = parseFloat(info[k]); return isNaN(v) ? 0 : v }
    function gb(mb) { return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB" }
    function setProfile(p) {
        const o = Object.assign({}, info); o.pp = p; info = o
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" profile \"$1\"", "_", p])
        page.ctl.status = I18n.t("Power profile: ") + p
    }

    // one fact; with a bar when it has a "how full"
    component Fact: Rectangle {
        property string icon: ""
        property string glyph: ""
        property string label: ""
        property string value: ""
        property real frac: -1
        width: parent ? parent.width : 300
        height: frac >= 0 ? 76 : 62
        radius: M3.rM
        color: M3.surfaceC
        Rectangle { x: 14; y: 13; width: 36; height: 36; radius: 18; color: M3.secondaryContainer
            Icon { anchors.centerIn: parent; name: parent.parent.icon; glyph: parent.parent.glyph; size: 17; color: M3.inkSecondaryC } }
        Column {
            x: 62; y: 12; width: parent.width - 62 - 14
            spacing: 1
            T { text: parent.parent.label; font.pixelSize: 11; color: M3.inkDim }
            T { width: parent.width; elide: Text.ElideRight; text: parent.parent.value || "—"; font.pixelSize: 14; font.weight: Font.Medium }
        }
        WavyBar {
            visible: parent.frac >= 0
            x: 62; width: parent.width - 62 - 14; height: 12
            anchors.bottom: parent.bottom; anchors.bottomMargin: 9
            value: Math.max(0, parent.frac)
            thick: 4
            color: parent.frac > 0.9 ? M3.error : M3.primary
            running: page.visible
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the shell and your system ----------
        Rectangle {
            width: parent.width; height: 160; radius: M3.rXL; color: M3.surfaceC
            clip: true
            Item {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 112; height: 112
                Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primaryContainer
                    RotationAnimator on rotation { from: 0; to: 360; duration: 40000; loops: Animation.Infinite; running: page.visible } }
                MoonLogo { anchors.centerIn: parent; size: 100; running: page.visible }
            }
            Column {
                x: 160; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 160 - 24
                spacing: 4
                Row {
                    spacing: 10
                    T { kind: "title"; text: I18n.t("DarkShadow's Shell"); font.pixelSize: 28; font.weight: Font.Medium }
                    T { anchors.baseline: parent.children[0].baseline; text: page.info.version ? "V" + page.info.version : ""; font.pixelSize: 16; color: M3.primary }
                }
                T { text: (page.info.os || "Linux") + "  ·  " + (page.info.host || ""); font.pixelSize: 13; color: M3.inkDim }
                Row {
                    spacing: 8; topPadding: 6
                    Btn { text: I18n.t("Displays"); sym: "monitor"; icon: ""; onClicked: page.ctl.page = 4 }
                    Btn { text: I18n.t("About"); sym: "info"; icon: ""; onClicked: page.ctl.page = 17 }
                }
            }
        }

        // ---------- power ----------
        SectionTitle { text: I18n.t("Power"); sub: page.info.pp ? I18n.t("power-profiles-daemon: battery life or speed.") : I18n.t("power-profiles-daemon is not running, so the profile cannot change.") }
        Row {
            visible: !!page.info.pp
            width: parent.width
            spacing: 6
            Repeater {
                model: [{ k: "power-saver", n: "Low", i: "eco", g: "" }, { k: "balanced", n: "Medium", i: "balance", g: "" }, { k: "performance", n: "High", i: "bolt", g: "" }]
                delegate: Rectangle {
                    readonly property bool on: page.info.pp === modelData.k
                    width: (parent.width - 12) / 3; height: 52
                    radius: on ? 26 : M3.rM
                    color: on ? M3.primary : (pm.containsMouse ? M3.surfaceHigh : M3.surfaceC)
                    Behavior on radius { NumberAnimation { duration: M3.d(240); easing.type: M3.springy; easing.overshoot: 1.6 * Prefs.bounce } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Icon { name: modelData.i; glyph: modelData.g; size: 18; filled: parent.parent.on; color: parent.parent.on ? M3.inkPrimary : M3.ink; anchors.verticalCenter: parent.verticalCenter }
                        T { text: modelData.n; font.pixelSize: 14; font.weight: Font.Medium; color: parent.parent.on ? M3.inkPrimary : M3.ink; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setProfile(modelData.k) }
                }
            }
        }

        // ---------- hardware ----------
        SectionTitle { text: I18n.t("Hardware"); sub: I18n.t("What this computer is made of, and how full it is.") }
        Grid {
            id: hw
            width: parent.width
            columns: width > 640 ? 2 : 1
            columnSpacing: 10; rowSpacing: 10
            readonly property real cw: (width - (columns - 1) * 10) / columns
            Fact { width: hw.cw; icon: "memory"; glyph: ""; label: I18n.t("Processor") + (page.info.cores ? "  ·  " + page.info.cores + I18n.t(" threads") : ""); value: page.info.cpu }
            Fact { width: hw.cw; icon: "videogame_asset"; glyph: ""; label: I18n.t("Graphics"); value: page.info.gpu }
            Fact { width: hw.cw; icon: "memory_alt"; glyph: ""; label: I18n.t("Memory"); value: page.gb(page.n("memu")) + " / " + page.gb(page.n("memt"))
                frac: page.n("memt") > 0 ? page.n("memu") / page.n("memt") : 0 }
            Fact { width: hw.cw; icon: "swap_horiz"; glyph: ""; label: I18n.t("Swap"); value: page.n("swapt") > 0 ? page.gb(page.n("swapu")) + " / " + page.gb(page.n("swapt")) : "No swap"
                frac: page.n("swapt") > 0 ? page.n("swapu") / page.n("swapt") : 0 }
            Fact { width: hw.cw; icon: "hard_drive"; glyph: ""; label: I18n.t("Storage (home)"); value: page.gb(page.n("disku")) + " / " + page.gb(page.n("diskt"))
                frac: page.n("diskt") > 0 ? page.n("disku") / page.n("diskt") : 0 }
            Fact { width: hw.cw; icon: "schedule"; glyph: ""; label: I18n.t("Up for"); value: page.info.up }
        }

        // ---------- system and session ----------
        SectionTitle { text: I18n.t("Operating system and session") }
        Grid {
            id: os
            width: parent.width
            columns: width > 640 ? 2 : 1
            columnSpacing: 10; rowSpacing: 10
            readonly property real cw: (width - (columns - 1) * 10) / columns
            Fact { width: os.cw; icon: "deployed_code"; glyph: ""; label: I18n.t("Distribution"); value: page.info.os }
            Fact { width: os.cw; icon: "person"; glyph: ""; label: I18n.t("User"); value: page.info.user }
            Fact { width: os.cw; icon: "terminal"; glyph: ""; label: I18n.t("Kernel"); value: page.info.kernel }
            Fact { width: os.cw; icon: "code"; glyph: ""; label: I18n.t("Shell"); value: page.info.shell }
            Fact { width: os.cw; icon: "window"; glyph: ""; label: page.info.wm || "Hyprland"; value: page.info.hypr }
            Fact { width: os.cw; icon: "widgets"; glyph: ""; label: I18n.t("Quickshell"); value: page.info.qs }
        }
    }
}
