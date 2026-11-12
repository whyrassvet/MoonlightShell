import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Dynamic island (it took the place of the Dashboard): what the island in the bar shows at rest, what
// it grows into and how its card behaves (rice-bar island_*). The stage at the top plays the island's moments in
// a loop, in your shape and with wavy progress.
Item {
    id: page
    property var ctl
    property var qb: ({})
    function v(k, d) { return qb[k] !== undefined ? qb[k] : d }
    function setv(key, value) {
        const n = Object.assign({}, qb)
        n[key] = value === "on" ? true : value === "off" ? false : value
        qb = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-bar\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
        refresh.restart()
    }
    function open(tab) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" island \"$1\"", "_", tab]) }
    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-bar\" state 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.qb = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: refresh; interval: 800; onTriggered: stateProc.running = true }
    readonly property bool onBar: page.v("style", "") === "dynamic" || ["left", "center", "right"].some(function(z) { return ((page.qb.layout || {})[z] || []).indexOf("island") >= 0 })

    PageScroll {
        anchors.fill: parent

        // ---------- the stage: the island's moments, one after another ----------
        Rectangle {
            id: stage
            width: parent.width; height: 250
            radius: M3.rL
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: M3.stageTop }
                GradientStop { position: 1; color: M3.stageBottom }
            }
            // the moments: time, volume, a workspace, a notification, the player, today
            readonly property var moments: ["idle", "volume", "ws", "notif", "media", "today"]
            property int m: 0
            readonly property string mode: moments[m]
            Timer { running: page.visible; interval: stage.mode === "idle" ? 1600 : 2300; repeat: true; onTriggered: stage.m = (stage.m + 1) % stage.moments.length }
            readonly property bool big: mode === "notif" || mode === "media" || mode === "today"
            // a bar along the top
            Rectangle { x: 16; y: 14; width: parent.width - 32; height: 36; radius: 18; color: Qt.rgba(0, 0, 0, 0.35) }
            Row { x: 30; y: 14; height: 36; spacing: 8
                Repeater { model: 4; delegate: Rectangle { anchors.verticalCenter: parent.verticalCenter; width: index === 1 ? 26 : 8; height: 8; radius: 4
                    color: index === 1 ? M3.primary : Qt.rgba(1, 1, 1, 0.3) } } }
            Row { anchors.right: parent.right; anchors.rightMargin: 30; y: 14; height: 36; spacing: 12
                Repeater { model: 4; delegate: Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: Qt.rgba(1, 1, 1, 0.45) } } }
            // the island in the bar
            Rectangle {
                id: pill
                readonly property real w: stage.mode === "volume" ? 220 : (stage.mode === "ws" ? 170 : 104)
                width: w; height: 30; radius: 15
                anchors.horizontalCenter: parent.horizontalCenter; y: 17
                color: M3.surface
                Behavior on width { SpringAnimation { spring: 3; damping: 0.32; epsilon: 0.4 } }
                Row { anchors.centerIn: parent; spacing: 8; opacity: stage.mode === "idle" || stage.big ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    T { text: "16:42"; font.pixelSize: 13; font.bold: true }
                    T { visible: page.v("island_weather", true) !== false; text: "7°"; font.pixelSize: 12; color: M3.inkDim } }
                Row { anchors.centerIn: parent; spacing: 8; opacity: stage.mode === "volume" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Item { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter
                        Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primary }
                        Icon { anchors.centerIn: parent; name: "volume_up"; size: 13; filled: true; color: M3.inkPrimary } }
                    WavyBar { width: 140; height: 16; value: 0.62; anchors.verticalCenter: parent.verticalCenter } }
                Row { anchors.centerIn: parent; spacing: 6; opacity: stage.mode === "ws" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Repeater { model: 5; delegate: Rectangle { anchors.verticalCenter: parent.verticalCenter
                        width: index === 2 ? 26 : 7; height: index === 2 ? 18 : 7; radius: height / 2
                        color: index === 2 ? Qt.hsla(((M3.primary.hslHue < 0 ? 0.55 : M3.primary.hslHue) + 0.24) % 1, M3.primary.hslSaturation, M3.primary.hslLightness, 1) : Qt.rgba(1, 1, 1, 0.25)
                        T { anchors.centerIn: parent; visible: index === 2; text: "3"; font.pixelSize: 10; font.bold: true; color: M3.inkPrimary } } } }
            }
            // the card beside the bar
            Rectangle {
                id: card
                property real t: stage.big ? 1 : 0
                Behavior on t { NumberAnimation { duration: stage.big ? 800 : 300; easing.type: stage.big ? Easing.OutBack : Easing.InOutCubic; easing.overshoot: 0.9 } }
                readonly property real cw: stage.mode === "notif" ? 300 : 340
                readonly property real ch: stage.mode === "notif" ? 70 : (stage.mode === "media" ? 130 : 150)
                property real cwA: cw
                property real chA: ch
                Behavior on cwA { SpringAnimation { spring: 2.4; damping: 0.36 } }
                Behavior on chA { SpringAnimation { spring: 2.4; damping: 0.36 } }
                width: Math.max(30, pill.width + (cwA - pill.width) * Math.max(0, t))
                height: Math.max(20, 30 + (chA - 30) * Math.max(0, t))
                anchors.horizontalCenter: parent.horizontalCenter
                y: 17 + 38 * Math.min(1, Math.max(0, t))
                radius: Math.min(height / 2, 15 + 9 * Math.min(1, Math.max(0, t)))
                color: M3.surface
                opacity: t < 0.02 ? 0 : Math.min(1, t * 4)
                clip: true
                // notification
                Item { anchors.fill: parent; opacity: stage.mode === "notif" && card.t > 0.8 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Item { x: 14; y: 14; width: 40; height: 40
                        Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primaryContainer }
                        Icon { anchors.centerIn: parent; name: "chat"; size: 18; filled: true; color: M3.inkPrimaryC } }
                    Column { x: 66; y: 14; spacing: 2
                        T { text: I18n.t("Messages"); font.pixelSize: 10; color: M3.inkDim }
                        T { text: I18n.t("Example text"); font.pixelSize: 13; font.bold: true }
                        WavyBar { width: 210; height: 12; value: 0.6 } } }
                // player
                Item { anchors.fill: parent; opacity: stage.mode === "media" && card.t > 0.8 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Item { x: 14; y: 14; width: 60; height: 60
                        Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.tertiary } }
                    Column { x: 88; y: 20; spacing: 2
                        T { text: I18n.t("SPOTIFY"); font.pixelSize: 9; font.bold: true; color: M3.primary }
                        T { text: I18n.t("A song"); font.pixelSize: 15; font.bold: true }
                        T { text: I18n.t("An artist"); font.pixelSize: 11; color: M3.inkDim } }
                    WavyBar { x: 14; y: 90; width: parent.width - 28; height: 16; value: 0.4 } }
                // today
                Item { anchors.fill: parent; opacity: stage.mode === "today" && card.t > 0.8 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Column { x: 18; y: 16; spacing: 2
                        T { text: I18n.t("Wednesday"); font.pixelSize: 11; color: M3.primary; font.bold: true }
                        T { text: I18n.t("4 November"); font.pixelSize: 18; font.bold: true } }
                    Item { x: 18; y: 70; width: 50; height: 50
                        Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primaryContainer }
                        Icon { anchors.centerIn: parent; name: "partly_cloudy_day"; size: 24; filled: true; color: M3.inkPrimaryC } }
                    T { x: 80; y: 82; text: "7°C"; font.pixelSize: 20; font.bold: true }
                    Grid { x: 190; y: 20; columns: 7; spacing: 4
                        Repeater { model: 28; delegate: Item { width: 16; height: 16
                            Blob { anchors.fill: parent; visible: index === 9; kind: Prefs.accentShape; color: M3.primary }
                            T { anchors.centerIn: parent; text: index + 1; font.pixelSize: 8; color: index === 9 ? M3.inkPrimary : M3.ink } } } } }
            }
            T { anchors.left: parent.left; anchors.leftMargin: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: page.onBar ? I18n.t("On your bar") : I18n.t("Not on your bar yet: add Island in Bar layout"); font.pixelSize: 11; color: M3.inkDim }
        }
        Row {
            spacing: 8
            Btn { primary: true; sym: "calendar_today"; text: I18n.t("Open Today"); onClicked: page.open("today") }
            Btn { sym: "memory"; text: I18n.t("System"); onClicked: page.open("system") }
            Btn { sym: "info"; text: I18n.t("About"); onClicked: page.open("about") }
            Btn { visible: !page.onBar; sym: "view_column"; text: I18n.t("Bar layout"); onClicked: page.ctl.page = 3 }
        }

        // ---------- at rest ----------
        SectionTitle { text: I18n.t("At rest"); sub: I18n.t("The island is your clock. Click it for Today, right-click for System, scroll on it for the volume.") }
        ToggleRow { label: I18n.t("Weather"); desc: I18n.t("The weather icon and temperature beside the time")
            checked: page.v("island_weather", true) !== false; onToggled: function(x) { page.setv("island_weather", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Date"); desc: I18n.t("The day and date beside the time")
            checked: page.v("island_date", false) === true; onToggled: function(x) { page.setv("island_date", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Seconds"); desc: I18n.t("Show seconds in the time")
            checked: page.v("seconds", false) === true; onToggled: function(x) { page.setv("seconds", x ? "on" : "off") } }

        // ---------- moments ----------
        SectionTitle { text: I18n.t("It grows into"); sub: I18n.t("For a moment, then it is the clock again.") }
        ToggleRow { label: I18n.t("Dynamic island"); desc: I18n.t("Off: only the clock. It grows into nothing; volume and notifications pop up as usual, a click still opens Today")
            checked: page.v("island_dynamic", true) !== false; onToggled: function(x) { page.setv("island_dynamic", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Music on hover"); desc: I18n.t("Point at the island while something plays to open the player")
            enabled: page.v("island_dynamic", true) !== false; opacity: enabled ? 1 : 0.45
            checked: page.v("island_hover", true) !== false; onToggled: function(x) { page.setv("island_hover", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Volume and microphone"); desc: I18n.t("A wavy level you can drag, instead of the pop-up at the bottom")
            enabled: page.v("island_dynamic", true) !== false; opacity: enabled ? 1 : 0.45
            checked: page.v("island_volume", true) !== false; onToggled: function(x) { page.setv("island_volume", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Workspaces"); desc: I18n.t("Which workspace you switched to, in your workspace style and its own color")
            enabled: page.v("island_dynamic", true) !== false; opacity: enabled ? 1 : 0.45
            checked: page.v("island_ws", true) !== false; onToggled: function(x) { page.setv("island_ws", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Notifications"); desc: I18n.t("They grow out of the island instead of popping up (urgent ones still pop up). Needs Shown by: DarkShadow")
            enabled: page.v("island_dynamic", true) !== false; opacity: enabled ? 1 : 0.45
            checked: page.v("island_notifs", true) !== false; onToggled: function(x) { page.setv("island_notifs", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Charger"); desc: I18n.t("Plugging the charger in or out shows the battery as a wave (laptops)")
            enabled: page.v("island_dynamic", true) !== false; opacity: enabled ? 1 : 0.45
            checked: page.v("island_charge", true) !== false; onToggled: function(x) { page.setv("island_charge", x ? "on" : "off") } }

        // ---------- the card ----------
        SectionTitle { text: I18n.t("The card"); sub: I18n.t("What a click opens. Esc, a click on the desktop or another window closes it.") }
        SegRow { label: I18n.t("Opens on"); desc: I18n.t("The tab a click on the island opens")
            options: [ { label: I18n.t("Today"), value: "today" }, { label: I18n.t("System"), value: "system" }, { label: I18n.t("About"), value: "about" } ]
            current: page.v("island_tab", "today"); onChosen: function(x) { page.setv("island_tab", x) } }
        SliderRow { label: I18n.t("Closes after"); desc: I18n.t("Seconds after the pointer leaves it")
            from: 2; to: 10; step: 1; unit: " s"; value: page.v("island_close", 4)
            onCommitted: function(x) { page.setv("island_close", Math.round(x)) } }
    }
}
