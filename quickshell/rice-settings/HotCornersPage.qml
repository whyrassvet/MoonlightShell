import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var hc: ({ sections: [], toggles: [] })
    property var tools: ({})
    property string accent: "#d4d4d4"
    property var walls: []
    property string wall: ""

    readonly property var allSections: [
        { k: "wallpaper", n: "Wallpaper", d: "Your latest wallpapers, one click to switch", g: "󰋩" },
        { k: "colors", n: "Color schemes", d: "All color schemes, one click to switch", g: "\udb80\udfd8" },
        { k: "apps", n: "Apps", d: "Search and launch apps, pinned apps when empty", g: "󰀻" },
        { k: "awake", n: "Keep Awake", d: "Stop the screen from locking or sleeping", g: "󰅶" },
        { k: "record", n: "Screen recording", d: "Fullscreen or region, list of recordings (settings in Recorder)", g: "󰕧" },
        { k: "shot", n: "Screenshots", d: "Whole screen or a region, copied to clipboard", g: "󰄀" },
        { k: "toggles", n: "Quick toggles", d: "Wi-Fi, Bluetooth, Do Not Disturb and more", g: "󰕰" },
        { k: "media", n: "Now playing", d: "Song with play, pause, next and previous", g: "󰎈" }
    ]
    readonly property var allToggles: [
        { k: "wifi", n: "Wi-Fi" }, { k: "bluetooth", n: "Bluetooth" }, { k: "dnd", n: "Do Not Disturb" },
        { k: "gaming", n: "Gaming mode" }, { k: "mic", n: "Microphone" }, { k: "settings", n: "Settings" },
        { k: "wallpaper", n: "Wallpaper" }, { k: "lock", n: "Lock screen" }
    ]
    function v(k, d) { return hc[k] !== undefined ? hc[k] : d }
    function nameOf(list, k) { for (let i = 0; i < list.length; i++) if (list[i].k === k) return list[i].n; return k }
    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, hc); n[key] = page.norm(value); hc = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
        reload.restart()
    }
    function setList(key, arr) {
        const n = Object.assign({}, hc); n[key] = arr; hc = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" list \"$1\" \"$2\"", "_", key, arr.join(",")])
        page.ctl.status = I18n.t("Applied")
        reload.restart()
    }
    function moved(arr, i, j) { const a = arr.slice(); const t = a[i]; a[i] = a[j]; a[j] = t; return a }
    // enabled sections first (in their order), then the rest
    function sectionRows() {
        const on = (hc.sections || []).slice()
        const rest = allSections.map(s => s.k).filter(k => on.indexOf(k) < 0)
        return on.concat(rest)
    }

    Process {
        id: cfgProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" config; echo '@@'; \"$HOME/.local/bin/rice-hotcorner\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("@@")
                try { page.hc = JSON.parse(p[0]) } catch (e) { }
                try { const s = JSON.parse(p[1]); page.tools = s.tools || {}; page.accent = s.accent || "#d4d4d4"; page.walls = s.walls || []; page.wall = s.wall || "" } catch (e) { }
            }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- preview ----------
        Rectangle {
            id: scr
            width: parent.width
            height: 250
            radius: 16
            clip: true
            border.width: 1
            border.color: "#1f1f1f"
            gradient: Gradient {
                GradientStop { position: 0; color: "#2a2540" }
                GradientStop { position: 1; color: "#12131a" }
            }
            readonly property string corner: page.v("corner", "bottom-right")
            readonly property bool atBottom: corner.indexOf("bottom") === 0
            readonly property bool atRight: corner.indexOf("right") > 0

            Rectangle {
                width: 26; height: 26; radius: 13
                x: scr.atRight ? scr.width - 13 : -13
                y: scr.atBottom ? scr.height - 13 : -13
                color: page.accent
                opacity: 0.55
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.6; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Item {
                id: mini
                readonly property real s: Math.min(0.5, (scr.height - 24) / Math.max(1, prev.height))
                width: prev.width * s
                height: prev.height * s
                x: scr.atRight ? scr.width - width - 12 : 12
                y: scr.atBottom ? scr.height - height - 12 : 12
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                HotCornerPanel {
                    id: prev
                    scale: mini.s
                    transformOrigin: Item.TopLeft
                    cfg: page.hc
                    open: true
                    st: ({ awake: false, wifi: true, bluetooth: true, dnd: false, gaming: false, mic_muted: false, accent: page.accent,
                           walls: page.walls, wall: page.wall, schemes: page.ctl.schemes, scheme: page.ctl.colorMode,
                           recordings: [{ name: "Recording_2026-10-31.mp4", path: "", time: "today" }] })
                }
            }
            Column {
                x: scr.atRight ? 18 : scr.width - width - 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                width: 210
                T { text: I18n.t("Touch the corner"); font.pixelSize: 18; font.bold: true }
                T { width: parent.width; text: I18n.t("Move the pointer into the ") + scr.corner.replace("-", " ") + I18n.t(" corner to open the panel."); font.pixelSize: 12; color: "#b0b0bc"; wrapMode: Text.WordWrap }
                Btn {
                    primary: true
                    text: I18n.t("Open it now")
                    onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" open"])
                }
            }
        }

        // ---------- general ----------
        SectionTitle { text: I18n.t("Hot corner") }
        ToggleRow { label: I18n.t("Enable"); desc: I18n.t("Show the panel when the pointer touches the corner"); checked: page.v("enabled", true) === true; onToggled: function(x) { page.setv("enabled", x ? "on" : "off") } }
        SegRow {
            label: I18n.t("Corner")
            options: [{ label: I18n.t("Bottom right"), value: "bottom-right" }, { label: I18n.t("Bottom left"), value: "bottom-left" },
                      { label: I18n.t("Top right"), value: "top-right" }, { label: I18n.t("Top left"), value: "top-left" }]
            current: page.v("corner", "bottom-right")
            onChosen: function(x) { page.setv("corner", x) }
        }
        SliderRow {
            label: I18n.t("Open delay")
            desc: I18n.t("How long the pointer must stay in the corner")
            from: 0; to: 800; step: 25; unit: " ms"
            value: page.v("delay", 150)
            onCommitted: function(x) { page.setv("delay", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Corner size")
            desc: I18n.t("Size of the invisible hot spot")
            from: 1; to: 16; step: 1; unit: " px"
            value: page.v("trigger", 4)
            onCommitted: function(x) { page.setv("trigger", Math.round(x)) }
        }
        ToggleRow { label: I18n.t("Greeting header"); desc: I18n.t("Your picture, a greeting and the time at the top"); checked: page.v("header", true) === true; onToggled: function(x) { page.setv("header", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Close when the pointer leaves"); desc: I18n.t("Off keeps it open until you touch the corner again"); checked: page.v("close_on_leave", true) === true; onToggled: function(x) { page.setv("close_on_leave", x ? "on" : "off") } }

        // ---------- sections ----------
        SectionTitle { text: I18n.t("Sections"); sub: I18n.t("Turn sections on or off and change their order with the arrows.") }
        Repeater {
            model: page.sectionRows()
            delegate: Rectangle {
                readonly property int pos: (page.hc.sections || []).indexOf(modelData)
                readonly property bool on: pos >= 0
                readonly property var info: page.allSections.filter(s => s.k === modelData)[0]
                width: parent.width
                height: 60
                radius: 12
                color: "#141414"
                border.width: 1
                border.color: "#1f1f1f"
                opacity: on ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Rectangle {
                    id: sIco
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: info ? info.g : ""; font.pixelSize: 17 }
                }
                Column {
                    anchors.left: sIco.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    T { text: info ? info.n : modelData; font.pixelSize: 14 }
                    T { kind: "reading"; text: info ? info.d : ""; color: "#8a8a8a"; font.pixelSize: 11 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Glyph {
                        glyph: "󰅃"
                        anchors.verticalCenter: parent.verticalCenter
                        active: on && pos > 0
                        onClicked: page.setList("sections", page.moved(page.hc.sections, pos, pos - 1))
                    }
                    Glyph {
                        glyph: "󰅀"
                        anchors.verticalCenter: parent.verticalCenter
                        active: on && pos < page.hc.sections.length - 1
                        onClicked: page.setList("sections", page.moved(page.hc.sections, pos, pos + 1))
                    }
                    Item { width: 8; height: 1 }
                    Tog {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: on
                        onToggled: function(x) {
                            const cur = (page.hc.sections || []).slice()
                            if (x && cur.indexOf(modelData) < 0) cur.push(modelData)
                            if (!x) cur.splice(cur.indexOf(modelData), 1)
                            page.setList("sections", cur)
                        }
                    }
                }
            }
        }

        // ---------- quick toggles ----------
        SectionTitle { text: I18n.t("Quick toggles"); sub: I18n.t("Arrows change the order, x removes. Click a + button to add.") }
        Rectangle {
            width: parent.width
            height: tgCol.implicitHeight + 28
            radius: 12
            color: "#141414"
            border.width: 1
            border.color: "#1f1f1f"
            Column {
                id: tgCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: page.hc.toggles || []
                        delegate: Chip {
                            label: page.nameOf(page.allToggles, modelData)
                            canLeft: index > 0
                            canRight: index < page.hc.toggles.length - 1
                            onMoveLeft: page.setList("toggles", page.moved(page.hc.toggles, index, index - 1))
                            onMoveRight: page.setList("toggles", page.moved(page.hc.toggles, index, index + 1))
                            onRemoved: page.setList("toggles", page.hc.toggles.filter(t => t !== modelData))
                        }
                    }
                    T { visible: !(page.hc.toggles && page.hc.toggles.length > 0); text: I18n.t("No toggles. Add some below."); color: "#8a8a8a"; font.pixelSize: 12 }
                }
                Rectangle { width: parent.width; height: 1; color: "#222222" }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: page.allToggles.filter(t => (page.hc.toggles || []).indexOf(t.k) < 0)
                        delegate: Rectangle {
                            height: 32
                            width: addRow.implicitWidth + 22
                            radius: 9
                            color: am.containsMouse ? "#222222" : "#1a1a1a"
                            border.width: 1
                            border.color: "#2a2a2a"
                            Row {
                                id: addRow
                                anchors.centerIn: parent
                                spacing: 6
                                T { kind: "icon"; text: "󰐕"; font.pixelSize: 13; color: "#9a9aa4"; anchors.verticalCenter: parent.verticalCenter }
                                T { text: modelData.n; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: am
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setList("toggles", (page.hc.toggles || []).concat([modelData.k]))
                            }
                        }
                    }
                }
            }
        }

        // ---------- pinned apps ----------
        SectionTitle { text: I18n.t("Pinned apps"); sub: I18n.t("Shown in the Apps section before you type. Use the app name or its .desktop id.") }
        Rectangle {
            width: parent.width
            height: paCol.implicitHeight + 28
            radius: 12
            color: "#141414"
            border.width: 1
            border.color: "#1f1f1f"
            Column {
                id: paCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: page.hc.apps || []
                        delegate: Chip {
                            label: modelData
                            canLeft: index > 0
                            canRight: index < page.hc.apps.length - 1
                            onMoveLeft: page.setList("apps", page.moved(page.hc.apps, index, index - 1))
                            onMoveRight: page.setList("apps", page.moved(page.hc.apps, index, index + 1))
                            onRemoved: page.setList("apps", page.hc.apps.filter(t => t !== modelData))
                        }
                    }
                }
                Row {
                    spacing: 8
                    Field {
                        id: appField
                        width: 240
                        placeholder: I18n.t("e.g. firefox, kitty, steam")
                        onAccepted: addApp.clicked()
                    }
                    Btn {
                        id: addApp
                        text: I18n.t("Add")
                        onClicked: {
                            const n = appField.text.trim()
                            if (n.length === 0) return
                            page.setList("apps", (page.hc.apps || []).concat([n]))
                            appField.text = ""
                        }
                    }
                }
            }
        }

        // ---------- look ----------
        SectionTitle { text: I18n.t("Look & animation") }
        SegRow {
            label: I18n.t("Animation")
            desc: I18n.t("Grow unfolds the panel out of the corner")
            options: [{ label: I18n.t("Grow"), value: "grow" }, { label: I18n.t("Slide"), value: "slide" }, { label: I18n.t("Pop"), value: "scale" }, { label: I18n.t("Fade"), value: "fade" }]
            current: page.v("animation", "grow")
            onChosen: function(x) { page.setv("animation", x) }
        }
        SliderRow {
            label: I18n.t("Animation speed")
            from: 0.5; to: 2.0; step: 0.1; decimals: 1; unit: "x"
            value: page.v("speed", 1.0)
            onCommitted: function(x) { page.setv("speed", x.toFixed(1)) }
        }
        SegRow {
            label: I18n.t("Size")
            desc: I18n.t("Makes the whole panel bigger or smaller: text, icons and buttons")
            options: [{ label: I18n.t("Small"), value: "0.85" }, { label: I18n.t("Normal"), value: "1" }, { label: I18n.t("Large"), value: "1.15" }, { label: I18n.t("Huge"), value: "1.3" }]
            current: {
                const v = Number(page.v("scale", 1))
                return v <= 0.9 ? "0.85" : v < 1.07 ? "1" : v < 1.22 ? "1.15" : "1.3"
            }
            onChosen: function(x) { page.setv("scale", Number(x)) }
        }
        SliderRow {
            label: I18n.t("Scale")
            desc: I18n.t("Fine tuning of the size")
            from: 0.75; to: 1.5; step: 0.05; decimals: 2; unit: "x"
            value: page.v("scale", 1)
            onCommitted: function(x) { page.setv("scale", Number(x.toFixed(2))) }
        }
        SliderRow {
            label: I18n.t("Width")
            desc: I18n.t("How wide the panel is (before scaling)")
            from: 300; to: 680; step: 10; unit: " px"
            value: page.v("width", 400)
            onCommitted: function(x) { page.setv("width", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Corner radius")
            from: 0; to: 36; step: 1; unit: " px"
            value: page.v("radius", 26)
            onCommitted: function(x) { page.setv("radius", Math.round(x)) }
        }

        // ---------- blur & transparency ----------
        SectionTitle { text: I18n.t("Blur & transparency"); sub: I18n.t("Blur shows the desktop softly through the panel. It needs transparency.") }
        ToggleRow { label: I18n.t("Blur"); desc: I18n.t("Blur whatever is behind the panel"); checked: page.v("blur", true) === true; onToggled: function(x) { page.setv("blur", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Transparency"); desc: I18n.t("Off makes the panel fully solid"); checked: page.v("transparency", true) === true; onToggled: function(x) { page.setv("transparency", x ? "on" : "off") } }
        SliderRow {
            label: I18n.t("Panel opacity")
            desc: page.v("transparency", true) === true ? I18n.t("Lower is more see-through") : I18n.t("Turn on Transparency to use this")
            from: 0.3; to: 1.0; step: 0.02; decimals: 2
            value: page.v("opacity", 0.9)
            opacity: page.v("transparency", true) === true ? 1 : 0.45
            onCommitted: function(x) { page.setv("opacity", x.toFixed(2)) }
        }
        SliderRow {
            label: I18n.t("Card brightness")
            desc: I18n.t("How much the section cards stand out")
            from: 0.0; to: 0.2; step: 0.01; decimals: 2
            value: page.v("card_alpha", 0.05)
            onCommitted: function(x) { page.setv("card_alpha", x.toFixed(2)) }
        }
        ToggleRow { label: I18n.t("Theme tint"); desc: I18n.t("Mix a little of your Theme color into the panel"); checked: page.v("tint", false) === true; onToggled: function(x) { page.setv("tint", x ? "on" : "off") } }

        // ---------- capture ----------
        SectionTitle { text: I18n.t("Recording & screenshots"); sub: I18n.t("Screenshots go to Pictures/Screenshots. Recording size, quality and sound are on the Recorder page.") }
        ToggleRow { label: I18n.t("Copy screenshots"); desc: I18n.t("Also put every screenshot on the clipboard"); checked: page.v("clipboard", true) === true; onToggled: function(x) { page.setv("clipboard", x ? "on" : "off") } }
        T {
            readonly property var miss: {
                const t = page.tools, m = []
                if (t["wf-recorder"] === false && t["gpu-screen-recorder"] === false) m.push("wf-recorder")
                if (t.grim === false) m.push("grim")
                if (t.slurp === false) m.push("slurp")
                if (t["wl-copy"] === false) m.push("wl-clipboard")
                return m
            }
            visible: miss.length > 0
            width: parent.width
            text: I18n.t("Missing programs: ") + miss.join(", ") + I18n.t(". Install them so recording and screenshots work.")
            color: "#e0a050"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Row {
            topPadding: 8
            Btn {
                text: I18n.t("Reset hot corner")
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" reset"])
                    page.ctl.status = I18n.t("Hot corner reset")
                    reload.restart()
                }
            }
        }
    }
    Timer { id: reload; interval: 600; onTriggered: cfgProc.running = true }
}
