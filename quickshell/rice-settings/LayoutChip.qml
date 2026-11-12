import QtQuick

// A module on the bar (or in a tray). Press and drag it; the page draws the floating copy.
Rectangle {
    id: c
    property string name: ""
    property string kind: "mod"       // "mod" = bar module, "sub" = icon inside System icons
    property string zone: ""
    property string icon: ""
    property string label: ""
    property bool dimmed: false
    property bool compact: false       // icon only (on the bar); the name shows on hover
    property var page

    height: 36
    width: compact ? 38 : row.implicitWidth + 26
    radius: 11
    color: m.containsMouse ? M3.surfaceHighest : "#1b1b1b"
    border.width: 1
    border.color: m.containsMouse ? M3.outline : M3.surfaceHighest
    opacity: dimmed ? 0.25 : 1
    Behavior on opacity { NumberAnimation { duration: 140 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        T { kind: "icon"; text: c.icon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; color: "#F6F5F4" }
        T { visible: !c.compact; text: c.label; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }

    Rectangle {
        visible: c.compact && m.containsMouse && !(c.page && c.page.dragName !== "")
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height + 6
        z: 50
        width: tip.implicitWidth + 16
        height: 24
        radius: 8
        color: "#F6F5F4"
        T { id: tip; anchors.centerIn: parent; text: c.label; font.pixelSize: 11; font.bold: true; color: "#0d0d0d" }
    }

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: c.page && c.page.dragName === c.name ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real sx: 0
        property real sy: 0
        property bool moved: false
        onPressed: function(e) { sx = e.x; sy = e.y; moved = false }
        onPositionChanged: function(e) {
            if (!pressed) return
            const p = mapToItem(c.page, e.x, e.y)
            if (!moved && Math.abs(e.x - sx) + Math.abs(e.y - sy) > 4) {
                moved = true
                c.page.startDrag(c, p.x, p.y, e.x, e.y)
            }
            if (moved) c.page.moveDrag(p.x, p.y)
        }
        onReleased: function(e) {
            if (!moved) return
            const p = mapToItem(c.page, e.x, e.y)
            c.page.endDrag(p.x, p.y)
        }
        onCanceled: c.page.cancelDrag()
    }
}
