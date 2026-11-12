import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var ls: ({})
    property string wall: ""
    property date now: new Date()

    function v(k, d) { return ls[k] !== undefined ? ls[k] : d }
    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, ls)
        n[key] = page.norm(value)
        ls = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-lock\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
        refresh.restart()
    }
    function mins(x) { return x <= 0 ? "Never" : (x + " min") }
    // lock screen clock fonts (rice-fonts downloads them)
    readonly property var clockFonts: [
        { k: "default", n: "Default", f: "" },
        { k: "bebas", n: "Bebas Neue", f: "Bebas Neue" },
        { k: "orbitron", n: "Orbitron", f: "Orbitron" },
        { k: "outfit", n: "Outfit", f: "Outfit" },
        { k: "grotesk", n: "Space Grotesk", f: "Space Grotesk" },
        { k: "unbounded", n: "Unbounded", f: "Unbounded" },
        { k: "shoulders", n: "Big Shoulders", f: "Big Shoulders Display" }
    ]
    readonly property var famList: Qt.fontFamilies()
    function hasFam(f) { return f === "" || famList.indexOf(f) >= 0 }
    function clockFam() {
        const k = v("clock_font", "default")
        for (let i = 0; i < clockFonts.length; i++) if (clockFonts[i].k === k && clockFonts[i].f !== "") return clockFonts[i].f
        return Fonts.family("number")
    }
    function greeting() {
        const h = now.getHours()
        return (h < 5 ? I18n.t("Good night") : h < 12 ? I18n.t("Good morning") : h < 18 ? I18n.t("Good afternoon") : I18n.t("Good evening")) + ", " + Quickshell.env("USER")
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-lock\" state; echo; cat \"$HOME/.cache/hyprquickpaper-current\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n")
                try { page.ls = JSON.parse(parts[0]) } catch (e) { }
                page.wall = parts.length > 1 ? parts[1].trim() : ""
            }
        }
    }
    Timer { id: refresh; interval: 800; onTriggered: stateProc.running = true }
    Timer { interval: 20000; running: true; repeat: true; onTriggered: page.now = new Date() }

    PageScroll {
        anchors.fill: parent

        // ---------- lock screen preview (scaled from a 1920x1080 screen) ----------
        Item {
            width: parent.width
            height: pv.height

            // the DarkShadow lock screen, in small (Preview shows the real one)
            Rectangle {
                id: npv
                visible: page.v("engine", "shell") === "shell"
                anchors.horizontalCenter: parent.horizontalCenter
                width: pv.width; height: pv.height; radius: M3.rL; clip: true
                gradient: Gradient { GradientStop { position: 0; color: M3.stageTop } GradientStop { position: 1; color: M3.stageBottom } }
                readonly property real s: height / 1080
                readonly property bool isLeft: page.v("layout", "center") === "left"
                readonly property string st: page.v("clock", "big")
                Column {
                    x: npv.isLeft ? npv.width * 0.08 : (npv.width - width) / 2
                    y: npv.height * 0.12
                    width: npv.width * 0.5
                    spacing: 10 * npv.s
                    T { anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter; visible: page.v("date", true) === true
                        text: I18n.t("Wednesday, 4 November"); font.pixelSize: 26 * npv.s; color: M3.ink }
                    Item {
                        width: parent.width; height: npv.st === "shape" ? 300 * npv.s : (npv.st === "stacked" ? 300 * npv.s : (npv.st === "minimal" ? 96 * npv.s : 190 * npv.s))
                        T { visible: npv.st !== "shape" && npv.st !== "stacked"; anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter; text: "20:56"; font.family: page.clockFam()
                            font.pixelSize: (npv.st === "minimal" ? 80 : 168) * npv.s; font.bold: npv.st !== "minimal"; color: M3.ink }
                        Column { visible: npv.st === "stacked"; anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter; spacing: -36 * npv.s
                            T { text: "20"; font.family: page.clockFam(); font.pixelSize: 160 * npv.s; font.bold: true; color: M3.ink }
                            T { text: "56"; font.family: page.clockFam(); font.pixelSize: 160 * npv.s; font.bold: true; color: page.v("accent_clock", false) ? M3.primary : M3.inkDim } }
                        Item { visible: npv.st === "shape"; width: 300 * npv.s; height: width; anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter
                            Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primary }
                            Column { anchors.centerIn: parent; spacing: -22 * npv.s
                                T { anchors.horizontalCenter: parent.horizontalCenter; text: "20"; font.family: page.clockFam(); font.pixelSize: 104 * npv.s; font.bold: true; color: M3.inkPrimary }
                                T { anchors.horizontalCenter: parent.horizontalCenter; text: "56"; font.family: page.clockFam(); font.pixelSize: 104 * npv.s; font.bold: true; color: M3.inkPrimary } } }
                    }
                    Row { anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter; spacing: 12 * npv.s
                        Blob { visible: page.v("avatar", true) === true; width: 52 * npv.s; height: width; kind: Prefs.accentShape; color: M3.primaryContainer; anchors.verticalCenter: parent.verticalCenter }
                        T { visible: page.v("greeting", true) === true; text: I18n.t("Good evening"); font.pixelSize: 20 * npv.s; color: M3.ink; anchors.verticalCenter: parent.verticalCenter } }
                    Row { anchors.horizontalCenter: npv.isLeft ? undefined : parent.horizontalCenter; spacing: 10 * npv.s
                        Repeater { model: [page.v("weather", false) === true, page.v("notifications", true) === true, page.v("resources", false) === true]
                            delegate: Rectangle { visible: modelData; width: 120 * npv.s; height: 40 * npv.s; radius: height / 2; color: M3.surfaceHigh } } }
                }
                // the password: your shape and the dots
                Rectangle {
                    readonly property string kind: page.v("input", "pill")
                    width: 380 * npv.s; height: 56 * npv.s
                    x: npv.isLeft ? npv.width * 0.08 : (npv.width - width) / 2
                    y: npv.height * 0.66
                    radius: kind === "pill" ? height / 2 : (kind === "box" ? 18 * npv.s : 0)
                    color: kind === "line" ? "transparent" : M3.surfaceHigh
                    border.width: kind === "line" ? 0 : 2; border.color: M3.primary
                    Rectangle { visible: parent.kind === "line"; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: M3.primary }
                    Blob { x: 8 * npv.s; anchors.verticalCenter: parent.verticalCenter; width: 40 * npv.s; height: width; kind: Prefs.accentShape; color: M3.primary }
                    Row { x: 62 * npv.s; anchors.verticalCenter: parent.verticalCenter; spacing: 6 * npv.s
                        Repeater { model: 6; delegate: Blob { width: 12 * npv.s; height: width; kind: Prefs.accentShape; color: M3.ink } } }
                }
                Row { visible: page.v("power", true) === true; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 36 * npv.s; spacing: 12 * npv.s
                    Repeater { model: 3; delegate: Rectangle { width: 52 * npv.s; height: width; radius: width / 2; color: index === 2 ? Qt.rgba(1, 0.42, 0.42, 0.3) : M3.surfaceHigh } } }
            }
            Rectangle {
                id: pv
                visible: page.v("engine", "shell") !== "shell"
                readonly property real s: height / 1080
                readonly property bool isLeft: page.v("layout", "center") === "left"
                readonly property string st: page.v("clock", "big")
                readonly property string acc: page.v("accent", "#d4d4d4")
                readonly property var ys: st === "stacked" ? ({ avatar: 400, date: 30, greet: -6, input: -96, power: -190 })
                                        : st === "minimal" ? ({ avatar: 150, date: 0, greet: 50, input: -40, power: -140 })
                                        : ({ avatar: 310, date: 66, greet: 30, input: -50, power: -146 })
                function px(w) { return isLeft ? 110 * s : (width - w) / 2 }
                function py(yoff, h) { return height / 2 - yoff * s - h / 2 }
                function hhmm() {
                    const d = page.now
                    let h = d.getHours()
                    if (!page.v("clock_24h", true)) h = h % 12 === 0 ? 12 : h % 12
                    return { h: String(h).padStart(2, "0"), m: String(d.getMinutes()).padStart(2, "0") }
                }

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 560)
                height: Math.round(width * 9 / 16)
                radius: 14
                clip: true
                color: "#0c0c0e"
                border.width: 1
                border.color: M3.surfaceHighest

                Image {
                    anchors.fill: parent
                    visible: page.v("background", "screenshot") === "wallpaper" && page.wall.length > 0
                    source: visible ? "file://" + page.wall : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 640
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent
                    visible: page.v("background", "screenshot") === "screenshot"
                    gradient: Gradient {
                        GradientStop { position: 0; color: M3.stageTop }
                        GradientStop { position: 1; color: M3.stageBottom }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: page.v("background", "screenshot") === "color" ? 0 : (1 - page.v("dim", 0.5)) * 0.9
                }

                // avatar
                Rectangle {
                    visible: page.v("avatar", true) && page.v("has_face", false)
                    width: 96 * pv.s; height: width; radius: width / 2
                    x: pv.px(width); y: pv.py(pv.ys.avatar, height)
                    color: M3.surfaceHighest
                    border.width: 1
                    border.color: pv.acc
                    RoundImage { anchors.fill: parent; anchors.margins: 1; source: "file://" + Quickshell.env("HOME") + "/.face" }
                }
                // clock
                T {
                    visible: pv.st === "big"
                    kind: "number"
                    font.family: page.clockFam()
                    textFormat: Text.StyledText
                    // white hours, grey minutes
                    text: "<b>" + pv.hhmm().h + I18n.t("</b><font color='") + (page.v("accent_clock", false) ? Qt.darker(pv.acc, 1.6) : "#8c8c8c") + "'>:" + pv.hhmm().m + I18n.t("</font>")
                    font.pixelSize: 96 * 1.33 * pv.s
                    color: page.v("accent_clock", false) ? pv.acc : "#F6F5F4"
                    x: pv.px(implicitWidth); y: pv.py(160, implicitHeight)
                }
                T {
                    visible: pv.st === "stacked"
                    kind: "number"
                    font.family: page.clockFam()
                    text: pv.hhmm().h
                    font.pixelSize: 120 * 1.33 * pv.s; font.bold: true
                    color: page.v("accent_clock", false) ? pv.acc : "#F6F5F4"
                    x: pv.px(implicitWidth); y: pv.py(250, implicitHeight)
                }
                T {
                    visible: pv.st === "stacked"
                    kind: "number"
                    font.family: page.clockFam()
                    text: pv.hhmm().m
                    font.pixelSize: 120 * 1.33 * pv.s
                    color: page.v("accent_clock", false) ? pv.acc : "#F6F5F4"
                    opacity: 0.55
                    x: pv.px(implicitWidth); y: pv.py(118, implicitHeight)
                }
                T {
                    visible: pv.st === "minimal"
                    kind: "number"
                    font.family: page.clockFam()
                    text: pv.hhmm().h + ":" + pv.hhmm().m
                    font.pixelSize: 30 * 1.33 * pv.s
                    color: page.v("accent_clock", false) ? pv.acc : "#F6F5F4"
                    x: pv.px(implicitWidth); y: 48 * pv.s - implicitHeight / 2
                }
                T { scaled: false
                    visible: page.v("date", true)
                    text: page.now.toLocaleDateString(I18n.loc, "dddd, d MMMM")
                    font.pixelSize: (pv.st === "minimal" ? 14 : 18) * 1.33 * pv.s
                    color: "#F6F5F4"; opacity: 0.55
                    x: pv.px(implicitWidth)
                    y: pv.st === "minimal" ? 96 * pv.s - implicitHeight / 2 : pv.py(pv.ys.date, implicitHeight)
                }
                T {
                    visible: page.v("greeting", true)
                    text: page.greeting()
                    font.pixelSize: 15 * 1.33 * pv.s
                    color: "#F6F5F4"; opacity: 0.9
                    x: pv.px(implicitWidth)
                    y: pv.py((page.v("date", true) || pv.st === "minimal") ? pv.ys.greet : pv.ys.date, implicitHeight)
                }
                // password field
                Rectangle {
                    readonly property string kind: page.v("input", "pill")
                    width: 300 * pv.s; height: 52 * pv.s
                    x: pv.px(width); y: pv.py(pv.ys.input, height)
                    radius: kind === "pill" ? height / 2 : (kind === "box" ? 12 * pv.s : 0)
                    color: kind === "pill" ? Qt.rgba(1, 1, 1, 0.08) : (kind === "box" ? Qt.rgba(0, 0, 0, 0.35) : "transparent")
                    border.width: kind === "box" ? 1 : 0
                    border.color: pv.acc
                    T { anchors.centerIn: parent; text: I18n.t("Enter password"); font.pixelSize: 15 * 1.33 * pv.s; color: "#F6F5F4"; opacity: 0.45 }
                    Rectangle { visible: parent.kind === "line"; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: pv.acc }
                }
                // power buttons
                Row {
                    visible: page.v("power", true)
                    spacing: 90 * pv.s - 30 * 1.33 * pv.s
                    x: pv.isLeft ? 110 * pv.s : (pv.width - width) / 2
                    y: pv.py(pv.ys.power, height)
                    Repeater {
                        model: ["󰍃", "󰐥", "󰤄", "󰜉"]
                        delegate: T { kind: "icon"; text: modelData; font.pixelSize: 30 * 1.33 * pv.s; color: "#F6F5F4"; opacity: 0.6 }
                    }
                }
                // bottom lines
                Column {
                    x: pv.isLeft ? 110 * pv.s : (pv.width - width) / 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24 * pv.s
                    spacing: 6 * pv.s
                    Repeater {
                        model: [
                            { k: "notifications", t: "󰂚  2 notifications" },
                            { k: "weather", t: "Partly cloudy  +7°C" },
                            { k: "resources", t: "CPU 8%  ·  RAM 17%  ·  GPU 16%" },
                            { k: "media", t: "󰎈  Artist - Song" }
                        ]
                        delegate: T {
                            visible: page.v(modelData.k, false)
                            anchors.horizontalCenter: pv.isLeft ? undefined : parent.horizontalCenter
                            text: modelData.t
                            font.pixelSize: 14 * 1.33 * pv.s
                            color: "#F6F5F4"; opacity: 0.75
                        }
                    }
                }
                T {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                    visible: page.v("managed", true) === false
                    text: I18n.t("Using your own hyprlock.conf")
                    font.pixelSize: 10; color: "#e0a050"
                }
            }
        }

        Row {
            spacing: 10
            Btn { primary: true; icon: ""; text: I18n.t("Lock now"); onClicked: Quickshell.execDetached(["bash", "-c", "setsid -f \"$HOME/.local/bin/rice-lock\" now >/dev/null 2>&1"]) }
            // the new lock screen in a window: try it without locking (Esc closes it)
            Btn { visible: page.v("engine", "shell") === "shell"; sym: "visibility"; text: I18n.t("Preview")
                onClicked: Quickshell.execDetached(["bash", "-c", "setsid -f \"$HOME/.local/bin/rice-lock\" preview >/dev/null 2>&1"]) }
            Btn { text: I18n.t("Reset"); onClicked: { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-lock\" reset"]); page.ctl.status = I18n.t("Lock screen reset"); refresh.restart() } }
        }

        // ---------- idle ----------
        SectionTitle { text: I18n.t("Idle"); sub: I18n.t("What happens when you leave the computer. Slide to 0 for Never.") }
        SliderRow {
            label: I18n.t("Lock after")
            desc: I18n.t("Currently: ") + page.mins(page.v("lock_after", 5))
            from: 0; to: 60; step: 1; unit: " min"
            value: page.v("lock_after", 5)
            onCommitted: function(x) { page.setv("lock_after", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Turn screen off after")
            desc: I18n.t("Currently: ") + page.mins(page.v("screen_off_after", 0))
            from: 0; to: 60; step: 1; unit: " min"
            value: page.v("screen_off_after", 0)
            onCommitted: function(x) { page.setv("screen_off_after", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Sleep after")
            desc: I18n.t("Currently: ") + page.mins(page.v("suspend_after", 15))
            from: 0; to: 120; step: 5; unit: " min"
            value: page.v("suspend_after", 15)
            onCommitted: function(x) { page.setv("suspend_after", Math.round(x)) }
        }
        ToggleRow { label: I18n.t("Lock before sleep"); desc: I18n.t("Always lock the screen before the computer sleeps"); checked: page.v("lock_before_sleep", true) === true; onToggled: function(x) { page.setv("lock_before_sleep", x ? "on" : "off") } }

        // ---------- lock screen ----------
        SectionTitle { text: I18n.t("Lock screen"); sub: I18n.t("Changes show up the next time you lock. Preview shows it without locking.") }
        SegRow {
            label: I18n.t("Lock screen")
            desc: page.v("engine", "shell") === "shell"
                  ? "DarkShadow: Material 3, your shape and wavy progress (hyprlock steps in if it ever fails)"
                  : "hyprlock: the classic lock screen"
            options: [{ label: I18n.t("DarkShadow"), value: "shell" }, { label: "hyprlock", value: "hyprlock" }]
            current: page.v("engine", "shell")
            onChosen: function(x) { page.setv("engine", x) }
        }
        ToggleRow { visible: page.v("engine", "shell") === "hyprlock"; label: I18n.t("Manage lock screen"); desc: I18n.t("Off keeps your own hyprlock.conf untouched"); checked: page.v("managed", true) === true; onToggled: function(x) { page.setv("managed", x ? "on" : "off") } }
        SegRow {
            visible: page.v("engine", "shell") === "shell"
            label: I18n.t("Style")
            desc: I18n.t("Cards: the month, the time and your music on tall cards. Classic: one column")
            options: [{ label: I18n.t("Cards"), value: "cards" }, { label: I18n.t("Classic"), value: "classic" }]
            current: page.v("style", "cards")
            onChosen: function(x) { page.setv("style", x) }
        }
        SegRow {
            visible: page.v("style", "cards") === "classic"
            label: I18n.t("Layout")
            desc: I18n.t("Everything centered, or on the left side")
            options: [{ label: I18n.t("Center"), value: "center" }, { label: I18n.t("Left"), value: "left" }]
            current: page.v("layout", "center")
            onChosen: function(x) { page.setv("layout", x) }
        }
        SegRow {
            visible: page.v("style", "cards") === "classic"
            label: I18n.t("Clock style")
            desc: I18n.t("Big, stacked hours over minutes, small, or inside your shape")
            options: [{ label: I18n.t("Big"), value: "big" }, { label: I18n.t("Stacked"), value: "stacked" }, { label: I18n.t("Minimal"), value: "minimal" }, { label: I18n.t("Shape"), value: "shape" }]
            current: page.v("clock", "big")
            onChosen: function(x) { page.setv("clock", x) }
        }
        // ---------- clock font ----------
        Column {
            width: parent.width
            spacing: 8
            topPadding: 4
            T { text: I18n.t("Clock font"); font.pixelSize: 14 }
            T { kind: "reading"; text: I18n.t("The clock stays white and grey. Fonts that are not here yet download when you pick them."); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
            Grid {
                id: cfGrid
                width: parent.width
                columns: 4
                spacing: 10
                Repeater {
                    model: page.clockFonts
                    delegate: Rectangle {
                        id: ft
                        readonly property bool on: page.v("clock_font", "default") === modelData.k
                        readonly property bool here: page.hasFam(modelData.f)
                        width: (cfGrid.width - 30) / 4
                        height: 92
                        radius: 14
                        color: fm.containsMouse ? M3.surfaceHigh : M3.surfaceC
                        border.width: on ? 2 : 1
                        border.color: on ? M3.primary : M3.outlineVariant
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        scale: fm.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            textFormat: Text.StyledText
                            text: I18n.t("<b>18</b><font color='#8c8c8c'>:36</font>")
                            font.family: modelData.f !== "" ? modelData.f : Fonts.family("number")
                            font.pixelSize: 34
                            color: "#F6F5F4"
                            opacity: ft.here ? 1 : 0.4
                        }
                        T {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height - 26
                            text: ft.here ? modelData.n : modelData.n + "  \u2193"
                            font.pixelSize: 11
                            color: ft.on ? M3.primary : M3.inkDim
                        }
                        MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { page.setv("clock_font", modelData.k); if (!ft.here) page.ctl.status = I18n.t("Downloading ") + modelData.n + "..." } }
                    }
                }
            }
        }
        ToggleRow { label: I18n.t("24-hour clock"); checked: page.v("clock_24h", true) === true; onToggled: function(x) { page.setv("clock_24h", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Accent clock"); desc: I18n.t("Color the clock with your Theme"); checked: page.v("accent_clock", false) === true; onToggled: function(x) { page.setv("accent_clock", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Date"); checked: page.v("date", true) === true; onToggled: function(x) { page.setv("date", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Greeting"); desc: I18n.t("Good morning / evening with your name"); checked: page.v("greeting", true) === true; onToggled: function(x) { page.setv("greeting", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Profile picture"); desc: I18n.t("Your avatar from Home"); checked: page.v("avatar", true) === true; onToggled: function(x) { page.setv("avatar", x ? "on" : "off") } }
        SegRow {
            label: I18n.t("Password field")
            options: [{ label: I18n.t("Pill"), value: "pill" }, { label: I18n.t("Box"), value: "box" }, { label: I18n.t("Line"), value: "line" }]
            current: page.v("input", "pill")
            onChosen: function(x) { page.setv("input", x) }
        }
        ToggleRow { label: I18n.t("Power buttons"); desc: I18n.t("Sleep, restart and shut down (in red); restart and shut down ask for a second click"); checked: page.v("power", true) === true; onToggled: function(x) { page.setv("power", x ? "on" : "off") } }

        SectionTitle { text: I18n.t("Background") }
        SegRow {
            label: I18n.t("Source")
            desc: I18n.t("Blurred screenshot, your wallpaper, or a plain color")
            options: [{ label: I18n.t("Screenshot"), value: "screenshot" }, { label: I18n.t("Wallpaper"), value: "wallpaper" }, { label: I18n.t("Color"), value: "color" }]
            current: page.v("background", "screenshot")
            onChosen: function(x) { page.setv("background", x) }
        }
        SliderRow {
            label: I18n.t("Blur")
            from: 0; to: 4; step: 1
            value: page.v("blur", 3)
            onCommitted: function(x) { page.setv("blur", Math.round(x)) }
        }
        SliderRow {
            label: I18n.t("Brightness")
            desc: I18n.t("Lower makes the background darker")
            from: 0.2; to: 1.0; step: 0.05; decimals: 2
            value: page.v("dim", 0.5)
            onCommitted: function(x) { page.setv("dim", x.toFixed(2)) }
        }

        SectionTitle { text: I18n.t("Widgets"); sub: I18n.t("Small lines at the bottom of the lock screen.") }
        ToggleRow { label: I18n.t("Media"); desc: I18n.t("What is playing right now"); checked: page.v("media", true) === true; onToggled: function(x) { page.setv("media", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Resources"); desc: I18n.t("CPU, RAM and GPU usage"); checked: page.v("resources", false) === true; onToggled: function(x) { page.setv("resources", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Notifications"); desc: I18n.t("How many notifications are waiting"); checked: page.v("notifications", true) === true; onToggled: function(x) { page.setv("notifications", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Weather"); desc: I18n.t("Current weather from wttr.in"); checked: page.v("weather", false) === true; onToggled: function(x) { page.setv("weather", x ? "on" : "off") } }

        Row {
            topPadding: 8
            Btn { text: I18n.t("Restore my original files"); onClicked: { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-lock\" restore"]); page.ctl.status = I18n.t("Original hyprlock/hypridle restored"); refresh.restart() } }
        }
    }
}
