import QtQuick

Item {
    id: page
    property var ctl

    property string peekKey: ""
    readonly property var shown: {
        const l = page.ctl.schemes || []
        const k = peekKey.length > 0 ? peekKey : page.ctl.colorMode
        for (let i = 0; i < l.length; i++) if (l[i].key === k) return l[i]
        return l.length > 0 ? l[0] : ({ name: "", preview: [M3.surfaceLow, "#888888", "#eeeeee"] })
    }
    function group(kind) { return (page.ctl.schemes || []).filter(s => s.kind === kind) }
    function currentName() {
        const l = page.ctl.schemes || []
        for (let i = 0; i < l.length; i++) if (l[i].key === page.ctl.colorMode) return l[i].name
        return page.ctl.colorMode
    }

    PageScroll {
        anchors.fill: parent

        // ---------- live preview: a tiny desktop in the hovered (or current) scheme ----------
        Rectangle {
            id: tprev
            readonly property color surf: page.shown.preview[0]
            readonly property color acc: page.shown.preview[1]
            readonly property color txt: page.shown.preview[2]
            width: parent.width
            height: 210
            radius: 16
            clip: true
            border.width: 1
            border.color: M3.outlineVariant
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(tprev.surf, 1.5) }
                GradientStop { position: 1; color: Qt.rgba(tprev.surf.r * 0.7 + tprev.acc.r * 0.3, tprev.surf.g * 0.7 + tprev.acc.g * 0.3, tprev.surf.b * 0.7 + tprev.acc.b * 0.3, 1) }
            }
            // bar
            Rectangle {
                x: 10; y: 10
                width: parent.width - 20; height: 26; radius: 9
                color: Qt.rgba(tprev.surf.r, tprev.surf.g, tprev.surf.b, 0.92)
                Behavior on color { ColorAnimation { duration: 220 } }
                Row {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: index === 0 ? 22 : 14; height: 14; radius: 7
                            color: index === 0 ? tprev.acc : Qt.rgba(tprev.txt.r, tprev.txt.g, tprev.txt.b, 0.25)
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }
                }
                T { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "12:34"; font.pixelSize: 11; color: tprev.txt }
            }
            // window with accent border
            Rectangle {
                x: 24; y: 50
                width: parent.width * 0.52; height: 140; radius: 12
                color: Qt.rgba(tprev.surf.r, tprev.surf.g, tprev.surf.b, 0.95)
                border.width: 2
                border.color: tprev.acc
                Behavior on border.color { ColorAnimation { duration: 220 } }
                Behavior on color { ColorAnimation { duration: 220 } }
                Column {
                    x: 14; y: 14; spacing: 8
                    T { text: page.shown.name; font.pixelSize: 18; font.bold: true; color: tprev.txt }
                    Rectangle { width: 160; height: 6; radius: 3; color: Qt.rgba(tprev.txt.r, tprev.txt.g, tprev.txt.b, 0.4) }
                    Rectangle { width: 120; height: 6; radius: 3; color: Qt.rgba(tprev.txt.r, tprev.txt.g, tprev.txt.b, 0.25) }
                    Rectangle {
                        width: 92; height: 26; radius: 13
                        color: tprev.acc
                        T { anchors.centerIn: parent; text: I18n.t("Button"); font.pixelSize: 11; font.bold: true
                            color: (0.299 * tprev.acc.r + 0.587 * tprev.acc.g + 0.114 * tprev.acc.b) > 0.55 ? M3.surfaceLow : "#F6F5F4" }
                    }
                }
            }
            // notification
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 18
                y: 50
                width: parent.width * 0.36; height: 58; radius: 12
                color: Qt.rgba(tprev.surf.r, tprev.surf.g, tprev.surf.b, 0.95)
                border.width: 1
                border.color: Qt.rgba(tprev.txt.r, tprev.txt.g, tprev.txt.b, 0.12)
                Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 10; color: tprev.acc }
                Column {
                    x: 52; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    T { text: I18n.t("Theme"); font.pixelSize: 12; font.bold: true; color: tprev.txt }
                    T { text: page.peekKey.length > 0 ? I18n.t("Click to use it") : I18n.t("In use"); font.pixelSize: 10; color: tprev.txt; opacity: 0.6 }
                }
            }
            T {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                text: page.peekKey.length > 0 ? I18n.t("Preview") : I18n.t("Current theme")
                font.pixelSize: 10
                color: tprev.txt
                opacity: 0.5
            }
        }

        SectionTitle { text: I18n.t("Dynamic"); sub: I18n.t("Taken from your wallpaper, they change with it.") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.group("dynamic")
                delegate: SchemeTile { scheme: modelData; selected: page.ctl.colorMode === modelData.key; onPicked: function(k) { page.ctl.setColorMode(k) }
                    onPeek: function(k, on) { if (on) page.peekKey = k; else if (page.peekKey === k) page.peekKey = "" } }
            }
        }

        SectionTitle { text: I18n.t("Monochrome"); sub: I18n.t("Black, white and quiet greys.") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.group("mono")
                delegate: SchemeTile { scheme: modelData; selected: page.ctl.colorMode === modelData.key; onPicked: function(k) { page.ctl.setColorMode(k) }
                    onPeek: function(k, on) { if (on) page.peekKey = k; else if (page.peekKey === k) page.peekKey = "" } }
            }
        }

        SectionTitle { text: I18n.t("Colors"); sub: I18n.t("Fixed palettes, the same on every wallpaper.") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.group("color")
                delegate: SchemeTile { scheme: modelData; selected: page.ctl.colorMode === modelData.key; onPicked: function(k) { page.ctl.setColorMode(k) }
                    onPeek: function(k, on) { if (on) page.peekKey = k; else if (page.peekKey === k) page.peekKey = "" } }
            }
        }
    }
}
