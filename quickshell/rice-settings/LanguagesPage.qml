import Quickshell
import QtQuick

// Settings > System > Languages: the language of this app. The choice is kept (settings-app.json) and applies at once.
// The words are in I18nData.qml; a text without a translation stays in English.
Item {
    id: page
    property var ctl
    readonly property var all: I18n.langs

    PageScroll {
        anchors.fill: parent

        // ---------- the language now ----------
        Rectangle {
            width: parent.width
            height: 132
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob { width: 220; height: 220; x: parent.width - 150; y: -50; kind: "flower"; color: M3.alpha(M3.inkPrimaryC, 0.06) }
            Icon { x: 24; y: 22; name: "translate"; glyph: ""; size: 20; color: M3.alpha(M3.inkPrimaryC, 0.75) }
            T { x: 54; y: 22; text: I18n.t("YOUR LANGUAGE"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                color: M3.alpha(M3.inkPrimaryC, 0.75) }
            T { x: 24; y: 48; kind: "title"; text: I18n.nameOf(I18n.lang); font.pixelSize: 30; font.weight: Font.Medium
                color: M3.inkPrimaryC; width: parent.width - 48; elide: Text.ElideRight }
            T { x: 24; y: 94; kind: "reading"; text: I18n.t("Choose the language of Settings. It changes right away."); font.pixelSize: 13
                color: M3.alpha(M3.inkPrimaryC, 0.85); width: parent.width - 48; elide: Text.ElideRight }
        }

        SectionTitle { text: I18n.t("All languages"); sub: I18n.t("Some pages are still in English; they will be translated step by step.") }

        // ---------- the languages ----------
        Flow {
            id: flow
            width: parent.width
            spacing: 10
            readonly property int cols: width >= 700 ? 3 : 2
            readonly property real cw: (width - (cols - 1) * spacing) / cols
            Repeater {
                model: page.all
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool on: I18n.lang === modelData[0]
                    width: flow.cw
                    height: 64
                    radius: M3.rL
                    color: on ? M3.secondaryContainer : (hov.hovered ? M3.surfaceHigh : M3.surfaceC)
                    border.width: on ? 2 : 0
                    border.color: M3.primary
                    Behavior on color { ColorAnimation { duration: 160 } }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    Column {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36 - 26
                        spacing: 2
                        T { text: card.modelData[1]; font.pixelSize: 15; font.weight: Font.Medium; width: parent.width; elide: Text.ElideRight
                            color: card.on ? M3.inkSecondaryC : M3.ink }
                        T { text: card.modelData[2]; font.pixelSize: 11; color: M3.inkDim; width: parent.width; elide: Text.ElideRight }
                    }
                    Icon { visible: card.on; name: "check_circle"; glyph: ""; size: 20; color: M3.primary
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.setLang(card.modelData[0]) }
                }
            }
        }
    }
}
