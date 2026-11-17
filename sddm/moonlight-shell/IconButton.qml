import QtQuick 2.15

// A round tonal button with a line icon; the corners square off a little while it is pressed (Material 3).
Rectangle {
    id: b
    property string kind: "power"
    property string tip: ""
    property color tone: "#33353a"
    property color ink: "white"
    property color hoverTone: Qt.lighter(tone, 1.25)
    signal clicked()
    width: 52; height: 52
    radius: m.pressed ? 16 : width / 2
    color: m.containsMouse || activeFocus ? hoverTone : tone
    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 140 } }
    activeFocusOnTab: true
    Keys.onReturnPressed: b.clicked()
    Keys.onSpacePressed: b.clicked()
    Glyph { anchors.centerIn: parent; kind: b.kind; color: b.ink }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    Text {
        visible: m.containsMouse && b.tip.length > 0
        text: b.tip
        color: b.ink
        font.pixelSize: 12
        font.family: b.parent && b.parent.fontName ? b.parent.fontName : ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
    }
}
