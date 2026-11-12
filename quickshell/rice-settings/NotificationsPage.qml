import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Notifications: who shows them, and how the pop-ups and the control center look: where they appear,
// how long they stay, the theme, text size, corners, transparency and blur. A live sample on top shows it all.
Item {
    id: page
    property var ctl
    property var ns: ({})

    function v(k, d) { return ns[k] !== undefined ? ns[k] : d }
    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, ns)
        n[key] = page.norm(value)
        ns = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-notify\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
        refresh.restart()
    }
    function tool(arg) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-notify\" \"$1\"", "_", arg]) }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-notify\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.ns = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: refresh; interval: 800; onTriggered: stateProc.running = true }

    // who shows notifications: the shell itself (pop-ups + the control center) or swaync (rice-cc engine)
    property string engine: "swaync"
    Process {
        id: engProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-cc\" engine state"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.engine = text.trim() === "shell" ? "shell" : "swaync" }
    }
    function setEngine(v) {
        engine = v
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-cc\" engine \"$1\"", "_", v])
        page.ctl.status = v === "shell" ? I18n.t("Notifications: the shell shows them") : I18n.t("Notifications: swaync shows them")
    }

    // the themes, the same colors the shell uses (rice-desktop/NPal.qml)
    readonly property var themes: [
        { k: "shell", n: "DarkShadow", d: "Your theme color, softly" },
        { k: "graphite", n: "Graphite", d: "Neutral grey" },
        { k: "black", n: "Black", d: "Deep black, OLED" },
        { k: "slate", n: "Slate", d: "Cool blue grey" },
        { k: "tinted", n: "Tinted", d: "More of your color" },
        { k: "white", n: "Light", d: "Light cards, dark text" }
    ]
    readonly property real hue: { const h = Qt.color(M3.seed).hslHue; return h < 0 ? 0.55 : h }
    readonly property real sat: (Qt.color(M3.seed).hslHue < 0 || Qt.color(M3.seed).hslSaturation < 0.1) ? 0 : Math.max(0.35, Math.min(0.85, Qt.color(M3.seed).hslSaturation))
    function pal(k, a) {
        const light = k === "white"
        let s
        switch (k) {
        case "black": s = Qt.rgba(0.02, 0.02, 0.025, a); break
        case "graphite": s = Qt.rgba(0.075, 0.075, 0.085, a); break
        case "slate": s = Qt.rgba(0.09, 0.105, 0.135, a); break
        case "white": s = Qt.rgba(0.96, 0.96, 0.965, a); break
        case "tinted": s = Qt.hsla(hue, sat * 0.4, 0.11, a); break
        default: s = Qt.hsla(hue, 0.08, 0.085, a)
        }
        return {
            surface: s,
            fg: light ? "#16171a" : "#ECEDEE", dim: light ? "#5a5e66" : "#A9ADB2",
            primary: light ? Qt.hsla(hue, sat, 0.36, 1) : Qt.hsla(hue, sat, 0.78, 1),
            container: light ? Qt.hsla(hue, sat * 0.5, 0.86, 1) : Qt.hsla(hue, sat * (k === "tinted" ? 0.55 : 0.35), 0.25, 1),
            inkContainer: light ? Qt.hsla(hue, sat, 0.2, 1) : Qt.hsla(hue, sat * 0.6, 0.88, 1),
            line: light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)
        }
    }
    readonly property var cur: pal(v("colors", "shell"), v("popup_opacity", 0.85))

    // a sample pop-up in the chosen look
    component Sample: Rectangle {
        id: sp
        property var p: page.cur
        property bool small: false
        radius: page.v("radius", 22) + 4
        color: p.surface
        border.width: 1; border.color: p.line
        Item {
            x: 14; y: 14; width: sp.small ? 32 : 42; height: width
            Blob { anchors.fill: parent; kind: Prefs.accentShape; color: sp.p.container }
            Icon { anchors.centerIn: parent; name: "notifications"; glyph: ""; size: sp.small ? 15 : 19; filled: true; color: sp.p.inkContainer }
        }
        Column {
            x: sp.small ? 56 : 68; y: 13; width: parent.width - x - 14
            spacing: 2
            T { scaled: false; text: I18n.t("Messages  ·  now"); font.pixelSize: sp.small ? 9 : 11; color: sp.p.dim }
            T { scaled: false; width: parent.width; elide: Text.ElideRight; text: I18n.t("Example text"); font.pixelSize: sp.small ? 11 : page.v("font_size", 13) + 1; font.weight: Font.DemiBold; color: sp.p.fg }
            T { scaled: false; width: parent.width; elide: Text.ElideRight; visible: !sp.small; text: I18n.t("Did you see the new notifications?"); font.pixelSize: page.v("font_size", 13) - 1; color: sp.p.dim }
            Row {
                visible: !sp.small; spacing: 6; topPadding: 6
                Rectangle { width: r1.implicitWidth + 22; height: 28; radius: 14; color: sp.p.container
                    T { id: r1; scaled: false; anchors.centerIn: parent; text: I18n.t("Reply"); font.pixelSize: 11; color: sp.p.inkContainer } }
                Rectangle { width: r2.implicitWidth + 22; height: 28; radius: 14; color: sp.p.container
                    T { id: r2; scaled: false; anchors.centerIn: parent; text: I18n.t("Mark as read"); font.pixelSize: 11; color: sp.p.inkContainer } }
            }
        }
        Rectangle { visible: !sp.small; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; x: 18; width: (parent.width - 36) * 0.6; height: 3; radius: 2
            color: Qt.rgba(sp.p.primary.r, sp.p.primary.g, sp.p.primary.b, 0.55) }
    }

    PageScroll {
        anchors.fill: parent

        SegRow {
            label: I18n.t("Shown by")
            desc: page.engine === "shell" ? I18n.t("DarkShadow: its own pop-ups and the control center (SUPER + N)") : I18n.t("swaync: its pop-ups and its panel")
            options: [{ label: I18n.t("DarkShadow"), value: "shell" }, { label: "swaync", value: "swaync" }]
            current: page.engine
            onChosen: function(x) { page.setEngine(x) }
        }

        // ---------- live sample: a little screen with the pop-up where it will be ----------
        Rectangle {
            id: stage
            width: parent.width
            height: 210
            radius: M3.rXL
            clip: true
            gradient: Gradient { GradientStop { position: 0; color: M3.stageTop } GradientStop { position: 1; color: M3.stageBottom } }
            Rectangle { x: 16; y: 10; width: parent.width - 32; height: 18; radius: 9; color: Qt.rgba(0, 0, 0, 0.35) }
            Sample {
                width: Math.min(stage.width - 40, page.v("popup_width", 380) * 0.95)
                height: 112
                x: page.v("pos_x", "right") === "left" ? 20 : (page.v("pos_x", "right") === "center" ? (stage.width - width) / 2 : stage.width - width - 20)
                y: page.v("pos_y", "top") === "top" ? 40 : stage.height - height - 16
                Behavior on x { NumberAnimation { duration: M3.d(480); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Behavior on y { NumberAnimation { duration: M3.d(480); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Behavior on width { NumberAnimation { duration: M3.d(360); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
            }
        }
        Row {
            spacing: 10
            Btn { primary: true; sym: "send"; icon: ""; text: I18n.t("Send a test"); onClicked: page.tool("test") }
            Btn { sym: "right_panel_open"; icon: ""; text: page.engine === "shell" ? I18n.t("Open control center") : I18n.t("Open panel"); onClicked: page.tool("panel") }
        }

        // ---------- pop-ups ----------
        SectionTitle { text: I18n.t("Pop-ups"); sub: I18n.t("Where they appear and how long they stay. Pointing at one keeps it.") }
        SegRow {
            label: I18n.t("Side"); desc: I18n.t("Of the screen")
            options: [{ label: I18n.t("Left"), value: "left" }, { label: I18n.t("Middle"), value: "center" }, { label: I18n.t("Right"), value: "right" }]
            current: page.v("pos_x", "right")
            onChosen: function(x) { page.setv("pos_x", x) }
        }
        SegRow {
            label: I18n.t("Edge"); desc: I18n.t("Top or bottom")
            options: [{ label: I18n.t("Top"), value: "top" }, { label: I18n.t("Bottom"), value: "bottom" }]
            current: page.v("pos_y", "top")
            onChosen: function(x) { page.setv("pos_y", x) }
        }
        SliderRow {
            label: I18n.t("Width"); desc: I18n.t("How wide a pop-up is")
            from: 300; to: 520; step: 10; unit: " px"
            value: page.v("popup_width", 380)
            onCommitted: function(x) { page.setv("popup_width", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Time on screen"); desc: I18n.t("Seconds before a pop-up goes (a thin line shows what is left)")
            from: 2; to: 30; step: 1; unit: " s"
            value: page.v("timeout", 6)
            onCommitted: function(x) { page.setv("timeout", Math.round(x)) }
        }
        ToggleRow {
            label: I18n.t("Important ones stay"); desc: I18n.t("Urgent notifications wait until you close them")
            checked: page.v("critical_sticky", true) === true
            onToggled: function(x) { page.setv("critical_sticky", x ? "on" : "off") }
        }
        ToggleRow {
            label: I18n.t("Pictures"); desc: I18n.t("Show the picture a notification brings (screenshots, covers)")
            checked: page.v("images", true) === true
            onToggled: function(x) { page.setv("images", x ? "on" : "off") }
        }

        // ---------- the look ----------
        SectionTitle { text: I18n.t("Theme"); sub: I18n.t("For the pop-ups and the control center.") }
        Grid {
            id: tgrid
            width: parent.width
            columns: width > 700 ? 3 : 2
            spacing: 10
            Repeater {
                model: page.themes
                delegate: Rectangle {
                    id: tt
                    readonly property bool on: page.v("colors", "shell") === modelData.k
                    width: (tgrid.width - (tgrid.columns - 1) * 10) / tgrid.columns
                    height: 132
                    radius: tm.pressed ? M3.rM : M3.rL
                    color: on ? M3.secondaryContainer : (tm.containsMouse ? M3.surfaceHigh : M3.surfaceC)
                    border.width: on ? 2 : 0; border.color: M3.primary
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on radius { NumberAnimation { duration: M3.d(220) } }
                    Rectangle {
                        x: 10; y: 10; width: parent.width - 20; height: 74; radius: M3.rM
                        gradient: Gradient { GradientStop { position: 0; color: M3.stageTop } GradientStop { position: 1; color: M3.stageBottom } }
                        Sample { small: true; p: page.pal(modelData.k, 0.92); x: 8; y: 8; width: parent.width - 16; height: 58 }
                    }
                    T { x: 14; y: 92; text: modelData.n; font.pixelSize: 13; font.weight: Font.Medium; color: tt.on ? M3.inkSecondaryC : M3.ink }
                    T { x: 14; y: 110; text: modelData.d; font.pixelSize: 11; color: M3.inkDim; width: parent.width - 28; elide: Text.ElideRight }
                    Rectangle { visible: tt.on; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16; width: 22; height: 22; radius: 11; color: M3.primary
                        Icon { anchors.centerIn: parent; name: "check"; glyph: ""; size: 13; color: M3.inkPrimary } }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setv("colors", modelData.k) }
                }
            }
        }
        SliderRow {
            label: I18n.t("Text size"); desc: I18n.t("Of the pop-ups and the notifications in the control center")
            from: 10; to: 18; step: 1; unit: " px"
            value: page.v("font_size", 13)
            onCommitted: function(x) { page.setv("font_size", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Corners"); desc: I18n.t("How round the pop-ups are")
            from: 4; to: 32; step: 1; unit: " px"
            value: page.v("radius", 22)
            onCommitted: function(x) { page.setv("radius", Math.round(x)) }
        }

        // ---------- transparency and blur ----------
        SectionTitle { text: I18n.t("Transparency & blur"); sub: I18n.t("Blur shows where the surface is see-through. Light mode and gaming mode make everything solid.") }
        SliderRow {
            label: I18n.t("Pop-ups"); desc: I18n.t("Lower is more see-through")
            from: 0.3; to: 1; step: 0.02; decimals: 2
            value: page.v("popup_opacity", 0.85)
            onCommitted: function(x) { page.setv("popup_opacity", x.toFixed(2)) }
        }
        ToggleRow {
            label: I18n.t("Blur behind pop-ups"); desc: I18n.t("Frosted glass")
            checked: page.v("blur_popups", true) === true
            onToggled: function(x) { page.setv("blur_popups", x ? "on" : "off") }
        }
        SliderRow {
            label: I18n.t("Control center"); desc: I18n.t("Lower is more see-through")
            from: 0.3; to: 1; step: 0.02; decimals: 2
            value: page.v("opacity", 0.8)
            onCommitted: function(x) { page.setv("opacity", x.toFixed(2)) }
        }
        ToggleRow {
            label: I18n.t("Blur behind the control center"); desc: I18n.t("Frosted glass")
            checked: page.v("blur", true) === true
            onToggled: function(x) { page.setv("blur", x ? "on" : "off") }
        }

        // ---------- swaync only ----------
        SectionTitle { visible: page.engine === "swaync"; text: "swaync"; sub: I18n.t("Only while swaync shows your notifications.") }
        ToggleRow {
            visible: page.engine === "swaync"
            label: I18n.t("Keep notifications when clicked")
            desc: I18n.t("Clicking opens the app and the notification stays in swaync's panel")
            checked: page.v("keep_clicked", true)
            onToggled: function(x) { page.setv("keep_clicked", x ? "on" : "off") }
        }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim; topPadding: 6
            text: I18n.t("The sound for new notifications is in Sound & language > Sfx & sounds.") }
    }
}
