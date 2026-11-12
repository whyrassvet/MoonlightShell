import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var rs: ({ themes: {} })

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/rice-rofi"

    function v(k, d) { return rs[k] !== undefined ? rs[k] : d }

    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, rs)
        n[key] = page.norm(value)
        rs = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-rofi\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
        refresh.restart()
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-rofi\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.rs = JSON.parse(text) } catch (e) { } }
        }
    }
    Timer { id: refresh; interval: 700; onTriggered: stateProc.running = true }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 24
        anchors.topMargin: 6
        contentWidth: width
        contentHeight: col.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking && !flickWheel.active
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        WheelScroll { id: flickWheel; flick: flick }

        Column {
            id: col
            width: flick.width
            spacing: 10

            // ---------- live preview ----------
            Rectangle {
                id: rprev
                visible: Prefs.previews
                width: parent.width
                height: 230
                radius: M3.rL
                clip: true
                border.width: 0
                border.color: M3.outlineVariant
                gradient: Gradient {
                    GradientStop { position: 0; color: M3.stageTop }
                    GradientStop { position: 1; color: M3.stageBottom }
                }
                readonly property var th: (page.rs.themes && page.rs.themes[page.v("theme", "shadow")]) ? page.rs.themes[page.v("theme", "shadow")]
                                          : ({ bg: "#0d0d0d", alt: M3.surfaceHigh, sel: "#F6F5F4", fg: "#F6F5F4" })
                readonly property real sc: width / 1920 * 1.35
                readonly property string lay: page.v("layout", "list")
                readonly property string pos: page.v("position", "center")
                readonly property real alpha: page.v("transparency", true) === true ? page.v("opacity", 0.82) : 1
                function withAlpha(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a) }
                function lum(c) { const q = Qt.color(c); return 0.299 * q.r + 0.587 * q.g + 0.114 * q.b }
                readonly property color selFg: lum(th.sel) > 0.55 ? M3.surfaceLow : "#F6F5F4"
                readonly property int rows: Math.min(5, page.v("lines", 8))

                Rectangle { x: 50; y: 30; width: 220; height: 120; radius: 10; color: Qt.rgba(1, 1, 1, 0.05) }

                Rectangle {
                    id: win
                    readonly property bool bar: rprev.lay === "bar"
                    readonly property real leftw: rprev.lay === "split" ? width * 0.36 : 0
                    Rectangle {   // split: the wallpaper side
                        visible: rprev.lay === "split"
                        width: win.leftw; height: parent.height; radius: win.radius
                        gradient: Gradient { GradientStop { position: 0; color: "#e2a0a0" } GradientStop { position: 1; color: "#7a86b8" } }
                    }
                    width: bar ? rprev.width : Math.min(rprev.width - 40, Math.max(rprev.lay === "split" ? 860 : (rprev.lay === "grid" ? 720 : 360), page.v("width", 620)) * rprev.sc)
                    height: bar ? 34 : body.implicitHeight + 20
                    x: (rprev.width - width) / 2
                    y: rprev.pos === "top" ? (bar ? 0 : 16) : rprev.pos === "bottom" ? rprev.height - height - (bar ? 0 : 16) : (rprev.height - height) / 2
                    radius: bar ? 0 : page.v("radius", 18) * 0.7
                    color: rprev.withAlpha(rprev.th.bg, rprev.alpha)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // full-width bar style
                    Row {
                        visible: win.bar
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8
                        Rectangle {
                            width: parent.width * 0.22; height: parent.height; radius: 7
                            color: rprev.withAlpha(rprev.th.alt, Math.min(1, rprev.alpha + 0.08))
                            T { x: 8; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Search"); font.pixelSize: 10; color: rprev.th.fg; opacity: 0.5 }
                        }
                        Repeater {
                            model: ["Firefox", "Kitty", "Files", "Spotify", "Discord"]
                            delegate: Rectangle {
                                height: parent.height; width: bl.implicitWidth + 16; radius: 6
                                color: index === 0 ? rprev.th.sel : "transparent"
                                T { id: bl; anchors.centerIn: parent; text: modelData; font.pixelSize: 10; color: index === 0 ? rprev.selFg : rprev.th.fg }
                            }
                        }
                    }

                    Column {
                        id: body
                        visible: !win.bar
                        x: 10 + win.leftw; y: 10
                        width: parent.width - 20 - win.leftw
                        spacing: 6
                        Rectangle {
                            width: parent.width; height: 26; radius: Math.max(4, win.radius - 4)
                            color: rprev.withAlpha(rprev.th.alt, Math.min(1, rprev.alpha + 0.08))
                            T { kind: "icon"; x: 9; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 11; color: rprev.th.fg; opacity: 0.6 }
                            T { x: 26; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Search"); font.pixelSize: 10; color: rprev.th.fg; opacity: 0.5 }
                        }
                        // list
                        Repeater {
                            model: rprev.lay === "list" ? ["Firefox", "Kitty", "Files", "Spotify", "Discord"].slice(0, rprev.rows) : []
                            delegate: Rectangle {
                                width: body.width; height: 20; radius: Math.max(3, win.radius - 6)
                                color: index === 0 ? rprev.th.sel : "transparent"
                                Row {
                                    x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                                    Rectangle { visible: page.v("icons", true) === true; width: 11; height: 11; radius: 3; color: ["#e06c75", "#61afef", "#e5c07b", "#98c379", "#c678dd"][index]; anchors.verticalCenter: parent.verticalCenter }
                                    T { text: modelData; font.pixelSize: 10; color: index === 0 ? rprev.selFg : rprev.th.fg; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                        // grid
                        Grid {
                            visible: rprev.lay === "grid"
                            columns: 4
                            spacing: 6
                            Repeater {
                                model: rprev.lay === "grid" ? 8 : 0
                                delegate: Rectangle {
                                    width: (body.width - 18) / 4; height: 40; radius: Math.max(3, win.radius - 6)
                                    color: index === 0 ? rprev.th.sel : "transparent"
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 6; width: 16; height: 16; radius: 4; color: ["#e06c75", "#61afef", "#e5c07b", "#98c379", "#c678dd", "#56b6c2", "#d19a66", "#abb2bf"][index] }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 28; width: parent.width * 0.5; height: 4; radius: 2; color: index === 0 ? rprev.selFg : rprev.th.fg; opacity: 0.6 }
                                }
                            }
                        }
                    }
                }
                T {
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 8
                    text: I18n.t("Preview")
                    font.pixelSize: 10
                    color: M3.inkDim
                }
            }

            T { kind: "title"; text: I18n.t("Theme"); font.pixelSize: 16; font.bold: true }

            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: Object.keys(page.rs.themes || {})
                    delegate: Rectangle {
                        readonly property var th: page.rs.themes[modelData]
                        readonly property bool on: page.v("theme", "shadow") === modelData
                        width: 124
                        height: 84
                        radius: 14
                        color: M3.surfaceC
                        border.width: on ? 2 : 1
                        border.color: on ? M3.primary : (tMouse.containsMouse ? M3.outline : M3.surfaceHighest)
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Rectangle {
                            x: 10; y: 10
                            width: parent.width - 20; height: 34
                            radius: 8
                            color: th.bg
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle { x: 6; y: 6; width: 34; height: 8; radius: 4; color: th.alt }
                            Rectangle { x: 6; y: 18; width: parent.width - 12; height: 10; radius: 5; color: th.sel }
                        }
                        T {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 54
                            text: th.name
                            font.pixelSize: 12
                            font.bold: on
                        }
                        MouseArea {
                            id: tMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.setv("theme", modelData)
                        }
                    }
                }
            }

            T { kind: "title"; text: I18n.t("Layout"); font.pixelSize: 16; font.bold: true; topPadding: 14 }

            SegRow {
                label: I18n.t("Style")
                desc: I18n.t("List, icon grid, full-width bar, or split (wallpaper on the left)")
                options: [
                    { label: I18n.t("List"), value: "list" },
                    { label: I18n.t("Grid"), value: "grid" },
                    { label: I18n.t("Bar"), value: "bar" },
                    { label: I18n.t("Split"), value: "split" }
                ]
                current: page.v("layout", "list")
                onChosen: function(x) { page.setv("layout", x) }
            }
            SegRow {
                label: I18n.t("Position")
                desc: I18n.t("Where the launcher opens on the screen")
                options: [
                    { label: I18n.t("Top"), value: "top" },
                    { label: I18n.t("Center"), value: "center" },
                    { label: I18n.t("Bottom"), value: "bottom" }
                ]
                current: page.v("position", "center")
                onChosen: function(x) { page.setv("position", x) }
            }
            SliderRow {
                label: I18n.t("Width")
                desc: I18n.t("Not used by the bar style")
                from: 360; to: 1200; step: 20
                value: page.v("width", 620)
                unit: " px"
                onCommitted: function(x) { page.setv("width", Math.round(x)) }
            }
            SliderRow {
                label: I18n.t("Rows")
                desc: I18n.t("How many results are visible")
                from: 3; to: 14; step: 1
                value: page.v("lines", 8)
                onCommitted: function(x) { page.setv("lines", Math.round(x)) }
            }

            T { kind: "title"; text: I18n.t("Appearance"); font.pixelSize: 16; font.bold: true; topPadding: 14 }

            ToggleRow {
                label: I18n.t("Transparency")
                desc: I18n.t("Translucent background; off makes it solid")
                checked: page.v("transparency", true) === true
                onToggled: function(x) { page.setv("transparency", x ? "on" : "off") }
            }
            SliderRow {
                label: I18n.t("Opacity")
                desc: I18n.t("Lower is more transparent")
                from: 0.3; to: 1.0; step: 0.02
                decimals: 2
                value: page.v("opacity", 0.82)
                onCommitted: function(x) { page.setv("opacity", x.toFixed(2)) }
            }
            ToggleRow {
                label: I18n.t("Blur")
                desc: I18n.t("Blur whatever is behind the launcher (needs transparency)")
                checked: page.v("blur", true) === true
                onToggled: function(x) { page.setv("blur", x ? "on" : "off") }
            }
            SliderRow {
                label: I18n.t("Corner radius")
                desc: I18n.t("Roundness of the window")
                from: 0; to: 32; step: 1
                value: page.v("radius", 18)
                unit: " px"
                onCommitted: function(x) { page.setv("radius", Math.round(x)) }
            }

            T { kind: "title"; text: I18n.t("Text"); font.pixelSize: 16; font.bold: true; topPadding: 14 }

            SliderRow {
                label: I18n.t("Font size")
                desc: I18n.t("The font comes from Services > Fonts (monospace)")
                from: 9; to: 20; step: 1
                value: page.v("font_size", 13)
                unit: " pt"
                onCommitted: function(x) { page.setv("font_size", Math.round(x)) }
            }
            ToggleRow {
                label: I18n.t("App icons")
                desc: I18n.t("Show icons next to the results")
                checked: page.v("icons", true) === true
                onToggled: function(x) { page.setv("icons", x ? "on" : "off") }
            }

            Row {
                spacing: 10
                topPadding: 8
                Rectangle {
                    width: 150; height: 38; radius: 12
                    color: pMouse.containsMouse ? "#ffffff" : "#F6F5F4"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    T { anchors.centerIn: parent; text: I18n.t("Open it"); font.pixelSize: 13; font.bold: true; color: "#0d0d0d" }
                    MouseArea {
                        id: pMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", "-c", "sleep 0.3; \"$HOME/.local/bin/rice-launch\""])
                    }
                }
                Rectangle {
                    width: 150; height: 38; radius: 12
                    color: rMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    T { anchors.centerIn: parent; text: I18n.t("Reset"); font.pixelSize: 13 }
                    MouseArea {
                        id: rMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-rofi\" reset"])
                            page.ctl.status = I18n.t("Launcher reset")
                            refresh.restart()
                        }
                    }
                }
            }

        }
    }
}
