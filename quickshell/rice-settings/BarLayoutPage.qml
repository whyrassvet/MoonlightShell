import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Bar layout: drag the modules of the DarkShadow bar between left, center and right,
// reorder them, or hide them.
Item {
    id: page
    property var ctl

    readonly property var info: ({
        "launcher": ["\udb80\udc3b", "Launcher"], "workspaces": ["\udb80\uddd8", "Workspaces"], "title": ["\udb81\uddb2", "Window title"],
        "media": ["\udb81\udf5a", "Music"], "tray": ["\udb81\udd70", "Tray"],
        "volume": ["\udb81\udd7e", "Volume"], "network": ["\udb81\udda9", "Wi-Fi"], "bluetooth": ["\udb80\udcaf", "Bluetooth"],
        "battery": ["\udb80\udc79", "Battery"], "notifications": ["\udb80\udc9a", "Notifications"], "power": ["\udb81\udc25", "Power"],
        "island": ["\udb80\udd50", "Island (clock)"], "visualizer": ["\udb81\udc7d", "Visualizer"],
        "weather": ["\udb81\udd99", "Weather"], "sysmon": ["\udb80\udd28", "System (CPU, RAM, disk)"], "date": ["\udb80\udcf0", "Date"], "music": ["\udb81\udf5a", "Music (player card)"]
    })
    readonly property var subsAll: []
    readonly property var defaults: ({
        left: ["launcher", "workspaces", "title"], center: ["island"],
        right: ["music", "tray", "volume", "bluetooth", "network", "battery", "notifications", "power"]
    })

    // the bar's settings (rice-bar)
    property var qb: ({})
    function qrun(args) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-bar\" \"$@\"", "_"].concat(args.map(function(a) { return String(a) })))
    }
    Process {
        id: qproc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-bar\" state 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.qb = JSON.parse(text); page.pull() } catch (e) { } } }
    }

    // local copy so drops show at once; refreshed from Settings state when not dragging
    property var lay: ({ left: [], center: [], right: [], available: [] })
    property var apps: []
    function pull() {
        if (dragName !== "") return
        if (qb.layout) {
            const l = JSON.parse(JSON.stringify(qb.layout))
            for (const z of ["left", "center", "right", "available"]) l[z] = (l[z] || []).map(function(m) { return m === "clock" ? "island" : m })
                .filter(function(m, i, a) { return a.indexOf(m) === i })
            lay = l
        }
    }
    Component.onCompleted: pull()

    // ready-made layouts (the island in the middle is the clock and everything that happens)
    readonly property var presets: [
        { k: "island", n: "Island", d: "Launcher and workspaces, the island, your status",
          l: { left: ["launcher", "workspaces"], center: ["island"], right: ["tray", "volume", "network", "battery", "notifications", "power"] } },
        { k: "focus", n: "Focus", d: "The window you work in, the island, a few icons",
          l: { left: ["workspaces", "title"], center: ["island"], right: ["volume", "network", "battery", "power"] } },
        { k: "full", n: "Everything", d: "All modules, music on the left",
          l: { left: ["launcher", "workspaces", "media"], center: ["island"], right: ["tray", "bluetooth", "network", "volume", "battery", "notifications", "power"] } },
        { k: "minimal", n: "Minimal", d: "Workspaces, the island, volume and power",
          l: { left: ["workspaces"], center: ["island"], right: ["volume", "power"] } },
        { k: "center", n: "All in the middle", d: "One group in the middle: great with the Notch style",
          l: { left: [], center: ["workspaces", "island", "volume", "network", "battery"], right: [] } }
    ]
    function same(a, b) { return JSON.stringify(a || []) === JSON.stringify(b || []) }
    function isPreset(l) { return same(lay.left, l.left) && same(lay.center, l.center) && same(lay.right, l.right) }
    function usePreset(pr) {
        const n = { left: pr.l.left.slice(), center: pr.l.center.slice(), right: pr.l.right.slice() }
        const used = n.left.concat(n.center, n.right)
        n.available = Object.keys(info).filter(function(k) { return used.indexOf(k) < 0 })
        lay = n
        page.qrun(["layout-set", JSON.stringify({ left: n.left, center: n.center, right: n.right })])
        page.ctl.status = I18n.t("Bar layout: ") + pr.n
    }

    function chip(n) {
        let i = info[n]
        if (!i) i = ["•", n]
        return { name: n, icon: i[0], label: i[1] }
    }
    function chips(list) { return (list || []).map(chip) }
    // room a zone needs for its icons, so nothing wraps onto a second line
    function need(list) { const n = (list || []).length; return n * 42 + 24 }
    readonly property var subHidden: subsAll.filter(function(s) { return apps.indexOf(s) < 0 })

    // ---------------- drag and drop ----------------
    property string dragName: ""
    property string dragKind: ""
    property string dragFrom: ""
    property string overZone: ""
    property int overIndex: -1
    property real gx: 0
    property real gy: 0
    property real offX: 0
    property real offY: 0
    readonly property var zonesMod: [zLeft, zCenter, zRight, zHidden]
    readonly property var zonesSub: []

    function startDrag(c, x, y, ox, oy) {
        dragName = c.name; dragKind = c.kind; dragFrom = c.zone
        ghost.icon = c.icon; ghost.label = c.label
        offX = ox; offY = oy
        moveDrag(x, y)
    }
    function moveDrag(x, y) {
        gx = x; gy = y
        const zs = dragKind === "sub" ? zonesSub : zonesMod
        let hit = null
        for (let i = 0; i < zs.length; i++) {
            const p = zs[i].mapFromItem(page, x, y)
            if (p.x >= 0 && p.y >= 0 && p.x <= zs[i].width && p.y <= zs[i].height) { hit = zs[i]; break }
        }
        if (hit) {
            const p = hit.mapFromItem(page, x, y)
            overZone = hit.zone
            overIndex = hit.indexAt(p.x, p.y)
        } else { overZone = ""; overIndex = -1 }
    }
    function cancelDrag() { dragName = ""; dragKind = ""; overZone = ""; overIndex = -1 }
    function endDrag(x, y) {
        moveDrag(x, y)
        const name = dragName, kind = dragKind, from = dragFrom, to = overZone
        let idx = overIndex
        cancelDrag()
        if (to === "") return
        if (kind === "mod") {
            const n = JSON.parse(JSON.stringify(lay))
            const src = n[from] || []
            const at = src.indexOf(name)
            if (from === to && at >= 0 && at < idx) idx -= 1   // same list: the gap closes first
            for (const z of ["left", "center", "right", "available"]) n[z] = (n[z] || []).filter(function(m) { return m !== name })
            n[to].splice(Math.max(0, Math.min(idx, n[to].length)), 0, name)
            lay = n
            page.qrun(["layout-set", JSON.stringify({ left: n.left, center: n.center, right: n.right })])
            page.ctl.status = to === "available" ? chip(name).label + I18n.t(" hidden") : chip(name).label + I18n.t(" moved")
        }
    }

    Column {
        id: col
        x: 24
        width: parent.width - 48
        spacing: 10

        SectionTitle {
            text: I18n.t("Layouts")
            sub: I18n.t("Pick one to start from, then change it below. The island in the middle is your clock, and it grows into music, volume, notifications and today.")
        }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.presets
                delegate: Rectangle {
                    id: pc
                    readonly property bool on: page.isPreset(modelData.l)
                    width: (parent.width - 20) / 3; height: 116
                    radius: on ? 28 : 18
                    Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    color: on ? M3.primaryContainer : (pm.containsMouse ? M3.surfaceHigh : M3.surfaceC)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    scale: pm.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    // a small bar: zones as tonal pills, the island in your key color
                    Item {
                        x: 14; y: 14; width: parent.width - 28; height: 26
                        Row {
                            id: lRow; spacing: 3; anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.l.left.length > 0
                            Repeater { model: modelData.l.left; delegate: Rectangle { width: 9; height: 9; radius: 4.5; color: pc.on ? M3.inkPrimaryC : M3.inkDim; opacity: 0.8 } }
                        }
                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Repeater { model: modelData.l.center
                                delegate: Rectangle { anchors.verticalCenter: parent.verticalCenter
                                    width: modelData === "island" ? 44 : 9; height: modelData === "island" ? 18 : 9; radius: height / 2
                                    color: modelData === "island" ? M3.primary : (pc.on ? M3.inkPrimaryC : M3.inkDim); opacity: modelData === "island" ? 1 : 0.8 } }
                        }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Repeater { model: modelData.l.right; delegate: Rectangle { width: 9; height: 9; radius: 4.5; color: pc.on ? M3.inkPrimaryC : M3.inkDim; opacity: 0.8 } }
                        }
                    }
                    Column {
                        x: 16; y: 52; width: parent.width - 32; spacing: 3
                        T { text: modelData.n; font.pixelSize: 14; font.bold: true; color: pc.on ? M3.inkPrimaryC : M3.ink }
                        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: modelData.d; font.pixelSize: 11; color: pc.on ? M3.inkPrimaryC : M3.inkDim }
                    }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.usePreset(modelData) }
                }
            }
        }

        SectionTitle {
            text: I18n.t("Bar layout")
            sub: I18n.t("Drag a module to move it. Drop it between others to change the order, or into \"Not on the bar\" to hide it. ")
        }

        // ---------- the bar ----------
        Rectangle {
            width: parent.width
            height: 128
            radius: M3.rL
            border.width: 0
            border.color: M3.outlineVariant
            gradient: Gradient {
                GradientStop { position: 0; color: M3.stageTop }
                GradientStop { position: 1; color: M3.stageBottom }
            }
            Rectangle {
                id: barBg
                x: 10; y: 12
                width: parent.width - 20
                height: 70
                radius: 14
                color: Qt.rgba(0.04, 0.04, 0.05, 0.92)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    LayoutZone {
                        id: zLeft
                        compact: true
                        zone: "left"; title: "LEFT"; page: page
                        width: Math.max(130, page.need(page.lay.left)); height: parent.height
                        items: page.chips(page.lay.left)
                        align: Qt.AlignLeft
                    }
                    LayoutZone {
                        id: zCenter
                        compact: true
                        zone: "center"; title: I18n.t("CENTER"); page: page
                        width: Math.max(70, parent.width - 8 - zLeft.width - zRight.width); height: parent.height
                        items: page.chips(page.lay.center)
                        align: Qt.AlignHCenter
                    }
                    LayoutZone {
                        id: zRight
                        compact: true
                        zone: "right"; title: I18n.t("RIGHT"); page: page
                        width: Math.max(130, page.need(page.lay.right)); height: parent.height
                        items: page.chips(page.lay.right)
                        align: Qt.AlignRight
                    }
                }
            }
            // names, in order, under each part of the bar
            Item {
                x: barBg.x + 4; y: barBg.y + barBg.height + 10
                width: barBg.width - 8; height: 16
                component Names: T {
                    property var list: []
                    text: list.map(function(m) { return page.chip(m).label }).join("  ·  ")
                    font.pixelSize: 10
                    color: M3.inkDim
                    elide: Text.ElideRight
                }
                Names { list: page.lay.left || []; x: 0; width: zLeft.width; horizontalAlignment: Text.AlignLeft; leftPadding: 10 }
                Names { list: page.lay.center || []; x: zLeft.width + 4; width: zCenter.width; horizontalAlignment: Text.AlignHCenter }
                Names { list: page.lay.right || []; x: zLeft.width + zCenter.width + 8; width: zRight.width; horizontalAlignment: Text.AlignRight; rightPadding: 10 }
            }
        }

        SectionTitle { text: I18n.t("Not on the bar"); sub: I18n.t("Drag one up to add it.") }
        LayoutZone {
            id: zHidden
            zone: "available"; page: page; wrap: true
            width: parent.width; height: 70
            color: hot ? Qt.rgba(1, 1, 1, 0.06) : M3.surfaceLow
            border.color: hot ? Qt.rgba(1, 1, 1, 0.35) : M3.outlineVariant
            items: page.chips(page.lay.available)
        }

        Row {
            spacing: 10
            topPadding: 6
            Btn {
                text: I18n.t("Default layout")
                icon: ""
                onClicked: {
                    const n = { left: page.defaults.left.slice(), center: page.defaults.center.slice(), right: page.defaults.right.slice(), available: [] }
                    page.lay = n
                    page.qrun(["layout-reset"])
                    page.ctl.status = I18n.t("Default layout")
                }
            }
        }
    }

    // floating copy under the pointer while dragging
    Rectangle {
        id: ghost
        property string icon: ""
        property string label: ""
        visible: page.dragName !== ""
        x: page.gx - page.offX
        y: page.gy - page.offY
        z: 100
        height: 36
        width: grow.implicitWidth + 26
        radius: 11
        color: "#F6F5F4"
        scale: 1.06
        Row {
            id: grow
            anchors.centerIn: parent
            spacing: 8
            T { kind: "icon"; text: ghost.icon; font.pixelSize: 14; color: "#0d0d0d"; anchors.verticalCenter: parent.verticalCenter }
            T { text: ghost.label; font.pixelSize: 12; font.bold: true; color: "#0d0d0d"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
