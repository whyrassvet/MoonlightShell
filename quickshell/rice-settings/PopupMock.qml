import QtQuick

// A small fake notification popup that mirrors the swaync popup styles (see bin/rice-notify).
Item {
    id: m
    property string look: "glass"          // glass | solid | google | outline | minimal | pill | accent | glow | island | light
    property string surface: "graphite"    // black | graphite | slate | white | tinted
    property string edge: "subtle"         // subtle | accent | none
    property string fam: ""
    property string acc: "#d4d4d4"
    property string accFg: "#0d0d0d"
    property real baseRadius: 18
    property real op: 0.8                  // panel opacity (outline look)
    property real pop: 0.85                // popup opacity
    property bool shadowOn: true
    property real iconSize: 36
    property bool showBody: true
    property real fs: 1                    // font scale

    function hexRgb(h) {
        const x = String(h).replace("#", "")
        return [parseInt(x.substr(0, 2), 16) || 212, parseInt(x.substr(2, 2), 16) || 212, parseInt(x.substr(4, 2), 16) || 212]
    }
    readonly property var baseRgb: {
        if (surface === "black") return [0, 0, 0]
        if (surface === "slate") return [24, 27, 34]
        if (surface === "white") return [246, 245, 244]
        if (surface === "tinted") { const a = hexRgb(acc); return [14 + (a[0] - 14) * 0.14, 14 + (a[1] - 14) * 0.14, 14 + (a[2] - 14) * 0.14] }
        return [18, 18, 20]
    }
    // Google look: surfaces tinted with the accent
    function tonal(k) {
        const a = hexRgb(acc), b = surface === "white" ? [254, 247, 255] : [20, 19, 24]
        return Qt.rgba((b[0] + (a[0] - b[0]) * k) / 255, (b[1] + (a[1] - b[1]) * k) / 255, (b[2] + (a[2] - b[2]) * k) / 255, 1)
    }
    function bgc(a) { return Qt.rgba(baseRgb[0] / 255, baseRgb[1] / 255, baseRgb[2] / 255, a) }

    readonly property bool lightText: look === "light" || (surface === "white" && look !== "island")
    readonly property color fg: lightText ? M3.surfaceC : "#F6F5F4"
    readonly property color dim: lightText ? "#5c5c64" : M3.inkDim
    readonly property real r: look === "pill" ? height / 2 : look === "minimal" ? 8 : look === "accent" ? 10
                            : look === "island" ? Math.min(28, height / 2) : look === "google" ? baseRadius + 8 : baseRadius

    // soft drop shadow
    Rectangle {
        visible: m.shadowOn && m.look !== "glow"
        anchors.fill: card
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: card.radius
        color: "black"
        opacity: 0.22
    }
    // glow
    Rectangle {
        visible: m.look === "glow"
        anchors.fill: card
        anchors.margins: -5
        radius: card.radius + 5
        color: m.acc
        opacity: 0.22
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: m.r
        color: m.look === "island" ? "#000000"
             : m.look === "light" ? Qt.rgba(0.965, 0.96, 0.957, Math.max(m.pop, 0.9))
             : m.look === "solid" ? m.bgc(1)
             : m.look === "google" ? m.tonal(0.12)
             : m.look === "glass" ? m.bgc(Math.min(m.pop, 0.62))
             : m.look === "outline" ? m.bgc(m.op)
             : m.bgc(m.pop)
        border.width: (m.look === "minimal" || m.look === "island" || m.look === "google" || (m.edge === "none" && m.look !== "glow" && m.look !== "outline")) ? 0 : 1
        border.color: (m.look === "outline" || m.look === "glow" || m.edge === "accent") ? m.acc
                    : m.lightText ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.10)
        Behavior on radius { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 180 } }

        Rectangle {
            visible: m.look === "accent"
            width: 4; height: parent.height
            radius: 2
            color: m.acc
        }
        Rectangle {
            id: ico
            x: (m.look === "pill" || m.look === "island") ? parent.height * 0.18 : 10 * m.fs + (m.look === "accent" ? 4 : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(m.iconSize, parent.height - 12); height: width
            radius: (m.look === "pill" || m.look === "island") ? width / 2 : Math.max(5, width * 0.3)
            color: m.acc
            T { scaled: false; kind: "icon"; anchors.centerIn: parent; text: ""; font.pixelSize: ico.width * 0.45; color: m.accFg }
        }
        Column {
            anchors.left: ico.right
            anchors.leftMargin: 10 * m.fs
            anchors.right: parent.right
            anchors.rightMargin: 12 * m.fs
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * m.fs
            Item {
                width: parent.width
                height: sum.implicitHeight
                Text {
                    id: sum
                    text: I18n.t("DarkShadow's Shell")
                    font.family: m.fam.length > 0 ? m.fam : Fonts.family("main")
                    font.pixelSize: 13 * m.fs
                    font.bold: true
                    color: (m.look === "island") ? M3.primary : m.fg
                    width: parent.width - 30 * m.fs
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right
                    text: "now"
                    font.family: m.fam.length > 0 ? m.fam : Fonts.family("main")
                    font.pixelSize: 10 * m.fs
                    color: (m.look === "island") ? M3.inkDim : m.dim
                }
            }
            Text {
                visible: m.showBody
                width: parent.width
                text: I18n.t("This is how your notifications look.")
                font.family: m.fam.length > 0 ? m.fam : Fonts.family("main")
                font.pixelSize: 11 * m.fs
                color: (m.look === "island") ? M3.inkDim : m.dim
                elide: Text.ElideRight
            }
        }
    }
}
