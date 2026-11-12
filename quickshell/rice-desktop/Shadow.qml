import QtQuick

// A soft shadow under one of the shell's own parts (Settings > Desktop > Windows > Shell shadows): a few
// rounded layers that fade out, cheap to draw. Put it before the thing it belongs to, with the same geometry.
Item {
    id: sh
    property real radius: 20
    property bool on: Look.shadows
    property real size: Look.shadowSize
    property real strength: Look.shadowStrength
    property real offsetY: Math.round(size * 0.25)
    visible: on && strength > 0.01
    Repeater {
        model: 6
        delegate: Rectangle {
            readonly property real k: (index + 1) / 6
            x: -sh.size * k; y: -sh.size * k + sh.offsetY
            width: sh.width + 2 * sh.size * k; height: sh.height + 2 * sh.size * k
            radius: sh.radius + sh.size * k
            color: Qt.rgba(0, 0, 0, sh.strength * 0.16 * (1 - k * 0.8))
        }
    }
}
