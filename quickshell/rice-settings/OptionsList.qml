import QtQuick

Column {
    id: list
    property var ctl
    property var specs: []
    spacing: 10

    function num(key, def) {
        const v = (ctl && ctl.hv) ? ctl.hv[key] : undefined
        if (v === undefined || v === null || typeof v === "boolean") return def
        const n = Number(v)
        return isFinite(n) ? n : def
    }

    Repeater {
        model: list.specs
        delegate: Item {
            id: cell
            width: list.width
            property var spec: modelData
            opacity: 0
            Component.onCompleted: appear.start()
            SequentialAnimation {
                id: appear
                PauseAnimation { duration: Math.min(index, 12) * 28 }
                NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            }
            height: spec.type === "slider" ? sl.height : (spec.type === "toggle" ? tg.height : sg.height)

            SliderRow {
                id: sl
                visible: cell.spec.type === "slider"
                width: parent.width
                label: cell.spec.label
                desc: cell.spec.desc || ""
                from: cell.spec.min !== undefined ? cell.spec.min : 0
                to: cell.spec.max !== undefined ? cell.spec.max : 1
                step: cell.spec.step !== undefined ? cell.spec.step : 1
                decimals: cell.spec.dec !== undefined ? cell.spec.dec : 0
                unit: cell.spec.unit || ""
                value: list.num(cell.spec.key, cell.spec.def !== undefined ? cell.spec.def : 0)
                onCommitted: function(v) { list.ctl.hset(cell.spec.key, v) }
            }
            ToggleRow {
                id: tg
                visible: cell.spec.type === "toggle"
                width: parent.width
                label: cell.spec.label
                desc: cell.spec.desc || ""
                checked: list.ctl.hv[cell.spec.key] === true
                onToggled: function(v) { list.ctl.hset(cell.spec.key, v) }
            }
            SegRow {
                id: sg
                visible: cell.spec.type === "seg"
                width: parent.width
                label: cell.spec.label
                desc: cell.spec.desc || ""
                options: cell.spec.options || []
                current: String(list.ctl.hv[cell.spec.key])
                onChosen: function(v) { list.ctl.hset(cell.spec.key, v) }
            }
        }
    }
}