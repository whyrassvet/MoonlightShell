import QtQuick

// A place chips can be dropped into: a part of the bar, the "not on the bar" tray, ...
Rectangle {
    id: zr
    property string zone: ""
    property string kind: "mod"
    property string title: ""
    property var items: []            // [{ name, icon, label }]
    property var page
    property int align: Qt.AlignLeft  // for the bar zones
    property bool wrap: false         // trays wrap onto more lines
    property bool compact: false      // icon-only chips
    property bool hot: page && page.dragKind === kind && page.overZone === zone
    property int marker: hot ? page.overIndex : -1
    readonly property alias flow: fl

    radius: 12
    color: hot ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    border.width: 1
    border.color: hot ? Qt.rgba(1, 1, 1, 0.35) : (page && page.dragKind === kind ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    T {
        visible: zr.title.length > 0
        x: 10; y: 4
        text: zr.title
        font.pixelSize: 9
        font.letterSpacing: 1.2
        color: "#5a5a62"
    }

    // index where a chip dropped at (px, py) (in this zone's coordinates) would go
    function indexAt(px, py) {
        let n = 0
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i)
            if (!it) continue
            const p = it.mapToItem(zr, 0, 0)
            const cy = p.y + it.height / 2
            const cx = p.x + it.width / 2
            if (cy < py - it.height / 2 || (Math.abs(cy - py) <= it.height / 2 && cx < px)) n = i + 1
        }
        return n
    }
    // x/y of the insert marker for index i
    function markerPos(i) {
        if (rep.count === 0) return Qt.point(fl.x + (fl.width - fl.implicitW) / 2, fl.y)
        if (i < rep.count) {
            const it = rep.itemAt(i)
            const p = it.mapToItem(zr, 0, 0)
            return Qt.point(p.x - 4, p.y)
        }
        const it = rep.itemAt(rep.count - 1)
        const p = it.mapToItem(zr, 0, 0)
        return Qt.point(p.x + it.width + 2, p.y)
    }

    Flow {
        id: fl
        readonly property real implicitW: {
            let w = 0
            for (let i = 0; i < rep.count; i++) { const it = rep.itemAt(i); if (it) w += it.width + spacing }
            return Math.max(0, w - spacing)
        }
        width: zr.wrap ? zr.width - 20 : Math.min(zr.width - 20, implicitW + 1)
        x: zr.wrap || zr.align === Qt.AlignLeft ? 10 : (zr.align === Qt.AlignRight ? zr.width - width - 10 : (zr.width - width) / 2)
        y: zr.wrap ? 20 : (zr.height - 36) / 2 + (zr.title.length > 0 ? 5 : 0)
        spacing: zr.compact ? 4 : 6
        move: Transition { NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic } }
        Repeater {
            id: rep
            model: zr.items
            delegate: LayoutChip {
                name: modelData.name || ""
                icon: modelData.icon || ""
                label: modelData.label || ""
                kind: zr.kind
                zone: zr.zone
                page: zr.page
                compact: zr.compact
                dimmed: !!zr.page && zr.page.dragName === modelData.name && zr.page.dragKind === zr.kind
            }
        }
    }
    T {
        visible: rep.count === 0 && !zr.hot
        anchors.centerIn: parent
        anchors.verticalCenterOffset: zr.title.length > 0 ? 5 : 0
        text: zr.wrap ? I18n.t("Drop here") : "empty"
        font.pixelSize: 11
        color: "#4a4a52"
    }
    Rectangle {
        visible: zr.marker >= 0
        readonly property point mp: zr.marker >= 0 ? zr.markerPos(zr.marker) : Qt.point(0, 0)
        x: mp.x; y: mp.y
        width: 2; height: 36; radius: 1
        color: "#F6F5F4"
    }
}
