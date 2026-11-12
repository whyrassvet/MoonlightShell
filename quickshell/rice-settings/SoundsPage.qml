import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Sfx & sounds: the interface sounds (clicks, switches, sliders, typing, welcome music)
// and the notification sound.
Item {
    id: page
    property var ctl
    property var sx: ({})        // rice-sfx state
    property var ns: ({})        // rice-notify state (notification sound)

    function v(k, d) { return sx[k] !== undefined ? sx[k] : d }
    function nv(k, d) { return ns[k] !== undefined ? ns[k] : d }
    function setv(key, value) {
        const n = Object.assign({}, sx)
        n[key] = value
        sx = n
        // this window hears the change at once, the dashboard and hot corner within a few seconds
        if (key === "enabled") Sfx.enabled = value
        else if (key === "volume") Sfx.volume = value
        else if (key === "pack") Sfx.pack = value
        else { const o = Object.assign({}, Sfx.opt); o[key] = value; Sfx.opt = o }
        const arg = typeof value === "boolean" ? (value ? "on" : "off") : String(value)
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-sfx\" set \"$1\" \"$2\"", "_", key, arg])
        page.ctl.status = I18n.t("Applied")
    }
    function setn(key, value) {
        const n = Object.assign({}, ns)
        n[key] = value
        ns = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-notify\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
    }
    function previewNote(name, vol) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-sound\" play \"$1\" \"$2\"", "_", name, String(vol)])
    }

    Process {
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-sfx\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.sx = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-notify\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.ns = JSON.parse(text) } catch (e) { } } }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the switch for all of it ----------
        Rectangle {
            width: parent.width
            height: 112
            radius: M3.rL
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: M3.stageTop }
                GradientStop { position: 1; color: M3.stageBottom }
            }
            border.width: 1
            border.color: M3.outlineVariant
            // a little equalizer that dances while sounds are on
            Row {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 7
                    Rectangle {
                        width: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#F6F5F4"
                        opacity: page.v("enabled", true) ? 0.9 : 0.25
                        property real h: 0.3
                        height: 10 + 40 * h
                        SequentialAnimation on h {
                            running: page.visible && page.v("enabled", true); loops: Animation.Infinite
                            NumberAnimation { to: 0.35 + 0.65 * ((index * 37) % 10) / 10; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.15; duration: 360 + index * 50; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Column {
                x: 110
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                T { kind: "title"; text: I18n.t("Sounds of your desktop"); font.pixelSize: 18; font.bold: true }
                T { kind: "reading"; text: I18n.t("Clicks, switches and sliders in the shell's own parts. Never in other apps."); color: M3.inkDim; font.pixelSize: 12 }
            }
            Tog {
                anchors.right: parent.right; anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                checked: page.v("enabled", true)
                onToggled: function(x) { page.setv("enabled", x); if (x) Sfx.play("done") }
            }
        }

        // ---------- interface sounds ----------
        SectionTitle { text: I18n.t("Sound pack"); sub: I18n.t("How the clicks and switches sound. Click one to hear it.") }
        Flow {
            id: packs
            width: parent.width
            spacing: 10
            Repeater {
                model: [
                    { k: "pebble", n: "Pebble", b: [0.15, 0.9, 0.2, 0.7, 0.1] },
                    { k: "tap", n: "Tap", b: [0.2, 1, 0.3, 0.9, 0.15] },
                    { k: "soft", n: "Soft", b: [0.35, 0.8, 0.5, 0.3, 0.15] },
                    { k: "pluck", n: "Pluck", b: [0.9, 0.6, 0.45, 0.3, 0.2] },
                    { k: "keys", n: "Keys", b: [0.7, 0.25, 0.75, 0.3, 0.65] },
                    { k: "crystal", n: "Crystal", b: [0.3, 0.6, 0.9, 1, 0.55] },
                    { k: "bubble", n: "Bubble", b: [0.8, 0.35, 0.75, 0.3, 0.2] },
                    { k: "retro", n: "Retro", b: [0.6, 0.6, 1, 1, 0.4] }
                ]
                delegate: SoundTile {
                    width: (packs.width - 30) / 4
                    name: modelData.k
                    label: modelData.n
                    bars: modelData.b
                    selected: page.v("pack", "tap") === modelData.k
                    onPicked: {
                        if (!selected) page.setv("pack", modelData.k)
                        Sfx.pack = modelData.k
                        Sfx.play("done")
                    }
                }
            }
        }
        SliderRow {
            label: I18n.t("Volume")
            desc: I18n.t("How loud the interface sounds are, on top of your system volume")
            from: 0; to: 100; step: 5; unit: " %"
            value: page.v("volume", 45)
            onCommitted: function(x) { page.setv("volume", Math.round(x)); Sfx.play("select") }
        }

        SectionTitle { text: I18n.t("When to play"); sub: I18n.t("Turn single sounds on or off.") }
        ToggleRow { label: I18n.t("Clicks"); desc: I18n.t("Buttons, cards, the sidebar and the dashboard"); checked: page.v("click", true); onToggled: function(x) { page.setv("click", x) } }
        ToggleRow { label: I18n.t("Switches"); desc: I18n.t("A soft up when something turns on, down when it turns off"); checked: page.v("switch", true); onToggled: function(x) { page.setv("switch", x) } }
        ToggleRow { label: I18n.t("Sliders"); desc: I18n.t("A tiny tick for every step while you drag"); checked: page.v("slider", true); onToggled: function(x) { page.setv("slider", x) } }
        ToggleRow { label: I18n.t("Typing"); desc: I18n.t("Search fields and text boxes"); checked: page.v("typing", true); onToggled: function(x) { page.setv("typing", x) } }
        ToggleRow { label: I18n.t("Welcome music"); desc: I18n.t("Quiet music during the welcome intro and the Settings tour"); checked: page.v("music", true); onToggled: function(x) { page.setv("music", x) } }

        Row {
            spacing: 10
            topPadding: 6
            Btn { icon: ""; text: I18n.t("Play the music"); onClicked: Sfx.music(true) }
            Btn { icon: ""; text: I18n.t("Stop"); onClicked: Sfx.music(false) }
            Btn { icon: ""; text: I18n.t("Replay the welcome"); onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-welcome\" show"]) }
            Btn { icon: ""; text: I18n.t("Start the tour"); onClicked: page.ctl.startTour() }
        }

        // ---------- notification sound (it was in Notifications before) ----------
        SectionTitle { text: I18n.t("Notification sound"); sub: I18n.t("Plays when a notification arrives (Discord, updates, ...). Silent during Do Not Disturb. Click one to hear it.") }
        Flow {
            id: sounds
            width: parent.width
            spacing: 10
            Repeater {
                model: [
                    { k: "glass", n: "Glass", b: [0.45, 1, 0.75, 0.5, 0.3] },
                    { k: "droplet", n: "Droplet", b: [0.3, 0.9, 0.4, 0.7, 0.2] },
                    { k: "chime", n: "Chime", b: [0.4, 0.6, 0.85, 1, 0.6] },
                    { k: "bubble", n: "Bubble", b: [0.9, 0.3, 0.8, 0.25, 0.15] },
                    { k: "marimba", n: "Marimba", b: [1, 0.45, 0.85, 0.4, 0.2] },
                    { k: "aurora", n: "Aurora", b: [0.3, 0.55, 0.8, 0.95, 0.75] },
                    { k: "ping", n: "Ping", b: [1, 0.4, 0.6, 0.25, 0.1] },
                    { k: "harp", n: "Harp", b: [0.4, 0.55, 0.7, 0.85, 1] },
                    { k: "keys", n: "Keys", b: [0.8, 0.5, 0.9, 0.6, 0.35] },
                    { k: "ripple", n: "Ripple", b: [1, 0.3, 0.6, 0.2, 0.35] },
                    { k: "off", n: "Off", b: [0.13, 0.13, 0.13, 0.13, 0.13] }
                ]
                delegate: SoundTile {
                    width: (sounds.width - 30) / 4
                    name: modelData.k
                    label: modelData.n
                    bars: modelData.b
                    selected: page.nv("sound", "glass") === modelData.k
                    onPicked: {
                        if (modelData.k !== "off") page.previewNote(modelData.k, page.nv("sound_volume", 70))
                        if (!selected) page.setn("sound", modelData.k)
                    }
                }
            }
        }
        SliderRow {
            label: I18n.t("Notification sound volume")
            desc: I18n.t("How loud the notification sound is, on top of your system volume")
            from: 0; to: 100; step: 5; unit: " %"
            value: page.nv("sound_volume", 70)
            onCommitted: function(x) {
                page.setn("sound_volume", Math.round(x))
                if (page.nv("sound", "glass") !== "off") page.previewNote(page.nv("sound", "glass"), Math.round(x))
            }
        }
        Item { width: 1; height: 10 }
    }
}
