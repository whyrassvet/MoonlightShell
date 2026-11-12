import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Wallpaper: the wallpaper you have, the colors it gives the shell, and all your wallpapers to pick from.
// The slideshow, live (video) wallpapers and the folders they come from (yours, Waypaper's): rice-walls.
Item {
    id: page
    property var ctl
    property var w: ({ dir: "", current: "", still: "", walls: [] })
    property var st: ({ dirs: [], folders: [], waypaper: true, waypaper_found: false, waypaper_hook: false,
                        slideshow: { on: false, minutes: 30, order: "shuffle", folder: "" }, live: { sound: false, now: "" }, have: {} })
    Process {
        id: stProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-walls\" state 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: rw
        property string msg: ""
        onExited: function(code) { if (page.ctl) page.ctl.status = code === 0 ? rw.msg : I18n.t("That did not work"); stProc.running = true; wallsProc.running = true }
    }
    // rice-walls ARGS, then everything is read again
    function walls(args, msg) {
        if (rw.running) return
        rw.msg = msg || ""
        rw.command = ["bash", "-c", "\"$HOME/.local/bin/rice-walls\" \"$@\"", "_"].concat(args)
        rw.running = true
    }
    function patch(k, v) { const n = Object.assign({}, st); const o = Object.assign({}, st.slideshow); o[k] = v; n.slideshow = o; st = n }
    // the folder picker (zenity), then the folder is added
    Process {
        id: pick
        stdout: StdioCollector { onStreamFinished: { const d = text.trim(); if (d) page.walls(["folder", "add", d], I18n.t("Folder added")) } }
    }
    function home(p) { return (p || "").replace(Quickshell.env("HOME"), "~") }
    readonly property bool liveOn: (st.live && st.live.now) ? true : false
    Process {
        id: wallsProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-walls\" list 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.w = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: again; interval: 2500; onTriggered: wallsProc.running = true }
    onVisibleChanged: if (visible) { wallsProc.running = true; stProc.running = true }
    function setWall(p) {
        const n = Object.assign({}, w); n.current = p; w = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" wall \"$1\"", "_", p])
        page.ctl.status = I18n.t("Wallpaper set, colors follow in a moment")
        again.restart()
        stAgain.restart()
    }
    Timer { id: stAgain; interval: 3000; onTriggered: stProc.running = true }
    function randomWall() { const l = (w.walls || []).filter(function(x) { return !x.live }); if (l.length) setWall(l[Math.floor(Math.random() * l.length)].path) }
    function themeName() {
        const l = page.ctl ? page.ctl.schemes || [] : []
        for (let i = 0; i < l.length; i++) if (l[i].key === page.ctl.colorMode) return l[i].name
        return page.ctl ? page.ctl.colorMode : ""
    }

    PageScroll {
        anchors.fill: parent

        // ---------- what you have now ----------
        Rectangle {
            id: now
            width: parent.width
            height: Math.max(230, Math.min(300, width * 0.32))
            radius: M3.rXL
            color: M3.surfaceC
            Rectangle {
                id: frame
                x: 12; y: 12
                width: Math.min(parent.width * 0.56, (parent.height - 24) * 16 / 9)
                height: parent.height - 24
                radius: M3.rL
                color: M3.surfaceHigh
                RoundImage {
                    anchors.fill: parent
                    cornerRadius: M3.rL
                    fallback: ""
                    res: 1280
                    source: (page.w.still || page.w.current) ? "file://" + (page.liveOn ? page.w.still : (page.w.current || page.w.still)) : ""
                }
                Rectangle {
                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                    width: nt.implicitWidth + 20; height: 26; radius: 13
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: page.w.current !== ""
                    T { id: nt; anchors.centerIn: parent; text: (page.w.current || "").split("/").pop(); font.pixelSize: 11; color: "#ffffff"
                        width: Math.min(implicitWidth, frame.width - 40); elide: Text.ElideMiddle }
                }
            }
            Column {
                x: frame.x + frame.width + 20
                y: 18
                width: parent.width - x - 18
                spacing: 10
                T { text: I18n.t("COLORS FROM YOUR WALLPAPER"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.1; color: M3.primary }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [M3.primary, M3.tertiary, M3.primaryContainer, M3.secondaryContainer, M3.surfaceHighest, M3.surfaceHigh, M3.surfaceC, M3.inkPrimaryC]
                        delegate: Rectangle { width: 30; height: 30; radius: 15; color: modelData; border.width: 1; border.color: M3.alpha("#ffffff", 0.08) }
                    }
                }
                Rectangle {
                    width: tn.implicitWidth + 26; height: 30; radius: 15; color: M3.secondaryContainer
                    T { id: tn; anchors.centerIn: parent; text: I18n.t("Theme · ") + page.themeName(); font.pixelSize: 12; color: M3.inkSecondaryC }
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Btn { text: I18n.t("Surprise me"); sym: "shuffle"; icon: ""; primary: true; onClicked: page.randomWall() }
                    Btn { text: I18n.t("Theme"); sym: "palette"; icon: ""; onClicked: page.ctl.page = 8 }
                    Btn { text: I18n.t("Folder"); sym: "folder_open"; icon: ""; onClicked: if (page.w.dir) Quickshell.execDetached(["xdg-open", page.w.dir]) }
                }
            }
            // a live wallpaper plays now
            Rectangle {
                visible: page.liveOn
                x: frame.x + 10; y: frame.y + 10
                width: lvn.implicitWidth + 30; height: 26; radius: 13; color: Qt.rgba(0, 0, 0, 0.6)
                Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: "#ff5a5a" }
                T { id: lvn; x: 23; anchors.verticalCenter: parent.verticalCenter; text: "LIVE"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffffff" }
            }
        }

        // ---------- all wallpapers ----------
        SectionTitle {
            text: I18n.t("Your wallpapers")
            sub: page.w.dir ? (page.w.walls.length + " " + I18n.t("in") + " " + ((page.w.dirs || []).length > 1 ? (page.w.dirs.length + " " + I18n.t("folders")) : page.home(page.w.dir)) + ". " + I18n.t("Click one to use it.")) : I18n.t("No wallpaper folder found (~/Pictures/Wallpapers).")
        }
        Grid {
            id: grid
            width: parent.width
            columns: width > 760 ? 4 : 3
            spacing: 10
            Repeater {
                model: page.w.walls || []
                delegate: Item {
                    id: wt
                    readonly property bool on: page.w.current === modelData.path
                    width: (grid.width - (grid.columns - 1) * 10) / grid.columns
                    height: width * 0.62
                    Rectangle {
                        anchors.fill: parent
                        radius: wm.pressed ? M3.rS : M3.rL
                        color: M3.surfaceHigh
                        border.width: wt.on ? 3 : 0
                        border.color: M3.primary
                        Behavior on radius { NumberAnimation { duration: M3.d(180) } }
                    }
                    RoundImage {
                        anchors.fill: parent
                        anchors.margins: wt.on ? 6 : 0
                        cornerRadius: wt.on ? M3.rM : M3.rL
                        res: 480
                        source: modelData.thumb ? "file://" + modelData.thumb : (modelData.live ? "" : "file://" + modelData.path)
                        scale: wm.containsMouse && !wt.on ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: M3.d(220); easing.type: Easing.OutCubic } }
                        Behavior on anchors.margins { NumberAnimation { duration: M3.d(220); easing.type: M3.springy; easing.overshoot: 1.6 * Prefs.bounce } }
                    }
                    Rectangle {
                        visible: wt.on
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                        width: 26; height: 26; radius: 13; color: M3.primary
                        Icon { anchors.centerIn: parent; name: "check"; glyph: ""; size: 15; color: M3.inkPrimary }
                    }
                    Icon { visible: modelData.live && !modelData.thumb; anchors.centerIn: parent; name: "movie"; glyph: ""; size: 28; color: M3.inkDim }
                    Rectangle {
                        visible: modelData.live === true
                        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
                        width: lvt.implicitWidth + 28; height: 22; radius: 11; color: Qt.rgba(0, 0, 0, 0.6)
                        Rectangle { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: "#ff5a5a" }
                        T { id: lvt; x: 21; anchors.verticalCenter: parent.verticalCenter; text: "LIVE"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                    }
                    MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setWall(modelData.path) }
                }
            }
        }
        // ---------- animation: how a new wallpaper comes in ----------
        SectionTitle { text: I18n.t("Animation"); sub: I18n.t("How a new wallpaper comes in. Ripple and Portal start where your pointer is (Hyprland; niri: the middle).") }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { k: "ripple", n: "Ripple", s: "radio_button_checked" }, { k: "wave", n: "Wave", s: "waves" },
                    { k: "wipe", n: "Wipe", s: "swipe_right" }, { k: "portal", n: "Portal", s: "trip_origin" },
                    { k: "fade", n: "Fade", s: "gradient" }, { k: "slide", n: "Slide", s: "view_carousel" },
                    { k: "pixel", n: "Dissolve", s: "grain" }, { k: "random", n: "Surprise me", s: "shuffle" },
                    { k: "none", n: "None", s: "block" }
                ]
                delegate: Rectangle {
                    id: tc
                    readonly property bool on: ((page.st.transition || {}).style || "ripple") === modelData.k
                    width: tcr.implicitWidth + 28; height: 40; radius: on ? 12 * M3.shapeK : 20 * M3.shapeK
                    color: on ? M3.secondaryContainer : (tcm.containsMouse ? M3.surfaceHigh : "transparent")
                    border.width: on ? 0 : 1; border.color: M3.outlineVariant
                    Behavior on radius { NumberAnimation { duration: 200 } }
                    Row { id: tcr; anchors.centerIn: parent; spacing: 7
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.s; glyph: ""; size: 17; color: tc.on ? M3.inkSecondaryC : M3.inkDim }
                        T { anchors.verticalCenter: parent.verticalCenter; text: I18n.t(modelData.n); font.pixelSize: 13; color: tc.on ? M3.inkSecondaryC : M3.ink } }
                    MouseArea { id: tcm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const n = Object.assign({}, page.st); n.transition = Object.assign({}, page.st.transition || {}, { style: modelData.k }); page.st = n
                            page.walls(["transition", modelData.k], I18n.t("Animation: ") + I18n.t(modelData.n))
                        } }
                }
            }
        }
        SliderRow {
            visible: ((page.st.transition || {}).style || "ripple") !== "none"
            label: I18n.t("Animation speed"); desc: I18n.t("Lower is faster")
            from: 0.4; to: 2.5; step: 0.1; decimals: 1; unit: "×"
            value: Number((page.st.transition || {}).speed || 1)
            onCommitted: function(x) { page.walls(["transition", "speed", x.toFixed(1)], I18n.t("Saved")) }
        }

            // ---------- slideshow ----------
        SectionTitle { text: I18n.t("Slideshow"); sub: I18n.t("A new wallpaper from your folders every few minutes. The colors follow each one.") }
        ToggleRow {
            label: I18n.t("Change the wallpaper by itself")
            desc: page.st.slideshow.on ? I18n.t("On: the next one comes in the time you chose below") : I18n.t("Off: the wallpaper stays until you pick another one")
            checked: page.st.slideshow.on === true
            onToggled: function(v) { page.patch("on", v); page.walls(["slideshow", v ? "on" : "off"], v ? I18n.t("Slideshow on") : I18n.t("Slideshow off")) }
        }
        SegRow {
            visible: page.st.slideshow.on === true
            label: I18n.t("Every")
            options: [{ label: I18n.t("5 min"), value: "5" }, { label: I18n.t("15 min"), value: "15" }, { label: I18n.t("30 min"), value: "30" }, { label: "1 h", value: "60" }, { label: "3 h", value: "180" }]
            current: String(page.st.slideshow.minutes)
            onChosen: function(v) { page.patch("minutes", Number(v)); page.walls(["slideshow", "minutes", v], I18n.t("Saved")) }
        }
        SegRow {
            visible: page.st.slideshow.on === true
            label: I18n.t("Order")
            options: [{ label: I18n.t("Shuffle"), value: "shuffle" }, { label: I18n.t("By name"), value: "name" }]
            current: page.st.slideshow.order || "shuffle"
            onChosen: function(v) { page.patch("order", v); page.walls(["slideshow", "order", v], I18n.t("Saved")) }
        }
        SettingRow {
            visible: page.st.slideshow.on === true && page.st.dirs.length > 1
            label: I18n.t("From")
            desc: page.st.slideshow.folder ? page.home(page.st.slideshow.folder) : I18n.t("All your folders")
            reserved: 200
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Change"); sym: "folder"; icon: ""
                onClicked: {
                    // all folders, then each folder in turn
                    const l = [""].concat(page.st.dirs.map(function(d) { return d.path }))
                    const i = l.indexOf(page.st.slideshow.folder || "")
                    const nx = l[(i + 1) % l.length]
                    page.patch("folder", nx); page.walls(["slideshow", "folder", nx], I18n.t("Saved"))
                } }
        }
        SettingRow {
            visible: page.st.slideshow.on === true
            label: I18n.t("Next wallpaper")
            desc: I18n.t("Skip to the next one now")
            reserved: 160
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Next"); sym: "skip_next"; icon: ""; primary: true
                onClicked: { page.walls(["next"], I18n.t("Next wallpaper")); again.restart() } }
        }

        // ---------- live wallpapers ----------
        SectionTitle { text: I18n.t("Live wallpapers"); sub: I18n.t("Put videos (.mp4, .webm, .mkv) in a wallpaper folder: they show LIVE in your wallpapers. Pick one and it plays as your wallpaper; it pauses under full-screen apps.") }
        Rectangle {
            visible: page.st.have !== undefined && page.st.have.mpvpaper === false
            width: parent.width; height: miss.implicitHeight + 26; radius: M3.rM; color: M3.alpha(M3.tertiary, 0.12)
            T { id: miss; x: 18; y: 13; width: parent.width - 36; wrapMode: Text.WordWrap; font.pixelSize: 13
                text: I18n.t("Live wallpapers need mpvpaper (and ffmpeg for the previews). Install them with your package manager (NixOS: pkgs.mpvpaper, pkgs.ffmpeg).") }
        }
        ToggleRow {
            label: I18n.t("Sound")
            desc: I18n.t("Live wallpapers play their sound too")
            checked: page.st.live.sound === true
            onToggled: function(v) { const n = Object.assign({}, page.st); n.live = Object.assign({}, page.st.live, { sound: v }); page.st = n
                page.walls(["live", "sound", v ? "on" : "off"], I18n.t("Saved")) }
        }
        SettingRow {
            visible: page.liveOn
            label: I18n.t("Playing now")
            desc: (page.st.live.now || "").split("/").pop()
            reserved: 200
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Stop it"); sym: "stop"; icon: ""
                onClicked: if (page.w.still) page.walls(["set", page.w.still], I18n.t("A still picture of it stays")) }
        }

        // ---------- folders ----------
        SectionTitle { text: I18n.t("Wallpaper folders"); sub: I18n.t("Every picture and video in these folders (and one level of folders in them) is in the list.") }
        Repeater {
            model: page.st.dirs || []
            delegate: SettingRow {
                label: page.home(modelData.path)
                desc: modelData.from === "waypaper" ? I18n.t("From Waypaper") : (modelData.from === "default" ? I18n.t("The default folder") : I18n.t("Added by you"))
                reserved: 230
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Btn { text: I18n.t("Open"); sym: "folder_open"; icon: ""; variant: "text"; onClicked: Quickshell.execDetached(["xdg-open", modelData.path]) }
                    Btn { visible: modelData.from === "yours"; text: I18n.t("Remove"); sym: "close"; icon: ""
                        onClicked: page.walls(["folder", "remove", modelData.path], I18n.t("Folder removed")) }
                }
            }
        }
        SettingRow {
            label: I18n.t("Add a folder")
            desc: I18n.t("Type its path and press Enter, or choose it")
            reserved: 430
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Field { id: addF; width: 270; placeholder: "~/Pictures/Walls"
                    onAccepted: { const d = text.trim().replace(/^~/, Quickshell.env("HOME")); if (d) { page.walls(["folder", "add", d], I18n.t("Folder added")); text = "" } } }
                Btn { text: I18n.t("Choose"); sym: "create_new_folder"; icon: ""
                    onClicked: { pick.command = ["bash", "-c", "zenity --file-selection --directory --title=\"$1\" 2>/dev/null || kdialog --getexistingdirectory ~ 2>/dev/null", "_", I18n.t("Wallpaper folder")]; pick.running = true } }
            }
        }
        ToggleRow {
            visible: page.st.waypaper_found === true
            label: I18n.t("Waypaper's folder")
            desc: I18n.t("The wallpapers you have in Waypaper are in this list too")
            checked: page.st.waypaper !== false
            onToggled: function(v) { page.walls(["waypaper", v ? "on" : "off"], I18n.t("Saved")) }
        }
        ToggleRow {
            visible: page.st.waypaper_found === true
            label: I18n.t("Colors follow Waypaper")
            desc: I18n.t("When you pick a wallpaper in the Waypaper app, the shell takes its colors too")
            checked: page.st.waypaper_hook === true
            onToggled: function(v) { page.walls(["waypaper-hook", v ? "on" : "off"], I18n.t("Saved")) }
        }

    }
}
