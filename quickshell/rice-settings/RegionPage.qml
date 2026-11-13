import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Sound & language > Language & region: the clock (24 or 12 hours), °C or °F, the first day of the
// week, and the language you prefer (rice-region).
Item {
    id: page
    property var ctl
    property var rg: ({ clock: "24", units: "c", week: "mon", lang: "en" })
    Process {
        id: st
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-region\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.rg = JSON.parse(text) } catch (e) { } } }
    }
    function set(k, v) {
        const n = Object.assign({}, rg); n[k] = v; rg = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-region\" set \"$1\" \"$2\"", "_", k, v])
        page.ctl.status = I18n.t("Saved")
    }
    property var now: new Date()
    Timer { interval: 1000; running: page.visible; repeat: true; onTriggered: page.now = new Date() }
    function two(n) { return n < 10 ? "0" + n : "" + n }
    readonly property string clockText: rg.clock === "12"
        ? ((now.getHours() + 11) % 12 + 1) + ":" + two(now.getMinutes()) + (now.getHours() < 12 ? " AM" : " PM")
        : two(now.getHours()) + ":" + two(now.getMinutes())

    PageScroll {
        anchors.fill: parent

        // ---------- the clock as you will see it ----------
        Rectangle {
            width: parent.width; height: 150; radius: M3.rXL; color: M3.primaryContainer
            clip: true
            Item {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 110; height: 110
                Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.alpha(M3.primary, 0.3)
                    RotationAnimator on rotation { from: 0; to: 360; duration: 30000; loops: Animation.Infinite; running: page.visible } }
                Icon { anchors.centerIn: parent; name: "language"; glyph: ""; size: 40; color: M3.inkPrimaryC }
            }
            Column {
                x: 160; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                T { text: I18n.t("LANGUAGE & REGION"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "number"; text: page.clockText; font.pixelSize: 34; font.weight: Font.Medium; color: M3.inkPrimaryC }
                T { text: page.now.toLocaleDateString(I18n.loc, "dddd, d MMMM") + "  ·  " + (page.rg.units === "f" ? "41°F" : "5°C") + I18n.t(" outside (example)")
                    font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85) }
            }
        }

        SectionTitle { text: I18n.t("Region"); sub: I18n.t("How times, temperatures and calendars look in the shell.") }
        SegRow {
            label: I18n.t("Clock format"); desc: I18n.t("The bar, the game bar and the desktop")
            options: [{ label: "24 h", value: "24" }, { label: "12 h", value: "12" }]
            current: page.rg.clock
            onChosen: function(x) { page.set("clock", x) }
        }
        SegRow {
            label: I18n.t("Temperature"); desc: I18n.t("Weather widgets and the lock screen")
            options: [{ label: I18n.t("Celsius °C"), value: "c" }, { label: I18n.t("Fahrenheit °F"), value: "f" }]
            current: page.rg.units
            onChosen: function(x) { page.set("units", x) }
        }
        SegRow {
            label: I18n.t("First day of the week"); desc: I18n.t("Calendars")
            options: [{ label: I18n.t("Monday"), value: "mon" }, { label: I18n.t("Sunday"), value: "sun" }]
            current: page.rg.week
            onChosen: function(x) { page.set("week", x) }
        }

        SettingRow {
            label: I18n.t("Language")
            desc: I18n.t("Change the language of Settings and the shell")
            reserved: 120
            Btn { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Open"); onClicked: page.ctl.page = 31 }
        }
    }
}
