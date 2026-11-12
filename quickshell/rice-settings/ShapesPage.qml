import Quickshell
import QtQuick

// Settings > Appearance > Shapes: the shape library of the shell. Pick your shape (the avatar in the rail, the
// Home hero and highlights use it) and how round corners are everywhere in Settings.
Item {
    id: page
    property var ctl
    Blob { id: lib; visible: false }
    readonly property var names: ({
        circle: "Circle", square: "Square", slanted: "Slanted", arch: "Arch", fan: "Fan", arrow: "Arrow", semicircle: "Semicircle",
        oval: "Oval", pill: "Pill", triangle: "Triangle", diamond: "Diamond", clamshell: "Clamshell", pentagon: "Pentagon",
        hexagon: "Hexagon", gem: "Gem", sun: "Sun", verysunny: "Very sunny", cookie4: "Cookie 4", cookie6: "Cookie 6",
        cookie7: "Cookie 7", cookie: "Cookie 9", cookie12: "Cookie 12", ghostish: "Ghostish", clover: "Clover", clover8: "Clover 8",
        burst: "Burst", softburst: "Soft burst", boom: "Boom", softboom: "Soft boom", flower: "Flower", puffy: "Puffy",
        puffydiamond: "Puffy diamond", pixelcircle: "Pixel circle", pixeltriangle: "Pixel triangle", bun: "Bun", heart: "Heart"
    })
    function nm(k) { return names[k] || k }

    PageScroll {
        anchors.fill: parent

        // ---------- your shape ----------
        Rectangle {
            width: parent.width
            height: 170
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob {
                id: big
                x: 28; anchors.verticalCenter: parent.verticalCenter
                width: 124; height: 124
                kind: Prefs.accentShape
                color: M3.primary
                scale: 1
                RotationAnimator on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: page.visible }
                SequentialAnimation on scale { id: pop; running: false
                    NumberAnimation { to: 0.8; duration: 90 } NumberAnimation { to: 1; duration: M3.d(420); easing.type: Easing.OutBack; easing.overshoot: 2.2 * Prefs.bounce } }
            }
            Column {
                x: 180; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 180 - 24
                spacing: 6
                T { text: I18n.t("YOUR SHAPE"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "title"; text: page.nm(Prefs.accentShape); font.pixelSize: 28; font.weight: Font.Medium; color: M3.inkPrimaryC }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85)
                    text: I18n.t("Your avatar in the rail, the Home hero and the highlights of Settings take this shape. ") + lib.kinds.length + I18n.t(" shapes, all drawn by the shell.") }
            }
        }

        // ---------- the library ----------
        SectionTitle { text: I18n.t("Shape library"); sub: I18n.t("Click one to make it yours.") }
        Rectangle {
            width: parent.width
            height: grid.implicitHeight + 32
            radius: M3.rL
            color: M3.surfaceC
            Grid {
                id: grid
                x: 16; y: 16
                width: parent.width - 32
                columns: Math.max(4, Math.floor(width / 92))
                spacing: 4
                Repeater {
                    model: lib.kinds
                    delegate: Item {
                        id: cell
                        readonly property bool on: Prefs.accentShape === modelData
                        width: (grid.width - (grid.columns - 1) * 4) / grid.columns
                        height: width + 4
                        Rectangle {
                            anchors.fill: parent
                            radius: M3.rM
                            color: cell.on ? M3.secondaryContainer : (cm.containsMouse ? M3.surfaceHigh : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        Blob {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 10
                            width: parent.width * 0.52; height: width
                            kind: modelData
                            color: cell.on ? M3.primary : M3.inkDim
                            scale: cm.pressed ? 0.85 : (cm.containsMouse ? 1.08 : 1)
                            rotation: cm.containsMouse ? 20 : 0
                            Behavior on scale { NumberAnimation { duration: M3.d(260); easing.type: Easing.OutBack; easing.overshoot: 2 * Prefs.bounce } }
                            Behavior on rotation { NumberAnimation { duration: M3.d(500); easing.type: Easing.OutBack; easing.overshoot: 1.4 * Prefs.bounce } }
                        }
                        T { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: page.nm(modelData); font.pixelSize: 11; color: cell.on ? M3.inkSecondaryC : M3.inkDim }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Prefs.setAccentShape(modelData); pop.restart(); page.ctl.status = I18n.t("Your shape: ") + page.nm(modelData) } }
                    }
                }
            }
        }

        // ---------- corners ----------
        SectionTitle { text: I18n.t("Corners"); sub: I18n.t("How round cards, lists, menus, buttons and fields are in Settings.") }
        SliderRow {
            label: I18n.t("Corners")
            desc: I18n.t("1.0 is the Material 3 look; lower is squarer")
            from: 0.3; to: 1.5; step: 0.05; decimals: 2; unit: "×"
            value: Prefs.cornerScale
            onCommitted: function(v) { Prefs.setCornerScale(v) }
        }
        Row {
            width: parent.width
            spacing: 10
            Rectangle {
                width: (parent.width - 10) * 0.4; height: 110; radius: M3.rL; color: M3.surfaceC
                T { x: 16; y: 14; text: I18n.t("Card"); font.pixelSize: 14; font.weight: Font.Medium }
                T { kind: "reading"; x: 16; y: 36; width: parent.width - 32; wrapMode: Text.WordWrap; font.pixelSize: 11; color: M3.inkDim
                    text: I18n.t("Corners grow and shrink with the slider.") }
            }
            Rectangle {
                width: (parent.width - 10) * 0.6; height: 110; radius: M3.rL; color: M3.surfaceC
                Column {
                    x: 14; y: 14; width: parent.width - 28; spacing: 8
                    Rectangle {
                        width: parent.width; height: 40; radius: M3.rM; color: M3.secondaryContainer
                        Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "wifi"; glyph: ""; size: 18; color: M3.inkSecondaryC }
                        T { x: 42; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Wi-Fi  ·  connected"); font.pixelSize: 13; color: M3.inkSecondaryC }
                    }
                    Row { spacing: 8
                        Btn { text: I18n.t("Button"); primary: true }
                        Btn { text: I18n.t("Tonal") } }
                }
            }
        }
        Row {
            spacing: 8
            topPadding: 4
            Btn { text: I18n.t("Reset shapes"); sym: "restart_alt"; icon: ""; onClicked: { Prefs.setCornerScale(1); Prefs.setAccentShape("verysunny") } }
        }
    }
}
