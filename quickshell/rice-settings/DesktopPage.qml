import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl

    readonly property var widgets: [
        { key: "weather", label: I18n.t("Weather"), icon: "", desc: I18n.t("Temperature and sky") },
        { key: "media", label: I18n.t("Media player"), icon: "", desc: I18n.t("Now playing + controls") },
        { key: "resources", label: I18n.t("Resources"), icon: "", desc: I18n.t("CPU, RAM and GPU") },
        { key: "usercard", label: I18n.t("User card"), icon: "", desc: I18n.t("Greeting and date") },
        { key: "calendar", label: I18n.t("Calendar"), icon: "", desc: I18n.t("Month view") },
        { key: "visualizer", label: I18n.t("Visualizer"), icon: "\uf001", desc: I18n.t("See-through, at the bottom") },
        { key: "battery", label: I18n.t("Battery"), icon: "\uf240", desc: I18n.t("Charge and time left") },
        { key: "todo", label: I18n.t("To-do"), icon: "\uf14a", desc: I18n.t("Tasks to tick off") },
        { key: "focus", label: I18n.t("Focus timer"), icon: "\uf017", desc: I18n.t("Work and break timer") },
        { key: "notes", label: I18n.t("Note"), icon: "\uf249", desc: I18n.t("A note on the desktop") },
        { key: "gauge", label: I18n.t("Gauge"), icon: "\uf4bc", desc: I18n.t("CPU, RAM, GPU or heat in a soft shape") },
        { key: "date", label: I18n.t("Date"), icon: "\uf073", desc: I18n.t("Today in a flower or cookie shape") },
        { key: "sky", label: I18n.t("Sky"), icon: "\uf0c2", desc: I18n.t("The weather as a tilted pill") },
        { key: "nowring", label: I18n.t("Now playing"), icon: "\uf001", desc: I18n.t("The song in a round label") },
        { key: "player", label: I18n.t("Player"), icon: "\uf144", desc: I18n.t("Cover, seek line and buttons") },
        { key: "playpill", label: I18n.t("Play button"), icon: "\uf04b", desc: I18n.t("A big cookie to play and pause") },
        { key: "lyrics", label: I18n.t("Lyrics"), icon: "\uf075", desc: I18n.t("The words in time with the song") },
        { key: "storage", label: I18n.t("Storage"), icon: "\uf0a0", desc: I18n.t("Used and free disk space") },
        { key: "trio", label: I18n.t("CPU · GPU · RAM"), icon: "\uf2db", desc: I18n.t("Three small shapes") },
        { key: "forecast", label: I18n.t("Forecast"), icon: "\uf0c2", desc: I18n.t("Now, how it feels and the next hours") },
        { key: "music", label: I18n.t("Music card"), icon: "\uf001", desc: I18n.t("Cover and buttons; opens to the lyrics") },
        { key: "datepill", label: I18n.t("Date & time"), icon: "\uf017", desc: I18n.t("A slim pill with the date and the time") }
    ]

    // widget styles (Settings > Widgets > Theme)
    readonly property var themes: [
        { k: "shadow", n: "DarkShadow", d: "Frosted glass, black and white" },
        { k: "google", n: "Google", d: "Soft cards in your theme color" },
        { k: "outline", n: "Outline", d: "No fill, just a thin line" }
    ]
    function wv(id, key, d) { const w = page.ctl.dst.widgets; return w && w[id] && w[id][key] !== undefined ? w[id][key] : d }
    property color accent: "#9ec9bd"
    Process {
        command: ["bash", "-c", "sed -n 's/^@define-color accent *\\(#[0-9a-fA-F]\\{6\\}\\).*/\\1/p' \"$HOME/.config/waybar/colors.css\" 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); if (/^#[0-9a-fA-F]{6}$/.test(t)) page.accent = t } }
    }

    // the lock screen clock fonts (rice-fonts downloads them)
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

    // the to-do list (also on the desktop widget)
    property var todos: []
    Process {
        id: todoProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-todo\" list"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.todos = JSON.parse(text) } catch (e) { } } }
    }
    function todoDo(args) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-todo\" \"$@\"", "_"].concat(args.map(a => String(a))))
        todoDelay.restart()
    }
    Timer { id: todoDelay; interval: 450; onTriggered: todoProc.running = true }

    function wOn(k) {
        const w = page.ctl.dst.widgets
        return w && w[k] ? w[k].enabled === true : false
    }
    function cv(k, d) {
        const c = page.ctl.dst.clock
        return c && c[k] !== undefined ? c[k] : d
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 24
        anchors.topMargin: 6
        contentWidth: width
        contentHeight: col.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking && !flickWheel.active
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        WheelScroll { id: flickWheel; flick: flick }

        Column {
            id: col
            width: flick.width
            spacing: 10

            T { kind: "title"; text: I18n.t("Widgets"); font.pixelSize: 16; font.bold: true }
            // the widget editor on the desktop (Settings closes so you can see it)
            Rectangle {
                width: parent.width
                height: 72
                radius: 14
                color: edMouse.containsMouse ? M3.surfaceHigh : M3.surfaceC
                border.width: 1
                border.color: M3.surfaceHighest
                Behavior on color { ColorAnimation { duration: 140 } }
                Rectangle {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 12
                    color: "#F6F5F4"
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf044"; font.pixelSize: 17; color: "#0d0d0d" }
                }
                Column {
                    x: 72; anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    T { text: I18n.t("Edit widgets"); font.pixelSize: 15; font.bold: true }
                    T { kind: "reading"; text: I18n.t("Add, move, resize and style widgets right on your desktop"); font.pixelSize: 12; color: M3.inkDim }
                }
                T { kind: "icon"; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: "\uf054"; color: M3.inkDim }
                MouseArea {
                    id: edMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" edit on"])
                        Qt.quit()
                    }
                }
            }
            T {
                width: parent.width
                text: I18n.t("Switch a widget on to put it on the desktop. Edit widgets opens the editor on your desktop: add widgets, drag them, pull a corner to resize, change style and opacity. Shortcut: SUPER + ALT + W.")
                color: M3.inkDim
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Flickable {
                id: rowFlick
                width: parent.width
                height: 150
                contentWidth: wrow.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Behavior on contentX {
                    enabled: !rowFlick.dragging && !rowFlick.flicking && !rowFlickWheel.active
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                WheelScroll { id: rowFlickWheel; flick: rowFlick; horizontal: true; outer: flickWheel }

                Row {
                    id: wrow
                    spacing: 10
                    Repeater {
                        model: page.widgets
                        delegate: Rectangle {
                            id: card
                            width: 172
                            height: 146
                            radius: 14
                            readonly property bool on: page.wOn(modelData.key)
                            color: cardMouse.containsMouse ? M3.surfaceHigh : M3.surfaceC
                            border.width: 1
                            border.color: card.on ? M3.primary : M3.outlineVariant
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.ctl.dset("widget", modelData.key, card.on ? "off" : "on")
                            }
                            Rectangle {
                                x: 14
                                y: 14
                                width: 40
                                height: 40
                                radius: 12
                                color: card.on ? M3.primary : M3.surfaceHighest
                                Behavior on color { ColorAnimation { duration: 200 } }
                                T { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 18; color: card.on ? M3.inkPrimary : "#F6F5F4" }
                            }
                            Column {
                                x: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                spacing: 3
                                T { text: modelData.label; font.pixelSize: 14; font.bold: true }
                                T { text: modelData.desc; font.pixelSize: 10; color: M3.inkDim }
                            }
                            Tog {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                y: 22
                                checked: card.on
                                onToggled: function(v) { page.ctl.dset("widget", modelData.key, v ? "on" : "off") }
                            }
                        }
                    }
                }
            }

            ToggleRow {
                label: I18n.t("Auto-hide widgets")
                desc: I18n.t("Hide them while a tiled window is open on the screen; floating windows (Settings, pop-ups) leave them alone. Lighter on the computer")
                checked: page.ctl.dst.autoHide === true
                onToggled: function(v) { page.ctl.setAutoHide(v) }
            }
            ToggleRow {
                label: I18n.t("Blur behind widgets")
                desc: I18n.t("Frosted glass: the widgets take the colors of your wallpaper. Off: plain dark cards")
                checked: page.ctl.dst.widgetBlur !== false
                onToggled: function(v) {
                    const d = JSON.parse(JSON.stringify(page.ctl.dst)); d.widgetBlur = v; page.ctl.dst = d
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" widgets-blur \"$1\"", "_", v ? "on" : "off"])
                    page.ctl.status = I18n.t("Widget blur ") + (v ? "on" : "off")
                }
            }
            SliderRow {
                label: I18n.t("Transparency of the widgets")
                desc: I18n.t("How much of the wallpaper shows through the cards (with blur: frosted glass), on Hyprland and niri")
                from: 0; to: 80; step: 5; decimals: 0; unit: "%"
                value: Math.round((1 - (page.ctl.dst.widgetOpacity !== undefined ? Number(page.ctl.dst.widgetOpacity) : 1)) * 100)
                onCommitted: function(x) {
                    const o = (1 - x / 100).toFixed(2)
                    const d = JSON.parse(JSON.stringify(page.ctl.dst)); d.widgetOpacity = Number(o); page.ctl.dst = d
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" widgets-opacity \"$1\"", "_", o])
                }
            }
            SegRow {
                label: I18n.t("Frame rate")
                desc: I18n.t("How smooth the moving parts of the widgets are (turning shapes, the visualizer). Screen: as fast as your monitor (144, 180 Hz ...), a little more work")
                options: [{ label: "30", value: "30" }, { label: "60", value: "60" }, { label: "120", value: "120" }, { label: I18n.t("Screen"), value: "0" }]
                current: String(page.ctl.dst.fps !== undefined ? page.ctl.dst.fps : 60)
                onChosen: function(v) {
                    const d = JSON.parse(JSON.stringify(page.ctl.dst)); d.fps = Number(v); page.ctl.dst = d
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" widgets-fps \"$1\"", "_", v])
                }
            }
            Row {
                spacing: 8
                Pill { label: I18n.t("Reset widget positions"); onClicked: page.ctl.dreset() }
            }

            // ---------- Task view (rice-taskview) ----------
            T { kind: "title"; text: I18n.t("Task view"); font.pixelSize: 16; font.bold: true; topPadding: 14 }
            T {
                width: parent.width; wrapMode: Text.WordWrap; kind: "dim"
                text: I18n.t("Super + Tab shows every workspace with its windows: type to find one, drag a window to another workspace, middle click closes it. Alt + Tab switches windows: hold Alt, press Tab, let go. Other keys: Settings > Keybinds (the pencil).")
            }
            Item {
                id: tvs
                width: parent.width; height: tvCol.implicitHeight
                property var c: ({ live: true, count: 10, empty: true, super: false })
                Process { id: tvGet; running: true; command: ["bash", "-c", "\"$HOME/.local/bin/rice-taskview\" get 2>/dev/null"]
                    stdout: StdioCollector { onStreamFinished: { try { tvs.c = JSON.parse(text) } catch (e) { } } } }
                function setv(k, v) {
                    const n = JSON.parse(JSON.stringify(tvs.c)); n[k] = (v === "on") ? true : (v === "off" ? false : Number(v)); tvs.c = n
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-taskview\" set \"$1\" \"$2\"", "_", k, String(v)])
                }
                Column {
                    id: tvCol
                    width: parent.width; spacing: 8
                    ToggleRow { visible: !page.ctl.niri; label: I18n.t("Super alone opens it"); desc: I18n.t("Press Super and let go (Super + a key still does what it did)")
                        checked: tvs.c.super === true; onToggled: function(v) { tvs.setv("super", v ? "on" : "off") } }
                    ToggleRow { label: I18n.t("Live pictures of the windows"); desc: I18n.t("Off: their icons (lighter)")
                        checked: tvs.c.live !== false; onToggled: function(v) { tvs.setv("live", v ? "on" : "off") } }
                    ToggleRow { label: I18n.t("Empty workspaces too"); desc: I18n.t("Off: only the workspaces with windows")
                        checked: tvs.c.empty !== false; onToggled: function(v) { tvs.setv("empty", v ? "on" : "off") } }
                    SegRow { label: I18n.t("Workspaces"); desc: I18n.t("How many it shows (more when you use more)")
                        options: [{ label: "5", value: "5" }, { label: "10", value: "10" }]
                        current: String(tvs.c.count || 10); onChosen: function(v) { tvs.setv("count", v) } }
                }
            }

            // ---------- Clipboard (rice-clip, cliphist) ----------
            T { kind: "title"; text: I18n.t("Clipboard"); font.pixelSize: 16; font.bold: true; topPadding: 14 }
            T {
                width: parent.width; wrapMode: Text.WordWrap; kind: "dim"
                text: I18n.t("Super + V shows everything you copied, texts and pictures. Type to search, Enter puts it back (and pastes it), Del removes it, Ctrl + P pins a text to the top. Float / tile a window moved to Super + Shift + V. Other keys: Settings > Keybinds.")
            }
            Item {
                id: clip
                width: parent.width; height: clipCol.implicitHeight
                property var c: ({ enabled: true, paste: true, images: true, max: 200, cliphist: true, wtype: true })
                property bool armed: false
                Process { running: true; command: ["bash", "-c", "\"$HOME/.local/bin/rice-clip\" state 2>/dev/null"]
                    stdout: StdioCollector { onStreamFinished: { try { clip.c = JSON.parse(text) } catch (e) { } } } }
                function setv(k, v) {
                    const n = JSON.parse(JSON.stringify(clip.c)); n[k] = (v === "on") ? true : (v === "off" ? false : Number(v)); clip.c = n
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-clip\" set \"$1\" \"$2\"", "_", k, String(v)])
                }
                Timer { id: clipDisarm; interval: 3000; onTriggered: clip.armed = false }
                Column {
                    id: clipCol
                    width: parent.width; spacing: 8
                    T { visible: clip.c.cliphist === false; width: parent.width; wrapMode: Text.WordWrap; color: "#e5c07b"; font.pixelSize: 12
                        text: I18n.t("cliphist is not installed. Run the installer again (Settings > Update Center), or install cliphist and wl-clipboard.") }
                    ToggleRow { label: I18n.t("Keep a clipboard history"); desc: I18n.t("Off: nothing you copy is written down")
                        checked: clip.c.enabled !== false; onToggled: function(v) { clip.setv("enabled", v ? "on" : "off") } }
                    ToggleRow { label: I18n.t("Paste right away"); desc: clip.c.wtype === false ? I18n.t("Needs wtype (the installer adds it)") : I18n.t("Picking an entry also pastes it into the window you were in")
                        checked: clip.c.paste !== false; onToggled: function(v) { clip.setv("paste", v ? "on" : "off") } }
                    ToggleRow { label: I18n.t("Pictures too"); desc: I18n.t("Screenshots and copied images, with a small preview")
                        checked: clip.c.images !== false; onToggled: function(v) { clip.setv("images", v ? "on" : "off") } }
                    SegRow { label: I18n.t("How many to keep"); desc: I18n.t("The oldest go first")
                        options: [{ label: "50", value: "50" }, { label: "200", value: "200" }, { label: "500", value: "500" }, { label: "1000", value: "1000" }]
                        current: String(clip.c.max || 200); onChosen: function(v) { clip.setv("max", v) } }
                    Row {
                        spacing: 8
                        Pill { label: I18n.t("Open the clipboard"); onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-clip\" open"]) }
                        Pill { label: clip.armed ? I18n.t("Sure? Click again") : I18n.t("Clear the history")
                            onClicked: { if (!clip.armed) { clip.armed = true; clipDisarm.restart(); return } clip.armed = false
                                Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-clip\" wipe"]) } }
                    }
                }
            }

            // ---------- Performance (rice-effects lite) ----------
            T { kind: "title"; text: I18n.t("Performance"); font.pixelSize: 16; font.bold: true; topPadding: 14 }
            Item {
                id: perf
                width: parent.width; height: perfCol.implicitHeight
                property bool lite: false
                Process { running: true; command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state 2>/dev/null"]
                    stdout: StdioCollector { onStreamFinished: { try { perf.lite = JSON.parse(text).lite === true } catch (e) { } } } }
                Column {
                    id: perfCol
                    width: parent.width; spacing: 8
                    ToggleRow { label: I18n.t("Light mode"); desc: I18n.t("For laptops and older graphics: no blur, no see-through, no shadows, quicker panels, widgets hide behind windows")
                        checked: perf.lite
                        onToggled: function(v) { perf.lite = v; Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" lite \"$1\"", "_", v ? "on" : "off"]) } }
                    T { width: parent.width; wrapMode: Text.WordWrap; kind: "dim"
                        text: I18n.t("Less memory: turn off the widgets you do not use (an off widget takes no memory now), and the Visualizer. Panels like the control center are only made when you open them.") }
                }
            }

            // ---------- visualizer ----------
            T { kind: "title"; text: I18n.t("Visualizer"); font.pixelSize: 16; font.bold: true; topPadding: 14 }
            SegRow {
                label: I18n.t("Style")
                desc: I18n.t("Round bars, a mirror, a wave or dots")
                options: [{ label: I18n.t("Bars"), value: "bars" }, { label: I18n.t("Mirror"), value: "mirror" }, { label: I18n.t("Wave"), value: "wave" }, { label: I18n.t("Dots"), value: "dots" }]
                current: page.wv("visualizer", "style", "bars")
                onChosen: function(v) { page.ctl.dwset("visualizer", "style", v) }
            }
            SegRow {
                label: I18n.t("Color")
                desc: I18n.t("Your Theme color, a gradient from it, rainbow, or white (black on a light wallpaper)")
                options: [{ label: I18n.t("Theme"), value: "accent" }, { label: I18n.t("Gradient"), value: "gradient" }, { label: I18n.t("Rainbow"), value: "rainbow" }, { label: I18n.t("White / black"), value: "mono" }]
                current: page.wv("visualizer", "color", "accent")
                onChosen: function(v) { page.ctl.dwset("visualizer", "color", v) }
            }
            SegRow {
                label: I18n.t("Direction")
                desc: I18n.t("Grow up from the bottom, or hang down from the top")
                options: [{ label: I18n.t("Up"), value: "off" }, { label: I18n.t("Down"), value: "on" }]
                current: (page.wv("visualizer", "flip", false) === true || page.wv("visualizer", "flip", false) === "on") ? "on" : "off"
                onChosen: function(v) { page.ctl.dwset("visualizer", "flip", v) }
            }

            // ---------- to-do ----------
            T { kind: "title"; text: I18n.t("To-do list"); font.pixelSize: 16; font.bold: true; topPadding: 14 }
            T { width: parent.width; text: I18n.t("The tasks of the To-do widget. On the desktop, click the widget once to type in it. In a terminal: rice-todo add \"buy milk\"."); color: M3.inkDim; font.pixelSize: 12; wrapMode: Text.WordWrap }
            Field {
                id: todoField
                width: parent.width
                placeholder: I18n.t("Add a task and press Enter")
                onAccepted: { if (text.trim().length > 0) { page.todoDo(["add", text.trim()]); text = "" } }
            }
            Repeater {
                model: page.todos
                delegate: Rectangle {
                    width: col.width
                    height: 44
                    radius: 12
                    color: M3.surfaceC
                    border.width: 1
                    border.color: M3.outlineVariant
                    Rectangle {
                        id: tbx
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20; radius: 10
                        color: modelData.done ? M3.primary : "transparent"
                        border.width: modelData.done ? 0 : 2
                        border.color: "#6a6a70"
                        T { visible: modelData.done; anchors.centerIn: parent; kind: "icon"; text: "\uf00c"; font.pixelSize: 10; color: "#0d0d0d" }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: page.todoDo(["toggle", index]) }
                    }
                    T {
                        anchors.left: tbx.right; anchors.leftMargin: 12
                        anchors.right: dl.left; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.t
                        font.pixelSize: 13
                        font.strikeout: modelData.done
                        color: modelData.done ? "#6a6a70" : "#F6F5F4"
                        elide: Text.ElideRight
                    }
                    T {
                        id: dl
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "icon"; text: "\uf00d"; font.pixelSize: 13; color: M3.inkDim
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: page.todoDo(["remove", index]) }
                    }
                }
            }
            Row {
                visible: page.todos.some(t => t.done)
                Pill { label: I18n.t("Clear ticked tasks"); onClicked: page.todoDo(["clear"]) }
            }

            T { kind: "title"; text: I18n.t("Clock"); font.pixelSize: 16; font.bold: true; topPadding: 14 }

            ToggleRow {
                label: I18n.t("Enable")
                desc: I18n.t("Show a clock on the desktop")
                checked: page.cv("enabled", false) === true
                onToggled: function(v) { page.ctl.dset("clock", "enabled", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Show only when locked")
                desc: I18n.t("Hide it on the desktop")
                checked: page.cv("onlyLocked", false) === true
                onToggled: function(v) { page.ctl.dset("clock", "onlyLocked", v ? "on" : "off") }
            }
            SegRow {
                label: I18n.t("Placement strategy")
                desc: I18n.t("Move it in the widget editor, or auto-pick a spot")
                options: [
                    { label: I18n.t("Draggable"), value: "draggable" },
                    { label: I18n.t("Least busy"), value: "leastBusy" },
                    { label: I18n.t("Most busy"), value: "mostBusy" }
                ]
                current: page.cv("placement", "draggable")
                onChosen: function(v) { page.ctl.dset("clock", "placement", v) }
            }
            SegRow {
                label: I18n.t("Clock style")
                desc: I18n.t("Look of the desktop clock")
                options: [
                    { label: I18n.t("Digital"), value: "digital" },
                    { label: I18n.t("Line"), value: "line" },
                    { label: I18n.t("Cookie"), value: "cookie" },
                    { label: I18n.t("Pixel"), value: "pixel" }
                ]
                current: page.cv("style", "digital")
                onChosen: function(v) { page.ctl.dset("clock", "style", v) }
            }

            Column {
                width: parent.width
                spacing: 8
                topPadding: 4
                T { text: I18n.t("Clock font"); font.pixelSize: 14 }
                T { kind: "reading"; text: I18n.t("The same fonts as the lock screen clock. They show on the Digital and Line styles. Fonts that are not here yet download when you pick them."); color: M3.inkDim; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                Grid {
                    id: cfGrid
                    width: parent.width
                    columns: 4
                    spacing: 10
                    Repeater {
                        model: page.clockFonts
                        delegate: Rectangle {
                            id: ft
                            readonly property bool on: page.cv("font", "default") === modelData.k
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
                                onClicked: { page.ctl.dwset("clock", "font", modelData.k); if (!ft.here) page.ctl.status = I18n.t("Downloading ") + modelData.n + "..." } }
                        }
                    }
                }
            }
        }
    }
}
