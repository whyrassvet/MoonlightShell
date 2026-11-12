import Quickshell
import QtQuick

Item {
    id: page
    property var ctl

    function dv(k, d) {
        const c = page.ctl.dst.dock
        return c && c[k] !== undefined ? c[k] : d
    }
    // ---------- pinned apps (the dock shows them first, in this order) ----------
    readonly property var pins: page.ctl && page.ctl.dst.dock && page.ctl.dst.dock.apps ? page.ctl.dst.dock.apps : []
    property string q: ""
    function idOf(e) { return (e.id || "").replace(/\.desktop$/, "") }
    function entry(id) { return DesktopEntries.heuristicLookup(id) }
    function setPins(l) {
        const d = JSON.parse(JSON.stringify(page.ctl.dst)); d.dock = d.dock || {}; d.dock.apps = l; page.ctl.dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" dock-apps \"$1\"", "_", JSON.stringify(l)])
        page.ctl.status = I18n.t("Dock: ") + l.length + I18n.t(" pinned apps")
    }
    function pin(id) { if (pins.indexOf(id) < 0) setPins(pins.concat([id])) }
    function unpin(id) { setPins(pins.filter(function(x) { return x !== id })) }
    function move(i, d) { const l = pins.slice(); const j = i + d; if (j < 0 || j >= l.length) return; const t = l[i]; l[i] = l[j]; l[j] = t; setPins(l) }
    readonly property var found: {
        const s = q.trim().toLowerCase()
        const l = DesktopEntries.applications.values.filter(function(e) { return !e.noDisplay && (s === "" || (e.name || "").toLowerCase().indexOf(s) >= 0) })
        return l.slice().sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") }).slice(0, 48)
    }

    function lv(k) {
        const c = page.ctl.dst.lock
        return !!(c && c[k] === true)
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

            T { kind: "title"; text: I18n.t("Dock"); font.pixelSize: 16; font.bold: true }

            // live preview of the dock
            Rectangle {
                width: parent.width
                height: 150
                radius: M3.rL
                clip: true
                border.width: 0
                border.color: M3.outlineVariant
                gradient: Gradient {
                    GradientStop { position: 0; color: M3.stageTop }
                    GradientStop { position: 1; color: M3.stageBottom }
                }
                Rectangle { x: 40; y: 26; width: 180; height: 60; radius: 10; color: Qt.rgba(1, 1, 1, 0.07) }
                Rectangle { x: parent.width - 260; y: 18; width: 200; height: 76; radius: 10; color: Qt.rgba(1, 1, 1, 0.05) }
                Rectangle {
                    id: mockDock
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: icons.width + 20
                    height: 52
                    radius: 20
                    visible: page.dv("enabled", false) === true
                    color: page.dv("background", true) === false ? "transparent"
                         : Qt.rgba(0.1, 0.1, 0.11, Number(page.dv("opacity", 0.78)))
                    border.width: page.dv("background", true) === false ? 0 : 1
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Row {
                        id: icons
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: ["#e06c75", "#61afef", "#e5c07b", "#98c379", "#c678dd", "#56b6c2"]
                            delegate: Rectangle {
                                width: 34; height: 34; radius: 10
                                color: page.dv("tint", false) === true ? M3.inkDim : (page.dv("shade", true) !== false ? Qt.tint(modelData, Qt.rgba(M3.primary.r, M3.primary.g, M3.primary.b, 0.62)) : modelData)
                                opacity: 0.9
                            }
                        }
                    }
                }
                T {
                    anchors.centerIn: parent
                    visible: page.dv("enabled", false) !== true
                    text: I18n.t("Dock is off")
                    color: M3.inkDim
                    font.pixelSize: 13
                }
                T {
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                    visible: page.dv("enabled", false) === true && page.dv("blur", true) === true && page.dv("background", true) !== false
                    text: I18n.t("blur on")
                    color: M3.inkDim
                    font.pixelSize: 10
                }
            }

            ToggleRow {
                label: I18n.t("Enable")
                desc: I18n.t("A minimal dock with your apps on a screen edge (bottom, left or right)")
                checked: page.dv("enabled", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "enabled", v ? "on" : "off") }
            }
            SegRow {
                label: I18n.t("Position")
                desc: I18n.t("Which screen edge the dock sits on")
                options: [{ label: I18n.t("Bottom"), value: "bottom" }, { label: I18n.t("Left"), value: "left" }, { label: I18n.t("Right"), value: "right" }]
                current: page.dv("position", "bottom") === "top" ? "bottom" : page.dv("position", "bottom")
                onChosen: function(x) { page.ctl.dset("dock", "position", x) }
            }
            ToggleRow {
                label: I18n.t("Background")
                desc: I18n.t("Draw a panel behind the icons")
                checked: page.dv("background", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "background", v ? "on" : "off") }
            }
            SliderRow {
                label: I18n.t("Opacity")
                desc: I18n.t("Lower is more see-through")
                from: 0.2; to: 1.0; step: 0.02; decimals: 2
                value: Number(page.dv("opacity", 0.78))
                onCommitted: function(x) { page.ctl.dset("dock", "opacity", x.toFixed(2)) }
            }
            ToggleRow {
                label: I18n.t("Blur")
                desc: I18n.t("Blur the desktop behind the dock")
                checked: page.dv("blur", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "blur", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Hover to reveal")
                desc: I18n.t("Hide the dock and slide it in when the pointer touches its screen edge")
                checked: page.dv("hover", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "hover", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Keep room for it")
                desc: I18n.t("While the dock stays out, windows end next to it instead of under it (like the bar)")
                checked: page.dv("reserve", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "reserve", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Pinned on startup")
                desc: I18n.t("Start with the dock held open")
                checked: page.dv("pinnedStartup", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "pinnedStartup", v ? "on" : "off") }
            }

            T { kind: "title"; text: I18n.t("Buttons"); font.pixelSize: 16; font.bold: true; topPadding: 8 }

            ToggleRow {
                label: I18n.t("Media player")
                desc: I18n.t("The song cover and a play / pause button in the dock")
                checked: page.dv("media", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "media", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Now playing text")
                desc: I18n.t("Write the song title and artist in the dock while something plays")
                checked: page.dv("nowText", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "nowText", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Show pin button")
                desc: I18n.t("Button that holds the dock open")
                checked: page.dv("pinButton", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "pinButton", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("Show apps button")
                desc: I18n.t("Button that opens the app launcher")
                checked: page.dv("appsButton", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "appsButton", v ? "on" : "off") }
            }
            ToggleRow {
                label: I18n.t("App menu")
                desc: I18n.t("The apps button opens the dock's own app menu (with pins); off: it opens the launcher")
                checked: page.dv("appMenu", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "appMenu", v ? "on" : "off") }
            }

            // ---------- pinned apps ----------
            SectionTitle { text: I18n.t("Pinned apps"); sub: page.pins.length + I18n.t(" on the dock, in this order. Pin more below, or right-click an app in the dock's app menu.") }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: page.pins
                    delegate: Rectangle {
                        id: chip
                        readonly property var e: page.entry(modelData)
                        readonly property int pi: index
                        readonly property string pid: modelData
                        height: 52; width: pr.implicitWidth + 24; radius: 26
                        color: M3.secondaryContainer
                        Row {
                            id: pr
                            anchors.centerIn: parent
                            spacing: 6
                            Item { width: 34; height: 34; anchors.verticalCenter: parent.verticalCenter
                                Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.alpha(M3.primary, 0.25) }
                                Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize.width: 48; sourceSize.height: 48; source: Icons.get(chip.e ? (chip.e.icon || "application-x-executable") : chip.pid, "application-x-executable") } }
                            T { text: chip.e ? chip.e.name : chip.pid; font.pixelSize: 13; color: M3.inkSecondaryC; anchors.verticalCenter: parent.verticalCenter }
                            Repeater {
                                model: [{ s: "chevron_left", g: "‹", d: -1 }, { s: "chevron_right", g: "›", d: 1 }, { s: "close", g: "×", d: 0 }]
                                delegate: Rectangle {
                                    width: 26; height: 26; radius: 13; anchors.verticalCenter: parent.verticalCenter
                                    color: bm.containsMouse ? M3.alpha(M3.ink, 0.12) : "transparent"
                                    Icon { anchors.centerIn: parent; name: modelData.s; glyph: modelData.g; size: 15; color: M3.inkSecondaryC }
                                    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.d === 0 ? page.unpin(chip.pid) : page.move(chip.pi, modelData.d) }
                                }
                            }
                        }
                    }
                }
            }
            Field {
                width: parent.width
                placeholder: I18n.t("Search apps to pin ...")
                onTextChanged: page.q = text
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: page.found
                    delegate: Rectangle {
                        readonly property string aid: page.idOf(modelData)
                        readonly property bool on: page.pins.indexOf(aid) >= 0
                        width: ar.implicitWidth + 24; height: 44; radius: on ? 22 : 12
                        color: on ? M3.primary : (am.containsMouse ? M3.surfaceHigh : M3.surfaceC)
                        Behavior on radius { NumberAnimation { duration: M3.d(240); easing.type: M3.springy; easing.overshoot: 1.6 * Prefs.bounce } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Row {
                            id: ar; anchors.centerIn: parent; spacing: 8
                            Image { width: 22; height: 22; sourceSize.width: 44; sourceSize.height: 44; anchors.verticalCenter: parent.verticalCenter; source: Icons.get(modelData.icon || "application-x-executable", "application-x-executable") }
                            T { text: modelData.name; font.pixelSize: 13; color: parent.parent.on ? M3.inkPrimary : M3.ink; anchors.verticalCenter: parent.verticalCenter }
                            Icon { name: "keep"; glyph: ""; size: 15; filled: parent.parent.on; visible: parent.parent.on || am.containsMouse; color: parent.parent.on ? M3.inkPrimary : M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: parent.on ? page.unpin(parent.aid) : page.pin(parent.aid) }
                    }
                }
            }

            ToggleRow {
                label: I18n.t("Tint app icons")
                desc: I18n.t("Paint icons in a single neutral tone")
                checked: page.dv("tint", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "tint", v ? "on" : "off") }
            }
            ToggleRow {
                visible: page.dv("tint", false) !== true
                label: I18n.t("Match the wallpaper")
                desc: I18n.t("App icons take a shade of your wallpaper's color")
                checked: page.dv("shade", true) !== false
                onToggled: function(v) { page.ctl.dset("dock", "shade", v ? "on" : "off") }
            }

            T {
                width: parent.width
                topPadding: 14
                text: I18n.t("Lock screen options moved to Idle & Lockscreen.")
                color: M3.inkDim
                font.pixelSize: 12
            }
        }
    }
}
