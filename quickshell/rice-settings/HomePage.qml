import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Item {
    id: page
    property var ctl
    // the "Make it yours" cards (the Settings tour points at them)
    property alias quickArea: quick

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")
    readonly property string faceUrl: "file://" + home + "/.face"
    property date now: new Date()
    property string uptime: ""
    property int tip: 0
    readonly property var tips: [
        "Press SUPER + U anywhere to open these settings.",
        "SUPER + W opens the wallpaper menu. The Auto theme follows your new wallpaper.",
        "Drag the desktop widgets anywhere, their position is saved.",
        "Pick a scheme in Theme to recolor the bar, borders, notifications and lock screen.",
        "Try the Islands or Pills style in DarkShadow bar for a floating look.",
        "Idle & Lockscreen decides when the screen locks and when the computer sleeps.",
        "Click your picture in the sidebar to change it. It is also shown on the lock screen.",
        "Gaming mode turns off animations, blur and gaps. Click it again to bring them back.",
        "Notifications has nine popup styles. Try Island or Accent bar.",
        "Theme has 21 color schemes, from pure Mono to Ocean and Rose.",
        "The launcher can open as a full-width bar, or Split with your wallpaper on the left.",
        "Lock screen clocks come in Big, Stacked and Minimal. Preview them in Idle & Lockscreen.",
        "Run rice-notify test in a terminal to see a sample notification.",
        "Everything here is also a command: rice-bar, rice-rofi, rice-lock, rice-notify."
    ]
    function greeting() {
        const h = now.getHours()
        return h < 5 ? I18n.t("Good night") : (h < 12 ? I18n.t("Good morning") : (h < 18 ? I18n.t("Good afternoon") : I18n.t("Good evening")))
    }
    function themeName() {
        const l = page.ctl.schemes || []
        for (let i = 0; i < l.length; i++) if (l[i].key === page.ctl.colorMode) return l[i].name
        return page.ctl.colorMode
    }

    // Light mode (rice-effects lite): for slower computers
    property bool lite: false
    function setLite(on) {
        lite = on
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" lite \"$1\"", "_", on ? "on" : "off"])
        page.ctl.status = I18n.t("Light mode ") + (on ? "on" : "off")
    }
    Process {
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.lite = JSON.parse(text).lite === true } catch (e) { } } }
    }

    // Profiles: the power mode of this computer (power-profiles-daemon). Only the modes this computer has are shown.
    property string profile: ""
    property var profiles: []
    function readProfile() { if (!profProc.running) profProc.running = true }
    property string wanted: ""
    function setProfile(k) {
        profile = k
        wanted = k
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-services\" profile \"$1\" 2>&1; powerprofilesctl get 2>/dev/null", "_", k]
        setProc.running = true
    }
    function pname(k) { return k === "power-saver" ? I18n.t("Power saver") : (k === "balanced" ? I18n.t("Balanced") : I18n.t("Performance")) }
    // switches, then reads back what the computer really runs now (and says so when it did not switch)
    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                const now = text.trim().split("\n").pop().trim()
                if (now === page.wanted) page.ctl.status = I18n.t("Profile: ") + page.pname(now)
                else page.ctl.status = I18n.t("The power mode did not change (power-profiles-daemon said no)")
                page.readProfile()
            }
        }
    }
    // power-profiles-daemon is installed but not running: start it (asks for your password)
    Process {
        id: startPP
        command: ["bash", "-c", "systemctl start power-profiles-daemon.service 2>&1 || pkexec systemctl enable --now power-profiles-daemon.service 2>&1"]
        onExited: function(code) { page.ctl.status = code === 0 ? I18n.t("Power modes are on") : I18n.t("Could not start power-profiles-daemon"); page.readProfile() }
    }
    property bool ppInstalled: false
    Process {
        id: profProc
        // every mode this computer has (a "* " marks the one on), then the one on now
        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null || { echo NONE; exit 0; }; powerprofilesctl list 2>/dev/null | sed -nE 's/^[*[:space:]]*(power-saver|balanced|performance):[[:space:]]*$/\\1/p'; echo CUR; powerprofilesctl get 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                page.ppInstalled = text.indexOf("NONE") < 0
                const parts = text.split("CUR")
                page.profiles = page.ppInstalled ? parts[0].split("\n").map(function(x) { return x.trim() }).filter(function(x) { return x.length > 0 && x !== "NONE" }) : []
                page.profile = parts.length > 1 ? parts[1].trim() : ""
            }
        }
    }

    Timer { interval: 15000; running: true; repeat: true; onTriggered: page.now = new Date() }
    Process {
        id: upProc
        command: ["bash", "-c", "cut -d. -f1 /proc/uptime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text.trim())
                if (isNaN(t)) return
                const d = Math.floor(t / 86400), h = Math.floor(t % 86400 / 3600), m = Math.floor(t % 3600 / 60)
                page.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m"
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: upProc.running = true }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking && !flickWheel.active
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        WheelScroll { id: flickWheel; flick: flick }

        Column {
            id: col
            x: 24
            y: 28
            width: flick.width - 48
            spacing: 12

            // ---------- hello: a tonal card with the time, your theme and the moon ----------
            Rectangle {
                id: hero
                width: parent.width
                height: 214
                radius: M3.rXL
                color: M3.primaryContainer
                clip: true
                // calm shapes in the corner, they turn slowly
                // two soft shapes that slowly change form: a rounded square turns into a circle and back, a pill breathes
                Rectangle {
                    id: shapeA
                    width: 200; height: 200; x: parent.width - 300; y: -70
                    color: M3.alpha(M3.primary, 0.14)
                    radius: 40
                    SequentialAnimation on radius {
                        running: page.visible; loops: Animation.Infinite
                        NumberAnimation { to: 100; duration: 4200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 40; duration: 4200; easing.type: Easing.InOutSine }
                    }
                    RotationAnimation on rotation { from: 0; to: 360; duration: 48000; loops: Animation.Infinite; running: page.visible }
                }
                // your shape (Appearance > Shapes), breathing near the moon
                Blob {
                    width: 92; height: 92; x: parent.width - 250; y: 110
                    kind: Prefs.accentShape
                    color: M3.alpha(M3.tertiary, 0.5)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 30000; loops: Animation.Infinite; running: page.visible }
                    SequentialAnimation on scale {
                        running: page.visible; loops: Animation.Infinite
                        NumberAnimation { to: 1.1; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.92; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    width: 150; height: 64; radius: 32; x: parent.width - 360; y: 140; rotation: -24
                    color: M3.alpha(M3.tertiary, 0.22)
                    SequentialAnimation on scale {
                        running: page.visible; loops: Animation.Infinite
                        NumberAnimation { to: 1.12; duration: 3000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.94; duration: 3000; easing.type: Easing.InOutSine }
                    }
                }
                MoonLogo {
                    id: homeLogo
                    objectName: "homeLogo"
                    anchors.right: parent.right; anchors.rightMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    size: 200
                    running: page.visible
                }
                Column {
                    x: 28; y: 24
                    width: parent.width - 28 - 230
                    spacing: 6
                    T { text: I18n.t("WELCOME BACK"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                    T { kind: "title"; text: page.greeting() + ", " + page.user; font.pixelSize: 30; font.weight: Font.Medium; color: M3.inkPrimaryC
                        width: parent.width; elide: Text.ElideRight }
                    T { text: page.now.toLocaleDateString(I18n.loc, "dddd, d MMMM") + I18n.t("  \u00b7  ") + page.now.toLocaleTimeString(I18n.loc, "HH:mm")
                        color: M3.alpha(M3.inkPrimaryC, 0.8); font.pixelSize: 13 }
                    Flow {
                        width: parent.width
                        spacing: 6
                        topPadding: 4
                        Repeater {
                            model: [
                                { i: "\udb80\udfd8", t: "Theme \u00b7 " + page.themeName() },
                                { i: "\uf017", t: "Up " + page.uptime },
                                { i: page.ctl.osGlyph(), t: page.ctl.osName }
                            ]
                            delegate: Rectangle {
                                visible: modelData.t.length > 3
                                height: 28
                                width: chip.implicitWidth + 24
                                radius: 14
                                color: M3.alpha(M3.inkPrimaryC, 0.12)
                                Row {
                                    id: chip
                                    anchors.centerIn: parent
                                    spacing: 7
                                    T { kind: "icon"; text: modelData.i; font.pixelSize: 11; color: M3.inkPrimaryC; anchors.verticalCenter: parent.verticalCenter }
                                    T { text: modelData.t; font.pixelSize: 12; color: M3.inkPrimaryC; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 8
                        topPadding: 6
                        Btn { text: I18n.t("Wallpaper"); sym: "wallpaper"; icon: "\uf03e"; primary: true; onClicked: page.ctl.page = 18 }
                        Btn { text: I18n.t("Gaming hub"); sym: "sports_esports"; icon: "\uf11b"; onClicked: page.ctl.page = 16 }
                    }
                }
            }

            // Light mode: one switch for slower computers, right on Home
            Rectangle {
                // found by the search in the sidebar
                property string label: I18n.t("Light mode")
                property string desc: I18n.t("Running slow? Turn off blur, transparency and shadows, animations stay; performance")
                property real reserved: 80
                width: parent.width
                height: 76
                radius: 14
                color: M3.surfaceC
                border.width: 1
                border.color: page.lite ? M3.primary : M3.outlineVariant
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Rectangle {
                    id: litei
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, page.lite ? 0.14 : 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf0e7"; font.pixelSize: 17 }
                }
                Column {
                    anchors.left: litei.right
                    anchors.leftMargin: 12
                    anchors.right: litetog.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: I18n.t("Light mode"); font.pixelSize: 13; font.bold: true }
                    T { kind: "reading"; text: I18n.t("Running slow? No blur or shadows, widgets rest when a window covers them. Animations stay"); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                }
                Tog {
                    id: litetog
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.lite
                    onToggled: function(v) { page.setLite(v) }
                }
            }

            // Auto-hide widgets: the desktop widgets rest while a window covers the screen
            Rectangle {
                property string label: I18n.t("Auto-hide widgets")
                property string desc: I18n.t("Hide the desktop widgets while a window covers the screen; floating windows leave them alone")
                property real reserved: 80
                readonly property bool on: page.ctl.dst.autoHide === true || page.lite
                width: parent.width
                height: 76
                radius: 14
                color: M3.surfaceC
                border.width: 1
                border.color: on ? M3.primary : M3.outlineVariant
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Rectangle {
                    id: ahi
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, parent.on ? 0.14 : 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: parent.parent.on ? "\uf070" : "\uf06e"; font.pixelSize: 17 }
                }
                Column {
                    anchors.left: ahi.right
                    anchors.leftMargin: 12
                    anchors.right: ahtog.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: I18n.t("Auto-hide widgets"); font.pixelSize: 13; font.bold: true }
                    T { kind: "reading"; text: page.lite ? I18n.t("On while Light mode is on") : I18n.t("Widgets hide while a window covers the screen, and come back on an empty desktop"); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                }
                Tog {
                    id: ahtog
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: parent.on
                    onToggled: function(v) { page.ctl.setAutoHide(v) }
                }
            }

            // the falling stars across this window
            Rectangle {
                property string label: I18n.t("Falling stars")
                property string desc: I18n.t("Comets falling across this window; turn them off for a calm look")
                property real reserved: 80
                width: parent.width
                height: 64
                radius: 14
                color: M3.surfaceC
                border.width: 1
                border.color: M3.outlineVariant
                Rectangle {
                    id: starsi
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 11
                    color: Qt.rgba(1, 1, 1, page.ctl.stars ? 0.12 : 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf005"; font.pixelSize: 15 }
                }
                Column {
                    anchors.left: starsi.right
                    anchors.leftMargin: 12
                    anchors.right: starstog.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: I18n.t("Falling stars"); font.pixelSize: 13; font.bold: true }
                    T { kind: "reading"; text: I18n.t("Comets falling across this window"); color: M3.inkDim; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                }
                Tog {
                    id: starstog
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.ctl.stars
                    onToggled: function(v) { page.ctl.setStars(v) }
                }
            }

            T { kind: "title"; text: I18n.t("Make it yours"); font.pixelSize: 16; font.bold: true; topPadding: 10 }

            Flow {
                id: quick
                width: parent.width
                spacing: 10
                Repeater {
                    model: [
                        { i: "\udb80\udfd8", s: "palette", t: "Theme", d: "Colors & schemes", p: 8 },
                        { i: "\uf03e", s: "wallpaper", t: "Wallpaper", d: "Pick a new one", p: 18 },
                        { i: "\uf0f3", s: "notifications", t: "Notifications", d: "Popups & panel", p: 10 },
                        { i: "\uf0c9", s: "toolbar", t: "Bar", d: "Style, layout, workspaces", p: 2 },
                        { i: "\uf002", s: "apps", t: "Launcher", d: "Themes and styles", p: 7 },
                        { i: "\uf11b", s: "sports_esports", t: "Gaming hub", d: "Gaming mode, launchers", p: 16 }
                    ]
                    delegate: Rectangle {
                        width: (quick.width - 20) / 3
                        height: 80
                        radius: qMouse.pressed ? M3.rM : M3.rL
                        color: qMouse.containsMouse ? M3.surfaceHigh : M3.surfaceC
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { NumberAnimation { duration: 160 } }
                        Rectangle {
                            id: qi
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44; radius: qMouse.containsMouse ? 14 : 22
                            color: M3.secondaryContainer
                            Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                            Icon { anchors.centerIn: parent; name: modelData.s || ""; glyph: modelData.i; size: 20; color: M3.inkSecondaryC }
                        }
                        Column {
                            anchors.left: qi.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            T { text: modelData.t; font.pixelSize: 13; font.bold: true; width: parent.width; elide: Text.ElideRight }
                            T { kind: "reading"; text: modelData.d; font.pixelSize: 11; color: M3.inkDim; width: parent.width; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: qMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.p >= 0) page.ctl.page = modelData.p
                                else Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-wallpaper\""])
                            }
                        }
                    }
                }
            }

            SectionTitle { text: I18n.t("Settings"); sub: I18n.t("The things you change most. They apply right away.") }

            // Profiles: Performance, Balanced, Power saver
            Item {
                id: profBox
                width: parent.width
                height: page.profiles.length > 0 ? 120 : 84
                Row {
                    id: profHead
                    spacing: 8
                    T { text: I18n.t("Profiles"); font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    T { kind: "reading"; text: page.profiles.length > 0 ? I18n.t("How fast this computer runs, and how much power it uses") : ""; color: M3.inkDim; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    visible: page.profiles.length > 0
                    y: 28
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            { k: "performance", i: "\udb81\udcc5", t: "Performance", d: "Fastest, uses more power" },
                            { k: "balanced", i: "\udb81\uddd1", t: "Balanced", d: "Good for everyday use" },
                            { k: "power-saver", i: "\udb80\udf2a", t: "Power saver", d: "Quiet, longest battery" }
                        ].filter(function(m) { return page.profiles.indexOf(m.k) >= 0 })
                        delegate: Rectangle {
                            id: pc
                            readonly property bool on: page.profile === modelData.k
                            width: (profBox.width - 10 * (page.profiles.length - 1)) / Math.max(1, page.profiles.length)
                            height: 84
                            radius: 14
                            color: on ? M3.primary : (pMouse.containsMouse ? "#1b1b1d" : M3.surfaceC)
                            border.width: 1
                            border.color: on ? M3.primary : (pMouse.containsMouse ? M3.outline : M3.outlineVariant)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Rectangle {
                                id: pi
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42; height: 42; radius: 13
                                color: pc.on ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.06)
                                T { kind: "icon"; anchors.centerIn: parent; text: modelData.i; font.pixelSize: 19; color: pc.on ? M3.inkPrimary : "#F6F5F4" }
                            }
                            Column {
                                anchors.left: pi.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                T { text: modelData.t; font.pixelSize: 14; font.bold: true; color: pc.on ? M3.inkPrimary : "#F6F5F4"; width: parent.width; elide: Text.ElideRight }
                                T { kind: "reading"; text: modelData.d; font.pixelSize: 11; color: pc.on ? "#3a3a3e" : M3.inkDim; width: parent.width; elide: Text.ElideRight }
                            }
                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setProfile(modelData.k)
                            }
                        }
                    }
                }
                T {
                    visible: page.profiles.length === 0
                    y: 26
                    width: parent.width - (startBtn.visible ? startBtn.width + 16 : 0)
                    wrapMode: Text.WordWrap
                    kind: "reading"
                    font.pixelSize: 12
                    color: M3.inkDim
                    text: page.ppInstalled
                        ? I18n.t("power-profiles-daemon is installed but not running. Turn it on (it asks for your password); on NixOS: services.power-profiles-daemon.enable = true.")
                        : I18n.t("Power modes need power-profiles-daemon, and it is not running on this computer. Install it and turn it on: sudo systemctl enable --now power-profiles-daemon (on NixOS: services.power-profiles-daemon.enable = true).")
                }
                Btn {
                    id: startBtn
                    visible: page.profiles.length === 0 && page.ppInstalled
                    anchors.right: parent.right; y: 26
                    text: I18n.t("Turn on"); sym: "bolt"; icon: ""; primary: true
                    onClicked: startPP.running = true
                }
            }

            SliderRow {
                id: sizeRow
                label: I18n.t("Window size")
                desc: I18n.t("Make this Settings window smaller or bigger")
                from: 75; to: 150; step: 5; unit: " %"
                value: Math.round(Prefs.size * 100)
                onCommitted: function(v) { Prefs.setSize(v / 100) }
            }

            // preview: the screen, and this Settings window on it, as big as the slider says (moves while you drag)
            Rectangle {
                id: szPrev
                width: parent.width
                height: 168
                radius: 12
                color: M3.surfaceC
                border.width: 1
                border.color: M3.outlineVariant
                readonly property var scr: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
                readonly property real sw: scr ? scr.width : 1920
                readonly property real sh: scr ? scr.height : 1080
                readonly property real k: sizeRow.shown / 100
                readonly property real ww: Prefs.winW(sw, k)
                readonly property real wh: Prefs.winH(sh, k)

                Rectangle {
                    id: mon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    height: 136
                    width: Math.min(260, Math.round(height * szPrev.sw / szPrev.sh))
                    radius: 6
                    color: "#0b0b0d"
                    border.width: 2
                    border.color: "#3a3a40"
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: M3.stageTop }
                        GradientStop { position: 1; color: M3.stageBottom }
                    }
                    // the bar
                    Rectangle { x: 0; y: 0; width: parent.width; height: 5; color: "#26262c" }
                    // the Settings window
                    Rectangle {
                        id: miniWin
                        width: Math.round(mon.width * szPrev.ww / szPrev.sw)
                        height: Math.round(mon.height * szPrev.wh / szPrev.sh)
                        x: Math.round((mon.width - width) / 2)
                        y: Math.round((mon.height - height) / 2)
                        radius: 4
                        color: M3.surfaceC
                        border.width: 1
                        border.color: M3.inkDim
                        Rectangle { x: 0; y: 0; width: Math.round(parent.width * 0.26); height: parent.height; color: "#1c1c1f"; radius: 4 }
                        Repeater {
                            model: 5
                            Rectangle {
                                x: 4; y: 8 + index * 9
                                width: Math.round(miniWin.width * 0.26) - 8
                                height: 4; radius: 2
                                color: index === 0 ? M3.primary : "#3a3a40"
                            }
                        }
                        Repeater {
                            model: 4
                            Rectangle {
                                x: Math.round(miniWin.width * 0.26) + 6
                                y: 8 + index * Math.round(miniWin.height * 0.2)
                                width: Math.round(miniWin.width * 0.74) - 12
                                height: Math.max(6, Math.round(miniWin.height * 0.14)); radius: 3
                                color: "#202024"
                            }
                        }
                        Behavior on width { enabled: !sizeRow.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on height { enabled: !sizeRow.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
                }
                Column {
                    anchors.left: mon.right
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    T { text: Math.round(szPrev.ww) + I18n.t(" \u00d7 ") + Math.round(szPrev.wh) + I18n.t(" px"); font.pixelSize: 20; font.bold: true }
                    T { kind: "reading"; text: Math.round(szPrev.ww * 100 / szPrev.sw) + I18n.t(" % of the screen width, ") + Math.round(szPrev.wh * 100 / szPrev.sh) + I18n.t(" % of its height"); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                    T { kind: "reading"; text: I18n.t("Preview: the small window follows the slider. It is applied when you let go."); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                }
            }

            ToggleRow {
                label: I18n.t("Bar transparency")
                desc: I18n.t("Translucent bar with blur; off makes it solid")
                checked: page.ctl.st.transparent === true
                onToggled: function(v) {
                    page.ctl.setSt("transparent", v)
                    page.ctl.run(["transparency", v ? "on" : "off"])
                }
            }
            ToggleRow {
                label: I18n.t("Window blur")
                desc: I18n.t("Blur behind the bar, notifications and see-through windows")
                checked: page.ctl.hv["decoration.blur.enabled"] !== false
                onToggled: function(v) { page.ctl.hset("decoration.blur.enabled", v) }
            }
            ToggleRow {
                label: I18n.t("Animations")
                desc: I18n.t("Windows and workspaces move smoothly. Off is the lightest")
                checked: page.ctl.ha.enabled !== false
                onToggled: function(v) { page.ctl.setAnim("enabled", v) }
            }

            SectionTitle { text: I18n.t("Previews"); sub: I18n.t("The live pictures at the top of some pages.") }
            ToggleRow {
                label: I18n.t("Show previews")
                desc: I18n.t("Bar, Launcher, Notifications and Cursors show a small live picture of your choices")
                checked: Prefs.previews
                onToggled: function(v) { Prefs.setPreviews(v) }
            }

            SectionTitle { text: I18n.t("Scrolling"); sub: I18n.t("How fast pages move. Try it in the box.") }

            SliderRow {
                label: I18n.t("Settings scroll speed")
                desc: I18n.t("Wheel and touchpad scrolling in this window")
                from: 0.3; to: 3; step: 0.05; decimals: 2; unit: "x"
                value: Prefs.scroll
                onCommitted: function(v) { Prefs.setScroll(v) }
            }
            // a small place to feel the speed
            Rectangle {
                width: parent.width
                height: 128
                radius: 12
                color: M3.surfaceC
                border.width: 1
                border.color: M3.outlineVariant
                Column {
                    x: 16; y: 14
                    width: 190
                    spacing: 4
                    T { text: I18n.t("Try it"); font.pixelSize: 14 }
                    T { kind: "reading"; text: I18n.t("Scroll in the box. The speed above changes how far one notch goes."); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                }
                Rectangle {
                    x: 226; y: 12
                    width: parent.width - 226 - 14
                    height: parent.height - 24
                    radius: 9
                    color: "#0e0e0f"
                    border.width: 1
                    border.color: M3.outlineVariant
                    clip: true
                    Flickable {
                        id: tryFlick
                        anchors.fill: parent
                        anchors.margins: 1
                        contentWidth: width
                        contentHeight: tryCol.height + 12
                        boundsBehavior: Flickable.StopAtBounds
                        Behavior on contentY { enabled: !tryFlick.dragging && !tryFlick.flicking && !tryFlickWheel.active; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        WheelScroll { id: tryFlickWheel; flick: tryFlick; outer: flickWheel }
                        Column {
                            id: tryCol
                            x: 10; y: 6
                            width: parent.width - 28
                            Repeater {
                                model: 40
                                delegate: Rectangle {
                                    width: tryCol.width; height: 26; radius: 6
                                    color: index % 2 === 0 ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
                                    T { x: 8; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Line ") + (index + 1); font.pixelSize: 12; color: "#9a9aa2" }
                                }
                            }
                        }
                    }
                    // where you are
                    Rectangle {
                        x: parent.width - 6; width: 3; radius: 1.5
                        y: 4 + (parent.height - 8 - height) * (tryFlick.contentHeight > tryFlick.height ? tryFlick.contentY / (tryFlick.contentHeight - tryFlick.height) : 0)
                        height: Math.max(16, (parent.height - 8) * tryFlick.height / Math.max(1, tryFlick.contentHeight))
                        color: "#5a5a60"
                    }
                }
            }

            SectionTitle { text: I18n.t("Mouse & touchpad"); sub: I18n.t("System-wide, for every app.") }

            SliderRow {
                label: I18n.t("Mouse wheel speed")
                desc: I18n.t("How far one notch scrolls, everywhere")
                from: 0.2; to: 3; step: 0.1; decimals: 1; unit: "x"
                value: page.ctl.hv["input.scroll_factor"] !== undefined ? page.ctl.hv["input.scroll_factor"] : 1
                onCommitted: function(v) { page.ctl.hset("input.scroll_factor", Math.round(v * 10) / 10) }
            }
            SliderRow {
                label: I18n.t("Touchpad scroll speed")
                desc: I18n.t("Two-finger scrolling, everywhere")
                from: 0.2; to: 3; step: 0.1; decimals: 1; unit: "x"
                value: page.ctl.hv["input.touchpad.scroll_factor"] !== undefined ? page.ctl.hv["input.touchpad.scroll_factor"] : 1
                onCommitted: function(v) { page.ctl.hset("input.touchpad.scroll_factor", Math.round(v * 10) / 10) }
            }
            ToggleRow {
                label: I18n.t("Natural scrolling")
                desc: I18n.t("Touchpad: content follows your fingers, like a phone")
                checked: page.ctl.hv["input.touchpad.natural_scroll"] === true
                onToggled: function(v) { page.ctl.hset("input.touchpad.natural_scroll", v) }
            }
            ToggleRow {
                label: I18n.t("Tap to click")
                desc: I18n.t("Touchpad: a light tap is a click")
                checked: page.ctl.hv["input.touchpad.tap-to-click"] !== false
                onToggled: function(v) { page.ctl.hset("input.touchpad.tap-to-click", v) }
            }
            SliderRow {
                label: I18n.t("Pointer speed")
                desc: I18n.t("How fast the cursor moves")
                from: -1; to: 1; step: 0.05; decimals: 2
                value: page.ctl.hv["input.sensitivity"] !== undefined ? page.ctl.hv["input.sensitivity"] : 0
                onCommitted: function(v) { page.ctl.hset("input.sensitivity", Math.round(v * 20) / 20) }
            }
        }
    }
}