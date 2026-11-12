import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
FloatingWindow {
    id: win
    title: I18n.t("Rice Settings")
    // about half of a 1080p screen, a little bigger on bigger screens, never more than fits
    readonly property var scr0: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property int sw0: scr0 ? scr0.width : 1920
    readonly property int sh0: scr0 ? scr0.height : 1080
    implicitWidth: Prefs.winW(sw0, Prefs.size)
    implicitHeight: Prefs.winH(sh0, Prefs.size)
    // While the size changes the window is pinned to it for a moment (Hyprland keeps a floating window inside these limits)
    property bool pin: false
    minimumSize: pin ? Qt.size(implicitWidth, implicitHeight) : Qt.size(0, 0)
    maximumSize: pin ? Qt.size(implicitWidth, implicitHeight) : Qt.size(16384, 16384)
    // A floating window cannot resize itself on Wayland, only Hyprland can. rice-settings-size asks it and checks the result.
    property bool sizeAgain: false
    function applySize() {
        pin = true
        unpin.restart()
        if (sizer.running) sizeAgain = true; else sizer.running = true
    }
    Process {
        id: sizer
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-settings-size\" \"$1\" \"$2\" >/dev/null 2>&1 || true", "_", String(win.implicitWidth), String(win.implicitHeight)]
        onExited: if (win.sizeAgain) { win.sizeAgain = false; running = true }
    }
    Timer { id: unpin; interval: 1200; onTriggered: win.pin = false }
    Timer { interval: 600; running: true; onTriggered: win.applySize() }
    Timer { id: sizeSoon; interval: 120; onTriggered: win.applySize() }
    Connections { target: Prefs; function onSizeChanged() { sizeSoon.restart() } }
    color: "transparent"
    visible: true
    onVisibleChanged: if (!visible) Qt.quit()

    readonly property string home: Quickshell.env("HOME")
    // the tour is on: the rest of the screen goes dark (dimWin below)
    property bool tourOn: false
    function startTour() { page = 0; tour.start() }

    // falling stars across the whole window (Home: Falling stars)
    property bool stars: true
    function setStars(on) {
        stars = on
        Prefs.save("stars", on)
    }
    Process {
        command: ["bash", "-c", "cat \"$HOME/.config/rice/settings-app.json\" 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { win.stars = JSON.parse(text).stars !== false } catch (e) { } } }
    }
    // Auto-hide widgets (Home and Widgets): widgets rest while a tiled window covers the screen
    function setAutoHide(on) {
        const d = JSON.parse(JSON.stringify(win.dst)); d.autoHide = on; win.dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" auto-hide \"$1\"", "_", on ? "on" : "off"])
        status = "Auto-hide widgets " + (on ? "on" : "off")
    }
    function closeNow() { Qt.quit() }
    // pages are made when you go to them; the first search makes all of them (search looks inside every page)
    property bool searchWanted: false
    property string lastQuery: ""
    function pageLoaded() { searchIndex = []; if (lastQuery.trim() !== "") pageAgain.restart() }
    Timer { id: pageAgain; interval: 120; onTriggered: win.runSearch(win.lastQuery) }

    // ---------- search: every setting on every page, found by its name, its section, its page or its text ----------
    property var results: []
    property int searchSel: 0
    property var searchIndex: []
    Connections { target: I18n; function onLangChanged() { win.searchIndex = [] } }
    readonly property var synonyms: ({
        canvas: ["infinite"], zoom: ["infinite", "zoom"], endless: ["infinite"], infinity: ["infinite"],
        bar: ["waybar", "bar"], colour: ["color"], colors: ["color", "theme", "scheme"],
        transparent: ["opacity", "transparency"], transparency: ["opacity", "transparency"], seethrough: ["opacity"],
        round: ["rounding", "radius", "round"], corners: ["rounding", "corner"], lock: ["lock", "idle"],
        sound: ["sound", "sfx", "volume"], sounds: ["sound", "sfx"], sfx: ["sound", "sfx"], music: ["music", "welcome"],
        volume: ["volume", "sound"], mouse: ["cursor", "pointer"], pointer: ["cursor", "pointer"], font: ["font", "text"],
        fonts: ["font"], gap: ["gaps", "gap"], anim: ["animation"], animations: ["animation"], notification: ["notification", "popup"],
        popup: ["popup", "notification"], popups: ["popup", "notification"], keyboard: ["keybind", "bind", "key", "layout", "keyboard"],
        shortcut: ["keybind", "bind", "shortcut"], shortcuts: ["keybind", "bind"], screen: ["screen", "monitor", "display"],
        keybind: ["keybinds", "keys"], keybinds: ["keybinds", "keys"], hotkey: ["keybinds", "keys"], hotkeys: ["keybinds", "keys"],
        terminal: ["terminal", "shell"], kitty: ["terminal"], foot: ["terminal"], alacritty: ["terminal"], ghostty: ["terminal"],
        neofetch: ["fastfetch"], fetch: ["fastfetch"], zsh: ["shell"], bash: ["shell"], fish: ["shell"], prompt: ["shell"],
        monitor: ["monitor", "screen", "display"], dark: ["dark", "black", "theme"], wallpaper: ["wallpaper", "background"],
        background: ["background", "wallpaper"], top: ["top", "position"], bottom: ["bottom", "position"],
        place: ["position"], where: ["position"], size: ["size", "width", "height", "scale"], big: ["size", "scale"],
        speed: ["speed", "animation"], fast: ["speed"], slow: ["speed", "light", "performance"], lag: ["light", "performance"], laggy: ["light", "performance"], performance: ["light", "performance"], power: ["power", "battery"], wifi: ["wi-fi", "wifi", "network"],
        launcher: ["launcher", "apps"], rofi: ["launcher"], record: ["record", "recorder", "recording"], recording: ["record", "recorder"], video: ["record", "recorder", "video"], desktop: ["widgets", "widget"], widget: ["widgets", "widget"], hide: ["auto-hide", "hide"], apps: ["apps", "rofi", "dock"], game: ["gaming"], games: ["gaming"], layout: ["layout", "keyboard"], color: ["color", "role", "theme"], switch: ["switch", "icons"], slider: ["slider", "thickness"], wavy: ["wavy", "progress"], spring: ["spring", "motion"]
    })
    function buildIndex() {
        const out = []
        const slots = pagesHolder.children
        for (let i = 0; i < slots.length; i++) {
            const sl = slots[i]
            if (sl.idx === undefined) continue
            const pg = win.pages[sl.idx]
            if (!pg) continue
            out.push({ page: sl.idx, label: I18n.t(pg.name), section: "", desc: I18n.t("Page"), pageName: I18n.t(pg.name), item: null, kind: "page" })
            const ctx = { section: "" }
            const walk = function(it) {
                const kids = it.children || []
                for (let k = 0; k < kids.length; k++) {
                    const c = kids[k]
                    if (c.sub !== undefined && c.text !== undefined && c.topPadding !== undefined && typeof c.text === "string") {
                        ctx.section = c.text
                        if (c.text.length) out.push({ page: sl.idx, label: c.text, section: "", desc: c.sub || "", pageName: I18n.t(pg.name), item: c, kind: "section" })
                        continue
                    }
                    if (c.reserved !== undefined && c.label !== undefined && typeof c.label === "string" && c.label.length) {
                        out.push({ page: sl.idx, label: c.label, section: ctx.section, desc: c.desc || "", pageName: I18n.t(pg.name), item: c, kind: "row" })
                        continue
                    }
                    // a heading made with a plain title text: it names the section too
                    if (c.kind === "title" && typeof c.text === "string" && c.text.length > 1 && c.text.length < 40 && c.font && c.font.pixelSize >= 15) {
                        ctx.section = c.text
                        continue
                    }
                    // a setting with its own layout (like the clock fonts): its 14 px name counts too
                    if (c.kind === "body" && typeof c.text === "string" && c.font && c.font.pixelSize === 14 && !c.font.bold
                            && c.text.length > 2 && c.text.length < 40 && c.text.indexOf("<") < 0) {
                        out.push({ page: sl.idx, label: c.text, section: ctx.section, desc: "", pageName: I18n.t(pg.name), item: c.parent || c, kind: "row" })
                    }
                    walk(c)
                }
            }
            walk(sl)
        }
        // the same setting twice (a page that keeps two copies of a part): once is enough
        const seen = {}
        searchIndex = out.filter(e => { const k = e.page + "|" + e.label + "|" + e.section; if (seen[k]) return false; seen[k] = true; return true })
    }
    function runSearch(q) {
        lastQuery = q
        if (q.trim() !== "") searchWanted = true
        q = q.trim().toLowerCase()
        searchSel = 0
        if (!q.length) { results = []; return }
        if (!searchIndex.length) buildIndex()
        const toks = q.split(/\s+/).filter(t => t.length)
        const scored = []
        for (const e of searchIndex) {
            const L = e.label.toLowerCase(), S = e.section.toLowerCase(), P = e.pageName.toLowerCase(), D = e.desc.toLowerCase()
            let score = 0, ok = true
            for (const t of toks) {
                const alts = [t].concat(win.synonyms[t] || [])
                let best = 0
                for (const a of alts) {
                    const w = a === t ? 1 : 0.8
                    if (L.startsWith(a) || L.indexOf(" " + a) >= 0) best = Math.max(best, 7 * w)
                    else if (L.indexOf(a) >= 0) best = Math.max(best, 5 * w)
                    if (S.indexOf(a) >= 0) best = Math.max(best, 3 * w)
                    if (P.indexOf(a) >= 0) best = Math.max(best, 3 * w)
                    if (D.indexOf(a) >= 0) best = Math.max(best, 1.5 * w)
                }
                if (best === 0) { ok = false; break }
                score += best
            }
            if (!ok) continue
            if (e.kind === "page") score += 1
            if (L === q) score += 6
            scored.push({ e: e, s: score })
        }
        scored.sort((a, b) => (b.s - a.s) || (a.e.label.length - b.e.label.length))
        results = scored.slice(0, 40).map(x => x.e)
    }
    function openResult(r) {
        if (!r) return
        Sfx.play("select")
        searchIn.text = ""
        card.forceActiveFocus()
        page = r.page
        if (r.item) { jumpTo.target = r.item; jumpTo.restart() }
    }
    // after the page has changed: scroll to the setting and light it up for a moment
    Timer {
        id: jumpTo
        property var target: null
        interval: 380
        onTriggered: {
            const it = target
            if (!it) return
            let f = it.parent
            while (f && f.contentY === undefined) f = f.parent
            if (f) {
                const y = it.mapToItem(f.contentItem, 0, 0).y
                f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 30))
            }
            Qt.createQmlObject('import QtQuick; Rectangle { anchors.fill: parent; anchors.margins: -3; radius: (parent.radius !== undefined ? parent.radius : 8) + 3; color: "transparent"; border.width: 2; border.color: "#F6F5F4"; opacity: 0; z: 50;' +
                ' SequentialAnimation on opacity { running: true; NumberAnimation { to: 1; duration: 220 } PauseAnimation { duration: 500 } NumberAnimation { to: 0.35; duration: 260 } NumberAnimation { to: 1; duration: 260 } PauseAnimation { duration: 500 } NumberAnimation { to: 0; duration: 600 } ScriptAction { script: destroy() } } }', it, "searchFlash")
        }
    }
    readonly property string presetTool: home + "/.local/bin/waybar-preset"
    property int page: 0
    // rice-settings PAGE: open on that page (the Settings card of the dashboard uses it)
    Process {
        command: ["bash", "-c", "f=\"$HOME/.cache/rice/settings-page\"; if [ -f \"$f\" ]; then cat \"$f\"; rm -f \"$f\"; " +
                  "elif grep -q '\"state\": \"running\"' \"$HOME/.cache/rice/update-live.json\" 2>/dev/null; then echo 35; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                if (!isNaN(n) && n >= 0 && n < win.pages.length) win.page = n
            }
        }
    }
    property var presets: []
    property var st: ({})
    property string status: ""
    property string colorMode: "auto"
    property alias stateTimer: stateTimer
    property var dst: ({ widgets: {}, clock: {}, dock: {}, lock: {} })
    property string osName: "Linux"
    property var osIds: ["linux"]
    // distro logo from the Nerd Font "font logos" set (NixOS logo on NixOS, Arch logo on Arch, ...)
    readonly property var osGlyphs: ({
        nixos: "\uf313", arch: "\uf303", archarm: "\uf303", cachyos: "\uf385", endeavouros: "\uf322", manjaro: "\uf312",
        garuda: "\uf303", ubuntu: "\uf31b", fedora: "\uf30a", nobara: "\uf380", bazzite: "\uf30a", ultramarine: "\uf30a", debian: "\uf306", opensuse: "\uf314", gentoo: "\uf30d",
        void: "\uf32e", alpine: "\uf300", linuxmint: "\uf30e", pop: "\uf32a"
    })
    function osGlyph() {
        for (let i = 0; i < osIds.length; i++) if (osGlyphs[osIds[i]] !== undefined) return osGlyphs[osIds[i]]
        return "\uf17c"
    }
    readonly property string userName: Quickshell.env("USER")
    readonly property int railW: 92
    // rice-effects: blur and transparency are off right now
    property bool flat: false
    Process {
        id: flatProc
        command: ["bash", "-c", "[ -e \"$HOME/.cache/rice/flat\" ] && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: win.flat = text.trim() === "1" }
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: if (!flatProc.running) flatProc.running = true }

    function dset(group, key, value) {
        const d = JSON.parse(JSON.stringify(dst))
        if (group === "widget") {
            if (!d.widgets[key]) d.widgets[key] = {}
            d.widgets[key].enabled = (value === "on")
        } else {
            if (!d[group]) d[group] = {}
            d[group][key] = (value === "on" || value === "off") ? (value === "on") : value
        }
        dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" \"$@\"", "_", group, key, String(value)])
        status = "Applied"
        drefresh.restart()
    }

    // one setting of a widget: wset ID KEY VALUE (visualizer color, clock font, focus minutes)
    function dwset(id, key, value) {
        const d = JSON.parse(JSON.stringify(dst))
        if (id === "clock") { if (!d.clock) d.clock = {}; d.clock[key] = value }
        else { if (!d.widgets[id]) d.widgets[id] = {}; d.widgets[id][key] = value }
        dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" wset \"$1\" \"$2\" \"$3\"", "_", id, key, String(value)])
        status = "Applied"
        drefresh.restart()
    }
    // widget style: shadow (DarkShadow's Shell), google, outline
    function setWidgetTheme(v) {
        const d = JSON.parse(JSON.stringify(dst)); d.widgetTheme = v; dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" widgets-theme \"$1\"", "_", v])
        status = "Widget style: " + v
    }
    // dark or light text and cards by the wallpaper behind each widget
    function setWidgetAdapt(on) {
        const d = JSON.parse(JSON.stringify(dst)); d.widgetAdapt = on; dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" widgets-adapt \"$1\"", "_", on ? "on" : "off"])
        status = "Adaptive colors " + (on ? "on" : "off")
    }

    function dreset() {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" reset-pos"])
        status = "Widget positions reset"
        drefresh.restart()
    }

    Process {
        id: dstate
        command: ["bash", "-c", "\"$HOME/.local/bin/desktop-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { win.dst = JSON.parse(text) } catch (e) { } }
        }
    }
    Timer { id: drefresh; interval: 900; onTriggered: dstate.running = true }

    Process {
        id: osProc
        command: ["bash", "-c", ". /etc/os-release 2>/dev/null; printf '%s\\n%s\\n%s\\n' \"${NAME:-Linux}\" \"${ID:-linux}\" \"${ID_LIKE:-}\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("\n")
                if (p[0] && p[0].trim().length > 0) win.osName = p[0].trim()
                win.osIds = ((p[1] || "") + " " + (p[2] || "")).trim().toLowerCase().split(/\s+/)
            }
        }
    }

    // Hyprland or niri (the page of window settings is named after the one that runs)
    readonly property bool niri: !!Quickshell.env("NIRI_SOCKET")
    readonly property string wmLabel: niri ? "niri" : "Hyprland"
    readonly property var pages: [
        { name: "Home", icon: "\uf015" },
        { name: "Sfx & sounds", icon: "\uf028" },
        { name: "DarkShadow bar", icon: "\uf0c9" },
        { name: "Bar layout", icon: "\uf0db" },
        { name: wmLabel, icon: "\uf108" },
        { name: "Recorder", icon: "\uf03d" },
        { name: "Dynamic island", icon: "\uf017" },
        { name: "Launcher", icon: "\uf002" },
        { name: "Color theme", icon: "\udb80\udfd8" },
        { name: "Cursors", icon: "\uf245" },
        { name: "Notifications", icon: "\uf0f3" },
        { name: "Idle & Lockscreen", icon: "\uf023" },
        { name: "Widgets", icon: "\uf26c" },
        { name: "Hot corners", icon: "\udb82\ude0b" },
        { name: "Dock", icon: "\uf2d0" },
        { name: "Services", icon: "" },
        { name: "Gaming hub", icon: "\uf11b" },
        { name: "About", icon: "\uf05a" },
        { name: "Wallpaper", icon: "\uf03e" },
        { name: "Fonts", icon: "\uf031" },
        { name: "Motion", icon: "\uf1e6" },
        { name: "Colors", icon: "\uf53f" },
        { name: "Components", icon: "\uf1de" },
        { name: "Keyboard", icon: "\uf11c" },
        { name: "Shapes", icon: "\uf5fd" },
        { name: "Windows", icon: "\uf2d0" },
        { name: "Language & region", icon: "\uf1ab" },
        { name: "System", icon: "\uf108" },
        { name: "Monitors", icon: "\uf108" },
        { name: "Look & Feel", icon: "\uf120" },
        { name: "Keybinds", icon: "\uf11c" },
        { name: "Languages", icon: "\uf1ab" },
        { name: "Security", icon: "\uf132" },
        { name: "Infinite Desktop", icon: "\uf065" },
        { name: "Themes", icon: "\uf53f" },
        { name: "Update Center", icon: "\uf021" }
    ]


    // the sidebar: Home, then groups with an arrow (touch one to see its pages)
    readonly property var navTree: [
        { page: 0 },
        { sep: true },
        { group: "wall", name: "Wallpaper", icon: "\uf03e", sym: "wallpaper", pages: [18], caption: I18n.t("Wallpaper and the colors it gives") },
        { group: "look", name: "Appearance", icon: "\udb80\udfd8", sym: "palette", pages: [34, 8, 21, 19, 24, 22, 9, 14], caption: I18n.t("Themes, colors, fonts, shapes, components, cursors and the dock") },
        { group: "motion", name: "Motion", icon: "\uf1e6", sym: "animation", pages: [20], caption: I18n.t("How windows and Settings move") },
        { group: "desk", name: "Desktop", icon: "\uf108", sym: "desktop_windows", pages: niri ? [29, 12, 25, 4, 11] : [29, 33, 12, 25, 4, 11], caption: I18n.t("Look & feel, widgets, windows, %1 and the lock screen", wmLabel) },
        { group: "bar", name: "Bar & launcher", icon: "\uf0c9", sym: "toolbar", pages: [2, 3, 6, 7], caption: I18n.t("The bar, the dynamic island and the launcher") },
        { group: "snd", name: "Sound & language", icon: "\uf028", sym: "graphic_eq", pages: [1, 10, 26], caption: I18n.t("Sounds, notifications, language and region") },
        { group: "sys", name: "System", icon: "\uf013", sym: "settings", pages: [30, 31, 28, 5, 23, 15], caption: I18n.t("Keybinds, languages, monitors, recording, keyboard and services") },
        { group: "game", name: "Gaming", icon: "\uf11b", sym: "sports_esports", pages: [16], caption: I18n.t("Play without distractions") },
        { group: "about", name: "About", icon: "\uf05a", sym: "info", pages: [17], caption: I18n.t("Version, system and credits") },
        { group: "upd", name: "Update Center", icon: "\uf021", sym: "system_update_alt", pages: [35], caption: I18n.t("Get the newest version, right here") }
    ]
    // the navigation rail: Home, then one stop per group (Gaming hub and About are groups with one page)
    readonly property var rail: [{ gid: "", name: "Home", icon: "\uf015", sym: "home", pages: [0], caption: I18n.t("Your desktop at a glance") }]
        .concat(navTree.filter(function(n) { return n.group }).map(function(n) { return { gid: n.group, name: n.name, icon: n.icon, sym: n.sym, pages: n.pages, caption: n.caption } }))
    // the tour: where a group's stop on the rail is, and where an item is (in the window's card)
    function railRect(idx) {
        const i = railOf(idx)
        return { x: navFlick.x + 2, y: navFlick.y + i * 58 - navFlick.contentY, w: navFlick.width - 4, h: 58 }
    }
    function rectOf(item, pad) {
        const p = item.mapToItem(card, 0, 0), d = pad || 0
        return { x: p.x - d, y: p.y - d, w: item.width + 2 * d, h: item.height + 2 * d }
    }
    // the part of the screen the tour lights up outside this window (the Dynamic island)
    readonly property string tourSpot: tour.spot
    function railOf(idx) { for (let i = 0; i < rail.length; i++) if (rail[i].pages.indexOf(idx) >= 0) return i; return 0 }
    readonly property int curRailIdx: railOf(page)
    readonly property var curRail: rail[curRailIdx]
    property var lastIn: ({})
    function goRail(i) { const r = rail[i]; page = lastIn[i] !== undefined ? lastIn[i] : r.pages[0] }
    readonly property var navRows: {
        const out = []
        for (let i = 0; i < navTree.length; i++) {
            const n = navTree[i]
            if (n.sep) { out.push({ kind: "sep" }); continue }
            if (n.group) {
                out.push({ kind: "group", gid: n.group, name: n.name, icon: n.icon })
                for (let k = 0; k < n.pages.length; k++) out.push({ kind: "page", idx: n.pages[k], gid: n.group, child: true })
                continue
            }
            out.push({ kind: "page", idx: n.page, gid: "", child: false })
        }
        return out
    }
    readonly property var navGroups: navTree.filter(function(n) { return n.group }).map(function(n) { return n.group })
    property var navOpen: ({})
    function groupOf(idx) {
        for (let i = 0; i < navRows.length; i++) if (navRows[i].kind === "page" && navRows[i].idx === idx) return navRows[i].gid
        return ""
    }
    function toggleGroup(g) { const o = Object.assign({}, navOpen); o[g] = !(o[g] === true); navOpen = o }
    function openFor(idx) { const g = groupOf(idx); if (g !== "" && navOpen[g] !== true) { const o = Object.assign({}, navOpen); o[g] = true; navOpen = o } }
    // the row of a page; when its group is closed: the row of the group
    function navRowOf(idx) {
        let g = -1
        for (let i = 0; i < navRows.length; i++) {
            const r = navRows[i]
            if (r.kind === "page" && r.idx === idx) { if (navLayout.vis[i]) return i; g = r.gid; break }
        }
        if (g === -1) return -1
        for (let i = 0; i < navRows.length; i++) if (navRows[i].kind === "group" && navRows[i].gid === g) return i
        return -1
    }
    readonly property var navLayout: {
        const ys = [], hs = [], vis = [], gbg = {}
        let y = 0
        for (let i = 0; i < navRows.length; i++) {
            const r = navRows[i]
            if (r.kind === "sep") { ys.push(y + 4); hs.push(10); vis.push(true); y += 18; continue }
            if (r.kind === "page" && r.child) {
                if (navOpen[r.gid] !== true) { ys.push(y); hs.push(38); vis.push(false); continue }
                if (!gbg[r.gid]) gbg[r.gid] = { y: y, h: 0 }
                ys.push(y); hs.push(38); vis.push(true)
                gbg[r.gid].h += 40
                y += 40
                continue
            }
            ys.push(y); hs.push(44); vis.push(true)
            y += 48
            // a little air under an open group
            if (r.kind === "group" && navOpen[r.gid] === true) y += 3
        }
        return { ys: ys, hs: hs, vis: vis, gbg: gbg, total: y }
    }
    // where the next page comes from (Material 3 shared axis): tabs of one group slide sideways,
    // another group comes up or down like the rail
    property int prevPage: 0
    property int navX: 0
    property int navY: 0
    function navFrom(a, b) {
        const ra = railOf(a), rb = railOf(b)
        if (ra === rb) {
            const l = rail[ra].pages
            navX = l.indexOf(b) >= l.indexOf(a) ? 1 : -1; navY = 0
        } else { navX = 0; navY = rb >= ra ? 1 : -1 }
    }
    onPageChanged: { navFrom(prevPage, page); prevPage = page; openFor(page); const n = Object.assign({}, lastIn); n[railOf(page)] = page; lastIn = n }
    Component.onCompleted: openFor(page)

    readonly property string hyprTool: home + "/.local/bin/hypr-set"
    property var hv: ({})
    property var hb: ({ mode: "wallpaper", active: "#F6F5F4", inactive: "#444444" })
    property var ha: ({ enabled: true, speed: 100 })
    property int hShadowInt: 60

    function hrun(args, msg) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/hypr-set\" \"$@\"", "_"].concat(args.map(a => String(a))))
        if (msg) status = msg
        hrefresh.restart()
    }

    function hset(key, value) {
        const v = Object.assign({}, hv)
        v[key] = value
        hv = v
        hrun(["set", key, String(value)], "Applied")
    }

    function setBorderMode(m) {
        const b = Object.assign({}, hb)
        b.mode = m
        hb = b
        hrun(["border-mode", m], "Borders: " + m)
    }

    function setBorderColor(which, hex) {
        const b = Object.assign({}, hb)
        b[which] = hex
        hb = b
        hrun(["border-color", which, hex], "Border color set")
    }

    function setAnimStyle(v) {
        const a = Object.assign({}, ha); a.style = v; ha = a
        hrun(["anim-style", v], "Motion: " + v)
    }
    function setAnim(k, v) {
        const a = Object.assign({}, ha)
        a[k] = v
        ha = a
        hrun([k === "enabled" ? "anim-enabled" : "anim-speed", k === "enabled" ? (v ? "on" : "off") : v], "Applied")
    }

    function setSt(key, value) {
        const s = Object.assign({}, st)
        s[key] = value
        st = s
    }

    function run(args) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/waybar-set\" \"$@\" && \"$HOME/.local/bin/waybar-reload\"", "_"].concat(args.map(a => String(a))))
        status = "Applied"
        stateTimer.restart()
    }

    function toggleModule(name, on) {
        setSt(name, on)
        run(["toggle", name, on ? "on" : "off"])
    }

    function setColorMode(m) {
        colorMode = m
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-colors\" mode \"$1\"", "_", m])
        let nm = m
        for (let i = 0; i < schemes.length; i++) if (schemes[i].key === m) nm = schemes[i].name
        status = "Colors: " + nm + " (applying...)"
    }

    Process {
        id: lister
        command: ["bash", "-c", "ls -1 \"$HOME/.config/waybar-presets\" 2>/dev/null | grep -v '^_'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: win.presets = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
        }
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/waybar-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { win.st = JSON.parse(text) } catch (e) { } }
        }
    }

    property var schemes: []
    Process {
        id: schemeProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-colors\" list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { win.schemes = JSON.parse(text) } catch (e) { } }
        }
    }

    Process {
        id: modeProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-colors\" get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { const m = text.trim(); if (m.length > 0) win.colorMode = m }
        }
    }

    Process {
        id: hstate
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    if (j.opts) win.hv = j.opts
                    if (j.borders) win.hb = j.borders
                    if (j.anim) win.ha = j.anim
                    if (j.shadow_int !== undefined) win.hShadowInt = j.shadow_int
                } catch (e) { }
            }
        }
    }

    Timer { id: hrefresh; interval: 800; onTriggered: hstate.running = true }

    Timer {
        id: stateTimer
        interval: 900
        onTriggered: { lister.running = true; stateProc.running = true }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        // solid while blur and transparency are off (Settings > Services, or gaming mode); the stars stay
        // see-through enough that the blur behind it shows (Hyprland: its window blur; niri: a window rule)
        color: win.flat ? M3.surface : M3.alpha(M3.surface, 0.8)
        Behavior on color { ColorAnimation { duration: 300 } }
        focus: true
        Keys.onEscapePressed: win.closeNow()
        // opening: fades in and settles from a touch smaller (Material 3 emphasized-decelerate)
        NumberAnimation on opacity { from: 0; to: 1; duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
        NumberAnimation on scale { from: 0.965; to: 1; duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }

        // falling stars over the whole window, behind everything (they stay put while the pages change)
        StarField {
            anchors.fill: parent
            count: 20
            readonly property bool on: win.stars
            running: win.visible && on
            opacity: on ? (win.page === 0 ? 1 : 0.55) : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        // ================= navigation rail =================
        // one stop per group; the pages of a group are tabs under the title
        Rectangle {
            id: railBg
            x: 0; y: 0
            width: win.railW
            height: parent.height
            color: win.flat ? M3.surfaceLow : M3.alpha(M3.surfaceLow, 0.72)
        }

        // you: your picture (click: Home, right click: change it)
        Item {
            id: profile
            x: (win.railW - width) / 2
            y: 18
            width: 52
            height: 52
            // your shape (Appearance > Shapes), turning slowly behind your letter
            Blob {
                anchors.fill: parent
                kind: Prefs.accentShape
                color: M3.primaryContainer
                RotationAnimator on rotation { from: 0; to: 360; duration: 40000; loops: Animation.Infinite; running: win.visible }
            }
            T { anchors.centerIn: parent; text: win.userName.length ? win.userName[0].toUpperCase() : "?"; font.pixelSize: 20; font.bold: true; color: M3.inkPrimaryC }
            RoundImage {
                id: avImg
                anchors.fill: parent
                source: "file://" + win.home + "/.face"
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.5)
                opacity: avm.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                T { anchors.centerIn: parent; kind: "icon"; text: ""; font.pixelSize: 15 }
            }
            scale: avm.pressed ? 0.94 : (avm.containsMouse ? 1.05 : 1)
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            MouseArea {
                id: avm
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: faceBox.show()
            }
        }
        Timer { id: faceReload; interval: 400; onTriggered: { avImg.source = ""; avImg.source = "file://" + win.home + "/.face" } }

        Flickable {
            id: navFlick
            x: 0
            y: 90
            width: win.railW
            height: parent.height - 90 - 12
            contentWidth: width
            contentHeight: railCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: railCol
                width: win.railW
                spacing: 2
                Repeater {
                    model: win.rail
                    delegate: Item {
                        id: ri
                        readonly property bool on: win.curRailIdx === index
                        width: win.railW
                        height: 56
                        // the indicator: a pill that grows out of the middle
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            width: ri.on ? 56 : (rim.containsMouse ? 56 : 24)
                            height: 32
                            radius: 16
                            color: ri.on ? M3.secondaryContainer : M3.surfaceHigh
                            opacity: ri.on || rim.containsMouse ? 1 : 0
                            Behavior on width { NumberAnimation { duration: M3.d(M3.bouncy ? 420 : 320); easing.type: M3.bouncy ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.5 * Prefs.bounce } }
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4; height: 32
                            name: modelData.sym
                            glyph: modelData.icon
                            size: 19
                            filled: ri.on
                            color: ri.on ? M3.inkSecondaryC : M3.inkDim
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        T {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 38
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: I18n.lang === "en" && modelData.name === "Bar & launcher" ? I18n.t("Bar") : I18n.t(modelData.name)
                            font.pixelSize: 11
                            font.weight: ri.on ? Font.DemiBold : Font.Medium
                            color: ri.on ? M3.ink : M3.inkDim
                        }
                        MouseArea { id: rim; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.goRail(index) }
                    }
                }
            }
        }

        // ================= header: where you are, search, close =================
        T {
            id: overline
            x: win.railW + 28
            y: 20
            text: (I18n.t("DarkShadow's Shell  ·  ") + win.curRail.caption).toUpperCase()
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
            color: M3.primary
            width: Math.max(80, searchBox.x - x - 20)
            elide: Text.ElideRight
        }
        T {
            id: pageTitle
            kind: "title"
            x: win.railW + 26
            y: 38
            text: win.pages[win.page] ? I18n.t(win.pages[win.page].name) : ""
            font.pixelSize: 30
            font.weight: Font.Medium
            width: Math.max(80, searchBox.x - x - 20)
            elide: Text.ElideRight
        }

        Rectangle {
            id: closeBtn
            width: 40
            height: 40
            radius: 20
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 22
            color: closeMouse.containsMouse ? M3.surfaceHighest : M3.surfaceHigh
            Behavior on color { ColorAnimation { duration: 140 } }
            Icon { anchors.centerIn: parent; name: "close"; glyph: "\u00d7"; size: 19; color: M3.ink }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.closeNow()
            }
        }

        // ---------- search anything (a search bar; results drop down under it) ----------
        Rectangle {
            id: searchBox
            anchors.right: closeBtn.left
            anchors.rightMargin: 10
            y: 22
            width: Math.min(280, Math.max(170, parent.width * 0.27))
            height: 40
            radius: 20
            color: searchIn.activeFocus ? M3.surfaceHighest : M3.surfaceHigh
            Behavior on color { ColorAnimation { duration: 160 } }
            Icon { name: "search"; glyph: "\uf002"; size: 17; x: 12; anchors.verticalCenter: parent.verticalCenter; color: searchIn.activeFocus ? M3.primary : M3.inkDim }
            TextInput {
                id: searchIn
                objectName: "searchIn"
                x: 42; width: parent.width - 74
                anchors.verticalCenter: parent.verticalCenter
                color: M3.ink
                font.family: Fonts.family("body")
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: { if (activeFocus) Sfx.play("type"); win.runSearch(text) }
                Keys.onDownPressed: win.searchSel = Math.min(win.searchSel + 1, win.results.length - 1)
                Keys.onUpPressed: win.searchSel = Math.max(0, win.searchSel - 1)
                Keys.onReturnPressed: win.openResult(win.results[win.searchSel])
                Keys.onEnterPressed: win.openResult(win.results[win.searchSel])
                Keys.onEscapePressed: { text = ""; card.forceActiveFocus() }
            }
            T {
                x: 42; anchors.verticalCenter: parent.verticalCenter
                visible: searchIn.text.length === 0
                text: I18n.t("Search settings")
                color: M3.inkDim; font.pixelSize: 13
            }
            Rectangle {
                visible: searchIn.text.length > 0
                width: 24; height: 24; radius: 12
                anchors.right: parent.right; anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                color: clrM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                T { anchors.centerIn: parent; text: "×"; font.pixelSize: 15; color: M3.inkDim }
                MouseArea { id: clrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: searchIn.text = "" }
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: searchIn.forceActiveFocus() }
        }

        // ================= tabs: the pages of this group =================
        Item {
            id: tabs
            readonly property var list: win.curRail.pages
            visible: list.length > 1
            x: win.railW + 20
            y: 84
            width: parent.width - x - 20
            height: visible ? 46 : 0
            Row {
                id: tabRow
                x: 6
                height: 44
                spacing: 4
                Repeater {
                    model: tabs.list
                    delegate: Item {
                        id: tb
                        readonly property bool on: win.page === modelData
                        width: tbt.implicitWidth + 28
                        height: 44
                        Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 12; color: tbm.containsMouse && !tb.on ? M3.surfaceHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } } }
                        T {
                            id: tbt
                            anchors.centerIn: parent
                            text: I18n.t(win.pages[modelData].name)
                            font.pixelSize: 14
                            font.weight: tb.on ? Font.DemiBold : Font.Medium
                            color: tb.on ? M3.primary : M3.inkDim
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        MouseArea { id: tbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = modelData }
                    }
                }
            }
            // the line under the open tab slides to it
            Rectangle {
                readonly property var it: {
                    const k = tabs.list.indexOf(win.page)
                    return k >= 0 && k < tabRow.children.length ? tabRow.children[k] : null
                }
                x: tabRow.x + (it ? it.x + 14 : 0)
                width: it ? it.width - 28 : 0
                y: 41
                height: 3
                radius: 1.5
                color: M3.primary
                Behavior on x { NumberAnimation { duration: M3.d(M3.bouncy ? 420 : 320); easing.type: M3.bouncy ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.2 * Prefs.bounce } }
                Behavior on width { NumberAnimation { duration: M3.d(M3.bouncy ? 420 : 320); easing.type: M3.bouncy ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.2 * Prefs.bounce } }
            }
            Rectangle { x: 0; y: 44; width: parent.width; height: 1; color: M3.outlineVariant }
        }

        Item {
            id: pagesHolder
            x: win.railW + 4
            y: tabs.visible ? 136 : 92
            width: parent.width - x
            height: parent.height - y
            clip: true


            PageSlot { nav: win; idx: 0; cur: win.page; HomePage { id: homePage; anchors.fill: parent; ctl: win } }
            PageSlot { nav: win; idx: 1; cur: win.page; page: Component { SoundsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 2; cur: win.page; page: Component { BarPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 3; cur: win.page; page: Component { BarLayoutPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 4; cur: win.page; page: Component { HyprlandPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 5; cur: win.page; page: Component { RecorderPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 6; cur: win.page; page: Component { IslandPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 7; cur: win.page; page: Component { RofiPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 8; cur: win.page; page: Component { ThemePage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 9; cur: win.page; page: Component { CursorsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 10; cur: win.page; page: Component { NotificationsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 11; cur: win.page; page: Component { IdlePage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 12; cur: win.page; page: Component { DesktopPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 14; cur: win.page; page: Component { InterfacePage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 15; cur: win.page; page: Component { ServicesPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 16; cur: win.page; page: Component { GamingPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 17; cur: win.page; page: Component { AboutPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 18; cur: win.page; page: Component { WallpaperPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 19; cur: win.page; page: Component { FontsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 20; cur: win.page; page: Component { MotionPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 21; cur: win.page; page: Component { ColorsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 22; cur: win.page; page: Component { ComponentsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 23; cur: win.page; page: Component { KeyboardPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 24; cur: win.page; page: Component { ShapesPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 25; cur: win.page; page: Component { WindowsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 26; cur: win.page; page: Component { RegionPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 27; cur: win.page; page: Component { SystemPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 28; cur: win.page; page: Component { ScreenPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 29; cur: win.page; page: Component { LookFeelPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 30; cur: win.page; page: Component { KeybindsPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 31; cur: win.page; page: Component { LanguagesPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 33; cur: win.page; page: Component { InfinitePage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 34; cur: win.page; page: Component { ThemesPage { anchors.fill: parent; ctl: win } } }
            PageSlot { nav: win; idx: 35; cur: win.page; page: Component { UpdatePage { anchors.fill: parent; ctl: win } } }
        }

        // results: the setting, and where it is (page > section)
        Rectangle {
            id: resultBox
            visible: searchIn.text.length > 0
            z: 50
            x: searchBox.x + searchBox.width - width
            y: searchBox.y + searchBox.height + 8
            width: 380
            height: Math.min(parent.height - y - 20, Math.max(64, resultList.contentHeight + 16))
            radius: M3.rL
            color: M3.surfaceHigh
            border.width: 1
            border.color: M3.outlineVariant
        ListView {
            id: resultList
            x: 8; y: 8
            width: parent.width - 16
            height: parent.height - 16
            clip: true
            model: win.results
            currentIndex: win.searchSel
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                width: resultList.width
                height: 50
                radius: 11
                color: index === win.searchSel ? Qt.rgba(1, 1, 1, 0.09) : (rm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Column {
                    x: 12; width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: modelData.label; font.pixelSize: 13; font.bold: index === win.searchSel; width: parent.width; elide: Text.ElideRight }
                    T {
                        text: modelData.kind === "page" ? I18n.t("Page") : (modelData.pageName + (modelData.section && modelData.section !== modelData.label ? I18n.t("  \u203a  ") + modelData.section : ""))
                        font.pixelSize: 11; color: M3.inkDim; width: parent.width; elide: Text.ElideRight
                    }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: win.searchSel = index; onClicked: win.openResult(modelData) }
            }
            T {
                visible: win.results.length === 0
                y: 14; x: 8; width: parent.width - 16
                text: I18n.t("Nothing found. Try other words, like \"blur\" or \"bar position\".")
                wrapMode: Text.WordWrap
                font.pixelSize: 12; color: M3.inkDim
            }
        }
        }


        // ---------- your profile picture (click it in the sidebar) ----------
        FacePicker { id: faceBox; onChanged: faceReload.restart() }

        // ---------- the tour (after the welcome intro, or rice-welcome tour) ----------
        Tour {
            id: tour
            objectName: "tour"
            onFinished: { card.forceActiveFocus(); win.tourOn = false }
            onActiveChanged: if (active) win.tourOn = true
            nav: win
            steps: [
                { title: I18n.t("Welcome to DarkShadow's Shell"), art: "welcome", icon: "waving_hand", page: 0,
                  body: "A one-minute tour: where things are on your desktop and in Settings. Enter or the arrow keys move on, Esc ends it." },
                { title: I18n.t("The Dynamic island"), art: "island", spot: "island", icon: "smart_display",
                  body: "The pill in the middle of your bar. It shows the time and the weather, and grows for music, the volume, workspace changes, recordings and notifications." },
                { title: I18n.t("Click the island for more"), art: "islandCard", spot: "island", icon: "touch_app",
                  body: "A left click opens Today (calendar and weather), a right click System (CPU, GPU and memory, live). About and Music are tabs inside. Scroll over the island to change the volume." },
                { title: I18n.t("Find anything"), r: 15, icon: "search",
                  body: "Type what you want to change, like \"blur\", \"bar position\" or \"terminal\", and jump right to it.",
                  rect: function() { return { x: searchBox.x - 5, y: searchBox.y - 5, w: searchBox.width + 10, h: searchBox.height + 10 } } },
                { title: I18n.t("Every part has a place"), r: 18, icon: "menu",
                  body: "Wallpaper, Appearance, Motion, Desktop, Bar, Sound, System, Gaming and About. Each one has a few tabs at the top.",
                  rect: function() { return { x: navFlick.x - 6, y: navFlick.y - 6, w: navFlick.width + 12, h: Math.min(navFlick.height, railCol.height) + 12 } } },
                { title: I18n.t("Bar & launcher"), page: 2, r: 14, icon: "toolbar",
                  body: "The bar's look and place, its modules, the Dynamic island's own settings (what it shows, what a click opens) and the app launcher (" + (win.niri ? "Super + D" : "Super + R") + ").",
                  rect: function() { return win.railRect(2) } },
                { title: I18n.t("Wallpaper and colors"), page: 18, r: 14, icon: "wallpaper",
                  body: "Super + W picks a wallpaper, and the colors of everything follow it. Appearance has the theme, fonts, shapes and cursors.",
                  rect: function() { return win.railRect(18) } },
                { title: I18n.t("Desktop: Look & Feel and widgets"), page: 29, r: 14, icon: "desktop_windows",
                  body: "Look & Feel: your terminal, shell and fastfetch. Widgets: a clock, weather, music and more on the desktop (Super + Alt + W moves them). Windows: gaps, borders, corners.",
                  rect: function() { return win.railRect(29) } },
                { title: I18n.t("Every key in one place"), page: 30, r: 20, icon: "keyboard", art: "keys",
                  body: "System > Keybinds lists all the keys, in groups, with a search. Start with these three. Super is the key with the Windows logo.",
                  rect: function() { return win.rectOf(pagesHolder, 4) } },
                { title: I18n.t("Gaming"), page: 16, r: 14, icon: "sports_esports",
                  body: "One switch for games: no animations, blur or gaps while you play, and the game bar (Super + G).",
                  rect: function() { return win.railRect(16) } },
                { title: I18n.t("This is you"), page: 0, r: 22, icon: "account_circle",
                  body: "Click your picture to change it, it shows on the lock screen too.",
                  rect: function() { return { x: profile.x - 5, y: profile.y - 5, w: profile.width + 10, h: profile.height + 10 } } },
                { title: I18n.t("That's it!"), r: 20, icon: "celebration",
                  body: "Open Settings any time with Super + U. The tour is in System > Keybinds (Show me around). Have fun with your desktop.",
                  rect: function() { return { x: closeBtn.x - 6, y: closeBtn.y - 6, w: closeBtn.width + 12, h: closeBtn.height + 12 } } }
            ]
        }
        Process {
            // the welcome intro leaves this file behind when it opens Settings
            id: tourCheck
            running: true
            command: ["bash", "-c", "f=\"$HOME/.cache/rice/settings-tour\"; [ -e \"$f\" ] && rm -f \"$f\" && echo 1 || echo 0"]
            stdout: StdioCollector { onStreamFinished: if (text.trim() === "1") tourDelay.start() }
        }
        Timer { id: tourDelay; interval: 650; onTriggered: { win.page = 0; tour.start() } }

        // the click sound for everything clickable in Settings (Sfx & sounds)
        SfxTap {}

        T {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 24
            text: win.status
            color: M3.inkDim
            font.pixelSize: 12
        }
    }
}

// ---------- during the tour: the whole screen goes dark (wallpaper, Waybar, widgets), only Settings stays lit ----------
PanelWindow {
    id: dimWin
    readonly property bool want: win.tourOn
    // where the Settings window is on this monitor (hyprctl), plus a little room for its border
    property real hx: 0
    property real hy: 0
    property real hw: 0
    property real hh: 0
    property real k: 0
    visible: k > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-tour-dim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // clicks on the dark part go nowhere, clicks on Settings go to Settings
    mask: Region { item: dimAll; Region { item: dimHole; intersection: Intersection.Subtract } }
    Item { id: dimAll; anchors.fill: parent }
    Item { id: dimHole; x: dimWin.hx; y: dimWin.hy; width: dimWin.hw; height: dimWin.hh }

    onWantChanged: { dimK.to = want ? 1 : 0; dimK.restart(); if (want) dimWhere.running = true }
    NumberAnimation { id: dimK; target: dimWin; property: "k"; duration: 420; easing.type: Easing.OutCubic }
    Process {
        id: dimWhere
        // "MONITOR x y w h" of the Settings window (Hyprland or niri), relative to its monitor
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-wm\" window 'Rice Settings'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const w = text.trim().split(" ")
                if (w.length < 5) return
                for (let j = 0; j < Quickshell.screens.length; j++)
                    if (Quickshell.screens[j].name === w[0]) dimWin.screen = Quickshell.screens[j]
                dimWin.hx = Number(w[1]) - 3; dimWin.hy = Number(w[2]) - 3
                dimWin.hw = Number(w[3]) + 6; dimWin.hh = Number(w[4]) + 6
            }
        }
    }
    // follow the window if it is moved during the tour
    Timer { interval: 500; repeat: true; running: dimWin.want; onTriggered: if (!dimWhere.running) dimWhere.running = true }

    // the tour can light the Dynamic island too (in the middle of the bar, at the top or the bottom)
    property var bar: ({})
    readonly property bool spotOn: win.tourSpot === "island"
    property real sk: 0
    Behavior on sk { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    onSpotOnChanged: { sk = spotOn ? 1 : 0; if (spotOn) barProc.running = true }
    Process {
        id: barProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-bar\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { dimWin.bar = JSON.parse(text) } catch (e) { } } }
    }
    readonly property real iw: 460 * sk
    readonly property real ih: ((bar.height ? bar.height : 38) + 26) * sk
    readonly property real ix: (width - iw) / 2
    readonly property real iy: bar.position === "bottom" ? height - ih - 4 : 4
    onIwChanged: shade.requestPaint()
    onHxChanged: shade.requestPaint()
    onHyChanged: shade.requestPaint()
    onHwChanged: shade.requestPaint()
    onHhChanged: shade.requestPaint()

    Canvas {
        id: shade
        anchors.fill: parent
        opacity: dimWin.k
        function hole(c, x, y, w, h, r) {
            if (w <= 0 || h <= 0) return
            r = Math.min(r, w / 2, h / 2)
            c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r)
            c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath()
        }
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.fillStyle = Qt.rgba(0, 0, 0, 0.88)
            c.fillRule = Qt.OddEvenFill
            c.beginPath()
            c.rect(0, 0, width, height)
            hole(c, dimWin.hx, dimWin.hy, dimWin.hw, dimWin.hh, 14)
            hole(c, dimWin.ix, dimWin.iy, dimWin.iw, dimWin.ih, dimWin.ih / 2)
            c.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    // the island's outline, in your key color
    Rectangle {
        visible: dimWin.sk > 0.02
        property real pulse: 1
        opacity: dimWin.k * dimWin.sk * pulse
        x: dimWin.ix - 4; y: dimWin.iy - 4; width: dimWin.iw + 8; height: dimWin.ih + 8
        radius: height / 2
        color: "transparent"
        border.width: 3
        border.color: M3.primary
        SequentialAnimation on pulse {
            running: dimWin.spotOn; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.45; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.45; to: 1; duration: 1200; easing.type: Easing.InOutSine }
        }
    }
}
}
