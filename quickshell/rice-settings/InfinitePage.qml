import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Desktop > Infinite Desktop: the windows of a workspace float on an endless canvas that you move (and on
// Hyprland zoom). Hyprland only (rice-infinite.lua does the work); on niri the page only says so (V4.23).
// Your keys: Keys, below (rice-infinite key ...).
Item {
    id: page
    property var ctl
    readonly property bool niri: !!Quickshell.env("NIRI_SOCKET")
    property var st: ({ keys: { key_toggle: "SUPER + F", mod_hold: "SUPER + ALT", mod_go: "SUPER + CTRL", mod_zoom: "CTRL" }, on: false, zoom: 1, step: 0.12, min: 0.2, pan: 180, speed: 1.0, dir: 1, push: 1, input: true, daemon: true, devices: null, loaded: true })

    function sh(args) { runner.command = ["bash", "-c", "\"$HOME/.local/bin/rice-infinite\" \"$@\" 2>&1", "_"].concat(args); runner.running = true }
    function fmt(n) { return String(Math.round(n * 100) / 100) }
    function kv(k, d) { return page.st.keys && page.st.keys[k] ? page.st.keys[k] : d }
    function nice(k) { return String(k).split(" + ").map(function(p) { return p.length > 1 ? p.charAt(0) + p.slice(1).toLowerCase() : p }).join(" + ") }
    function setKey(k, v) { page.sh(["key", k, v]); const n = Object.assign({}, page.st); n.keys = Object.assign({}, page.st.keys || {}); n.keys[k] = v; page.st = n }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-infinite\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { } } }
    }
    Process { id: runner; stdout: StdioCollector { onStreamFinished: stateLater.restart() } }
    Timer { id: stateLater; interval: 350; onTriggered: stateProc.running = true }
    Timer { interval: 2000; running: page.visible; repeat: true; onTriggered: if (!stateProc.running) stateProc.running = true }
    onVisibleChanged: if (visible) stateProc.running = true

    component KeyPick: SettingRow {
        property string key: ""
        property var choices: []
        reserved: 520
        Seg {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            options: parent.choices.map(function(c) { return { value: c, label: page.nice(c) } })
            current: page.kv(parent.key, parent.choices[0])
            onChosen: v => page.setKey(parent.key, v)
        }
    }
    component Key: Rectangle {
        property string keys: ""
        property string what: ""
        width: parent ? parent.width : 400
        height: 52
        color: kh.hovered ? M3.surfaceHigh : "transparent"
        HoverHandler { id: kh }
        T { x: 18; anchors.verticalCenter: parent.verticalCenter; width: parent.width - kc.width - 52; text: parent.what; font.pixelSize: 14; elide: Text.ElideRight }
        Row {
            id: kc
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Repeater {
                model: parent.parent.keys.split(" + ").reduce((a, k, i) => i ? a.concat(["+", k]) : [k], [])
                Rectangle {
                    readonly property bool plus: modelData === "+"
                    width: plus ? pl.implicitWidth : Math.max(30, pl.implicitWidth + 18); height: 30
                    radius: 9 * M3.shapeK
                    color: plus ? "transparent" : M3.surfaceHighest
                    border.width: plus ? 0 : 1; border.color: M3.outlineVariant
                    anchors.verticalCenter: parent.verticalCenter
                    T { id: pl; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.weight: parent.plus ? Font.Normal : Font.DemiBold
                        color: parent.plus ? M3.inkDim : M3.ink }
                }
            }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the switch, with a little canvas that breathes ----------
        Rectangle {
            width: parent.width
            height: 210
            radius: M3.rXL
            color: page.st.on ? M3.primaryContainer : M3.surfaceC
            clip: true
            Behavior on color { ColorAnimation { duration: 220 } }
            // the canvas: windows that come together when it zooms out
            Item {
                id: art
                width: 260; height: 170
                anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                property real k: 1
                SequentialAnimation on k {
                    loops: Animation.Infinite; running: page.visible
                    NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: 700 }
                    NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: 700 }
                }
                Repeater {
                    model: [[-80, -40, 120, 80], [56, -52, 110, 64], [-20, 46, 96, 70], [100, 36, 84, 92], [-150, 30, 70, 56], [170, -70, 80, 60]]
                    Rectangle {
                        readonly property var g: modelData
                        width: g[2] * art.k; height: g[3] * art.k
                        x: art.width / 2 + g[0] * art.k - width / 2; y: art.height / 2 + g[1] * art.k - height / 2
                        radius: 10 * art.k
                        color: index === 0 ? M3.primary : M3.alpha(page.st.on ? M3.inkPrimaryC : M3.ink, 0.10 + 0.05 * (index % 3))
                        border.width: 1; border.color: M3.alpha(M3.ink, 0.12)
                        Rectangle { x: 6 * art.k; y: 6 * art.k; width: parent.width * 0.4; height: 4 * art.k; radius: 2; color: M3.alpha(M3.ink, 0.18) }
                    }
                }
            }
            Column {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - art.width - 64
                spacing: 6
                T { text: I18n.t("INFINITE DESKTOP"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                    color: M3.alpha(page.st.on ? M3.inkPrimaryC : M3.ink, 0.7) }
                T { kind: "title"; text: page.niri ? I18n.t("Hyprland only") : page.st.on ? I18n.t("On") + (page.niri ? "" : " · " + Math.round(page.st.zoom * 100) + " %") : I18n.t("Off"); font.pixelSize: 28; font.weight: Font.Medium
                    color: page.st.on ? M3.inkPrimaryC : M3.ink }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 13; color: M3.alpha(page.st.on ? M3.inkPrimaryC : M3.ink, 0.8)
                    text: page.niri ? I18n.t("Infinite Desktop is made for Hyprland (it zooms and moves the windows on an endless canvas). niri scrolls its own way already, so here it is off.")
                                    : I18n.t("Your windows float on an endless canvas: zoom out to see them all, move the canvas to where you work.") }
                Item { width: 1; height: 4 }
                Btn {
                    visible: !page.niri
                    text: page.st.on ? I18n.t("Turn off") : I18n.t("Turn on"); sym: page.st.on ? "close_fullscreen" : "open_in_full"; icon: ""
                    variant: page.st.on ? "tonal" : "filled"
                    onClicked: { page.sh([page.st.on ? "off" : "on"]); const n = Object.assign({}, page.st); n.on = !n.on; page.st = n }
                }
            }
        }

        // SUPER + ALT + mouse: rice-canvasd reads the mouse and the keyboard directly
        Rectangle {
            id: cv
            readonly property var dv: page.st.devices || null
            readonly property bool denied: !!dv && dv.denied > 0 && (dv.keyboards === 0 || dv.mice === 0)
            readonly property bool ready: page.st.daemon === true && !!dv && dv.keyboards > 0 && dv.mice > 0
            visible: page.niri || page.st.hypr !== false
            width: parent.width; height: Math.max(72, ic.implicitHeight + 28); radius: M3.rL
            color: ready ? M3.surfaceC : M3.alpha(M3.primary, 0.10)
            border.width: ready ? 0 : 1; border.color: M3.alpha(M3.primary, 0.35)
            Rectangle { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; radius: 18
                color: cv.ready ? M3.secondaryContainer : M3.primaryContainer
                Icon { anchors.centerIn: parent; name: cv.ready ? "mouse" : "info"; glyph: cv.ready ? "\uf8cc" : "\uf05a"; size: 18
                    color: cv.ready ? M3.inkSecondaryC : M3.inkPrimaryC } }
            Column {
                id: ic
                x: 66; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 66 - (allowBtn.visible ? allowBtn.width + 32 : 20)
                spacing: 3
                T { font.pixelSize: 14; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight
                    text: cv.ready ? page.nice(page.kv("mod_hold", "SUPER + ALT")) + " + " + I18n.t("mouse is ready")
                        : (cv.denied ? (page.st.group ? I18n.t("Log out and back in once") : I18n.t("One step for SUPER + ALT + mouse"))
                        : (page.st.daemon ? I18n.t("No keyboard or mouse found yet") : I18n.t("SUPER + ALT + mouse is not running"))) }
                T { width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.inkDim
                    text: cv.ready ? (cv.dv.keyboards + " " + I18n.t("keyboard(s)") + " · " + cv.dv.mice + " " + I18n.t("mouse / mice"))
                        : (cv.denied ? (page.st.group ? I18n.t("You are in the input group now; it counts after the next login.")
                              : (page.st.nixos ? I18n.t("NixOS: add \"input\" to your user's extraGroups in configuration.nix, run sudo nixos-rebuild switch, then log in again. Allow shows the line.")
                                  : I18n.t("Your user joins the input group (your password, once), then log in again. Programs you run can then read the keyboard and the mouse too.")))
                        : (page.st.daemon ? I18n.t("Plug in a mouse, or check with: rice-infinite check") : I18n.t("It starts with Hyprland. Start it now:"))) }
            }
            Btn {
                id: allowBtn
                visible: !cv.ready && (cv.denied ? !page.st.group : !page.st.daemon)
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                text: cv.denied ? I18n.t("Allow") : I18n.t("Start"); variant: "filled"
                onClicked: {
                    if (cv.denied) Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-term\" -e bash -c '\"$HOME/.local/bin/rice-infinite\" allow; echo; read -n1 -r -p \"Press any key to close \"'"])
                    else page.sh(["daemon"])
                }
            }
        }

        T {
            visible: !page.niri && page.st.loaded === false
            width: parent.width; wrapMode: Text.WordWrap; color: M3.error
            text: I18n.t("Run the update once more (rice-update) so Hyprland loads it.")
        }

        // ---------- the keys: yours to change ----------
        SectionTitle { text: I18n.t("Keys"); sub: I18n.t("Pick the keys you like. The ones with arrows and the wheel work while it is on, on the workspace where you turned it on.") }
        KeyPick { label: I18n.t("On / off"); desc: page.nice(page.kv("key_toggle", "")); key: "key_toggle"
            choices: page.niri ? ["SUPER + ALT + F", "SUPER + ALT + I", "SUPER + CTRL + I"] : ["SUPER + F", "SUPER + ALT + F", "SUPER + I"] }
        KeyPick { label: I18n.t("Hold and move the mouse"); desc: I18n.t("The whole canvas moves with the mouse; with the arrows: one step"); key: "mod_hold"
            choices: ["SUPER + ALT", "SUPER + SHIFT", "CTRL + ALT"] }
        KeyPick { label: I18n.t("Next window") + " (+ " + I18n.t("Arrows") + ")"; desc: I18n.t("Go to the next window that way (the canvas glides to it)"); key: "mod_go"
            choices: page.niri ? ["SUPER + ALT + SHIFT", "CTRL + ALT", "SUPER + CTRL"] : ["SUPER + CTRL", "SUPER + ALT + SHIFT", "CTRL + ALT"] }
        KeyPick { visible: !page.niri; label: I18n.t("Zoom") + " (+ " + I18n.t("Mouse wheel") + ")"; desc: I18n.t("Zoom out (down) and in (up) around the pointer"); key: "mod_zoom"
            choices: ["CTRL", "SUPER + CTRL", "ALT"] }
        Rectangle {
            width: parent.width; height: keys.implicitHeight; radius: M3.rL; color: M3.surfaceC; clip: true
            Column {
                id: keys
                width: parent.width
                Key { keys: page.nice(page.kv("key_toggle", "SUPER + F")); what: I18n.t("Infinite Desktop on / off") }
                Key { keys: page.nice(page.kv("mod_hold", "SUPER + ALT")); what: I18n.t("Hold and move the mouse: the whole canvas moves with it") }
                Key { keys: page.nice(page.kv("mod_hold", "SUPER + ALT")) + " + Arrows"; what: I18n.t("Move the canvas") }
                Key { keys: page.nice(page.kv("mod_go", "SUPER + CTRL")) + " + Arrows"; what: I18n.t("Go to the next window that way (the canvas glides to it)") }
                Key { visible: !page.niri; keys: page.nice(page.kv("mod_zoom", "CTRL")) + " + Mouse wheel"; what: I18n.t("Zoom out (down) and in (up) around the pointer") }
                Key { visible: !page.niri; keys: "Super + Mouse wheel"; what: I18n.t("Move the canvas up and down") }
                Key { visible: !page.niri; keys: "Super + Shift + Mouse wheel"; what: I18n.t("Move the canvas left and right") }
                Key { visible: !page.niri && page.st.push === 1; keys: "Super + Left mouse"; what: I18n.t("Drag a window to the edge of the screen and keep going: the others come to it") }
                Key { visible: !page.niri; keys: page.nice(page.kv("mod_hold", "SUPER + ALT")) + " + 0"; what: I18n.t("Back to 100 %") }
            }
        }

        // ---------- how it feels ----------
        SectionTitle { text: I18n.t("How it feels") }
        SettingRow {
            label: I18n.t("When you move the mouse")
            desc: page.st.dir === 2 ? I18n.t("The canvas goes the other way, like looking around") : I18n.t("The windows follow the mouse, like pushing a sheet of paper")
            reserved: 420
            Seg {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                options: [{ value: "1", label: I18n.t("Follow") }, { value: "2", label: I18n.t("Reversed") }]
                current: String(page.st.dir || 1)
                onChosen: v => { page.sh(["set", "dir", v]); const n = Object.assign({}, page.st); n.dir = Number(v); page.st = n }
            }
        }
        SliderRow {
            label: I18n.t("Sensitivity of the mouse")
            desc: I18n.t("1.00x: the window under the pointer stays under it. Lower is calmer, higher goes farther")
            from: 0.3; to: 3; step: 0.05; decimals: 2; unit: "x"
            value: page.st.speed || 1.0
            onCommitted: function(v) { page.sh(["set", "speed", String(Math.round(v * 100) / 100)]); const n = Object.assign({}, page.st); n.speed = v; page.st = n }
        }
        ToggleRow {
            visible: !page.niri
            label: I18n.t("SUPER + drag a window to the edge pushes the others")
            desc: I18n.t("Take a window to the edge of the screen and keep going: the other windows come towards it")
            checked: page.st.push === 1
            onToggled: function(v) { page.sh(["set", "push", v ? "1" : "0"]); const n = Object.assign({}, page.st); n.push = v ? 1 : 0; page.st = n }
        }
        SettingRow {
            visible: !page.niri
            label: I18n.t("Zoom speed")
            desc: I18n.t("How much one turn of the wheel zooms")
            reserved: 300
            Seg {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                options: [{ value: "0.06", label: I18n.t("Slow") }, { value: "0.12", label: I18n.t("Normal") }, { value: "0.22", label: I18n.t("Fast") }]
                current: page.st.step <= 0.08 ? "0.06" : (page.st.step >= 0.18 ? "0.22" : "0.12")
                onChosen: v => { page.sh(["set", "step", v]); const n = Object.assign({}, page.st); n.step = Number(v); page.st = n }
            }
        }
        SettingRow {
            visible: !page.niri
            label: I18n.t("Zoom out as far as")
            desc: I18n.t("Smaller means more windows fit on the screen")
            reserved: 300
            Seg {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                options: [{ value: "0.5", label: "50 %" }, { value: "0.3", label: "30 %" }, { value: "0.2", label: "20 %" }, { value: "0.1", label: "10 %" }]
                current: page.fmt(page.st.min)
                onChosen: v => { page.sh(["set", "min", v]); const n = Object.assign({}, page.st); n.min = Number(v); page.st = n }
            }
        }
        SettingRow {
            label: I18n.t("Move step")
            desc: I18n.t("How far the canvas moves for one turn of the wheel or one arrow")
            reserved: 300
            Seg {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                options: [{ value: "100", label: I18n.t("Short") }, { value: "180", label: I18n.t("Normal") }, { value: "320", label: I18n.t("Long") }]
                current: page.st.pan <= 120 ? "100" : (page.st.pan >= 260 ? "320" : "180")
                onChosen: v => { page.sh(["set", "pan", v]); const n = Object.assign({}, page.st); n.pan = Number(v); page.st = n }
            }
        }
        Rectangle {
            width: parent.width; height: note.implicitHeight + 24; radius: M3.rM; color: M3.alpha(M3.primary, 0.08)
            T { id: note; x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.inkDim
                text: I18n.t("A new window gets its own room next to the one you were in, and the canvas glides to it, so there is always space. Zooming really makes the windows smaller (apps may keep a smallest size). Turning it off tiles the windows again, and the canvas is remembered: turn it on again (also after a restart) and every window is where you left it.") }
        }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim; topPadding: 6
            text: I18n.t("Based on hyprland-infinite-desktop-v2 by Sarods2D (github.com/sarodscommits).") }
    }
}
