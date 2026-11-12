import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Gaming hub: gaming mode and what stays on while you play, performance, your game launchers and the
// gaming tools this computer has. Gaming mode used to live in Services.
Item {
    id: page
    property var ctl

    // ---------- rice-effects: gaming mode, light mode and the "keep" options ----------
    property var fx: ({ lite: false, gaming: false, flat: false, opts: {} })
    function fxOpt(k) { return !!(fx.opts && fx.opts[k] === true) }
    function fxRun(args, msg) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" \"$@\"", "_"].concat(args))
        page.ctl.status = msg
        fxRefresh.restart()
    }
    function setGaming(on) { const n = JSON.parse(JSON.stringify(fx)); n.gaming = on; fx = n; fxRun(["gaming", on ? "on" : "off"], "Gaming mode " + (on ? "on" : "off")) }
    function setLite(on) { const n = JSON.parse(JSON.stringify(fx)); n.lite = on; fx = n; fxRun(["lite", on ? "on" : "off"], on ? "Light mode on" : "Light mode off") }
    function setOpt(k, on) { const n = JSON.parse(JSON.stringify(fx)); if (!n.opts) n.opts = {}; n.opts[k] = on; fx = n; fxRun(["set", k, on ? "on" : "off"], "Gaming mode: saved") }
    Process {
        id: fxProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.fx = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: fxRefresh; interval: 1500; onTriggered: if (!fxProc.running) fxProc.running = true }
    Timer { interval: 5000; running: page.visible; repeat: true; onTriggered: if (!fxProc.running) fxProc.running = true }

    // ---------- power mode (power-profiles-daemon) ----------
    property string profile: ""
    property bool havePP: false
    Process {
        id: ppProc
        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null && powerprofilesctl get 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); page.havePP = t.length > 0; page.profile = t } }
    }
    function setProfile(p) {
        profile = p
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" profile \"$1\"", "_", p])
        page.ctl.status = I18n.t("Power mode: ") + p
    }

    // ---------- your launchers and tools ----------
    readonly property var launchers: [
        { id: "steam", n: "Steam" }, { id: "com.heroicgameslauncher.hgl", n: "Heroic" }, { id: "heroic", n: "Heroic" },
        { id: "net.lutris.Lutris", n: "Lutris" }, { id: "lutris", n: "Lutris" }, { id: "org.prismlauncher.PrismLauncher", n: "Prism" },
        { id: "com.usebottles.bottles", n: "Bottles" }, { id: "retroarch", n: "RetroArch" }, { id: "org.libretro.RetroArch", n: "RetroArch" },
        { id: "io.itch.itch", n: "itch" }, { id: "minecraft-launcher", n: "Minecraft" }, { id: "com.valvesoftware.Steam", n: "Steam" },
        { id: "net.davidotek.pupgui2", n: "ProtonUp-Qt" }, { id: "discord", n: "Discord" }
    ]
    readonly property var found: {
        const out = [], seen = {}
        for (let i = 0; i < launchers.length; i++) {
            const e = DesktopEntries.heuristicLookup(launchers[i].id)
            if (!e || seen[e.name]) continue
            seen[e.name] = true
            out.push({ e: e, n: e.name })
        }
        return out
    }
    property var tools: ({})
    Process {
        id: toolProc
        command: ["bash", "-c", "for t in gamemoded mangohud gamescope steam wine; do command -v $t >/dev/null 2>&1 && echo \"$t 1\" || echo \"$t 0\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                text.trim().split("\n").forEach(function(l) { const p = l.split(" "); o[p[0]] = p[1] === "1" })
                page.tools = o
            }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the big switch ----------
        Rectangle {
            id: hero
            width: parent.width
            height: 156
            radius: M3.rXL
            color: page.fx.gaming ? M3.primaryContainer : M3.surfaceC
            Behavior on color { ColorAnimation { duration: M3.d(600) } }
            clip: true
            // a soft shape in the corner that turns when gaming mode switches
            Rectangle {
                width: 200; height: 200; radius: 64
                x: parent.width - 270; y: -70
                rotation: page.fx.gaming ? 45 : 20
                color: page.fx.gaming ? M3.alpha(M3.primary, 0.22) : M3.alpha(M3.ink, 0.04)
                Behavior on rotation { NumberAnimation { duration: M3.d(1400); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Behavior on color { ColorAnimation { duration: M3.d(600) } }
            }
            Rectangle {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 72; height: 72; radius: page.fx.gaming ? 24 : 36
                color: page.fx.gaming ? M3.primary : M3.surfaceHighest
                Behavior on radius { NumberAnimation { duration: M3.d(700); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                Behavior on color { ColorAnimation { duration: M3.d(500) } }
                T { kind: "icon"; anchors.centerIn: parent; text: ""; font.pixelSize: 30; color: page.fx.gaming ? M3.inkPrimary : M3.ink }
            }
            Column {
                x: 116; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 116 - 100
                spacing: 4
                T { kind: "title"; text: page.fx.gaming ? I18n.t("Game on") : I18n.t("Gaming mode"); font.pixelSize: 24; font.weight: Font.Medium
                    color: page.fx.gaming ? M3.inkPrimaryC : M3.ink }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12
                    color: page.fx.gaming ? M3.inkPrimaryC : M3.inkDim
                    text: page.fx.gaming ? I18n.t("Effects you did not keep below are off, so games get the speed.") : I18n.t("One switch turns off animations, blur, transparency, shadows and gaps. Pick below what stays.") }
            }
            Tog { anchors.right: parent.right; anchors.rightMargin: 26; anchors.verticalCenter: parent.verticalCenter
                checked: page.fx.gaming === true; onToggled: function(v) { page.setGaming(v) } }
        }

        // the game bar
        Rectangle {
            width: parent.width; height: 84; radius: M3.rL; color: M3.surfaceC
            Rectangle { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 48; height: 48; radius: 16; color: M3.secondaryContainer
                Icon { anchors.centerIn: parent; name: "space_dashboard"; glyph: "\uf009"; size: 22; color: M3.inkSecondaryC } }
            Column {
                x: 80; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80 - 170; spacing: 3
                T { text: I18n.t("Game bar  ·  SUPER + G"); font.pixelSize: 14; font.weight: Font.Medium }
                T { kind: "reading"; width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; color: M3.inkDim
                    text: I18n.t("CPU, GPU, RAM, ping, screenshot, record, mic, power mode, volume and brightness over your game") }
            }
            Btn { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Open"); sym: "open_in_new"; icon: ""; primary: true
                onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-gamebar\" open"]) }
        }

        SectionTitle { text: I18n.t("While you play"); sub: I18n.t("What stays on in gaming mode.") }
        ToggleRow { label: I18n.t("Keep blur & transparency"); desc: I18n.t("Off: everything is solid while you play (faster)"); checked: page.fxOpt("keep_blur"); onToggled: function(v) { page.setOpt("keep_blur", v) } }
        ToggleRow { label: I18n.t("Keep animations"); desc: I18n.t("Windows and workspaces still animate"); checked: page.fxOpt("keep_anim"); onToggled: function(v) { page.setOpt("keep_anim", v) } }
        ToggleRow { label: I18n.t("Keep shadows"); desc: I18n.t("Shadows under windows"); checked: page.fxOpt("keep_shadows"); onToggled: function(v) { page.setOpt("keep_shadows", v) } }
        ToggleRow { label: I18n.t("Keep gaps"); desc: I18n.t("Space between windows and around the screen"); checked: page.fxOpt("keep_gaps"); onToggled: function(v) { page.setOpt("keep_gaps", v) } }
        ToggleRow { label: I18n.t("Do Not Disturb"); desc: I18n.t("No notification popups while gaming mode is on"); checked: page.fxOpt("dnd"); onToggled: function(v) { page.setOpt("dnd", v) } }

        // ---------- the game bar (SUPER + G): transparency & blur ----------
        SectionTitle { text: I18n.t("Game bar: transparency & blur"); sub: I18n.t("The panel over your game (Super + G). Light mode and gaming mode make it solid.") }
        SliderRow {
            label: I18n.t("Opacity"); desc: I18n.t("Lower is more see-through")
            from: 0.2; to: 1; step: 0.02; decimals: 2
            value: page.ctl && page.ctl.dst.gamebar && page.ctl.dst.gamebar.opacity !== undefined ? Number(page.ctl.dst.gamebar.opacity) : 0.9
            onCommitted: function(x) { page.ctl.dset("gamebar", "opacity", x.toFixed(2)) }
        }
        ToggleRow {
            label: I18n.t("Blur behind the game bar"); desc: I18n.t("Frosted glass; off: only the see-through color")
            checked: !(page.ctl && page.ctl.dst.gamebar && page.ctl.dst.gamebar.blur === false)
            onToggled: function(v) { page.ctl.dset("gamebar", "blur", v ? "on" : "off") }
        }

        SectionTitle { text: I18n.t("Performance"); sub: I18n.t("For laptops and older computers, also when you are not playing.") }
        ToggleRow { label: I18n.t("Light mode"); desc: I18n.t("The visualizer stops and widgets rest while a window covers them"); checked: page.fx.lite === true; onToggled: function(v) { page.setLite(v) } }
        SegRow {
            visible: page.havePP
            label: I18n.t("Power mode")
            desc: I18n.t("power-profiles-daemon: battery life or speed")
            options: [{ label: I18n.t("Saver"), value: "power-saver" }, { label: I18n.t("Balanced"), value: "balanced" }, { label: I18n.t("Performance"), value: "performance" }]
            current: page.profile
            onChosen: function(x) { page.setProfile(x) }
        }

        SectionTitle { text: I18n.t("Your launchers"); sub: page.found.length ? I18n.t("Open them from here.") : I18n.t("No game launcher found (Steam, Heroic, Lutris, Prism, Bottles ...).") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.found
                delegate: Rectangle {
                    width: 128; height: 112; radius: M3.rL
                    color: lm.containsMouse ? M3.surfaceHigh : M3.surfaceC
                    scale: lm.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: M3.d(220) } }
                    Behavior on scale { NumberAnimation { duration: M3.d(260); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 18
                        width: 44; height: 44; sourceSize.width: 88; sourceSize.height: 88
                        source: Icons.get(modelData.e.icon || "applications-games", true)
                        scale: lm.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: M3.d(420); easing.type: Easing.OutBack; easing.overshoot: 1.4 * Prefs.bounce } }
                    }
                    T { anchors.horizontalCenter: parent.horizontalCenter; y: 74; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight; text: modelData.n; font.pixelSize: 13; font.weight: Font.Medium }
                    MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { modelData.e.execute(); page.ctl.status = I18n.t("Opening ") + modelData.n } }
                }
            }
        }

        SectionTitle { text: I18n.t("Tools"); sub: I18n.t("Gaming helpers on this computer.") }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { k: "gamemoded", n: "GameMode", d: "CPU and GPU boost while a game runs" },
                    { k: "mangohud", n: "MangoHud", d: "FPS and temperatures in games" },
                    { k: "gamescope", n: "Gamescope", d: "Game window with its own resolution" },
                    { k: "steam", n: "Steam", d: "Proton for Windows games" },
                    { k: "wine", n: "Wine", d: "Windows programs" }
                ]
                delegate: Rectangle {
                    readonly property bool ok: page.tools[modelData.k] === true
                    width: tr.implicitWidth + 30; height: 40; radius: 20
                    color: ok ? M3.secondaryContainer : "transparent"
                    border.width: ok ? 0 : 1
                    border.color: M3.outlineVariant
                    Row {
                        id: tr
                        anchors.centerIn: parent
                        spacing: 8
                        T { kind: "icon"; text: parent.parent.ok ? "" : ""; font.pixelSize: 11; color: parent.parent.ok ? M3.primary : M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                        T { text: modelData.n; font.pixelSize: 13; color: parent.parent.ok ? M3.inkSecondaryC : M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim; topPadding: 4
            text: I18n.t("Missing ones can be installed with your package manager (gamemode, mangohud, gamescope).") }
    }
}
