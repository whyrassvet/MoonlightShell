import QtQuick

// A small picture of the notification center for the style picker (see bin/rice-notify: glass, solid, google).
Item {
    id: m
    property string look: "glass"          // glass (DarkShadow Shell) | solid (Dark) | google
    property string surface: "graphite"
    property string acc: "#d4d4d4"
    property string accFg: "#0d0d0d"
    property real baseRadius: 18

    function hexRgb(h) {
        const x = String(h).replace("#", "")
        return [parseInt(x.substr(0, 2), 16) || 212, parseInt(x.substr(2, 2), 16) || 212, parseInt(x.substr(4, 2), 16) || 212]
    }
    readonly property bool light: surface === "white"
    readonly property var baseRgb: light ? [246, 245, 244] : (surface === "black" ? [0, 0, 0] : (surface === "slate" ? [24, 27, 34] : [18, 18, 20]))
    // two colors mixed: k of b
    function mx(a, b, k) { return Qt.rgba((a[0] + (b[0] - a[0]) * k) / 255, (a[1] + (b[1] - a[1]) * k) / 255, (a[2] + (b[2] - a[2]) * k) / 255, 1) }
    readonly property var ink: light ? [0, 0, 0] : [255, 255, 255]
    readonly property var ac: hexRgb(acc)
    readonly property var gb: light ? [254, 247, 255] : [20, 19, 24]

    readonly property color panelC: look === "google" ? mx(gb, ac, 0.07)
                                  : look === "solid" ? mx(baseRgb, baseRgb, 0)
                                  : Qt.rgba(baseRgb[0] / 255, baseRgb[1] / 255, baseRgb[2] / 255, 0.5)
    readonly property color cardC: look === "google" ? mx(gb, ac, 0.12) : look === "solid" ? mx(baseRgb, ink, 0.07)
                                 : Qt.rgba(mx(baseRgb, ink, 0.08).r, mx(baseRgb, ink, 0.08).g, mx(baseRgb, ink, 0.08).b, 0.9)
    readonly property color tileC: look === "google" ? mx(gb, ac, 0.18) : look === "solid" ? mx(baseRgb, ink, 0.07) : Qt.rgba(ink[0] / 255, ink[1] / 255, ink[2] / 255, 0.08)
    readonly property color lineC: light ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.45)
    readonly property real pr: look === "google" ? Math.min(20, baseRadius * 1.1 + 4) : Math.min(14, baseRadius * 0.8)
    readonly property real cr: look === "google" ? 10 : 6

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: m.pr
        color: m.panelC
        border.width: m.look === "google" ? 0 : 1
        border.color: m.light ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on radius { NumberAnimation { duration: 160 } }

        // switches
        Row {
            x: 8; y: 8
            spacing: 4
            Repeater {
                model: 4
                delegate: Rectangle {
                    width: (panel.width - 16 - 12) / 4; height: 14
                    radius: m.look === "google" ? 7 : 4
                    color: index < 2 ? m.acc : m.tileC
                }
            }
        }
        // two notifications that do not touch
        Repeater {
            model: 2
            delegate: Rectangle {
                x: 8; y: 28 + index * (cardH + 5)
                readonly property real cardH: (panel.height - 28 - 8 - 5) / 2
                width: panel.width - 16; height: cardH
                radius: m.cr
                color: m.cardC
                Rectangle {
                    x: 5; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(16, parent.height - 8); height: width
                    radius: m.look === "google" ? width / 2 : 4
                    color: index === 0 ? m.acc : Qt.rgba(m.ac[0] / 255, m.ac[1] / 255, m.ac[2] / 255, 0.35)
                }
                Rectangle { x: 26; y: parent.height / 2 - 6; width: parent.width * 0.45; height: 3; radius: 1.5; color: m.lineC }
                Rectangle { x: 26; y: parent.height / 2 + 2; width: parent.width * 0.3; height: 3; radius: 1.5; color: m.lineC; opacity: 0.5 }
            }
        }
    }
}
