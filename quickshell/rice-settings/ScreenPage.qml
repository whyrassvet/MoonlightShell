import Quickshell
import Quickshell.Io
import QtQuick

// Settings > System > Monitors: the size of everything (scale), the resolution and the refresh rate of each screen,
// on Hyprland and on niri (hypr-set monitors / monitor-apply). A change shows at once; it is kept only after you
// press Keep, otherwise it goes back by itself after 15 seconds (so a screen that goes black fixes itself).
// With more screens: drag them to how they stand on your desk, give them names, turn them around or off, and pick
// the main screen: the one the bar, the island, the widgets and the dock live on (rice-screens).
Item {
    id: page
    property var ctl
    property var mons: []
    property string sel: ""                 // the screen being changed
    property int countdown: 0
    property string mainName: ""            // the shell lives here (rice-screens main)
    property string widgetsName: ""         // the desktop widgets live here ("" = with the shell; rice-screens widgets)
    property var names: ({})                // your names for the screens
    property var moved: ({})                // Arrange: name -> {x, y} not applied yet
    function label(n) { return names[n] ? names[n] : n }
    readonly property string mainNow: {
        if (mainName !== "") for (let i = 0; i < mons.length; i++) if (mons[i].name === mainName) return mainName
        return mons.length ? mons[0].name : ""
    }
    function rs(args, msg) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-screens\" \"$@\"", "_"].concat(args)); if (msg) ctl.status = msg; again.restart() }
    function arrange() {
        const l = []
        for (let i = 0; i < mons.length; i++) {
            const mm = mons[i], p = moved[mm.name]
            if (!mm.disabled) l.push({ name: mm.name, x: Math.round(p ? p.x : mm.x), y: Math.round(p ? p.y : mm.y) })
        }
        ctl.hrun(["monitor-layout", JSON.stringify(l)], "Screens arranged: keep it or it goes back")
        moved = ({}); countdown = 15; again.restart()
    }
    function setOne(key, value) {
        if (!m) return
        ctl.hrun(["monitor-set", m.name, key, value], "Screen changed: keep it or it goes back")
        countdown = 15; again.restart()
    }
    readonly property var m: {
        for (let i = 0; i < mons.length; i++) if (mons[i].name === sel) return mons[i]
        return mons.length ? mons[0] : null
    }
    readonly property string curRes: m ? m.width + "x" + m.height : ""
    readonly property string wm: Quickshell.env("NIRI_SOCKET") ? "niri" : "Hyprland"

    function ratesFor(res) {
        if (!m) return []
        for (let i = 0; i < m.modes.length; i++) if (m.modes[i].res === res) return m.modes[i].rates
        return []
    }
    // where a screen is, in the layout's pixels (its size divided by its scale, turned on its side when rotated)
    function rectOf(mm) {
        const p = moved[mm.name]
        const sc = Number(mm.scale) || 1
        let w = (mm.width || 1920) / sc, h = (mm.height || 1080) / sc
        if ((mm.transform || 0) % 2 === 1) { const t = w; w = h; h = t }
        if (mm.disabled) { w = 1920; h = 1080 }
        return { x: p ? p.x : mm.x, y: p ? p.y : mm.y, w: w, h: h }
    }
    // a screen let go in the arrange box: it snaps to the closest side of another screen, and lines up with it
    function dropped(mm, x, y) {
        const me = rectOf(mm)
        let bx = x, by = y, best = 1e18
        for (let i = 0; i < mons.length; i++) {
            const o = mons[i]
            if (o.name === mm.name || o.disabled) continue
            const r = rectOf(o)
            const cands = [
                [r.x + r.w, y], [r.x - me.w, y], [x, r.y + r.h], [x, r.y - me.h]
            ]
            for (let c = 0; c < cands.length; c++) {
                let cx = cands[c][0], cy = cands[c][1]
                // along the side: line up with an edge or the middle when close
                if (c < 2) {
                    cy = Math.max(r.y - me.h + 40, Math.min(r.y + r.h - 40, cy))
                    for (const e of [r.y, r.y + r.h - me.h, r.y + (r.h - me.h) / 2]) if (Math.abs(cy - e) < 120) cy = e
                } else {
                    cx = Math.max(r.x - me.w + 40, Math.min(r.x + r.w - 40, cx))
                    for (const e of [r.x, r.x + r.w - me.w, r.x + (r.w - me.w) / 2]) if (Math.abs(cx - e) < 120) cx = e
                }
                const d = (cx - x) * (cx - x) + (cy - y) * (cy - y)
                if (d < best) { best = d; bx = cx; by = cy }
            }
        }
        const n = Object.assign({}, moved); n[mm.name] = { x: Math.round(bx), y: Math.round(by) }; moved = n
    }
    function scaleText(s) { return Math.round(Number(s) * 100) + " %" }
    function apply(res, rate, scale) {
        if (!m) return
        ctl.hrun(["monitor-apply", m.name, res, String(rate), String(scale)], "Screen changed: keep it or it goes back")
        countdown = 15
        again.restart()
    }
    function keep() { ctl.hrun(["monitor-keep"], "Screen settings saved"); countdown = 0; again.restart() }
    function revert() { ctl.hrun(["monitor-revert"], "Screen settings went back"); countdown = 0; again.restart() }

    Process {
        id: monProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-screens\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let j
                try { j = JSON.parse(text) } catch (e) { return }
                page.mons = j.screens || []
                page.mainName = j.main || ""
                page.widgetsName = j.widgets || ""
                page.names = j.names || ({})
                if (page.sel === "" && page.mons.length) page.sel = page.mons[0].name
            }
        }
    }
    Timer { id: again; interval: 1200; onTriggered: monProc.running = true }
    Timer {
        interval: 1000; repeat: true; running: page.countdown > 0
        onTriggered: { page.countdown -= 1; if (page.countdown === 0) page.revert() }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the screen now ----------
        Rectangle {
            width: parent.width
            height: 150
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob { width: 220; height: 220; x: parent.width - 170; y: -40; kind: "puffy"; color: M3.alpha(M3.inkPrimaryC, 0.07)
                RotationAnimator on rotation { from: 0; to: 360; duration: 50000; loops: Animation.Infinite; running: page.visible } }
            Item {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 96; height: 96
                Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primary }
                Icon { anchors.centerIn: parent; name: "desktop_windows"; glyph: ""; size: 38; color: M3.inkPrimary }
            }
            Column {
                x: 140; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 140 - 24
                spacing: 3
                T { text: I18n.t("YOUR SCREEN"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "title"; width: parent.width; elide: Text.ElideRight; font.pixelSize: 24; font.weight: Font.Medium; color: M3.inkPrimaryC
                    text: page.m ? page.curRes + "  ·  " + page.m.rate + I18n.t(" Hz") : I18n.t("Looking for screens ...") }
                T { width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85)
                    text: page.m ? page.label(page.m.name) + (page.names[page.m.name] ? " (" + page.m.name + ")" : "") + I18n.t("  ·  size ") + page.scaleText(page.m.scale) + "  ·  " + page.wm : "" }
            }
        }

        // ---------- keep it? ----------
        Rectangle {
            visible: page.countdown > 0
            width: parent.width
            height: 64
            radius: M3.rL
            color: M3.tertiaryContainer !== undefined ? M3.tertiaryContainer : M3.secondaryContainer
            T { x: 18; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 290; wrapMode: Text.WordWrap
                text: I18n.t("Keep this? It goes back in ") + page.countdown + " s"; font.pixelSize: 14; font.weight: Font.Medium
                color: M3.inkTertiaryC !== undefined ? M3.inkTertiaryC : M3.inkSecondaryC }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Btn { text: I18n.t("Keep"); sym: "check"; icon: ""; primary: true; onClicked: page.keep() }
                Btn { text: I18n.t("Go back"); sym: "undo"; icon: ""; variant: "outlined"; onClicked: page.revert() }
            }
        }

        // ---------- your screens, as they stand on your desk ----------
        SectionTitle {
            visible: page.mons.length > 1
            text: I18n.t("Arrange your screens")
            sub: I18n.t("Drag them to how they stand on your desk; they snap to each other. Click one to change it below.")
        }
        Rectangle {
            id: desk
            visible: page.mons.length > 1
            width: parent.width
            height: 260
            radius: M3.rL
            color: M3.surfaceLow
            clip: true
            // all screens in one box: the space they take, scaled to fit with a margin
            readonly property var box: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
                for (let i = 0; i < page.mons.length; i++) {
                    const r = page.rectOf(page.mons[i])
                    x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y); x1 = Math.max(x1, r.x + r.w); y1 = Math.max(y1, r.y + r.h)
                }
                if (x1 < x0) return { x: 0, y: 0, w: 1920, h: 1080 }
                return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
            }
            readonly property real k: Math.min((width - 80) / Math.max(1, box.w * 1.35), (height - 60) / Math.max(1, box.h * 1.2))
            readonly property real ox: (width - box.w * k) / 2 - box.x * k
            readonly property real oy: (height - box.h * k) / 2 - box.y * k
            Repeater {
                model: page.mons
                delegate: Rectangle {
                    id: scr
                    required property var modelData
                    readonly property var r: page.rectOf(modelData)
                    readonly property bool chosen: page.m && page.m.name === modelData.name
                    readonly property bool isMain: page.mainNow === modelData.name
                    x: desk.ox + r.x * desk.k; y: desk.oy + r.y * desk.k
                    width: Math.max(40, r.w * desk.k); height: Math.max(30, r.h * desk.k)
                    radius: M3.rS
                    opacity: modelData.disabled ? 0.45 : 1
                    color: chosen ? M3.primaryContainer : M3.surfaceHigh
                    border.width: chosen ? 2 : 1
                    border.color: chosen ? M3.primary : M3.outlineVariant
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 2
                        T { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold
                            text: page.label(scr.modelData.name); color: scr.chosen ? M3.inkPrimaryC : M3.ink }
                        T { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: 11; color: M3.inkDim
                            text: scr.modelData.disabled ? I18n.t("off") : (scr.modelData.width + "×" + scr.modelData.height) }
                    }
                    // the shell lives here
                    Rectangle {
                        visible: scr.isMain && !scr.modelData.disabled
                        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 5
                        width: Math.min(parent.width * 0.5, 54); height: 5; radius: 2.5; color: M3.primary
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: scr.modelData.disabled ? Qt.PointingHandCursor : Qt.OpenHandCursor
                        drag.target: scr.modelData.disabled ? null : scr
                        drag.threshold: 4
                        property bool dragged: false
                        onPressed: { page.sel = scr.modelData.name; dragged = false }
                        onPositionChanged: if (drag.active) dragged = true
                        onReleased: if (dragged) {
                            page.dropped(scr.modelData, (scr.x - desk.ox) / desk.k, (scr.y - desk.oy) / desk.k)
                            // follow the layout again (the drag had taken the place over)
                            scr.x = Qt.binding(() => desk.ox + scr.r.x * desk.k)
                            scr.y = Qt.binding(() => desk.oy + scr.r.y * desk.k)
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12
                spacing: 8
                visible: Object.keys(page.moved).length > 0
                Btn { text: I18n.t("Undo"); variant: "text"; onClicked: page.moved = ({}) }
                Btn { text: I18n.t("Apply"); sym: "check"; icon: ""; variant: "filled"; onClicked: page.arrange() }
            }
        }

        // ---------- the chosen screen ----------
        Rectangle {
            visible: page.m !== null
            width: parent.width
            height: one.implicitHeight + 24
            radius: M3.rL
            color: M3.surfaceC
            Column {
                id: one
                x: 0; y: 12
                width: parent.width
                spacing: 4
                Item {
                    x: 18; width: parent.width - 36; height: 48
                    T { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Name"); font.pixelSize: 14 }
                    Field {
                        id: nameField
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(300, parent.width - 160)
                        placeholder: page.m ? page.m.name + (page.m.description ? "  ·  " + page.m.description : "") : ""
                        text: page.m && page.names[page.m.name] ? page.names[page.m.name] : ""
                        onAccepted: if (page.m) page.rs(["name", page.m.name, text], "Name saved")
                    }
                }
                Item {
                    x: 18; width: parent.width - 36; height: 52
                    visible: page.mons.length > 1
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - mainBtn.width - 16
                        T { text: I18n.t("Main screen"); font.pixelSize: 14 }
                        T { text: I18n.t("The bar, the island, the dock and the menus live here"); font.pixelSize: 12; color: M3.inkDim; width: parent.width; elide: Text.ElideRight }
                    }
                    Btn {
                        id: mainBtn
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        enabled: page.m && page.m.name !== page.mainNow && !page.m.disabled
                        text: page.m && page.m.name === page.mainNow ? I18n.t("This is the main screen") : I18n.t("Make it the main screen")
                        variant: enabled ? "tonal" : "text"
                        onClicked: if (page.m) { page.mainName = page.m.name; page.rs(["main", page.m.name], "The shell moves to " + page.label(page.m.name)) }
                    }
                }
                Item {
                    x: 18; width: parent.width - 36; height: 52
                    visible: page.mons.length > 1
                    readonly property string wNow: page.widgetsName !== "" ? page.widgetsName : page.mainNow
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - wBtn.width - 16
                        T { text: I18n.t("Desktop widgets"); font.pixelSize: 14 }
                        T { text: I18n.t("The screen your widgets are on (Edit mode opens there)"); font.pixelSize: 12; color: M3.inkDim; width: parent.width; elide: Text.ElideRight }
                    }
                    Btn {
                        id: wBtn
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        enabled: page.m && page.m.name !== parent.wNow && !page.m.disabled
                        text: page.m && page.m.name === parent.wNow ? I18n.t("The widgets are here") : I18n.t("Put the widgets here")
                        variant: enabled ? "tonal" : "text"
                        onClicked: if (page.m) {
                            const w = page.m.name === page.mainNow ? "main" : page.m.name
                            page.widgetsName = w === "main" ? "" : w
                            page.rs(["widgets", w], I18n.t("The widgets move to ") + page.label(page.m.name))
                        }
                    }
                }
                SegRow {
                    visible: page.m && !page.m.disabled
                    label: I18n.t("Turn")
                    desc: I18n.t("For a screen that stands on its side")
                    options: [{ label: "0°", value: "0" }, { label: "90°", value: "1" }, { label: "180°", value: "2" }, { label: "270°", value: "3" }]
                    current: page.m ? String(page.m.transform || 0) : "0"
                    onChosen: function(v) { page.setOne("rotate", v) }
                }
                ToggleRow {
                    visible: page.mons.length > 1
                    label: I18n.t("Screen on")
                    desc: I18n.t("Off: the screen gets nothing (you can turn it on here again)")
                    checked: page.m ? !page.m.disabled : true
                    onToggled: function(v) { page.setOne("enabled", v ? "on" : "off") }
                }
            }
        }

        // ---------- size ----------
        SectionTitle { text: I18n.t("Size"); sub: I18n.t("How big everything looks: text, windows, the bar. 100 % shows the most; bigger is easier to read on small, sharp screens.") }
        SegRow {
            label: I18n.t("Size of everything")
            desc: page.m ? I18n.t("Now ") + page.scaleText(page.m.scale) : ""
            options: [{ label: "100 %", value: "1" }, { label: "125 %", value: "1.25" }, { label: "150 %", value: "1.5" }, { label: "200 %", value: "2" }]
            current: page.m ? String(Number(page.m.scale)) : ""
            onChosen: function(v) { if (page.m) page.apply(page.curRes, page.m.rate, v) }
        }

        // ---------- resolution ----------
        SectionTitle { text: I18n.t("Resolution"); sub: I18n.t("The number of pixels. The first one is your screen's own (the sharpest).") }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: page.m ? page.m.modes : []
                delegate: Rectangle {
                    readonly property bool on: modelData.res === page.curRes
                    width: rt.implicitWidth + 32; height: 40; radius: on ? 12 * M3.shapeK : 20 * M3.shapeK
                    Behavior on radius { NumberAnimation { duration: 200 } }
                    color: on ? M3.primary : (rm.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                    T { id: rt; anchors.centerIn: parent; text: modelData.res.replace("x", " × "); font.pixelSize: 13; color: parent.on ? M3.inkPrimary : M3.ink }
                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (!parent.on) { const r = page.ratesFor(modelData.res); page.apply(modelData.res, r.length ? r[0] : page.m.rate, page.m.scale) } }
                }
            }
        }

        // ---------- refresh rate ----------
        SectionTitle { text: I18n.t("Refresh rate"); sub: I18n.t("How many times a second the picture changes. Higher is smoother (and uses a little more power on a laptop).") }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: page.ratesFor(page.curRes)
                delegate: Rectangle {
                    readonly property bool on: page.m && Math.abs(Number(modelData) - Number(page.m.rate)) < 0.5
                    width: ft.implicitWidth + 32; height: 40; radius: on ? 12 * M3.shapeK : 20 * M3.shapeK
                    Behavior on radius { NumberAnimation { duration: 200 } }
                    color: on ? M3.primary : (fm.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                    T { id: ft; anchors.centerIn: parent; text: Math.round(Number(modelData)) + I18n.t(" Hz"); font.pixelSize: 13; color: parent.on ? M3.inkPrimary : M3.ink }
                    MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (!parent.on) page.apply(page.curRes, modelData, page.m.scale) }
                }
            }
        }

        T {
            visible: page.mons.length === 0
            width: parent.width; wrapMode: Text.WordWrap; topPadding: 12
            text: I18n.t("No screens found (") + page.wm + I18n.t(" did not answer).")
            color: M3.inkDim
        }
    }
}
