import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Content of the hot corner panel. HotCorner.qml puts it in a layer window and animates it.
Item {
    id: pnl
    property var cfg: ({})
    property var st: ({})
    property bool open: false
    property real nowTs: Date.now() / 1000
    property string hoverName: ""
    property bool showBg: true
    property date clock: new Date()
    signal act(string cmd, string arg, bool closeFirst)
    signal launch(var entry)
    Timer { interval: 10000; running: pnl.open; repeat: true; triggeredOnStart: true; onTriggered: pnl.clock = new Date() }
    function greeting() {
        const h = clock.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    readonly property real rad: cfg.radius !== undefined ? cfg.radius : 26
    // cards sit 14px inside the panel: their corners follow the panel corner (concentric)
    readonly property real inner: Math.max(6, rad - 14)
    readonly property string acc: st.accent ? st.accent : "#d4d4d4"
    readonly property real speed: cfg.speed ? cfg.speed : 1
    function lum(h) {
        const x = String(h).replace("#", "")
        const r = parseInt(x.substr(0, 2), 16), g = parseInt(x.substr(2, 2), 16), b = parseInt(x.substr(4, 2), 16)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    }
    readonly property color accFg: lum(acc) > 0.55 ? "#0d0d0d" : "#F6F5F4"
    function elapsed() {
        const s = Math.max(0, Math.floor(nowTs - (st.rec_start || nowTs)))
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }
    Timer { interval: 1000; running: pnl.open && pnl.st.recording === true; repeat: true; onTriggered: pnl.nowTs = Date.now() / 1000 }

    width: cfg.width ? cfg.width : 400
    height: col.implicitHeight + 28

    Rectangle {
        visible: pnl.showBg
        anchors.fill: parent
        radius: pnl.rad
        color: {
            const a = pnl.cfg.transparency === false ? 1 : (pnl.cfg.opacity !== undefined ? pnl.cfg.opacity : 0.9)
            let r = 18, g = 18, b = 20
            if (pnl.cfg.tint === true) {
                const x = String(pnl.acc).replace("#", "")
                r = 18 + (parseInt(x.substr(0, 2), 16) - 18) * 0.16
                g = 18 + (parseInt(x.substr(2, 2), 16) - 18) * 0.16
                b = 20 + (parseInt(x.substr(4, 2), 16) - 20) * 0.16
            }
            return Qt.rgba(r / 255, g / 255, b / 255, a)
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        // our own touch: a small greeting header with the time
        Item {
            id: head
            visible: pnl.cfg.header !== false
            width: parent.width
            height: visible ? 52 : 0
            opacity: pnl.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 / pnl.speed } }
            Rectangle {
                id: hAv
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 19
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: pnl.acc
                RoundImage { anchors.fill: parent; anchors.margins: 2; source: "file://" + Quickshell.env("HOME") + "/.face" }
            }
            Column {
                anchors.left: hAv.right; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                T { text: pnl.greeting() + ", " + Quickshell.env("USER"); font.pixelSize: 14; font.bold: true }
                T { text: pnl.clock.toLocaleDateString(Tr.loc, "dddd, d MMMM"); font.pixelSize: 11; color: "#9a9aa4" }
            }
            T {
                anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                kind: "number"
                text: pnl.clock.toLocaleTimeString(Tr.loc, "HH:mm")
                font.pixelSize: 26
                font.bold: true
                color: pnl.acc
            }
        }

        Repeater {
            model: pnl.cfg.sections ? pnl.cfg.sections : []
            delegate: Item {
                id: sec
                property real k: 0
                width: col.width
                height: ld.item ? ld.item.height : 0
                opacity: k
                transform: Translate { y: (1 - sec.k) * 14 }
                Loader {
                    id: ld
                    width: parent.width
                    sourceComponent: modelData === "awake" ? awakeC : modelData === "record" ? recordC
                                   : modelData === "shot" ? shotC : modelData === "toggles" ? togglesC
                                   : modelData === "media" ? mediaC : modelData === "wallpaper" ? wallC
                                   : modelData === "apps" ? appsC : modelData === "colors" ? colorsC : null
                }
                SequentialAnimation {
                    id: inAnim
                    PauseAnimation { duration: (60 + index * 45) / pnl.speed }
                    NumberAnimation { target: sec; property: "k"; to: 1; duration: 260 / pnl.speed; easing.type: Easing.OutCubic }
                }
                Connections {
                    target: pnl
                    function onOpenChanged() {
                        if (pnl.open) { sec.k = 0; inAnim.restart() }
                        else { inAnim.stop(); sec.k = 0 }
                    }
                }
                Component.onCompleted: if (pnl.open) inAnim.restart()
            }
        }
    }

    // ---------- building blocks ----------
    component HcCard: Rectangle {
        radius: pnl.inner
        color: Qt.rgba(1, 1, 1, pnl.cfg.card_alpha !== undefined ? pnl.cfg.card_alpha : 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.04)
    }
    component HcBubble: Rectangle {
        property string glyph: ""
        property bool on: false
        width: 44; height: 44; radius: 22
        color: on ? pnl.acc : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 180 } }
        T { kind: "icon"; anchors.centerIn: parent; text: parent.glyph; font.pixelSize: 20; color: parent.on ? pnl.accFg : "#F6F5F4" }
    }
    component HcPill: Rectangle {
        id: pb
        property string glyph: ""
        property string label: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        height: 36
        width: pbRow.implicitWidth + 26
        radius: 18
        color: danger ? (pm.containsMouse ? "#ff6b6b" : "#e05555")
             : primary ? (pm.containsMouse ? Qt.lighter(pnl.acc, 1.1) : pnl.acc)
             : (pm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: pm.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 7
            T { kind: "icon"; visible: pb.glyph.length > 0; text: pb.glyph; font.pixelSize: 15; color: (pb.primary || pb.danger) ? (pb.danger ? "#ffffff" : pnl.accFg) : "#F6F5F4"; anchors.verticalCenter: parent.verticalCenter }
            T { text: pb.label; font.pixelSize: 13; font.bold: pb.primary || pb.danger; color: (pb.primary || pb.danger) ? (pb.danger ? "#ffffff" : pnl.accFg) : "#F6F5F4"; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }
    component HcSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 48; height: 28; radius: 14
        color: checked ? pnl.acc : Qt.rgba(1, 1, 1, 0.12)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 22; height: 22; radius: 11
            y: 3
            x: sw.checked ? sw.width - width - 3 : 3
            color: sw.checked ? pnl.accFg : "#d0d0d4"
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    // ---------- sections ----------
    Component {
        id: colorsC
        HcCard {
            height: cCol.implicitHeight + 28
            Column {
                id: cCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 20
                    T { text: Tr.t("Color scheme"); font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    T {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const l = pnl.st.schemes || []
                            const hov = pnl.hoverName.indexOf("scheme:") === 0 ? pnl.hoverName.substr(7) : ""
                            if (hov) return hov
                            for (let i = 0; i < l.length; i++) if (l[i].key === pnl.st.scheme) return l[i].name
                            return ""
                        }
                        font.pixelSize: 12
                        color: "#9a9aa4"
                    }
                }
                Grid {
                    id: cGrid
                    columns: 7
                    spacing: 8
                    readonly property real cell: Math.floor((cCol.width - 6 * spacing) / 7)
                    Repeater {
                        model: pnl.st.schemes || []
                        delegate: Item {
                            readonly property bool cur: pnl.st.scheme === modelData.key
                            readonly property var pv: modelData.preview || ["#111111", "#d4d4d4", "#ffffff"]
                            width: cGrid.cell
                            height: cGrid.cell
                            // surface ring with the accent inside, like a little planet
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 34); height: width; radius: width / 2
                                color: pv[0]
                                border.width: cur ? 2 : 1
                                border.color: cur ? "#F6F5F4" : Qt.rgba(1, 1, 1, 0.14)
                                scale: sm.containsMouse ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.56; height: width; radius: width / 2
                                    color: pv[1]
                                }
                                T { visible: cur; kind: "icon"; anchors.centerIn: parent; text: "󰄬"; font.pixelSize: 11; color: "#0d0d0d" }
                            }
                            MouseArea {
                                id: sm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: pnl.hoverName = "scheme:" + modelData.name
                                onExited: if (pnl.hoverName === "scheme:" + modelData.name) pnl.hoverName = ""
                                onClicked: pnl.act("scheme", modelData.key, false)
                            }
                        }
                    }
                }
                T {
                    visible: !(pnl.st.schemes && pnl.st.schemes.length > 0)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.t("Loading color schemes...")
                    font.pixelSize: 12
                    color: "#7a7a84"
                }
            }
        }
    }

    Component {
        id: awakeC
        HcCard {
            height: 72
            HcBubble { id: ab; x: 14; anchors.verticalCenter: parent.verticalCenter; glyph: "󰅶"; on: pnl.st.awake === true }
            Column {
                anchors.left: ab.right; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                T { text: Tr.t("Keep Awake"); font.pixelSize: 15; font.bold: true }
                T { text: pnl.st.awake ? Tr.t("The screen will not lock or sleep") : Tr.t("Normal power management"); font.pixelSize: 12; color: "#9a9aa4" }
            }
            HcSwitch { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: pnl.st.awake === true; onToggled: pnl.act("awake", "", false) }
        }
    }

    Component {
        id: recordC
        HcCard {
            height: recCol.implicitHeight + 28
            Column {
                id: recCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 44
                    HcBubble { id: rb; glyph: pnl.st.recording ? "󰑊" : "󰕧"; on: pnl.st.recording === true; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.left: rb.right; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        T { text: Tr.t("Screen Recorder"); font.pixelSize: 15; font.bold: true }
                        T { text: pnl.st.recording ? Tr.t("Recording  ") + pnl.elapsed() : Tr.t("Ready"); font.pixelSize: 12; color: pnl.st.recording ? "#ff8080" : "#9a9aa4" }
                    }
                }
                Row {
                    spacing: 8
                    visible: pnl.st.recording !== true
                    HcPill { primary: true; glyph: "󰊓"; label: Tr.t("Fullscreen"); onClicked: pnl.act("record", "full", true) }
                    HcPill { glyph: "󰆞"; label: Tr.t("Region"); onClicked: pnl.act("record", "region", true) }
                }
                HcPill { visible: pnl.st.recording === true; danger: true; glyph: "󰓛"; label: Tr.t("Stop recording"); onClicked: pnl.act("record", "stop", false) }
                Item {
                    width: parent.width
                    height: 22
                    T { kind: "icon"; text: "󰉹"; font.pixelSize: 15; color: "#c8c8cc"; anchors.verticalCenter: parent.verticalCenter }
                    T { x: 24; text: Tr.t("Recordings"); font.pixelSize: 13; color: "#c8c8cc"; anchors.verticalCenter: parent.verticalCenter }
                    T {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        kind: "icon"; text: "󰉋"; font.pixelSize: 15
                        color: fm.containsMouse ? "#F6F5F4" : "#8a8a8a"
                        MouseArea { id: fm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("folder", "recordings", true) }
                    }
                }
                T {
                    visible: !(pnl.st.recordings && pnl.st.recordings.length > 0)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.t("No recordings yet")
                    font.pixelSize: 12
                    color: "#7a7a84"
                    bottomPadding: 4
                }
                Repeater {
                    model: pnl.st.recordings ? pnl.st.recordings.slice(0, 3) : []
                    delegate: Rectangle {
                        width: recCol.width
                        height: 38
                        radius: 10
                        color: rm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)
                        T { kind: "icon"; x: 10; anchors.verticalCenter: parent.verticalCenter; text: "󰈱"; font.pixelSize: 15; color: "#c8c8cc" }
                        T { x: 34; width: parent.width - 120; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.pixelSize: 12; elide: Text.ElideMiddle }
                        T { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.time; font.pixelSize: 11; color: "#8a8a8a" }
                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("show", modelData.path, true) }
                    }
                }
            }
        }
    }

    Component {
        id: shotC
        HcCard {
            height: shotCol.implicitHeight + 28
            Column {
                id: shotCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 44
                    HcBubble { id: sb; glyph: "󰄀"; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.left: sb.right; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        T { text: Tr.t("Screenshot"); font.pixelSize: 15; font.bold: true }
                        T { text: pnl.cfg.clipboard === false ? Tr.t("Saved to Screenshots") : Tr.t("Saved and copied to clipboard"); font.pixelSize: 12; color: "#9a9aa4" }
                    }
                    T {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        kind: "icon"; text: "󰉋"; font.pixelSize: 15
                        color: sfm.containsMouse ? "#F6F5F4" : "#8a8a8a"
                        MouseArea { id: sfm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("folder", "screenshots", true) }
                    }
                }
                Row {
                    spacing: 8
                    HcPill { primary: true; glyph: "󰊓"; label: Tr.t("Screen"); onClicked: pnl.act("shot", "full", true) }
                    HcPill { glyph: "󰆞"; label: Tr.t("Region"); onClicked: pnl.act("shot", "region", true) }
                }
            }
        }
    }

    Component {
        id: togglesC
        HcCard {
            id: tc
            readonly property var defs: ({
                wifi: { n: "Wi-Fi", on: pnl.st.wifi === true, g: pnl.st.wifi ? "󰖩" : "󰖪", a: "wifi", close: false },
                bluetooth: { n: "Bluetooth", on: pnl.st.bluetooth === true, g: pnl.st.bluetooth ? "󰂯" : "󰂲", a: "bluetooth", close: false },
                dnd: { n: "Do Not Disturb", on: pnl.st.dnd === true, g: pnl.st.dnd ? "󰂛" : "󰂚", a: "dnd", close: false },
                gaming: { n: "Gaming mode", on: pnl.st.gaming === true, g: "󰊗", a: "gaming", close: false },
                mic: { n: "Microphone", on: pnl.st.mic_muted !== true, g: pnl.st.mic_muted ? "󰍭" : "󰍬", a: "mic", close: false },
                settings: { n: "Settings", on: false, g: "󰒓", a: "settings", close: true },
                wallpaper: { n: "Wallpaper", on: false, g: "󰋩", a: "wallpaper", close: true },
                lock: { n: "Lock screen", on: false, g: "󰌾", a: "lock", close: true }
            })
            height: tCol.implicitHeight + 28
            Column {
                id: tCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 20
                    T { text: Tr.t("Quick Toggles"); font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    T { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: pnl.hoverName; font.pixelSize: 12; color: "#9a9aa4" }
                }
                Flow {
                    id: tFlow
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: pnl.cfg.toggles ? pnl.cfg.toggles : []
                        delegate: Rectangle {
                            readonly property var d: tc.defs[modelData]
                            readonly property int n: pnl.cfg.toggles ? pnl.cfg.toggles.length : 5
                            readonly property int cols: n <= 5 ? Math.max(1, n) : Math.ceil(n / 2)
                            width: Math.floor((tFlow.width - 8 * (cols - 1)) / cols)
                            height: 48
                            radius: 16
                            color: d.on ? (tm.containsMouse ? Qt.lighter(pnl.acc, 1.08) : pnl.acc)
                                        : (tm.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.07))
                            Behavior on color { ColorAnimation { duration: 180 } }
                            scale: tm.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            T { kind: "icon"; anchors.centerIn: parent; text: d.g; font.pixelSize: 20; color: d.on ? pnl.accFg : "#F6F5F4" }
                            MouseArea {
                                id: tm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: pnl.hoverName = d.n + (d.a === "settings" || d.a === "wallpaper" || d.a === "lock" ? "" : (d.on ? " · on" : " · off"))
                                onExited: pnl.hoverName = ""
                                onClicked: pnl.act(d.a, "", d.close)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaC
        HcCard {
            id: mc
            readonly property var player: {
                const l = Mpris.players.values
                for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i]
                return l.length > 0 ? l[0] : null
            }
            height: 72
            HcBubble { id: mb; x: 14; anchors.verticalCenter: parent.verticalCenter; glyph: "󰎈"; on: mc.player !== null && mc.player.isPlaying }
            Column {
                anchors.left: mb.right; anchors.leftMargin: 12
                anchors.right: ctl.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                T { width: parent.width; text: mc.player ? (mc.player.trackTitle || "Unknown") : Tr.t("Nothing playing"); font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                T { width: parent.width; text: mc.player ? (mc.player.trackArtist || "") : Tr.t("Start some music"); font.pixelSize: 12; color: "#9a9aa4"; elide: Text.ElideRight }
            }
            Row {
                id: ctl
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [{ g: "󰒮", a: "prev" }, { g: "󰐊", a: "toggle" }, { g: "󰒭", a: "next" }]
                    delegate: Rectangle {
                        width: 34; height: 34; radius: 17
                        color: mm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        T {
                            kind: "icon"; anchors.centerIn: parent; font.pixelSize: 17
                            text: modelData.a === "toggle" ? (mc.player && mc.player.isPlaying ? "󰏤" : "󰐊") : modelData.g
                        }
                        MouseArea {
                            id: mm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!mc.player) return
                                if (modelData.a === "prev") mc.player.previous()
                                else if (modelData.a === "next") mc.player.next()
                                else mc.player.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wallC
        HcCard {
            height: wCol.implicitHeight + 28
            Column {
                id: wCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 20
                    T { text: Tr.t("Wallpaper"); font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Item {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: allW.implicitWidth
                        height: allW.implicitHeight
                        Row {
                            id: allW
                            spacing: 4
                            T { text: Tr.t("All wallpapers"); font.pixelSize: 12; color: wm2.containsMouse ? "#F6F5F4" : "#9a9aa4" }
                            T { kind: "icon"; text: "󰇘"; font.pixelSize: 14; color: wm2.containsMouse ? "#F6F5F4" : "#9a9aa4" }
                        }
                        MouseArea { id: wm2; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("wallpaper", "", true) }
                    }
                }
                Grid {
                    id: wGrid
                    columns: 3
                    spacing: 8
                    Repeater {
                        model: pnl.st.walls ? pnl.st.walls.slice(0, 6) : []
                        delegate: Item {
                            readonly property bool cur: pnl.st.wall === modelData.path
                            width: Math.floor((wCol.width - 16) / 3)
                            height: Math.round(width * 0.62)
                            Rectangle {
                                id: wFrame
                                anchors.fill: parent
                                radius: 12
                                color: "#1c1c20"
                                border.width: cur ? 2 : 0
                                border.color: pnl.acc
                            }
                            RoundImage {
                                anchors.fill: parent
                                anchors.margins: cur ? 3 : 0
                                cornerRadius: cur ? 9 : 12
                                source: "file://" + modelData.thumb
                                scale: wm.containsMouse ? 1.04 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                            Rectangle {
                                visible: cur
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                                width: 20; height: 20; radius: 10
                                color: pnl.acc
                                T { kind: "icon"; anchors.centerIn: parent; text: "󰄬"; font.pixelSize: 12; color: pnl.accFg }
                            }
                            MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("wall", modelData.path, false) }
                        }
                    }
                }
                T {
                    visible: !(pnl.st.walls && pnl.st.walls.length > 0)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.t("No wallpapers found in ~/Pictures/Wallpapers")
                    font.pixelSize: 12
                    color: "#7a7a84"
                }
            }
        }
    }

    Component {
        id: appsC
        HcCard {
            id: ac
            property string query: ""
            readonly property var results: {
                const q = query.trim().toLowerCase()
                const out = []
                if (q.length === 0) {
                    const pins = pnl.cfg.apps || []
                    for (let i = 0; i < pins.length && out.length < 8; i++) {
                        const e = DesktopEntries.heuristicLookup(pins[i])
                        if (e) out.push(e)
                    }
                    return out
                }
                const all = DesktopEntries.applications.values
                for (let i = 0; i < all.length; i++) {
                    const e = all[i]
                    if (e.noDisplay) continue
                    const n = (e.name || "").toLowerCase()
                    if (n.indexOf(q) >= 0 || (e.genericName || "").toLowerCase().indexOf(q) >= 0) out.push(e)
                }
                out.sort((a, b) => {
                    const an = a.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                    const bn = b.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                    return an - bn || a.name.localeCompare(b.name)
                })
                return out.slice(0, 8)
            }
            function iconFor(e) {
                const p = e && e.icon ? Icons.get(e.icon, true) : ""
                return p !== "" ? p : Icons.get("application-x-executable", true)
            }
            Connections { target: pnl; function onOpenChanged() { if (!pnl.open) { ac.query = ""; search.text = "" } } }
            height: aCol.implicitHeight + 28
            Column {
                id: aCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: search.activeFocus ? 1 : 0
                    border.color: pnl.acc
                    T { kind: "icon"; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: "#9a9aa4" }
                    TextInput {
                        id: search
                        x: 40
                        width: parent.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#F6F5F4"
                        font.family: Fonts.family("main")
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: { ac.query = text; if (activeFocus) Sfx.play("type") }
                        Keys.onReturnPressed: if (ac.results.length > 0) pnl.launch(ac.results[0])
                        Keys.onEscapePressed: pnl.act("close", "", true)
                    }
                    T {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: Tr.t("Search apps")
                        font.pixelSize: 13
                        color: "#7a7a84"
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: search.forceActiveFocus(); z: -1 }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: allRow.implicitWidth + 20; height: 30; radius: 15
                        color: am2.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        Row {
                            id: allRow
                            anchors.centerIn: parent
                            spacing: 5
                            T { kind: "icon"; text: "󰀻"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            T { text: Tr.t("All"); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: am2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.act("allapps", "", true) }
                    }
                }
                Grid {
                    columns: 4
                    spacing: 6
                    Repeater {
                        model: ac.results
                        delegate: Rectangle {
                            width: Math.floor((aCol.width - 18) / 4)
                            height: 76
                            radius: 14
                            color: apm.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 10
                                width: 34; height: 34
                                sourceSize.width: 64; sourceSize.height: 64
                                source: ac.iconFor(modelData)
                                asynchronous: true
                                scale: apm.containsMouse ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                            T {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 52
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.name
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            MouseArea { id: apm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pnl.launch(modelData) }
                        }
                    }
                }
                T {
                    visible: ac.results.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: ac.query.length > 0 ? Tr.t("No apps match “") + ac.query + "”" : Tr.t("Pin apps in Settings > Hot corners")
                    font.pixelSize: 12
                    color: "#7a7a84"
                }
            }
        }
    }

}
