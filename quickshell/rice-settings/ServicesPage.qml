import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var fonts: ({})

    readonly property var roles: [
        { key: "main", label: I18n.t("Main font"), desc: I18n.t("Interface text, e.g. Rubik") },
        { key: "numbers", label: I18n.t("Numbers family"), desc: I18n.t("Digits in clocks and stats, e.g. Rubik") },
        { key: "title", label: I18n.t("Title family"), desc: I18n.t("Headings, e.g. Gabarito") },
        { key: "mono", label: I18n.t("Monospace font"), desc: I18n.t("Terminal, e.g. JetBrains Mono NF") },
        { key: "icons", label: I18n.t("Nerd font icons"), desc: I18n.t("Symbols, e.g. JetBrains Mono NF") },
        { key: "reading", label: I18n.t("Reading font"), desc: I18n.t("Descriptions, e.g. Readex Pro") }
    ]

    // ---------- switches and system services (rice-services) ----------
    property var sv: ({ have: {}, units: [] })
    property string busy: ""
    readonly property var switches: [
        { k: "wifi", n: "Wi-Fi", g: "\uf1eb", need: "nmcli" },
        { k: "bluetooth", n: "Bluetooth", g: "\uf294", need: "bluetoothctl" },
        { k: "sound", n: "Sound", g: "\uf028", need: "wpctl", offText: "Muted" },
        { k: "mic", n: "Microphone", g: "\uf130", need: "wpctl", offText: "Muted" },
        { k: "network", n: "Networking", g: "\uf0e8", need: "nmcli" },
        { k: "airplane", n: "Airplane mode", g: "\uf072", need: "nmcli" },
        { k: "dnd", n: "Do Not Disturb", g: "\uf1f6", need: "swaync-client" },
        { k: "awake", n: "Keep awake", g: "\uf0f4", need: "" },
        { k: "nightlight", n: "Night light", g: "\uf186", need: "hyprsunset" }
    ]
    function svSet(k, on) {
        const n = Object.assign({}, sv); n[k] = on
        if (k === "airplane") { n.wifi = !on; n.bluetooth = !on }
        sv = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" set \"$1\" \"$2\"", "_", k, on ? "on" : "off"])
        page.ctl.status = (on ? I18n.t("On: ") : I18n.t("Off: ")) + k
        svRefresh.restart()
    }
    function unit(name, action) {
        busy = name
        unitProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-services\" unit \"$1\" \"$2\" 2>&1", "_", name, action]
        unitProc.running = true
    }
    Process {
        id: svProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-services\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.sv = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: svRefresh; interval: 1200; onTriggered: svProc.running = true }
    Timer { interval: 5000; running: page.visible; repeat: true; onTriggered: if (!svProc.running) svProc.running = true }
    Process {
        id: unitProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim().length > 0 ? text.trim().split("\n").pop() : I18n.t("Done")
                page.busy = ""
                svProc.running = true
            }
        }
    }

    // ---------- blur & transparency, gaming mode (rice-effects) ----------
    property var fx: ({ lite: false, gaming: false, flat: false, opts: {} })
    function fxOpt(k) { return !!(fx.opts && fx.opts[k] === true) }
    function fxRun(args, msg) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" \"$@\"", "_"].concat(args))
        page.ctl.status = msg
        fxRefresh.restart()
    }
    function setLite(on) {
        const n = JSON.parse(JSON.stringify(fx)); n.lite = on; fx = n
        fxRun(["lite", on ? "on" : "off"], on ? "Light mode on" : "Light mode off")
    }
    function setGaming(on) {
        const n = JSON.parse(JSON.stringify(fx)); n.gaming = on; fx = n
        fxRun(["gaming", on ? "on" : "off"], "Gaming mode " + (on ? "on" : "off"))
    }
    function setOpt(k, on) {
        const n = JSON.parse(JSON.stringify(fx)); if (!n.opts) n.opts = {}; n.opts[k] = on; fx = n
        fxRun(["set", k, on ? "on" : "off"], "Gaming mode: saved")
    }
    Process {
        id: fxProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.fx = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: fxRefresh; interval: 1500; onTriggered: if (!fxProc.running) fxProc.running = true }
    Timer { interval: 4000; running: page.visible; repeat: true; onTriggered: if (!fxProc.running) fxProc.running = true }

    function applyFont(key, value) {
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/font-set\" set \"$1\" \"$2\" 2>&1", "_", key, value]
        setProc.running = true
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.fonts = JSON.parse(text) } catch (e) { } }
        }
    }
    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim()
                refresh.restart()
            }
        }
    }
    Process {
        id: resetProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" reset 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim()
                refresh.restart()
            }
        }
    }
    Timer { id: refresh; interval: 500; onTriggered: stateProc.running = true }

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

            SectionTitle { topPadding: 0; text: I18n.t("Switches"); sub: I18n.t("Turn things on and off for this computer. Night light needs ") + (Quickshell.env("NIRI_SOCKET") ? "gammastep" : "hyprsunset") + "." }
            Grid {
                id: swGrid
                width: parent.width
                columns: 3
                spacing: 10
                Repeater {
                    model: page.switches
                    delegate: Rectangle {
                        id: tile
                        readonly property bool avail: modelData.need === "" || (page.sv.have && page.sv.have[modelData.need] === true)
                        readonly property bool on: page.sv[modelData.k] === true
                        width: (swGrid.width - 20) / 3
                        height: 74
                        radius: 14
                        opacity: avail ? 1 : 0.45
                        color: tm.containsMouse && avail ? M3.surfaceHigh : M3.surfaceC
                        border.width: 1
                        border.color: on ? M3.primary : M3.outlineVariant
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40; radius: 12
                            color: tile.on ? M3.primary : M3.surfaceHighest
                            Behavior on color { ColorAnimation { duration: 200 } }
                            T { kind: "icon"; anchors.centerIn: parent; text: modelData.g; font.pixelSize: 16; color: tile.on ? M3.inkPrimary : "#F6F5F4" }
                        }
                        Column {
                            x: 66; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 66 - 60
                            spacing: 2
                            T { text: modelData.n; font.pixelSize: 13; font.bold: true; width: parent.width; elide: Text.ElideRight }
                            T {
                                kind: "reading"
                                text: !tile.avail ? I18n.t("Not installed") : (tile.on ? I18n.t("On") : (modelData.offText || "Off"))
                                font.pixelSize: 11
                                color: M3.inkDim
                            }
                        }
                        Sw {
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            checked: tile.on
                        }
                        MouseArea {
                            id: tm
                            anchors.fill: parent
                            enabled: tile.avail
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.svSet(modelData.k, !tile.on)
                        }
                    }
                }
            }
            SliderRow {
                visible: page.sv.have && page.sv.have.hyprsunset === true
                label: I18n.t("Night light warmth")
                desc: I18n.t("Lower is warmer (more orange)")
                from: 2500; to: 6500; step: 100; unit: " K"
                value: page.sv.night_temp || 4500
                onCommitted: function(x) {
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" night-temp \"$1\"", "_", String(Math.round(x))])
                    page.ctl.status = I18n.t("Night light: ") + Math.round(x) + " K"
                }
            }

            // gaming mode lives in its own page now: Gaming hub
            SettingRow {
                label: I18n.t("Gaming mode")
                desc: I18n.t("Moved to Gaming hub, with performance and your game launchers")
                reserved: 120
                Btn { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Open"); onClicked: page.ctl.page = 16 }
            }

            SectionTitle { text: I18n.t("System services"); sub: I18n.t("Background services. Start and stop ask for your password for system services.") }
            Repeater {
                model: page.sv.units || []
                delegate: Rectangle {
                    width: col.width
                    height: 64
                    radius: 14
                    color: M3.surfaceC
                    border.width: 1
                    border.color: M3.outlineVariant
                    Rectangle {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 4.5
                        color: modelData.active ? "#7bd88f" : M3.primary
                    }
                    Column {
                        x: 38; anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Row {
                            spacing: 8
                            T { text: modelData.label; font.pixelSize: 14; font.bold: true }
                            T { kind: "mono"; text: modelData.name; font.pixelSize: 10; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                        T { kind: "reading"; text: (modelData.active ? I18n.t("Running") : I18n.t("Stopped")) + "  ·  " + modelData.desc; font.pixelSize: 11; color: M3.inkDim }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Btn {
                            text: page.busy === modelData.name ? "..." : (modelData.active ? I18n.t("Stop") : I18n.t("Start"))
                            onClicked: page.unit(modelData.name, modelData.active ? "stop" : "start")
                        }
                        Btn {
                            visible: modelData.active
                            text: I18n.t("Restart")
                            onClicked: page.unit(modelData.name, "restart")
                        }
                    }
                }
            }
            T {
                visible: (page.sv.units || []).length === 0
                text: I18n.t("No services found (systemd is needed for this list).")
                font.pixelSize: 12
                color: M3.inkDim
            }

            SettingRow {
                label: I18n.t("Fonts")
                desc: I18n.t("Moved to Appearance > Fonts, with samples")
                reserved: 120
                Btn { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Open"); onClicked: page.ctl.page = 19 }
            }

            T { kind: "title"; text: I18n.t("Autostart"); font.pixelSize: 16; font.bold: true; topPadding: 18 }

            AutostartPage { width: parent.width; ctl: page.ctl }
        }
    }

    component Sw: Rectangle {
        property bool checked: false
        width: 40; height: 22; radius: 11
        color: checked ? M3.primary : M3.surfaceHighest
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: parent.checked ? parent.width - width - 3 : 3
            color: parent.checked ? M3.inkPrimary : M3.inkDim
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
}
