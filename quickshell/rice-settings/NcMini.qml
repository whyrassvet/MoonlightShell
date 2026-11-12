import QtQuick

// A small drawing of the Deck notification center on a screen (Settings > Notifications).
// Follows the side, floating or flat, size, transparency, color and which rows are on.
Rectangle {
    id: m
    property var ns: ({})
    function v(k, d) { return ns[k] !== undefined ? ns[k] : d }
    readonly property string acc: v("accent", true) ? v("accent_color", "#9ec9bd") : "#F6F5F4"
    readonly property string accFg: v("accent", true) ? v("on_accent", "#0d0d0d") : "#0d0d0d"
    readonly property bool atRight: v("cc_side", "right") === "right"
    readonly property bool floating: v("cc_float", true) === true
    readonly property bool light: v("colors", "graphite") === "white"
    readonly property real k: width / 1920             // screen pixels -> preview pixels
    readonly property real op: v("style", "glass") === "solid" || v("flat", false) ? 1 : v("opacity", 0.8)
    readonly property color base: light ? "#f4f4f6" : (v("colors", "graphite") === "black" ? "#000000"
                                  : v("colors", "graphite") === "slate" ? "#181b22" : M3.surfaceLow)
    readonly property color fg: light ? M3.surfaceC : "#F6F5F4"
    readonly property color tile: light ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08)
    readonly property real gap: floating ? Math.max(4, v("margin", 10) * k * 1.6) : 0

    height: width * 9 / 16
    radius: 14
    clip: true
    // the desktop
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: M3.stageTop }
        GradientStop { position: 0.55; color: M3.surfaceC }
        GradientStop { position: 1; color: M3.stageBottom }
    }
    Rectangle { x: m.width * 0.08; y: m.height * 0.62; width: m.width * 0.5; height: m.width * 0.5; radius: width / 2; color: "#3a2f63"; opacity: 0.35 }
    Rectangle { x: m.width * 0.55; y: -m.height * 0.3; width: m.width * 0.45; height: width; radius: width / 2; color: "#1f5050"; opacity: 0.3 }
    // a window, so the panel sits over something
    Rectangle {
        x: m.atRight ? m.width * 0.06 : m.width * 0.42
        y: m.height * 0.16
        width: m.width * 0.5; height: m.height * 0.66
        radius: 8
        color: "#16161a"; opacity: 0.85
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Behavior on x { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    }

    // ---------- the panel ----------
    Rectangle {
        id: pnl
        readonly property real full: m.height - 2 * m.gap
        width: Math.max(90, m.v("panel_width", 420) * m.k * 1.25)
        height: (m.v("fit", false) || !m.floating) ? full : Math.min(full, m.v("panel_height", 820) * m.k * 1.25)
        x: m.atRight ? m.width - width - m.gap : m.gap
        y: m.gap
        radius: m.floating ? Math.max(6, m.v("radius", 18) * 0.6) : 0
        color: Qt.rgba(m.base.r, m.base.g, m.base.b, m.op)
        border.width: 1
        border.color: m.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.09)
        Behavior on x { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 260 } }
        // flat against the edge: round only on the inside
        Rectangle {
            visible: !m.floating
            width: parent.radius; height: parent.height
            x: m.atRight ? parent.width - width : 0
            color: parent.color
        }

        readonly property real u: width / 100
        Column {
            x: 6 * pnl.u; y: 6 * pnl.u
            width: pnl.width - 12 * pnl.u
            spacing: 3.2 * pnl.u

            // switches
            Row {
                visible: m.v("w_quick", true) === true
                spacing: 2.4 * pnl.u
                Repeater {
                    model: 5
                    Rectangle {
                        width: (pnl.width - 12 * pnl.u - 4 * 2.4 * pnl.u) / 5; height: width * 0.86
                        radius: width * 0.3
                        color: index === 0 || index === 1 ? m.acc : m.tile
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.32; height: width; radius: width / 2
                            color: index === 0 || index === 1 ? m.accFg : m.fg; opacity: 0.8 }
                    }
                }
            }
            // power modes
            Rectangle {
                visible: m.v("w_power", true) === true
                width: parent.width; height: 8 * pnl.u
                radius: height / 2
                color: m.tile
                Rectangle { x: parent.width / 3 + 0.8 * pnl.u; y: 0.8 * pnl.u; width: parent.width / 3 - 1.6 * pnl.u; height: parent.height - 1.6 * pnl.u; radius: height / 2; color: m.acc }
                Repeater {
                    model: 3
                    Rectangle { x: (index + 0.5) * parent.width / 3 - width / 2; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.16; height: 1.4 * pnl.u; radius: height / 2
                        color: index === 1 ? m.accFg : m.fg; opacity: index === 1 ? 0.85 : 0.4 }
                }
            }
            // notifications
            Rectangle { width: parent.width * 0.36; height: 1.6 * pnl.u; radius: height / 2; color: m.fg; opacity: 0.45 }
            Repeater {
                model: 3
                Rectangle {
                    width: parent.width; height: 13 * pnl.u
                    radius: 3.5 * pnl.u
                    color: m.tile
                    Rectangle { x: 3 * pnl.u; anchors.verticalCenter: parent.verticalCenter; width: 7 * pnl.u; height: width; radius: 2 * pnl.u; color: index === 0 ? m.acc : Qt.rgba(0.5, 0.5, 0.5, 0.4) }
                    Rectangle { x: 13 * pnl.u; y: 3.6 * pnl.u; width: parent.width * (0.5 - index * 0.08); height: 1.6 * pnl.u; radius: height / 2; color: m.fg; opacity: 0.8 }
                    Rectangle { x: 13 * pnl.u; y: 7.4 * pnl.u; width: parent.width * (0.68 - index * 0.1); height: 1.3 * pnl.u; radius: height / 2; color: m.fg; opacity: 0.35 }
                }
            }
        }
        // the bottom: sliders and power buttons
        Column {
            x: 6 * pnl.u
            width: pnl.width - 12 * pnl.u
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6 * pnl.u
            spacing: 2.6 * pnl.u
            Repeater {
                // volume, brightness (only on screens that have it)
                model: [m.v("w_volume", true) === true ? 0.62 : -1, m.v("w_brightness", true) === true ? 0.8 : -1]
                Rectangle {
                    visible: modelData >= 0
                    width: parent.width; height: 8 * pnl.u
                    radius: 3 * pnl.u
                    color: m.tile
                    Rectangle { x: 3 * pnl.u; anchors.verticalCenter: parent.verticalCenter; width: 2.6 * pnl.u; height: width; radius: width / 2; color: m.fg; opacity: 0.8 }
                    Rectangle {
                        x: 9 * pnl.u; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 12 * pnl.u; height: 2.6 * pnl.u; radius: height / 2
                        color: m.light ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(1, 1, 1, 0.1)
                        Rectangle { width: parent.width * Math.max(0, modelData); height: parent.height; radius: height / 2; color: m.acc }
                    }
                }
            }
            Row {
                visible: m.v("w_session", true) === true
                spacing: 2.4 * pnl.u
                Repeater {
                    model: 5
                    Rectangle {
                        width: (pnl.width - 12 * pnl.u - 4 * 2.4 * pnl.u) / 5; height: 8.5 * pnl.u
                        radius: 2.6 * pnl.u
                        color: m.tile
                        Rectangle { anchors.centerIn: parent; width: 2.6 * pnl.u; height: width; radius: width / 2
                            color: index === 4 ? "#e0505a" : m.fg; opacity: 0.75 }
                    }
                }
            }
        }
    }

    T { scaled: false;
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
        text: m.floating ? I18n.t("Floating") : I18n.t("Against the edge")
        font.pixelSize: 11; color: "#F6F5F4"; opacity: 0.5
        visible: false
    }
}
