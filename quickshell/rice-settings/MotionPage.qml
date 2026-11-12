import Quickshell
import QtQuick

// Settings > Motion: how windows move (Hyprland's animations, with spring styles) and how Settings itself moves.
// Moved here from Hyprland > Animations.
Item {
    id: page
    property var ctl
    readonly property var ha: ctl ? ctl.ha : ({})
    readonly property string style: ha.style === "bouncy" ? "expressive" : (ha.style || "calm")

    // a little stage that plays the chosen feeling: a shape that travels, grows and changes its corners
    property bool flip: false
    Timer { interval: 1500; running: page.visible; repeat: true; onTriggered: page.flip = !page.flip }

    readonly property var styles: [
        { k: "calm", n: "Calm", d: "Smooth curves, no bounce", sym: "waves", g: "", over: 0, dur: 520 },
        { k: "lively", n: "Lively", d: "Springs with a small overshoot", sym: "airwave", g: "", over: 1.3, dur: 560 },
        { k: "fluid", n: "Fluid", d: "Material 3 emphasized: a long, soft landing, no bounce", sym: "water", g: "", over: 0, dur: 640 },
        { k: "expressive", n: "Expressive", d: "Material 3 springs: a soft pop with a hint of overshoot", sym: "auto_awesome", g: "", over: 1.4, dur: 620 },
        { k: "snappy", n: "Snappy", d: "Short and quick", sym: "bolt", g: "", over: 0, dur: 260 },
        { k: "minimal", n: "Minimal", d: "Fades only", sym: "blur_on", g: "", over: 0, dur: 360 }
    ]
    // Material 3 motion tokens (expressive springs, the standard ones when Settings > Feel is Standard)
    readonly property var springs: M3.bouncy ? [
        { n: "Spatial fast", z: 0.6, k: 800 }, { n: "Spatial default", z: 0.8, k: 380 }, { n: "Spatial slow", z: 0.8, k: 200 },
        { n: "Effects fast", z: 1, k: 3800 }, { n: "Effects default", z: 1, k: 1600 }, { n: "Effects slow", z: 1, k: 800 }
    ] : [
        { n: "Spatial fast", z: 0.9, k: 1400 }, { n: "Spatial default", z: 0.9, k: 700 }, { n: "Spatial slow", z: 0.9, k: 300 },
        { n: "Effects fast", z: 1, k: 3800 }, { n: "Effects default", z: 1, k: 1600 }, { n: "Effects slow", z: 1, k: 800 }
    ]
    readonly property var easings: [
        { n: "Emphasized", b: [0.2, 0, 0, 1], d: 500 },
        { n: "Emphasized decelerate", b: [0.05, 0.7, 0.1, 1], d: 400 },
        { n: "Emphasized accelerate", b: [0.3, 0, 0.8, 0.15], d: 200 },
        { n: "Standard", b: [0.2, 0, 0, 1], d: 300 },
        { n: "Standard decelerate", b: [0, 0, 0, 1], d: 250 },
        { n: "Standard accelerate", b: [0.3, 0, 1, 1], d: 200 }
    ]
    readonly property var durations: [
        ["short1", 50], ["short2", 100], ["short3", 150], ["short4", 200],
        ["medium1", 250], ["medium2", 300], ["medium3", 350], ["medium4", 400],
        ["long1", 450], ["long2", 500], ["long3", 550], ["long4", 600],
        ["xlong1", 700], ["xlong2", 800], ["xlong3", 900], ["xlong4", 1000]
    ]
    property int durSel: -1
    function cur() { for (let i = 0; i < styles.length; i++) if (styles[i].k === style) return styles[i]; return styles[0] }

    PageScroll {
        anchors.fill: parent

        // ---------- the stage ----------
        Rectangle {
            id: stage
            width: parent.width
            height: 170
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            readonly property var st: page.cur()
            Column {
                x: 26; anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.45
                spacing: 6
                T { text: I18n.t("MOTION"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "title"; text: stage.st.n; font.pixelSize: 30; font.weight: Font.Medium; color: M3.inkPrimaryC }
                T { kind: "reading"; text: stage.st.d + I18n.t(". Windows, workspaces and pop-ups move like this."); width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85) }
            }
            // the track the shape runs on
            Item {
                id: track
                x: parent.width * 0.5; width: parent.width * 0.5 - 30
                height: parent.height
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: M3.alpha(M3.inkPrimaryC, 0.12) }
                Rectangle {
                    id: ball
                    readonly property real big: page.flip ? 64 : 44
                    width: big; height: big
                    radius: page.flip ? big / 2 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    x: page.flip ? track.width - width : 0
                    color: M3.primary
                    opacity: stage.st.k === "minimal" ? (page.flip ? 1 : 0.35) : 1
                    Behavior on x { enabled: stage.st.k !== "minimal"
                        NumberAnimation { duration: stage.st.dur; easing.type: stage.st.over > 0 ? Easing.OutBack : (stage.st.k === "snappy" ? Easing.OutQuart : Easing.InOutCubic); easing.overshoot: stage.st.over } }
                    Behavior on width { NumberAnimation { duration: stage.st.dur; easing.type: stage.st.over > 0 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: stage.st.over } }
                    Behavior on height { NumberAnimation { duration: stage.st.dur; easing.type: stage.st.over > 0 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: stage.st.over } }
                    Behavior on radius { NumberAnimation { duration: stage.st.dur; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: stage.st.dur } }
                }
            }
        }

        // ---------- windows ----------
        SectionTitle { text: I18n.t("Windows"); sub: (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(": opening and closing windows, switching workspaces, pop-ups.") }
        ToggleRow {
            label: I18n.t("Animations")
            desc: I18n.t("Off: everything appears at once")
            checked: page.ha.enabled !== false
            onToggled: function(v) { page.ctl.setAnim("enabled", v) }
        }
        Flow {
            id: flow
            width: parent.width
            spacing: 10
            Repeater {
                model: page.styles
                delegate: Rectangle {
                    id: tile
                    readonly property bool on: page.style === modelData.k
                    width: (flow.width - 40) / 5 < 120 ? (flow.width - 20) / 3 : (flow.width - 40) / 5
                    height: 124
                    radius: tm.pressed ? M3.rM : M3.rL
                    color: on ? M3.secondaryContainer : (tm.containsMouse ? M3.surfaceHigh : M3.surfaceC)
                    border.width: on ? 2 : 0
                    border.color: M3.primary
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on radius { NumberAnimation { duration: 160 } }
                    // a small dot that plays this style while you point at it
                    Item {
                        x: 14; y: 16; width: parent.width - 28; height: 26
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: M3.alpha(M3.ink, 0.1) }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            color: tile.on ? M3.primary : M3.inkDim
                            x: (tm.containsMouse || tile.on) && page.flip ? parent.width - width : 0
                            opacity: modelData.k === "minimal" ? ((tm.containsMouse || tile.on) && page.flip ? 1 : 0.3) : 1
                            Behavior on x { enabled: modelData.k !== "minimal"
                                NumberAnimation { duration: modelData.dur; easing.type: modelData.over > 0 ? Easing.OutBack : Easing.InOutCubic; easing.overshoot: modelData.over } }
                            Behavior on opacity { NumberAnimation { duration: modelData.dur } }
                        }
                    }
                    Icon { x: 14; y: 54; name: modelData.sym; glyph: modelData.g; size: 18; color: tile.on ? M3.primary : M3.inkDim; filled: tile.on }
                    T { x: 40; y: 55; text: modelData.n; font.pixelSize: 14; font.weight: Font.Medium }
                    T { x: 14; y: 82; width: parent.width - 28; text: modelData.d; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        font.pixelSize: 11; color: M3.inkDim }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.ctl.setAnimStyle(modelData.k) }
                }
            }
        }
        SliderRow {
            label: I18n.t("Speed")
            desc: I18n.t("100% is the normal speed of the style; higher is faster")
            from: 50; to: 200; step: 10; unit: " %"
            value: page.ha.speed !== undefined ? page.ha.speed : 100
            onCommitted: function(v) { page.ctl.setAnim("speed", Math.round(v)) }
        }

        // ---------- spring physics ----------
        SectionTitle { text: I18n.t("Spring physics"); sub: I18n.t("Motion in Settings is made of springs: stiffness and damping instead of a duration and a curve. Spatial springs may bounce, effects never do.") }
        SegRow {
            label: I18n.t("Feel")
            desc: I18n.t("Expressive springs a little, Standard glides")
            options: [{ label: I18n.t("Expressive"), value: "expressive" }, { label: I18n.t("Standard"), value: "standard" }]
            current: Prefs.motion
            onChosen: function(x) { Prefs.setMotion(x); page.ctl.status = I18n.t("Motion: ") + x }
        }
        SliderRow {
            label: I18n.t("Speed")
            desc: I18n.t("Scales every spring and duration in Settings")
            from: 0.5; to: 2; step: 0.05; decimals: 2; unit: "x"
            value: Prefs.motionSpeed
            onCommitted: function(v) { Prefs.setMotionSpeed(v) }
        }
        SliderRow {
            label: I18n.t("Bounce")
            desc: I18n.t("0 takes the overshoot out of every spring; 2 makes it twice as playful")
            from: 0; to: 2; step: 0.1; decimals: 1; unit: "×"
            value: Prefs.bounce
            onCommitted: function(v) { Prefs.setBounce(v) }
        }
        Row {
            spacing: 8
            Btn { text: I18n.t("Reset motion"); sym: "restart_alt"; icon: ""; variant: "text"
                onClicked: { Prefs.setMotion("expressive"); Prefs.setMotionSpeed(1); Prefs.setBounce(1) } }
        }

        // ---------- try it ----------
        SectionTitle { text: I18n.t("Try it"); sub: I18n.t("Click a card to play it with the feel above.") }
        Grid {
            id: tryGrid
            width: parent.width
            columns: width > 600 ? 3 : 1
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: [
                    { n: "Move", d: "Something travels to its place" },
                    { n: "Grow", d: "A card opens out" },
                    { n: "Shape", d: "Corners change on press" }
                ]
                delegate: Rectangle {
                    id: tc
                    property bool go: false
                    width: (tryGrid.width - (tryGrid.columns - 1) * 10) / tryGrid.columns
                    height: 120
                    radius: M3.rL
                    color: tcm.containsMouse ? M3.surfaceHigh : M3.surfaceC
                    T { x: 16; y: 14; text: modelData.n; font.pixelSize: 14; font.weight: Font.Medium }
                    T { x: 16; y: 34; text: modelData.d; font.pixelSize: 11; color: M3.inkDim }
                    Rectangle {
                        readonly property bool b: M3.bouncy
                        width: index === 1 ? (tc.go ? 70 : 30) : 30
                        height: index === 1 ? (tc.go ? 40 : 30) : 30
                        radius: index === 2 ? (tc.go ? 6 : 15) : 15
                        x: index === 0 ? (tc.go ? tc.width - width - 18 : 18) : (tc.width - width) / 2
                        y: 66 + (index === 1 ? (40 - height) / 2 : 5)
                        color: M3.primary
                        Behavior on x { NumberAnimation { duration: M3.d(M3.bouncy ? 600 : 420); easing.type: M3.bouncy ? Easing.OutBack : Easing.InOutCubic; easing.overshoot: 1.6 * Prefs.bounce } }
                        Behavior on width { NumberAnimation { duration: M3.d(M3.bouncy ? 600 : 420); easing.type: M3.bouncy ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.6 * Prefs.bounce } }
                        Behavior on height { NumberAnimation { duration: M3.d(M3.bouncy ? 600 : 420); easing.type: M3.bouncy ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.6 * Prefs.bounce } }
                        Behavior on radius { NumberAnimation { duration: M3.d(360); easing.type: Easing.OutCubic } }
                    }
                    MouseArea { id: tcm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tc.go = !tc.go }
                }
            }
        }

        // ---------- tokens: springs ----------
        SectionTitle { text: I18n.t("Springs"); sub: I18n.t("The motion tokens behind the feel above: spatial ones move things, effect ones fade and recolor. Click one to play it.") }
        Grid {
            id: sGrid
            width: parent.width
            columns: width > 680 ? 3 : 2
            spacing: 10
            Repeater {
                model: page.springs
                delegate: SpringGraph {
                    width: (sGrid.width - (sGrid.columns - 1) * 10) / sGrid.columns
                    name: modelData.n
                    // Bounce changes the damping of the springs that may overshoot
                    zeta: Math.max(0.25, Math.min(1, 1 - (1 - modelData.z) * Prefs.bounce))
                    stiff: modelData.k * Prefs.motionSpeed * Prefs.motionSpeed
                    info: "ζ " + zeta.toFixed(2) + " · k " + Math.round(stiff)
                }
            }
        }

        // ---------- tokens: easing ----------
        SectionTitle { text: I18n.t("Easing curves"); sub: I18n.t("For changes with a fixed duration. Emphasized is for big moves, standard for small ones.") }
        Grid {
            id: eGrid
            width: parent.width
            columns: width > 680 ? 3 : 2
            spacing: 10
            Repeater {
                model: page.easings
                delegate: SpringGraph {
                    width: (eGrid.width - (eGrid.columns - 1) * 10) / eGrid.columns
                    height: 130
                    name: modelData.n
                    bez: modelData.b
                    dur: modelData.d
                    info: modelData.d + " ms"
                }
            }
        }

        // ---------- tokens: durations ----------
        SectionTitle { text: I18n.t("Durations"); sub: I18n.t("From a quick tap answer to a whole screen moving. Click a chip to see how long it is.") }
        Rectangle {
            width: parent.width
            height: dFlow.implicitHeight + 74
            radius: M3.rL
            color: M3.surfaceC
            Flow {
                id: dFlow
                x: 16; y: 16; width: parent.width - 32
                spacing: 6
                Repeater {
                    model: page.durations
                    delegate: Rectangle {
                        readonly property bool on: page.durSel === index
                        width: 76; height: 46; radius: on ? 23 : 12
                        color: on ? M3.primary : (dm.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                        Behavior on radius { NumberAnimation { duration: M3.d(200) } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Column {
                            anchors.centerIn: parent
                            T { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; font.pixelSize: 11; font.weight: Font.Medium; color: parent.parent.on ? M3.inkPrimary : M3.ink }
                            T { kind: "code"; anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1] + I18n.t(" ms"); font.pixelSize: 10; color: parent.parent.on ? M3.inkPrimary : M3.inkDim }
                        }
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { page.durSel = index; durRun.duration = modelData[1]; durBar.p = 0; durRun.restart() } }
                    }
                }
            }
            Rectangle {
                id: durBar
                property real p: 0
                x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                width: parent.width - 32; height: 10; radius: 5
                color: M3.surfaceHighest
                Rectangle { width: Math.max(10, parent.width * durBar.p); height: parent.height; radius: 5; color: M3.primary }
                NumberAnimation { id: durRun; target: durBar; property: "p"; from: 0; to: 1; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
            }
        }

        // ---------- gesture ----------
        SectionTitle { text: I18n.t("Gesture + spring"); sub: I18n.t("Throw the shape and let go: the spring takes the speed of your hand and brings it home.") }
        Rectangle {
            id: pad
            width: parent.width
            height: 230
            radius: M3.rXL
            color: M3.stageTop
            clip: true
            // home
            Rectangle { anchors.centerIn: parent; width: 84; height: 84; radius: 42; color: "transparent"; border.width: 2; border.color: M3.alpha(M3.primary, 0.35) }
            T { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; text: I18n.t("Drag and let go"); font.pixelSize: 12; color: M3.inkDim }
            Item {
                id: blob
                // offset from home, its speed, and the spring that pulls it back
                property real ox: 0
                property real oy: 0
                property real vx: 0
                property real vy: 0
                property bool held: false
                readonly property real k: M3.bouncy ? 260 : 320
                readonly property real c: (M3.bouncy ? 11 : 30) / Math.max(0.35, Prefs.bounce)
                width: 72; height: 72
                x: pad.width / 2 - 36 + ox
                y: pad.height / 2 - 36 + oy
                // squash a little in the direction it moves
                readonly property real sp: Math.min(1, Math.sqrt(vx * vx + vy * vy) / 2600)
                rotation: Math.atan2(vy, vx) * 180 / Math.PI
                Rectangle {
                    anchors.centerIn: parent
                    width: 72 * (1 + blob.sp * 0.35); height: 72 * (1 - blob.sp * 0.22)
                    radius: blob.held ? 22 : height / 2
                    color: M3.primary
                    Behavior on radius { NumberAnimation { duration: M3.d(260); easing.type: Easing.OutBack; easing.overshoot: 2 * Prefs.bounce } }
                    Icon { anchors.centerIn: parent; rotation: -blob.rotation; name: "pan_tool"; glyph: ""; size: 24; color: M3.inkPrimary; filled: blob.held }
                }
                Timer {
                    id: physics
                    interval: 16; repeat: true
                    onTriggered: {
                        const dt = 0.016
                        blob.vx += (-blob.k * blob.ox - blob.c * blob.vx) * dt
                        blob.vy += (-blob.k * blob.oy - blob.c * blob.vy) * dt
                        blob.ox += blob.vx * dt
                        blob.oy += blob.vy * dt
                        if (Math.abs(blob.ox) + Math.abs(blob.oy) < 0.3 && Math.abs(blob.vx) + Math.abs(blob.vy) < 4) { blob.ox = 0; blob.oy = 0; blob.vx = 0; blob.vy = 0; stop() }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: blob.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real px: 0
                    property real py: 0
                    property double pt: 0
                    onPressed: function(e) { physics.stop(); blob.held = true; blob.vx = 0; blob.vy = 0; const p = mapToItem(pad, e.x, e.y); px = p.x; py = p.y; pt = Date.now() }
                    onPositionChanged: function(e) {
                        const p = mapToItem(pad, e.x, e.y), now = Date.now(), dt = Math.max(8, now - pt) / 1000
                        const dx = p.x - px, dy = p.y - py
                        blob.ox += dx; blob.oy += dy
                        blob.vx = blob.vx * 0.4 + (dx / dt) * 0.6; blob.vy = blob.vy * 0.4 + (dy / dt) * 0.6
                        px = p.x; py = p.y; pt = now
                    }
                    onReleased: { blob.held = false; if (Date.now() - pt > 80) { blob.vx = 0; blob.vy = 0 } physics.start() }
                }
            }
        }
    }
}
