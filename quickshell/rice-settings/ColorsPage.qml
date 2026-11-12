import Quickshell
import QtQuick

// Settings > Appearance > Colors: every color role Settings and the shell are painted with, made from one key
// color (your theme accent / wallpaper). Click a tile to copy its hex code.
Item {
    id: page
    property var ctl
    function hex(c) {
        const q = Qt.color(c)
        const h = function(v) { const s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return ("#" + h(q.r) + h(q.g) + h(q.b)).toUpperCase()
    }
    function copy(name, c) {
        Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "_", hex(c)])
        page.ctl.status = name + " " + hex(c) + I18n.t(" copied")
    }

    readonly property var roles: [
        { n: "primary", c: M3.primary, i: M3.inkPrimary, on: "onPrimary" },
        { n: "primaryContainer", c: M3.primaryContainer, i: M3.inkPrimaryC, on: "onPrimaryContainer" },
        { n: "secondary", c: M3.secondary, i: M3.inkPrimary, on: "onSecondary" },
        { n: "secondaryContainer", c: M3.secondaryContainer, i: M3.inkSecondaryC, on: "onSecondaryContainer" },
        { n: "tertiary", c: M3.tertiary, i: M3.mix(M3.tertiary, "#000000", 0.8), on: "onTertiary" },
        { n: "tertiaryContainer", c: M3.tertiaryContainer, i: M3.inkTertiaryC, on: "onTertiaryContainer" },
        { n: "error", c: M3.error, i: "#690005", on: "onError" },
        { n: "errorContainer", c: M3.errorContainer, i: M3.inkErrorC, on: "onErrorContainer" }
    ]
    readonly property var surfaces: [
        { n: "Lowest", c: M3.surfaceLowest }, { n: "Surface", c: M3.surface }, { n: "Low", c: M3.surfaceLow },
        { n: "Container", c: M3.surfaceC }, { n: "High", c: M3.surfaceHigh }, { n: "Highest", c: M3.surfaceHighest },
        { n: "Bright", c: M3.surfaceBright }
    ]

    PageScroll {
        anchors.fill: parent

        // ---------- the key color ----------
        Rectangle {
            width: parent.width
            height: 132
            radius: M3.rXL
            color: M3.surfaceC
            clip: true
            // the key color, as a blob that grows into the role circles
            Repeater {
                model: [M3.primary, M3.secondary, M3.tertiary]
                delegate: Rectangle {
                    width: 86; height: 86; radius: 43
                    x: 24 + index * 46; anchors.verticalCenter: parent.verticalCenter
                    color: modelData
                    border.width: 3; border.color: M3.surfaceC
                    z: 3 - index
                }
            }
            Column {
                x: 24 + 2 * 46 + 86 + 22; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 24
                spacing: 6
                T { text: I18n.t("KEY COLOR"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.primary }
                T { kind: "title"; text: page.hex(M3.seed); font.pixelSize: 26; font.weight: Font.Medium }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.inkDim
                    text: I18n.t("Comes from your theme or wallpaper. Every color below is made from it, so the whole shell matches.") }
            }
            Btn { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Theme"); sym: "palette"; icon: ""; onClicked: page.ctl.page = 8 }
        }

        // ---------- roles ----------
        SectionTitle { text: I18n.t("Color roles"); sub: I18n.t("Each role has an \"on\" color for text and icons on top of it. Containers are the soft versions used for groups.") }
        Grid {
            id: grid
            width: parent.width
            columns: width > 700 ? 4 : 2
            spacing: 10
            Repeater {
                model: page.roles
                delegate: Rectangle {
                    id: tile
                    width: (grid.width - (grid.columns - 1) * 10) / grid.columns
                    height: 96
                    radius: tm.pressed ? M3.rS : M3.rL
                    color: modelData.c
                    scale: tm.pressed ? 0.97 : 1
                    Behavior on radius { NumberAnimation { duration: M3.d(200); easing.type: M3.springy } }
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    T { x: 14; y: 12; text: modelData.n; font.pixelSize: 13; font.weight: Font.Medium; color: modelData.i; width: parent.width - 28; elide: Text.ElideRight }
                    T { x: 14; y: 32; text: modelData.on; font.pixelSize: 11; color: M3.alpha(modelData.i, 0.75) }
                    T { kind: "code"; x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: page.hex(modelData.c); font.pixelSize: 11; color: modelData.i }
                    Icon { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; name: "content_copy"; glyph: ""; size: 15; color: modelData.i
                        opacity: tm.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 140 } } }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.copy(modelData.n, modelData.c) }
                }
            }
        }

        // ---------- surfaces ----------
        SectionTitle { text: I18n.t("Surfaces and containment"); sub: I18n.t("Surfaces stack the interface without shadows: lowest at the back, highest for what is on top.") }
        Row {
            id: srow
            width: parent.width
            height: 120
            Repeater {
                model: page.surfaces
                delegate: Rectangle {
                    width: srow.width / page.surfaces.length
                    height: srow.height
                    color: modelData.c
                    radius: index === 0 || index === page.surfaces.length - 1 ? M3.rL : 0
                    // square off the inner side of the two end pieces
                    Rectangle { visible: index === 0; anchors.right: parent.right; width: parent.radius; height: parent.height; color: parent.color }
                    Rectangle { visible: index === page.surfaces.length - 1; anchors.left: parent.left; width: parent.radius; height: parent.height; color: parent.color }
                    T { x: 12; y: 12; text: modelData.n; font.pixelSize: 12; font.weight: Font.Medium; color: M3.ink }
                    T { kind: "code"; x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: page.hex(modelData.c); font.pixelSize: 10; color: M3.inkDim }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.copy("surface " + modelData.n, modelData.c) }
                }
            }
        }
        // the same surfaces, nested the way the shell uses them
        Rectangle {
            width: parent.width; height: 170; radius: M3.rXL; color: M3.surfaceLowest
            Rectangle {
                anchors.fill: parent; anchors.margins: 14; radius: M3.rL; color: M3.surfaceC
                T { x: 16; y: 12; text: I18n.t("Window · surfaceContainer"); font.pixelSize: 11; color: M3.inkDim }
                Rectangle {
                    x: 14; y: 36; width: parent.width * 0.5 - 21; height: parent.height - 50; radius: M3.rM; color: M3.surfaceHigh
                    T { x: 14; y: 12; text: I18n.t("Card · high"); font.pixelSize: 11; color: M3.inkDim }
                    Rectangle { x: 14; y: 36; width: parent.width - 28; height: 30; radius: 15; color: M3.surfaceHighest
                        T { anchors.centerIn: parent; text: I18n.t("Field · highest"); font.pixelSize: 11; color: M3.inkDim } }
                }
                Rectangle {
                    x: parent.width * 0.5 + 7; y: 36; width: parent.width * 0.5 - 21; height: parent.height - 50; radius: M3.rM; color: M3.primaryContainer
                    T { x: 14; y: 12; text: I18n.t("Selected · primaryContainer"); font.pixelSize: 11; color: M3.inkPrimaryC }
                    Rectangle { x: 14; y: 36; width: bt.implicitWidth + 30; height: 34; radius: 17; color: M3.primary
                        T { id: bt; anchors.centerIn: parent; text: I18n.t("Button · primary"); font.pixelSize: 12; font.weight: Font.Medium; color: M3.inkPrimary } }
                }
            }
        }
    }
}
