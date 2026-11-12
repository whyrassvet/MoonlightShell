import QtQuick

Rectangle {
    id: zc
    property string title: ""
    property var items: []
    property var available: []
    property var labelOf: function(n) { return n }
    property bool adding: false
    signal addRequested(string name)
    signal removeRequested(string name)
    signal moveRequested(string name, string dir)
    signal addToggled()

    width: parent ? parent.width : 400
    height: inner.implicitHeight + 28
    radius: 12
    color: M3.surfaceC
    border.width: 1
    border.color: M3.outlineVariant
    clip: true
    Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    ListModel { id: lm }

    function sync() {
        const n = zc.items
        for (let i = lm.count - 1; i >= 0; i--) {
            if (n.indexOf(lm.get(i).name) < 0) lm.remove(i)
        }
        for (let i = 0; i < n.length; i++) {
            if (i < lm.count && lm.get(i).name === n[i]) continue
            let found = -1
            for (let j = i + 1; j < lm.count; j++) {
                if (lm.get(j).name === n[i]) { found = j; break }
            }
            if (found >= 0) lm.move(found, i, 1)
            else lm.insert(i, { name: n[i] })
        }
    }
    onItemsChanged: sync()
    Component.onCompleted: sync()

    Column {
        id: inner
        x: 16
        y: 14
        width: zc.width - 32
        spacing: 10

        T { text: zc.title; font.pixelSize: 12; color: M3.inkDim }

        Flow {
            width: parent.width
            spacing: 6

            move: Transition {
                NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.8; to: 1; duration: 260; easing.type: Easing.OutBack }
                }
            }

            Repeater {
                model: lm
                delegate: Chip {
                    label: zc.labelOf(model.name)
                    canLeft: index > 0
                    canRight: index < lm.count - 1
                    onMoveLeft: zc.moveRequested(model.name, "left")
                    onMoveRight: zc.moveRequested(model.name, "right")
                    onRemoved: zc.removeRequested(model.name)
                }
            }

            Rectangle {
                width: 32
                height: 32
                radius: 9
                color: zc.adding ? M3.primary : (plusMouse.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                border.width: 1
                border.color: M3.surfaceHighest
                Behavior on color { ColorAnimation { duration: 160 } }
                T {
                    anchors.centerIn: parent
                    text: zc.adding ? "−" : "+"
                    font.pixelSize: 16
                    color: zc.adding ? M3.inkPrimary : "#F6F5F4"
                }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: zc.addToggled()
                }
            }
        }

        Flow {
            visible: zc.adding && zc.available.length > 0
            width: parent.width
            spacing: 6

            Repeater {
                model: zc.adding ? zc.available : []
                delegate: Rectangle {
                    id: opt
                    height: 32
                    width: addText.implicitWidth + 26
                    radius: 9
                    opacity: 0
                    color: addMouse.containsMouse ? M3.surfaceHighest : M3.surfaceLow
                    border.width: 1
                    border.color: M3.outline
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Component.onCompleted: optIn.start()
                    SequentialAnimation {
                        id: optIn
                        PauseAnimation { duration: Math.min(index, 8) * 30 }
                        NumberAnimation { target: opt; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    }
                    T { id: addText; anchors.centerIn: parent; text: "+ " + zc.labelOf(modelData); font.pixelSize: 12 }
                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: zc.addRequested(modelData)
                    }
                }
            }
        }

        T {
            visible: zc.adding && zc.available.length === 0
            text: I18n.t("Every module is already placed in the bar.")
            font.pixelSize: 12
            color: M3.inkDim
        }
    }
}
