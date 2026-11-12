import QtQuick

Rectangle {
    id: t
    property var scheme: ({ key: "", name: "", preview: ["#111", "#888", "#eee"] })
    property bool selected: false
    signal picked(string key)
    signal peek(string key, bool on)
    width: 104
    height: 76
    radius: M3.rL
    color: selected ? M3.secondaryContainer : (m.containsMouse ? M3.surfaceHigh : M3.surfaceC)
    Behavior on color { ColorAnimation { duration: 160 } }
    border.width: selected ? 2 : 0
    border.color: selected ? M3.primary : (m.containsMouse ? M3.outline : M3.surfaceHighest)
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: m.containsMouse ? 1.03 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        x: 8; y: 8
        width: parent.width - 16
        height: 38
        radius: 9
        color: t.scheme.preview[0]
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        Rectangle { x: 7; y: 7; width: 30; height: 8; radius: 4; color: t.scheme.preview[1] }
        Rectangle { x: 7; y: 20; width: parent.width - 14; height: 10; radius: 5; color: t.scheme.preview[2]; opacity: 0.85 }
        Rectangle {
            visible: t.selected
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 5
            width: 14; height: 14; radius: 7
            color: M3.primary
            T { anchors.centerIn: parent; text: "✓"; font.pixelSize: 9; color: M3.inkPrimary; font.bold: true }
        }
    }
    T {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 53
        text: t.scheme.name
        font.pixelSize: 12
        font.bold: t.selected
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: t.picked(t.scheme.key)
        onEntered: t.peek(t.scheme.key, true)
        onExited: t.peek(t.scheme.key, false)
    }
}
