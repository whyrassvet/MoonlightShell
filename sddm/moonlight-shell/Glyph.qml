import QtQuick 2.15

// Small line icons drawn here (the login screen cannot count on any icon font being installed).
Canvas {
    id: g
    property string kind: "power"
    property color color: "white"
    property real stroke: 2.2
    width: 22; height: 22
    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        const w = width, h = height, cx = w / 2, cy = h / 2, r = Math.min(w, h) * 0.36
        c.reset()
        c.strokeStyle = g.color
        c.fillStyle = g.color
        c.lineWidth = g.stroke
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (kind === "power") {
            c.arc(cx, cy + 1, r, -Math.PI / 2 + 0.75, -Math.PI / 2 - 0.75 + 2 * Math.PI, false)
            c.moveTo(cx, cy - r - 1.5); c.lineTo(cx, cy + 0.5)
        } else if (kind === "restart") {
            const a0 = -Math.PI / 2 + 0.55, a1 = a0 + Math.PI * 2 - 1.1
            c.arc(cx, cy, r, a0, a1, false)
            c.stroke(); c.beginPath()
            // the arrow head at the end of the arc, along its way round
            const ex = cx + r * Math.cos(a1), ey = cy + r * Math.sin(a1)
            const tx = -Math.sin(a1), ty = Math.cos(a1), nx = Math.cos(a1), ny = Math.sin(a1), k = r * 0.55
            c.moveTo(ex + tx * k, ey + ty * k); c.lineTo(ex + nx * k * 0.75, ey + ny * k * 0.75); c.lineTo(ex - nx * k * 0.75, ey - ny * k * 0.75)
            c.closePath(); c.fill()
            return
        } else if (kind === "sleep") {
            c.arc(cx, cy, r + 1, 0, 2 * Math.PI, false)
            c.closePath(); c.fill()
            c.globalCompositeOperation = "destination-out"
            c.beginPath(); c.arc(cx + r * 0.6, cy - r * 0.55, r * 0.95, 0, 2 * Math.PI, false); c.fill()
            c.globalCompositeOperation = "source-over"
            return
        } else if (kind === "arrow") {
            c.moveTo(cx - r, cy); c.lineTo(cx + r, cy)
            c.moveTo(cx + r * 0.2, cy - r * 0.8); c.lineTo(cx + r, cy); c.lineTo(cx + r * 0.2, cy + r * 0.8)
        } else if (kind === "left") {
            c.moveTo(cx + r * 0.35, cy - r * 0.8); c.lineTo(cx - r * 0.45, cy); c.lineTo(cx + r * 0.35, cy + r * 0.8)
        } else if (kind === "right") {
            c.moveTo(cx - r * 0.35, cy - r * 0.8); c.lineTo(cx + r * 0.45, cy); c.lineTo(cx - r * 0.35, cy + r * 0.8)
        } else if (kind === "desktop") {
            c.rect(cx - r * 1.1, cy - r * 0.85, r * 2.2, r * 1.45)
            c.moveTo(cx - r * 0.5, cy + r * 1.05); c.lineTo(cx + r * 0.5, cy + r * 1.05)
        } else if (kind === "keyboard") {
            c.rect(cx - r * 1.15, cy - r * 0.7, r * 2.3, r * 1.4)
            c.moveTo(cx - r * 0.55, cy + r * 0.3); c.lineTo(cx + r * 0.55, cy + r * 0.3)
        } else if (kind === "caps") {
            c.moveTo(cx - r * 0.8, cy + r * 0.1); c.lineTo(cx, cy - r * 0.9); c.lineTo(cx + r * 0.8, cy + r * 0.1)
            c.moveTo(cx - r * 0.6, cy + r * 0.85); c.lineTo(cx + r * 0.6, cy + r * 0.85)
        }
        c.stroke()
    }
}
