import Quickshell
import Quickshell.Io
import QtQuick

// Settings > System > Keybinds: every key worth knowing, in groups, for the window manager that runs (Hyprland
// or niri). Type to find one. The pencil next to a key gives the action other keys (rice-keymap; niri too);
// keys for any other app or command are made on the Hyprland / niri page (Custom keybinds).
Item {
    id: page
    property var ctl
    readonly property bool niri: !!Quickshell.env("NIRI_SOCKET")
    property string q: ""
    // your own keys (Hyprland): rice-keymap list
    property var km: ({ hypr: false, keys: {}, binds: [] })
    property var editing: null     // [keys, what, id] of the key being changed
    function hyprKeys(h) {   // "SUPER + SHIFT + R" -> "Super + Shift + R"
        const m = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" }
        return h.split(" + ").map(p => m[p] || (p.length === 1 ? p.toUpperCase() : p.charAt(0).toUpperCase() + p.slice(1))).join(" + ")
    }
    // the keys of a line now: yours if you changed them
    function keysOf(k) {
        const e = k[2] && km.keys ? km.keys[k[2]] : null
        return e && e.now !== e.default ? hyprKeys(e.now) : k[0]
    }
    function changed(k) { const e = k[2] && km.keys ? km.keys[k[2]] : null; return !!(e && e.now !== e.default) }
    Process {
        id: kmProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-keymap\" list 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.km = JSON.parse(text) } catch (e) { } } }
    }
    Process { id: kmSet; stdout: StdioCollector { onStreamFinished: kmLater.restart() } }
    Timer { id: kmLater; interval: 300; onTriggered: kmProc.running = true }
    onVisibleChanged: if (visible) kmProc.running = true
    function kmRun(args) { kmSet.command = ["bash", "-c", "\"$HOME/.local/bin/rice-keymap\" \"$@\"", "_"].concat(args); kmSet.running = true }

    // [keys, what it does]; "Super" is the key with the Windows logo
    readonly property var groups: niri ? [
        { name: "Apps and menus", sym: "apps", keys: [
            ["Super + Return", "Terminal (Settings > Desktop > Look & Feel picks which)", "terminal"],
            ["Super + D", "Launcher: find and open apps", "launcher"], ["Alt + Space", "Launcher", "launcher2"],
            ["Super + E", "Files"], ["Super + U", "Settings (this window)", "settings"], ["Super + W", "Wallpapers", "wallpaper"],
            ["Super + A", "Quick switches: Wi-Fi, Bluetooth, Do not disturb ...", "quick"], ["Super + N", "Control center and notifications", "cc"],
            ["Super + G", "Game bar", "gamebar"], ["Super + Alt + D", "Dashboard", "dashboard"], ["Super + L", "Lock the screen", "lock"],
            ["Super + V", "Clipboard: everything you copied", "clipboard"] ] },
        { name: "Windows", sym: "select_window", keys: [
            ["Super + Q", "Close the window", "close"], ["Super + Shift + V", "Float / tile the window", "float"],
            ["Super + F", "Make the column as wide as the screen"], ["Super + Shift + F", "Fullscreen"],
            ["Super + T", "Windows of a column as tabs"], ["Super + R", "Next column width"],
            ["Super + Minus / Equal", "Column narrower / wider"], ["Super + [  /  ]", "Put the window in the column next to it / take it out"],
            ["Super + Arrows", "Focus the window next to it"], ["Super + Ctrl + Arrows", "Move the window"],
            ["Super + Home / End", "First / last column"] ] },
        { name: "Workspaces", sym: "view_carousel", keys: [
            ["Super + 1 … 0", "Go to workspace 1 … 10"], ["Super + Shift + 1 … 0", "Move the window to a workspace"],
            ["Super + Page Up / Down", "Workspace above / below"], ["Super + Mouse wheel", "Workspace above / below"],
            ["Super + Tab", "Task view: every workspace and its windows", "taskview"], ["Alt + Tab", "Switch windows (hold Alt, Tab on, let go)", "switcher"],
            ["Super + O", "niri's own overview"], ["Super + Shift + Arrows", "Focus another screen"] ] },
        { name: "Screenshots and recording", sym: "screenshot_monitor", keys: [
            ["Print", "Screenshot of an area", "shot"], ["Shift + Print", "Screenshot of the whole screen", "shotfull"],
            ["Alt + Print", "Screenshot of the window"], ["Super + Shift + R", "Record the screen (again: stop)", "record"] ] },
        { name: "Sound, brightness, music", sym: "volume_up", keys: [
            ["Volume keys", "Louder, quieter, mute"], ["Super + F12 / F11 / F10", "Louder / quieter / mute"],
            ["Alt + ]  /  [", "Louder / quieter"], ["Brightness keys", "Screen brighter / darker"],
            ["Play / Next / Previous", "Music"] ] },
        { name: "Desktop", sym: "desktop_windows", keys: [
            ["Super + Alt + W", "Edit the desktop widgets", "widgets"], ["Super + Shift + /", "niri's own list of keys"],
            ["Super + Shift + P", "Screens off"], ["Super + Shift + E", "Log out"] ] }
    ] : [
        { name: "Apps and menus", sym: "apps", keys: [
            ["Super + Return", "Terminal (Settings > Desktop > Look & Feel picks which)", "terminal"],
            ["Super + R", "Launcher: find and open apps", "launcher"], ["Alt + Space", "Launcher", "launcher2"],
            ["Super + E", "Files"], ["Super + U", "Settings (this window)", "settings"], ["Super + W", "Wallpapers", "wallpaper"],
            ["Super + A", "Quick switches: Wi-Fi, Bluetooth, Do not disturb ...", "quick"], ["Super + N", "Control center and notifications", "cc"],
            ["Super + G", "Game bar", "gamebar"], ["Super + Alt + D", "Dashboard", "dashboard"], ["Super + L", "Lock the screen", "lock"],
            ["Super + V", "Clipboard: everything you copied", "clipboard"] ] },
        { name: "Windows", sym: "select_window", keys: [
            ["Super + Q", "Close the window", "close"], ["Super + Shift + V", "Float / tile the window", "float"],
            ["Super + J", "Split the other way"], ["Super + P", "Pseudo-tile (keep its own size)"],
            ["Super + F", "Infinite Desktop: windows on an endless canvas (Ctrl + wheel zooms)", "infinite"],
            ["Super + Arrows", "Focus the window next to it"],
            ["Super + Left mouse", "Drag to move the window"], ["Super + Right mouse", "Drag to resize the window"] ] },
        { name: "Workspaces", sym: "view_carousel", keys: [
            ["Super + Tab", "Task view: every workspace and its windows", "taskview"],
            ["Alt + Tab", "Switch windows (hold Alt, Tab on, let go)", "switcher"],
            ["Super + 1 … 0", "Go to workspace 1 … 10"], ["Super + Shift + 1 … 0", "Move the window to a workspace"],
            ["Super + Mouse wheel", "Next / previous workspace"], ["Super + S", "The hidden scratch workspace"] ] },
        { name: "Screenshots and recording", sym: "screenshot_monitor", keys: [
            ["Print", "Screenshot of an area", "shot"], ["Shift + Print", "Screenshot of the whole screen", "shotfull"],
            ["Super + Shift + S", "Screenshot of an area"], ["Super + Shift + R", "Record the screen (again: stop)", "record"] ] },
        { name: "Sound, brightness, music", sym: "volume_up", keys: [
            ["Volume keys", "Louder, quieter, mute"], ["Super + F12 / F11 / F10", "Louder / quieter / mute"],
            ["Alt + ]  /  [", "Louder / quieter"], ["Brightness keys", "Screen brighter / darker"],
            ["Play / Next / Previous", "Music"] ] },
        { name: "Desktop", sym: "desktop_windows", keys: [
            ["Super + Alt + W", "Edit the desktop widgets", "widgets"], ["Super + M", "Log out"] ] }
    ]
    function match(k) {
        if (q === "") return true
        const s = q.toLowerCase()
        return keysOf(k).toLowerCase().indexOf(s) >= 0 || k[1].toLowerCase().indexOf(s) >= 0
    }

    // one key, drawn as a key cap
    component Cap: Rectangle {
        property string label: ""
        readonly property bool plus: label === "+"
        width: plus ? lt.implicitWidth : Math.max(30, lt.implicitWidth + 18)
        height: 30
        radius: 9 * M3.shapeK
        color: plus ? "transparent" : M3.surfaceHighest
        border.width: plus ? 0 : 1
        border.color: M3.outlineVariant
        // the edge under a key
        Rectangle { visible: !parent.plus; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 4; anchors.rightMargin: 4; height: 2; radius: 1; color: M3.alpha(M3.ink, 0.12) }
        T { id: lt; anchors.centerIn: parent; text: parent.label; font.pixelSize: 12; font.weight: parent.plus ? Font.Normal : Font.DemiBold
            color: parent.plus ? M3.inkDim : M3.ink }
    }
    // "Super + Shift + 1" -> caps
    component Caps: Row {
        property string keys: ""
        spacing: 5
        Repeater {
            model: parent.keys.split(" + ").reduce((a, k, i) => i ? a.concat(["+", k]) : [k], [])
            Cap { label: modelData; anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the keys you use most ----------
        Rectangle {
            width: parent.width
            height: 196
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob { width: 240; height: 240; x: parent.width - 170; y: -60; kind: "flower"; color: M3.alpha(M3.inkPrimaryC, 0.06) }
            T { x: 24; y: 20; text: I18n.t("KEYS TO KNOW"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                color: M3.alpha(M3.inkPrimaryC, 0.75) }
            T { x: 24; y: 40; kind: "title"; text: I18n.t("Super is the key with the Windows logo"); font.pixelSize: 22; font.weight: Font.Medium
                color: M3.inkPrimaryC; width: parent.width - 48; elide: Text.ElideRight }
            Row {
                x: 24; y: 92
                spacing: 12
                Repeater {
                    model: [[page.keysOf(["Super + Return", "", "terminal"]), "Terminal", "terminal"],
                            [page.keysOf([page.niri ? "Super + D" : "Super + R", "", "launcher"]), "Apps", "apps"],
                            [page.keysOf(["Super + U", "", "settings"]), "Settings", "settings"],
                            [page.keysOf(["Super + W", "", "wallpaper"]), "Wallpaper", "wallpaper"]]
                    delegate: Rectangle {
                        width: (page.width - 48 - 2 * 24 - 36) / 4
                        height: 82
                        radius: M3.rL
                        color: M3.alpha(M3.surface, 0.55)
                        Row {
                            x: 14; y: 12; spacing: 8
                            Icon { name: modelData[2]; glyph: ""; size: 18; color: M3.inkPrimaryC; anchors.verticalCenter: parent.verticalCenter }
                            T { text: modelData[1]; font.pixelSize: 13; font.weight: Font.DemiBold; color: M3.inkPrimaryC; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Caps { x: 14; y: 44; keys: modelData[0] }
                    }
                }
            }
        }

        // ---------- find a key, the tour ----------
        Item {
            width: parent.width
            height: 48
            Field {
                id: find
                width: parent.width - tourBtn.width - 12
                anchors.verticalCenter: parent.verticalCenter
                placeholder: I18n.t("Find a key: screenshot, close, workspace ...")
                onTextChanged: page.q = text.trim()
            }
            Btn {
                id: tourBtn
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Show me around"); sym: "tour"; icon: ""; variant: "tonal"
                onClicked: if (page.ctl && page.ctl.startTour) page.ctl.startTour()
            }
        }

        // ---------- every key, in groups ----------
        Repeater {
            model: page.groups
            delegate: Column {
                id: grp
                required property var modelData
                readonly property var shown: modelData.keys.filter(k => page.match(k))
                visible: shown.length > 0
                width: parent ? parent.width : 400
                spacing: 6
                topPadding: 8
                Row {
                    spacing: 10
                    Rectangle {
                        width: 32; height: 32; radius: 16; color: M3.secondaryContainer
                        Icon { anchors.centerIn: parent; name: grp.modelData.sym; glyph: ""; size: 18; color: M3.inkSecondaryC }
                    }
                    T { text: grp.modelData.name; font.pixelSize: 16; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    width: parent.width
                    height: list.implicitHeight
                    radius: M3.rL
                    color: M3.surfaceC
                    clip: true
                    Column {
                        id: list
                        width: parent.width
                        Repeater {
                            model: grp.shown
                            delegate: Rectangle {
                                // found by the search in the sidebar
                                property string label: modelData[1]
                                property string desc: modelData[0]
                                width: list.width
                                height: 52
                                color: rh.hovered ? M3.surfaceHigh : "transparent"
                                HoverHandler { id: rh }
                                readonly property bool editable: !!modelData[2] && !!page.km.loaded
                                T { x: 18; anchors.verticalCenter: parent.verticalCenter; width: parent.width - caps.width - 52 - (pen.visible ? 44 : 0)
                                    text: modelData[1]; font.pixelSize: 14; elide: Text.ElideRight }
                                Caps { id: caps; keys: page.keysOf(modelData); anchors.right: pen.visible ? pen.left : parent.right; anchors.rightMargin: pen.visible ? 8 : 14
                                    anchors.verticalCenter: parent.verticalCenter; opacity: page.changed(modelData) ? 1 : 0.95 }
                                Rectangle {
                                    visible: page.changed(modelData); width: 6; height: 6; radius: 3; color: M3.primary
                                    anchors.right: caps.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                }
                                // change the keys
                                Rectangle {
                                    id: pen
                                    visible: parent.editable
                                    width: 34; height: 34; radius: 17
                                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    color: penH.hovered ? M3.secondaryContainer : (rh.hovered ? M3.surfaceHighest : "transparent")
                                    HoverHandler { id: penH; cursorShape: Qt.PointingHandCursor }
                                    Icon { anchors.centerIn: parent; name: "edit"; glyph: "\uf044"; size: 16; color: penH.hovered ? M3.inkSecondaryC : M3.inkDim }
                                    TapHandler { onTapped: page.editing = modelData }
                                }
                                Rectangle { visible: index > 0; width: parent.width - 36; x: 18; height: 1; color: M3.outlineVariant; opacity: 0.6 }
                            }
                        }
                    }
                }
            }
        }

        T {
            visible: page.q !== "" && page.groups.every(g => g.keys.filter(k => page.match(k)).length === 0)
            width: parent.width; wrapMode: Text.WordWrap; topPadding: 12
            text: I18n.t("No key for \"") + page.q + I18n.t("\". Make your own on the ") + (page.niri ? "niri" : I18n.t("Hyprland")) + I18n.t(" page (Desktop).")
            color: M3.inkDim
        }

        // ---------- your own ----------
        SettingRow {
            visible: Object.keys(page.km.keys || {}).some(k => page.km.keys[k].now !== page.km.keys[k].default)
            label: I18n.t("Back to the default keys")
            desc: I18n.t("Every key you changed here goes back to how it came")
            reserved: 150
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Reset all"); variant: "tonal"; onClicked: page.kmRun(["reset-all"]) }
        }
        // your own keys for any app or command, right here (they were hidden in Windows > Keybinds)
        Item { width: parent.width; height: 8 }
        BindsPage { width: parent.width; ctl: page.ctl; showActive: false }
    }

    // ---------- change the keys of one action ----------
    Rectangle {
        anchors.fill: parent
        visible: page.editing !== null
        color: M3.alpha("#000000", 0.45)
        MouseArea { anchors.fill: parent; onClicked: page.editing = null }
        onVisibleChanged: if (visible) {
            const cur = page.keysOf(page.editing).split(" + ")
            ed.key = cur[cur.length - 1]
            ed.mods = { Super: cur.indexOf("Super") >= 0, Ctrl: cur.indexOf("Ctrl") >= 0, Alt: cur.indexOf("Alt") >= 0, Shift: cur.indexOf("Shift") >= 0 }
            cap.forceActiveFocus()
        }
        Rectangle {
            id: ed
            property string key: ""
            property var mods: ({})
            readonly property string human: ["Super", "Ctrl", "Alt", "Shift"].filter(m => mods[m]).concat(key ? [key] : []).join(" + ")
            readonly property string hypr: ["SUPER", "CTRL", "ALT", "SHIFT"].filter((m, i) => mods[["Super", "Ctrl", "Alt", "Shift"][i]])
                .concat(key ? [key.length === 1 ? key.toUpperCase() : key] : []).join(" + ")
            function norm(h) { const p = h.split("+").map(x => x.trim()).filter(x => x); const k = p.pop() || ""; return p.map(x => x.toUpperCase()).sort().concat([k.toUpperCase()]).join("+") }
            readonly property bool plain: !mods.Super && !mods.Ctrl && !mods.Alt && !/^(F\d+|Print|XF86.*)$/.test(key)
            readonly property var clash: {
                if (!key || !page.editing) return null
                const n = norm(hypr), id = page.editing[2], own = page.km.keys && page.km.keys[id] ? norm(page.km.keys[id].now) : ""
                if (n === own) return null
                for (const a in page.km.keys) if (a !== id && norm(page.km.keys[a].now) === n) return a
                const b = (page.km.binds || []).find(x => x.keys === n)
                return b ? (b.what || "another key") : null
            }
            width: Math.min(560, parent.width - 48)
            height: col.implicitHeight + 48
            anchors.centerIn: parent
            radius: M3.rXL
            color: M3.surfaceHigh
            MouseArea { anchors.fill: parent }
            Column {
                id: col
                x: 24; y: 24
                width: parent.width - 48
                spacing: 16
                T { text: I18n.t("Change the keys"); kind: "title"; font.pixelSize: 22 }
                T { text: page.editing ? page.editing[1] : ""; color: M3.inkDim; width: parent.width; wrapMode: Text.WordWrap }
                // the keys to hold
                Row {
                    spacing: 8
                    Repeater {
                        model: ["Super", "Ctrl", "Alt", "Shift"]
                        Rectangle {
                            readonly property bool on: !!ed.mods[modelData]
                            width: ml.implicitWidth + (on ? 40 : 28); height: 36; radius: on ? 18 : 10
                            color: on ? M3.primary : M3.surfaceHighest
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Row { anchors.centerIn: parent; spacing: 6
                                Icon { visible: parent.parent.on; name: "check"; glyph: "\uf00c"; size: 14; color: M3.inkPrimary; anchors.verticalCenter: parent.verticalCenter }
                                T { id: ml; text: modelData; font.pixelSize: 13; font.weight: Font.Medium; color: parent.parent.on ? M3.inkPrimary : M3.ink; anchors.verticalCenter: parent.verticalCenter } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { const n = Object.assign({}, ed.mods); n[modelData] = !n[modelData]; ed.mods = n; cap.forceActiveFocus() } }
                        }
                    }
                }
                // press the key
                Rectangle {
                    id: cap
                    width: parent.width; height: 64; radius: M3.rL
                    color: activeFocus ? M3.alpha(M3.primary, 0.10) : M3.surfaceC
                    border.width: activeFocus ? 2 : 1; border.color: activeFocus ? M3.primary : M3.outlineVariant
                    focus: true
                    T { visible: !ed.key; anchors.centerIn: parent; text: I18n.t("Press a key (a letter, a number, F1 ... F12, Print ...)"); color: M3.inkDim; font.pixelSize: 13 }
                    Caps { visible: !!ed.key; anchors.centerIn: parent; keys: ed.human }
                    MouseArea { anchors.fill: parent; onClicked: cap.forceActiveFocus() }
                    Keys.onPressed: e => {
                        const named = { [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Space]: "Space", [Qt.Key_Tab]: "Tab",
                            [Qt.Key_Print]: "Print", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
                            [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
                            [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                            [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period",
                            [Qt.Key_Slash]: "slash", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_BracketLeft]: "bracketleft",
                            [Qt.Key_BracketRight]: "bracketright", [Qt.Key_Backslash]: "backslash", [Qt.Key_QuoteLeft]: "grave",
                            [Qt.Key_Apostrophe]: "apostrophe" }
                        let k = ""
                        if (e.key === Qt.Key_Escape) { page.editing = null; e.accepted = true; return }
                        if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) k = String.fromCharCode(e.key)
                        else if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) k = String.fromCharCode(e.key)
                        else if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24) k = "F" + (e.key - Qt.Key_F1 + 1)
                        else if (named[e.key]) k = named[e.key]
                        if (!k) return
                        const m = e.modifiers
                        if (m & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier))
                            ed.mods = { Super: !!(m & Qt.MetaModifier), Ctrl: !!(m & Qt.ControlModifier), Alt: !!(m & Qt.AltModifier), Shift: !!(m & Qt.ShiftModifier) }
                        ed.key = k
                        e.accepted = true
                    }
                }
                T {
                    width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12
                    visible: text !== ""
                    color: ed.plain || ed.clash ? M3.error : M3.inkDim
                    text: !ed.key ? "" : (ed.plain ? I18n.t("Add Super, Ctrl or Alt: a key alone would stop working in your apps.")
                         : (ed.clash ? I18n.t("Already used by") + ": " + ed.clash + ". " + I18n.t("Saving takes it over.") : I18n.t("Free to use.")))
                }
                Item {
                    width: parent.width; height: 40
                    Btn { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Default"); variant: "text"
                        visible: page.editing && page.changed(page.editing)
                        onClicked: { page.kmRun(["reset", page.editing[2]]); page.editing = null } }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Btn { text: I18n.t("Cancel"); variant: "text"; onClicked: page.editing = null }
                        Btn { text: I18n.t("Save"); variant: "filled"; enabled: !!ed.key && !ed.plain; opacity: enabled ? 1 : 0.5
                            onClicked: {
                                const id = page.editing[2], n = Object.assign({}, page.km), keys = Object.assign({}, n.keys)
                                keys[id] = { default: keys[id].default, now: ed.hypr }; n.keys = keys; page.km = n
                                page.kmRun(["set", id, ed.hypr]); page.editing = null
                            } }
                    }
                }
            }
        }
    }
}
