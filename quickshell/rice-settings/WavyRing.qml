import QtQuick

// A round loader with a wavy edge that turns and breathes (Material 3 Expressive style, drawn our own way).
// value < 0: keeps spinning (busy); 0 .. 1: shows that much of the ring.
Item {
    id: wr
    property real value: -1
    property bool wavy: Prefs.wavy
    property int thick: Prefs.progressThick
    property color color: M3.primary
    property color track: M3.surfaceHighest
    property bool running: visible
    property real spin: 0
    property real phase: 0
    implicitWidth: 44
    implicitHeight: 44
    NumberAnimation on spin { from: 0; to: Math.PI * 2; duration: 1600; loops: Animation.Infinite; running: wr.running }
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 900; loops: Animation.Infinite; running: wr.running && wr.wavy }
    onSpinChanged: cv.requestPaint()
    onValueChanged: cv.requestPaint()
    onThickChanged: cv.requestPaint()
    Canvas {
        id: cv
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const cx = width / 2, cy = height / 2, t = wr.thick
            const r = Math.min(width, height) / 2 - t - (wr.wavy ? 2 : 0)
            const busy = wr.value < 0
            const len = busy ? Math.PI * (0.9 + 0.5 * Math.sin(wr.spin * 2)) : Math.PI * 2 * Math.max(0.001, Math.min(1, wr.value))
            const start = busy ? wr.spin * 1.5 : -Math.PI / 2
            c.lineCap = "round"
            c.lineWidth = t
            if (!busy && wr.value < 1) {
                c.strokeStyle = wr.track
                c.beginPath(); c.arc(cx, cy, r, start + len + 0.35, start + Math.PI * 2 - 0.35); c.stroke()
            }
            c.strokeStyle = wr.color
            c.beginPath()
            const n = Math.max(8, Math.round(len * r / 2))
            for (let i = 0; i <= n; i++) {
                const a = start + len * i / n
                const rr = r + (wr.wavy ? 2 * Math.sin(a * 9 - wr.phase) : 0)
                const x = cx + rr * Math.cos(a), y = cy + rr * Math.sin(a)
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
            }
            c.stroke()
        }
    }
}
