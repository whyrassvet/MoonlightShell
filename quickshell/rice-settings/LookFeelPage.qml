import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Desktop > Look & Feel: fastfetch (the logo and the info a terminal shows), the shell your terminals
// start and the terminal the keys open (rice-look). The top shows your terminal with fastfetch in it, as it is.
Item {
    id: page
    property var ctl
    property var st: ({ fetch: {}, shell: { list: [] }, terminal: { list: [] } })
    property var pv: ({ html: "", error: "", logo: "", bg: "#101014", fg: "#e5e3e3" })
    readonly property var ff: st.fetch || {}
    readonly property string shellNow: st.shell ? (st.shell.current || "") : ""
    readonly property string termNow: st.terminal ? (st.terminal.current || "") : ""
    readonly property var termInfo: {
        const l = st.terminal && st.terminal.list ? st.terminal.list : []
        for (let i = 0; i < l.length; i++) if (l[i].id === termNow) return l[i]
        return null
    }
    property string busy: ""                 // what is being changed (its card shows a spinner)

    function look(args, what) {
        busy = what || ""
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-look\" \"$@\" 2>&1", "_"].concat(args.map(a => String(a)))
        setProc.running = true
    }
    function setFetch(k, v) {
        const f = Object.assign({}, ff); f[k] = (k === "on_open") ? (v === "on") : v
        const s = Object.assign({}, st); s.fetch = f; st = s
        look(["fetch", k, v])
    }
    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-look\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: pvProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-look\" preview"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.pv = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").pop()
                if (l) page.ctl.status = l
                page.busy = ""
                again.restart()
            }
        }
    }
    Timer { id: again; interval: 250; onTriggered: { stateProc.running = true; if (!pvProc.running) pvProc.running = true } }
    // after an install in the terminal: look again now and then while the page is open
    Timer { interval: 5000; repeat: true; running: page.visible && page.waiting; onTriggered: stateProc.running = true }
    property bool waiting: false

    component Tile: Rectangle {
        id: tl
        property string name: ""
        property string desc: ""
        property string icon: ""
        property string fallbackIcon: "utilities-terminal"
        property string glyph: ""
        property bool on: false
        property bool installed: true
        property bool working: false
        signal picked()
        signal install()
        width: (parent.width - 2 * 10) / 3
        height: 132
        radius: on ? 28 * M3.shapeK : 18 * M3.shapeK
        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        color: on ? M3.primaryContainer : (tm.containsMouse ? M3.surfaceHigh : M3.surfaceC)
        Behavior on color { ColorAnimation { duration: 160 } }
        border.width: on ? 2 : 0
        border.color: M3.primary
        Item {
            id: ic
            x: 16; y: 16; width: 40; height: 40
            Image {
                id: im
                anchors.fill: parent
                visible: tl.icon !== "" && status === Image.Ready
                source: tl.icon !== "" ? Icons.get(tl.icon, tl.fallbackIcon) : ""
                sourceSize.width: 80; sourceSize.height: 80
                asynchronous: true
                opacity: tl.installed ? 1 : 0.45
            }
            Rectangle {
                anchors.fill: parent
                visible: !im.visible
                radius: 12 * M3.shapeK
                color: tl.on ? M3.primary : M3.surfaceHighest
                T { anchors.centerIn: parent; text: tl.glyph !== "" ? tl.glyph : tl.name.charAt(0).toUpperCase()
                    font.family: tl.glyph !== "" ? Fonts.icons : Fonts.title; font.pixelSize: 20; font.weight: Font.Bold
                    color: tl.on ? M3.inkPrimary : M3.ink }
            }
        }
        // in use / install
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 12; y: 18
            height: 26; radius: 13
            width: chip.implicitWidth + 20
            visible: tl.on || !tl.installed
            color: tl.on ? M3.primary : (im2.containsMouse ? M3.surfaceBright : M3.surfaceHighest)
            T { id: chip; anchors.centerIn: parent; font.pixelSize: 11; font.weight: Font.DemiBold
                text: tl.working ? "…" : (tl.on ? I18n.t("In use") : I18n.t("Install")); color: tl.on ? M3.inkPrimary : M3.ink }
            MouseArea { id: im2; anchors.fill: parent; hoverEnabled: true; enabled: !tl.on && !tl.installed
                cursorShape: Qt.PointingHandCursor; onClicked: tl.install() }
        }
        Column {
            x: 16; y: 68; width: parent.width - 32
            spacing: 2
            T { text: tl.name; font.pixelSize: 15; font.weight: Font.DemiBold; color: tl.on ? M3.inkPrimaryC : M3.ink }
            T { kind: "reading"; text: tl.desc; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                font.pixelSize: 12; color: tl.on ? M3.alpha(M3.inkPrimaryC, 0.8) : M3.inkDim }
        }
        MouseArea {
            id: tm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (tl.installed) tl.picked(); else tl.install() }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- your terminal, as it is ----------
        Rectangle {
            id: hero
            width: parent.width
            height: Math.max(240, Math.min(470, out.contentHeight + 96))
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob { width: 260; height: 260; x: parent.width - 190; y: -70; kind: "cookie"; color: M3.alpha(M3.inkPrimaryC, 0.06) }
            T { x: 22; y: 16; text: I18n.t("YOUR TERMINAL"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                color: M3.alpha(M3.inkPrimaryC, 0.75) }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 10
                spacing: 8
                Btn { text: I18n.t("Open it"); sym: "terminal"; icon: ""; primary: true; onClicked: page.look(["try"]) }
            }
            // the window
            Rectangle {
                id: twin
                x: 18; y: 50
                width: parent.width - 36; height: parent.height - 68
                radius: 14
                color: page.pv.bg || "#101014"
                border.width: 1; border.color: M3.alpha("#ffffff", 0.08)
                clip: true
                Row {
                    x: 14; y: 11; spacing: 7
                    Repeater { model: ["#ff5f57", "#febc2e", "#28c840"]; Rectangle { width: 11; height: 11; radius: 6; color: modelData; opacity: 0.85 } }
                }
                T { anchors.horizontalCenter: parent.horizontalCenter; y: 8; font.pixelSize: 12; color: M3.alpha(page.pv.fg || "#e5e3e3", 0.6)
                    text: (page.termInfo ? page.termInfo.name : page.termNow) + "  ·  " + page.shellNow }
                T {
                    id: prompt
                    x: 16; y: 34
                    scaled: false
                    font.family: Fonts.mono; font.pixelSize: 12
                    color: page.pv.fg || "#e5e3e3"
                    text: I18n.t("󰉋 ~> fastfetch")
                }
                Row {
                    x: 16; y: prompt.y + prompt.height + 6
                    width: parent.width - 32
                    spacing: 18
                    Rectangle {
                        visible: page.pv.logo !== ""
                        width: visible ? 150 : 0; height: 150; radius: 16; clip: true; color: "transparent"
                        Image { anchors.fill: parent; source: page.pv.logo !== "" ? "file://" + page.pv.logo : ""; cache: false
                            fillMode: Image.PreserveAspectCrop; sourceSize.width: 300 }
                    }
                    Flickable {
                        id: out
                        width: parent.width - (page.pv.logo !== "" ? 168 : 0)
                        height: twin.height - prompt.y - prompt.height - 18
                        contentWidth: txt.implicitWidth; contentHeight: txt.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        T {
                            id: txt
                            scaled: false
                            textFormat: Text.RichText
                            font.family: Fonts.mono; font.pixelSize: 12
                            lineHeight: 1.05
                            color: page.pv.fg || "#e5e3e3"
                            text: page.pv.html !== "" ? page.pv.html
                                : (page.pv.error !== "" ? page.pv.error : "Loading ...")
                        }
                    }
                }
            }
        }

        // ---------- fastfetch ----------
        SectionTitle { text: I18n.t("Fastfetch"); sub: I18n.t("The logo and the facts about your computer that a terminal shows.") }
        Rectangle {
            visible: page.ff.installed === false
            width: parent.width; height: 60; radius: M3.rL
            color: M3.surfaceC
            T { x: 18; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("fastfetch is not installed"); font.pixelSize: 14 }
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Install"); sym: "download"; icon: ""; onClicked: { page.waiting = true; page.look(["install", "fastfetch"]) } }
        }
        Rectangle {
            visible: page.ff.own === true
            width: parent.width; height: 68; radius: M3.rL
            color: M3.tertiaryContainer
            T { x: 18; width: parent.width - 220; anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.WordWrap
                text: I18n.t("You use your own fastfetch config: the choices below are saved but not used.")
                font.pixelSize: 13; color: M3.inkTertiaryC }
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Use DarkShadow's"); sym: "restart_alt"; icon: ""; onClicked: page.look(["fetch-own"]) }
        }
        ToggleRow {
            label: I18n.t("Show it when a terminal opens")
            desc: I18n.t("Every new terminal starts with fastfetch (fish, zsh and bash)")
            checked: page.ff.on_open === true
            onToggled: function(v) { page.setFetch("on_open", v ? "on" : "off") }
        }
        SegRow {
            label: I18n.t("Logo")
            desc: page.ff.logo === "wallpaper" && page.termInfo && !page.termInfo.images
                ? page.termNow + I18n.t(" cannot show pictures: the moon shows instead") : I18n.t("Your distro's, small like pfetch, DarkShadow's moon or black hole, or your wallpaper")
            options: [{ label: I18n.t("Distro"), value: "distro" }, { label: "pfetch", value: "small" }, { label: I18n.t("Moon"), value: "darkshadow" }, { label: I18n.t("Black hole"), value: "blackhole" },
                      { label: I18n.t("Wallpaper"), value: "wallpaper" }, { label: I18n.t("None"), value: "none" }]
            current: page.ff.logo || "distro"
            onChosen: function(v) { page.setFetch("logo", v) }
        }
        SegRow {
            label: I18n.t("Info")
            desc: page.ff.logo === "small" ? I18n.t("pfetch style: a small logo and a short list (os, host, kernel, uptime, pkgs, memory)") : I18n.t("How much it tells")
            options: [{ label: I18n.t("Everything"), value: "full" }, { label: I18n.t("The main"), value: "compact" }, { label: I18n.t("A little"), value: "minimal" }]
            current: page.ff.info || "full"
            onChosen: function(v) { page.setFetch("info", v) }
        }
        SegRow {
            label: I18n.t("Labels")
            desc: I18n.t("Words, or icons with the words")
            options: [{ label: I18n.t("Words"), value: "text" }, { label: I18n.t("Icons"), value: "icons" }]
            current: page.ff.labels || "text"
            onChosen: function(v) { page.setFetch("labels", v) }
        }
        ToggleRow {
            label: I18n.t("Wallpaper colors")
            desc: I18n.t("The logo and the labels take the colors of your wallpaper")
            checked: (page.ff.colors || "wallpaper") === "wallpaper"
            onToggled: function(v) { page.setFetch("colors", v ? "wallpaper" : "plain") }
        }

        // ---------- shell ----------
        SectionTitle { text: I18n.t("Shell"); sub: I18n.t("What you type commands into. New terminals start it, with the same prompt and colors.") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.st.shell ? page.st.shell.list : []
                delegate: Tile {
                    name: modelData.name; desc: modelData.desc
                    glyph: modelData.id === "fish" ? "\udb80\ude3a" : (modelData.id === "zsh" ? "\ue795" : "\uebca")
                    on: page.shellNow === modelData.id
                    installed: modelData.installed
                    working: page.busy === modelData.id
                    onPicked: if (!on) page.look(["shell", modelData.id], modelData.id)
                    onInstall: { page.waiting = true; page.look(["install", modelData.id], modelData.id) }
                }
            }
        }
        SettingRow {
            visible: page.st.shell && page.st.shell.login !== "" && page.st.shell.login !== page.shellNow
            label: I18n.t("Your login shell is ") + (page.st.shell ? page.st.shell.login : "")
            desc: I18n.t("Terminals start ") + page.shellNow + I18n.t("; make it your login shell too (it asks your password)")
            reserved: 210
            Btn { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Use ") + page.shellNow + I18n.t(" everywhere"); sym: "key"; icon: ""; variant: "tonal"
                onClicked: { page.waiting = true; page.look(["login-shell"]) } }
        }

        // ---------- terminal ----------
        SectionTitle { text: I18n.t("Terminal"); sub: I18n.t("The app Super + Return opens, also for the Wi-Fi menu and updates. It gets your wallpaper colors, font and see-through background.") }
        Flow {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.st.terminal ? page.st.terminal.list : []
                delegate: Tile {
                    name: modelData.name
                    desc: modelData.desc
                    icon: modelData.app
                    on: page.termNow === modelData.id
                    installed: modelData.installed
                    working: page.busy === modelData.id
                    onPicked: if (!on) page.look(["terminal", modelData.id], modelData.id)
                    onInstall: { page.waiting = true; page.look(["install", modelData.id], modelData.id) }
                }
            }
        }
        T {
            visible: page.termNow === "wezterm" || page.termNow === "konsole"
            width: parent.width; wrapMode: Text.WordWrap; topPadding: 4
            text: (page.termInfo ? page.termInfo.name : page.termNow) + I18n.t(" keeps its own look and starts your login shell.")
            color: M3.inkDim; font.pixelSize: 12
        }
    }
}
