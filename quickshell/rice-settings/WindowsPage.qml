import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Desktop > Windows: borders, corners and shadows of your windows (Hyprland, applied live), and the
// shell's own soft shadows under the bar, panels, widgets and notifications.
Item {
    id: page
    property var ctl
    function hv(k, d) { return page.ctl && page.ctl.hv[k] !== undefined ? page.ctl.hv[k] : d }

    property var sh: ({ enabled: true, bar: true, panels: true, widgets: true, notifications: true, size: 18, strength: 45 })
    Process {
        id: shProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-shadows\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.sh = JSON.parse(text) } catch (e) { } } }
    }
    function setSh(k, v) {
        const n = Object.assign({}, sh); n[k] = v; sh = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-shadows\" set \"$1\" \"$2\"", "_", k, typeof v === "boolean" ? (v ? "on" : "off") : String(v)])
        page.ctl.status = I18n.t("Shell shadows saved")
    }

    // a section header with an icon in a soft shape, like the rest of the redesigned pages
    component Head: Row {
        property string icon: ""
        property string glyph: ""
        property string title: ""
        property string sub: ""
        spacing: 14
        topPadding: 16
        Item {
            width: 40; height: 40
            Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.secondaryContainer }
            Icon { anchors.centerIn: parent; name: parent.parent.icon; glyph: parent.parent.glyph; size: 18; color: M3.inkSecondaryC }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            T { kind: "title"; text: parent.parent.title; font.pixelSize: 17; font.weight: Font.DemiBold }
            T { kind: "reading"; text: parent.parent.sub; font.pixelSize: 12; color: M3.inkDim }
        }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- a live sample ----------
        Rectangle {
            width: parent.width; height: 150; radius: M3.rXL
            gradient: Gradient { GradientStop { position: 0; color: M3.stageTop } GradientStop { position: 1; color: M3.stageBottom } }
            clip: true
            readonly property real rr: page.hv("decoration.rounding", 10)
            readonly property real bs: page.hv("general.border_size", 2)
            readonly property bool shOn: page.hv("decoration.shadow.enabled", true)
            readonly property real shR: page.hv("decoration.shadow.range", 4)
            Repeater {
                model: 2
                delegate: Item {
                    x: index === 0 ? 40 : parent.width / 2 + 10; y: 24
                    width: parent.width / 2 - 50; height: 102
                    Repeater {
                        model: parent.parent.shOn ? 5 : 0
                        delegate: Rectangle {
                            readonly property real k: (index + 1) / 5
                            readonly property real sz: Math.min(30, parent.parent.parent.shR) * k
                            x: -sz; y: -sz + 3; width: parent.width + 2 * sz; height: parent.height + 2 * sz
                            radius: parent.parent.parent.rr + sz
                            color: Qt.rgba(0, 0, 0, page.ctl.hShadowInt / 100 * 0.18 * (1 - k * 0.8))
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.parent.rr
                        color: M3.surfaceC
                        border.width: Math.min(6, parent.parent.bs); border.color: index === 0 ? M3.primary : M3.outlineVariant
                        Row { x: 12; y: 10; spacing: 6
                            Repeater { model: 3; delegate: Rectangle { width: 9; height: 9; radius: 5; color: M3.alpha(M3.ink, 0.25) } } }
                        T { x: 14; y: 34; text: index === 0 ? I18n.t("Focused window") : I18n.t("Other window"); font.pixelSize: 13; font.weight: Font.Medium }
                    }
                }
            }
        }

        // ---------- borders and corners ----------
        Head { icon: "rounded_corner"; glyph: ""; title: I18n.t("Borders and corners"); sub: I18n.t("Applied live to ") + (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(" windows") }
        SliderRow {
            label: I18n.t("Border thickness"); desc: I18n.t("0 hides the border")
            from: 0; to: 8; step: 1; unit: " px"
            value: page.hv("general.border_size", 2)
            onCommitted: function(v) { page.ctl.hset("general.border_size", Math.round(v)) }
        }
        SliderRow {
            label: I18n.t("Corner rounding"); desc: I18n.t("Radius of window corners")
            from: 0; to: 30; step: 1; unit: " px"
            value: page.hv("decoration.rounding", 10)
            onCommitted: function(v) { page.ctl.hset("decoration.rounding", Math.round(v)) }
        }

        // ---------- window shadows ----------
        Head { icon: "shadow"; glyph: ""; title: I18n.t("Shadows"); sub: I18n.t("Drawn by ") + (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(" behind each window") }
        ToggleRow {
            label: I18n.t("Shadows"); desc: I18n.t("A soft shadow behind windows")
            checked: page.hv("decoration.shadow.enabled", true) === true
            onToggled: function(v) { page.ctl.hset("decoration.shadow.enabled", v) }
        }
        SliderRow {
            label: I18n.t("Thickness"); desc: I18n.t("How far the shadow reaches")
            from: 0; to: 60; step: 1; unit: " px"
            value: page.hv("decoration.shadow.range", 4)
            onCommitted: function(v) { page.ctl.hset("decoration.shadow.range", Math.round(v)) }
        }
        SliderRow {
            label: I18n.t("Intensity"); desc: I18n.t("How dark the shadow is")
            from: 0; to: 100; step: 5; unit: " %"
            value: page.ctl ? page.ctl.hShadowInt : 60
            onCommitted: function(v) { page.ctl.hShadowInt = Math.round(v); page.ctl.hrun(["shadow-intensity", Math.round(v)], "Shadow strength: " + Math.round(v) + " %") }
        }

        // ---------- shell shadows ----------
        Head { icon: "layers"; glyph: ""; title: I18n.t("Shell shadows"); sub: I18n.t("Under the bar, panels, widgets and notifications; drawn by the shell itself") }
        ToggleRow { label: I18n.t("Enable shell shadows"); desc: I18n.t("All of the ones below"); checked: page.sh.enabled !== false; onToggled: function(v) { page.setSh("enabled", v) } }
        ToggleRow { label: I18n.t("Bar"); desc: I18n.t("Under the bar, its notch and the recording island"); checked: page.sh.bar !== false; onToggled: function(v) { page.setSh("bar", v) } }
        ToggleRow { label: I18n.t("Panels and pop-ups"); desc: I18n.t("The control center, the game bar and the menus of the bar"); checked: page.sh.panels !== false; onToggled: function(v) { page.setSh("panels", v) } }
        ToggleRow { label: I18n.t("Desktop widgets"); desc: I18n.t("Under the widget cards"); checked: page.sh.widgets !== false; onToggled: function(v) { page.setSh("widgets", v) } }
        ToggleRow { label: I18n.t("Notifications"); desc: I18n.t("Under notification pop-ups"); checked: page.sh.notifications !== false; onToggled: function(v) { page.setSh("notifications", v) } }
        SliderRow {
            label: I18n.t("Thickness"); desc: I18n.t("How far shell shadows reach")
            from: 4; to: 40; step: 1; unit: " px"
            value: page.sh.size !== undefined ? page.sh.size : 18
            onCommitted: function(v) { page.setSh("size", Math.round(v)) }
        }
        SliderRow {
            label: I18n.t("Intensity"); desc: I18n.t("How dark shell shadows are")
            from: 0; to: 100; step: 5; unit: " %"
            value: page.sh.strength !== undefined ? page.sh.strength : 45
            onCommitted: function(v) { page.setSh("strength", Math.round(v)) }
        }
    }
}
