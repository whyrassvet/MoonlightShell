import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Appearance > Themes: a whole look in one click (colors, corners, shapes, the bar, widgets, notifications,
// window corners and gaps, motion, the font), and your colors in your apps (VSCodium / VS Code, Discord). rice-theme.
Item {
    id: page
    property var ctl
    property var list: ({ current: "", themes: [] })
    property var st: ({ apps: { vscode: true, discord: true }, found: { vscode: [], discord: [] } })
    property string busyKey: ""
    Process {
        id: listP
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-theme\" list 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.list = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: stP
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-theme\" state 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { } } }
    }
    onVisibleChanged: if (visible) { listP.running = true; stP.running = true }
    Process {
        id: run
        property string msg: ""
        onExited: function(code) {
            page.busyKey = ""
            if (page.ctl) page.ctl.status = code === 0 ? run.msg : I18n.t("That did not work")
            listP.running = true; stP.running = true
        }
    }
    function theme(args, msg) {
        if (run.running) return
        run.msg = msg
        run.command = ["bash", "-c", "\"$HOME/.local/bin/rice-theme\" \"$@\"", "_"].concat(args)
        run.running = true
    }
    function use(t) {
        busyKey = t.key
        const n = Object.assign({}, list); n.current = t.key; list = n
        // this window follows at once (the rest of the desktop in a moment)
        Prefs.cornerScale = t.corners; Prefs.accentShape = t.shape; Prefs.wavy = t.wavy
        Prefs.motion = t.motion; Prefs.bounce = t.bounce
        if (page.ctl && page.ctl.colorMode !== undefined) page.ctl.colorMode = t.colors
        theme(["apply", t.key], I18n.t("Theme: %1").replace("%1", t.name))
    }
    function places(l) { return (l || []).join(", ") }

    PageScroll {
        anchors.fill: parent

        SectionTitle { text: I18n.t("Themes"); sub: I18n.t("A whole look in one click: colors, corners, the bar, widgets, notifications, windows, motion and the font. Fine-tune any part of it on the other pages.") }
        Grid {
            id: grid
            width: parent.width
            columns: width > 720 ? 3 : 2
            spacing: 12
            Repeater {
                model: page.list.themes || []
                delegate: Item {
                    id: card
                    readonly property bool on: page.list.current === modelData.key
                    readonly property color bg: modelData.preview[0]
                    readonly property color acc: modelData.preview[1]
                    readonly property color ink: modelData.preview[2]
                    readonly property real r: 14 * modelData.corners
                    readonly property real bo: modelData.bar_opacity
                    width: (grid.width - (grid.columns - 1) * grid.spacing) / grid.columns
                    height: width * 0.62 + 64
                    Rectangle {
                        anchors.fill: parent
                        radius: M3.rL
                        color: cm.containsMouse ? M3.surfaceHigh : M3.surfaceC
                        border.width: card.on ? 2 : 0
                        border.color: M3.primary
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    // a small desktop in this theme
                    Rectangle {
                        id: mock
                        x: 10; y: 10; width: parent.width - 20; height: parent.width * 0.62 - 10
                        radius: Math.max(4, card.r)
                        clip: true
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.darker(card.bg, 1.3) }
                            GradientStop { position: 1; color: Qt.rgba(card.bg.r * 0.65 + card.acc.r * 0.35, card.bg.g * 0.65 + card.acc.g * 0.35, card.bg.b * 0.65 + card.acc.b * 0.35, 1) }
                        }
                        // the bar, in the theme's style
                        Item {
                            x: modelData.bar === "flat" ? 0 : 8; y: modelData.bar === "flat" ? 0 : 7
                            width: parent.width - 2 * x; height: 18
                            Rectangle {
                                visible: modelData.bar === "flat" || modelData.bar === "dynamic" || modelData.bar === "island"
                                anchors.fill: parent
                                radius: modelData.bar === "flat" ? 0 : (modelData.bar === "island" ? Math.min(9, card.r) : 9)
                                color: Qt.rgba(card.bg.r, card.bg.g, card.bg.b, modelData.bar_opacity)
                            }
                            Row {
                                visible: modelData.bar === "islands" || modelData.bar === "pills"
                                anchors.fill: parent; spacing: 6
                                Repeater { model: [0.28, 0.3, 0.3]
                                    delegate: Rectangle { width: (parent.width - 12) * modelData; height: 18; radius: 9
                                        color: Qt.rgba(card.bg.r, card.bg.g, card.bg.b, Math.max(0.35, card.bo)) } }
                            }
                            Row {
                                x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                Repeater { model: 4
                                    delegate: Rectangle { width: index === 0 ? 14 : 7; height: 7; radius: Math.min(3.5, card.r / 3)
                                        color: index === 0 ? card.acc : Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.3) } }
                            }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 7; radius: Math.min(3.5, card.r / 3); color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.7) }
                        }
                        // two windows with the theme's corners and gaps
                        Rectangle {
                            x: 8 + modelData.gaps_out * 0.6; y: 34
                            width: parent.width * 0.55; height: parent.height - 44
                            radius: modelData.rounding * 0.6
                            color: Qt.rgba(card.bg.r, card.bg.g, card.bg.b, 0.92)
                            border.width: Math.max(1, modelData.border * 0.6); border.color: card.acc
                            Column {
                                x: 8; y: 8; spacing: 4
                                Repeater { model: [0.7, 0.5, 0.62, 0.4]
                                    delegate: Rectangle { width: mock.width * 0.4 * modelData; height: 4; radius: 2
                                        color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, index === 0 ? 0.8 : 0.35) } }
                            }
                            T { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 7; text: I18n.t("Aa")
                                font.family: modelData.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: card.acc }
                        }
                        Rectangle {
                            x: mock.width * 0.55 + 8 + modelData.gaps_out * 0.6 + modelData.gaps_in; y: 34
                            width: mock.width - x - 8 - modelData.gaps_out * 0.6; height: parent.height - 44
                            radius: modelData.rounding * 0.6
                            color: Qt.rgba(card.bg.r, card.bg.g, card.bg.b, 0.85)
                            border.width: modelData.widgets === "outline" ? 1 : 0; border.color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.3)
                            Blob { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * 0.5; height: width; kind: modelData.shape; color: card.acc }
                        }
                    }
                    Column {
                        x: 16; y: mock.y + mock.height + 10
                        width: parent.width - 32
                        spacing: 2
                        Row {
                            spacing: 8
                            T { text: modelData.name; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Rectangle { visible: card.on; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9; color: M3.primary
                                Icon { anchors.centerIn: parent; name: "check"; glyph: ""; size: 12; color: M3.inkPrimary } }
                            T { visible: page.busyKey === modelData.key; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Applying..."); font.pixelSize: 11; color: M3.primary }
                        }
                        T { kind: "reading"; text: I18n.t(modelData.desc); width: parent.width; font.pixelSize: 11; color: M3.inkDim; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap }
                    }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (!card.on && page.busyKey === "") page.use(modelData) }
                }
            }
        }

        // ---------- your apps ----------
        SectionTitle { text: I18n.t("Your apps"); sub: I18n.t("Your apps take the colors of the desktop, and change with them (a new wallpaper, another theme).") }
        ToggleRow {
            label: I18n.t("VSCodium / VS Code")
            desc: page.st.found.vscode.length ? I18n.t("Colors in %1").replace("%1", page.places(page.st.found.vscode)) : I18n.t("Not found: install VSCodium or VS Code and open it once")
            checked: page.st.apps.vscode !== false
            onToggled: function(v) { page.theme(["app", "vscode", v ? "on" : "off"], v ? I18n.t("VSCodium has your colors") : I18n.t("VSCodium has its own colors again")) }
        }
        ToggleRow {
            label: I18n.t("Discord")
            desc: page.st.found.discord.length ? I18n.t("A theme in %1").replace("%1", page.places(page.st.found.discord)) : I18n.t("Needs Vesktop, Vencord, Equicord or BetterDiscord (the normal Discord app has no themes)")
            checked: page.st.apps.discord !== false
            onToggled: function(v) { page.theme(["app", "discord", v ? "on" : "off"], v ? I18n.t("Discord has your colors (restart it once)") : I18n.t("Discord theme removed")) }
        }
        SettingRow {
            label: I18n.t("Color the apps now")
            desc: I18n.t("They are colored by themselves every time the colors change")
            reserved: 170
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Now"); sym: "sync"; icon: ""; onClicked: page.theme(["sync"], I18n.t("Apps colored")) }
        }

        // ---------- fine-tune ----------
        SectionTitle { text: I18n.t("Fine-tune"); sub: I18n.t("Change any part of the theme you chose") }
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: I18n.t("Colors"); sym: "palette"; icon: ""; onClicked: page.ctl.page = 8 }
            Btn { text: I18n.t("Shapes"); sym: "category"; icon: ""; onClicked: page.ctl.page = 24 }
            Btn { text: I18n.t("Fonts"); sym: "text_fields"; icon: ""; onClicked: page.ctl.page = 19 }
            Btn { text: I18n.t("Motion"); sym: "animation"; icon: ""; onClicked: page.ctl.page = 20 }
            Btn { text: I18n.t("Bar"); sym: "toolbar"; icon: ""; onClicked: page.ctl.page = 2 }
            Btn { text: I18n.t("Windows"); sym: "select_window"; icon: ""; onClicked: page.ctl.page = 4 }
        }
    }
}
