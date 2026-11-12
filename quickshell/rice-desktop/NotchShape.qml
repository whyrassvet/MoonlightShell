import QtQuick

// The notch: a shape that grows out of the screen edge, with soft inward curves (ears) where it meets the edge
// and round corners at the far side. flip: for a bar at the bottom. shadow: a soft shadow along its far side.
Item {
    id: n
    property color fill: "#050506"
    property bool flip: false
    property bool shadow: true
    property real ear: 14
    property real corner: 20
    function path(c, W, H, e, r, o) {
        c.beginPath()
        c.moveTo(0, 0)
        c.arcTo(e, 0, e, e, e)
        c.lineTo(e, H - r - o)
        c.arcTo(e, H - o, e + r, H - o, r)
        c.lineTo(W - e - r, H - o)
        c.arcTo(W - e, H - o, W - e, H - r - o, r)
        c.lineTo(W - e, e)
        c.arcTo(W - e, 0, W, 0, e)
        c.closePath()
    }
    Canvas {
        id: cv
        anchors.fill: parent
        anchors.bottomMargin: -8          // room for the shadow
        transform: Scale { origin.y: n.height / 2; yScale: n.flip ? -1 : 1 }
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d"); c.reset()
            const W = width, H = n.height, e = n.ear, r = Math.min(n.corner, (H - e) / 1.2)
            // the shadow only outside the shape, so a see-through notch stays evenly see-through (and blurred)
            if (n.shadow) {
                c.save(); c.shadowColor = "rgba(0,0,0,0.35)"; c.shadowBlur = 10; c.shadowOffsetY = 3
                n.path(c, W, H, e, r, 0); c.fillStyle = "#000"; c.fill(); c.restore()
                c.save(); c.globalCompositeOperation = "destination-out"
                n.path(c, W, H, e, r, 0); c.fillStyle = "#000"; c.fill(); c.restore()
            }
            n.path(c, W, H, e, r, 0)
            c.fillStyle = n.fill
            c.fill()
        }
    }
    onFillChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    onShadowChanged: cv.requestPaint()
    onVisibleChanged: if (visible) cv.requestPaint()
}
