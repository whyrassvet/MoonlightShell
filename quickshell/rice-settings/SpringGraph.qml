import QtQuick

// One motion token drawn as a graph: a spring (damping ratio + stiffness) or an easing curve (cubic bezier),
// with time to the right and progress up. Click it to send a dot along the curve.
Rectangle {
    id: g
    property string name: ""
    property string info: ""
    property real zeta: 0.8          // spring: damping ratio
    property real stiff: 380         // spring: stiffness
    property var bez: []             // easing: [x1, y1, x2, y2]; empty = spring
    property int dur: 500            // easing: duration in ms
    property real t: 1               // 0 .. 1 while playing
    readonly property bool spring: bez.length !== 4
    width: 200
    height: 150
    radius: M3.rL
    color: gm.containsMouse ? M3.surfaceHigh : M3.surfaceC
    Behavior on color { ColorAnimation { duration: 140 } }

    // how long the spring takes to settle, in seconds (for the time axis)
    readonly property real span: spring ? Math.min(1.6, Math.max(0.25, 4.6 / (Math.max(0.2, zeta) * Math.sqrt(stiff)))) : dur / 1000
    function springAt(s) {          // s: seconds
        const w = Math.sqrt(stiff), z = zeta
        if (z < 1) { const wd = w * Math.sqrt(1 - z * z); return 1 - Math.exp(-z * w * s) * (Math.cos(wd * s) + z * w / wd * Math.sin(wd * s)) }
        return 1 - Math.exp(-w * s) * (1 + w * s)
    }
    function bezAt(x) {             // y for x on a cubic bezier from (0,0) to (1,1)
        const x1 = bez[0], y1 = bez[1], x2 = bez[2], y2 = bez[3]
        let lo = 0, hi = 1, u = x
        for (let i = 0; i < 24; i++) {
            u = (lo + hi) / 2
            const bx = 3 * (1 - u) * (1 - u) * u * x1 + 3 * (1 - u) * u * u * x2 + u * u * u
            if (bx < x) lo = u; else hi = u
        }
        return 3 * (1 - u) * (1 - u) * u * y1 + 3 * (1 - u) * u * u * y2 + u * u * u
    }
    function at(p) { return spring ? springAt(p * span) : bezAt(p) }

    T { x: 14; y: 10; text: g.name; font.pixelSize: 12; font.weight: Font.Medium }
    T { kind: "code"; anchors.right: parent.right; anchors.rightMargin: 14; y: 12; text: g.info; font.pixelSize: 10; color: M3.inkDim }
    Canvas {
        id: cv
        x: 14; y: 34
        width: parent.width - 28; height: parent.height - 48
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const top = height * 0.18, bot = height - 4, H = bot - top
            // the target line
            c.strokeStyle = M3.alpha(M3.ink, 0.12); c.lineWidth = 1
            c.beginPath(); c.moveTo(0, top); c.lineTo(width, top); c.stroke()
            c.strokeStyle = M3.primary; c.lineWidth = 2.5; c.lineCap = "round"
            c.beginPath()
            for (let i = 0; i <= 80; i++) {
                const p = i / 80, y = bot - g.at(p) * H
                if (i === 0) c.moveTo(p * width, y); else c.lineTo(p * width, y)
            }
            c.stroke()
        }
        Component.onCompleted: requestPaint()
        Connections { target: M3; function onPrimaryChanged() { cv.requestPaint() } }
    }
    // the dot that runs the curve
    Rectangle {
        readonly property real t0: cv.height * 0.18
        readonly property real hh: cv.height - 4 - t0
        width: 12; height: 12; radius: 6
        color: M3.ink
        x: cv.x + g.t * cv.width - 6
        y: cv.y + cv.height - 4 - g.at(g.t) * hh - 6
        border.width: 2; border.color: M3.primary
    }
    NumberAnimation { id: play; target: g; property: "t"; from: 0; to: 1; duration: Math.round(g.span * 1000 * 1.6); easing.type: Easing.Linear }
    onZetaChanged: cv.requestPaint()
    onStiffChanged: cv.requestPaint()
    onBezChanged: cv.requestPaint()
    MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: play.restart() }
}
