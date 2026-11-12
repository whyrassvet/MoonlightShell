import QtQuick

// One notification sound: a little waveform you can click to pick and hear it.
Rectangle {
    id: tile
    property string name: ""
    property string label: ""
    property var bars: [0.4, 0.7, 1, 0.6, 0.3]
    property bool selected: false
    property bool playing: false
    signal picked()
    readonly property bool sfxOwn: true     // it plays its own sound when picked

    height: 84
    radius: M3.rL
    color: selected ? M3.secondaryContainer : (m.containsMouse ? M3.surfaceHigh : M3.surfaceC)
    border.width: selected ? 2 : 0
    border.color: selected ? M3.primary : (m.containsMouse ? M3.outline : M3.surfaceHighest)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: m.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    Timer { id: stop; interval: 1100; onTriggered: tile.playing = false }
    function flash() { playing = true; stop.restart() }

    Row {
        id: wave
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        height: 30
        spacing: 4
        Repeater {
            model: tile.bars
            delegate: Rectangle {
                id: bar
                property real k: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                radius: 2.5
                height: Math.max(4, 30 * modelData * k)
                color: tile.selected ? M3.primary : M3.inkDim
                Behavior on color { ColorAnimation { duration: 140 } }
                SequentialAnimation on k {
                    running: tile.playing
                    loops: 3
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: 110 + index * 35; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 140 + index * 30; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    T {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 54
        text: tile.label
        font.pixelSize: 12
        font.bold: tile.selected
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (tile.name !== "off") tile.flash(); tile.picked() }
    }
}
