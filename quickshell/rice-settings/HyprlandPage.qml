import Quickshell
import QtQuick

Item {
    id: page
    property var ctl
    property int tab: 0
    property bool confirmReset: false

    // animations moved to Settings > Motion
    // niri runs the shell: the same page sets niri (rice-niri writes its config); Hyprland-only options are hidden
    readonly property bool niri: !!Quickshell.env("NIRI_SOCKET")
    readonly property string wmName: niri ? "niri" : "Hyprland"
    readonly property var niriKeys: ["general.gaps_in", "general.gaps_out", "general.border_size", "decoration.rounding",
        "decoration.active_opacity", "decoration.inactive_opacity", "decoration.shadow.enabled", "decoration.shadow.range",
        "decoration.blur.enabled", "decoration.blur.size", "decoration.blur.passes", "decoration.blur.noise", "decoration.blur.vibrancy"]
    function fit(specs) { return niri ? specs.filter(x => niriKeys.indexOf(x.key) >= 0) : specs }
    readonly property var tabs: niri ? ["Gaps", "Borders", "Rounding & Opacity", "Blur", "Keybinds", "Monitors"]
                                     : ["Gaps", "Borders", "Layout", "Rounding & Opacity", "Blur", "Keybinds", "Monitors"]
    readonly property var comps: niri ? [gapsC, bordersC, roundC, blurC, bindsC, monC] : [gapsC, bordersC, layoutC, roundC, blurC, bindsC, monC]

    readonly property var gapsSpec: [
        { key: "general.gaps_in", type: "slider", label: I18n.t("Inner gaps"), desc: I18n.t("Gaps between windows"), min: 0, max: 40, step: 1, unit: " px", def: 5 },
        { key: "general.gaps_out", type: "slider", label: I18n.t("Outer gaps"), desc: I18n.t("Gaps between windows and the screen edges"), min: 0, max: 80, step: 1, unit: " px", def: 5 },
        { key: "general.gaps_workspaces", type: "slider", label: I18n.t("Workspace gaps"), desc: I18n.t("Gaps between workspaces"), min: 0, max: 100, step: 1, unit: " px", def: 0 }
    ]
    readonly property var bordersSpec: [
        { key: "general.border_size", type: "slider", label: I18n.t("Border size"), desc: I18n.t("Thickness of window borders"), min: 0, max: 12, step: 1, unit: " px", def: 2 },
        { key: "general.resize_on_border", type: "toggle", label: I18n.t("Resize on border"), desc: I18n.t("Drag borders and gaps to resize windows") },
        { key: "general.extend_border_grab_area", type: "slider", label: I18n.t("Border grab area"), desc: I18n.t("How far from the border you can grab it"), min: 0, max: 60, step: 1, unit: " px", def: 15 },
        { key: "general.hover_icon_on_border", type: "toggle", label: I18n.t("Cursor icon on border"), desc: I18n.t("Show a resize cursor over borders") }
    ]
    readonly property var layoutSpec: [
        { key: "general.layout", type: "seg", label: I18n.t("Layout"), desc: I18n.t("How windows are arranged"),
          options: [{ label: I18n.t("Dwindle"), value: "dwindle" }, { label: I18n.t("Master"), value: "master" }, { label: I18n.t("Scrolling"), value: "scrolling" }, { label: I18n.t("Monocle"), value: "monocle" }] },
        { key: "dwindle.preserve_split", type: "toggle", label: I18n.t("Preserve split"), desc: I18n.t("Keep the split direction when windows close (Dwindle)") },
        { key: "general.snap.enabled", type: "toggle", label: I18n.t("Window magnet"), desc: I18n.t("Floating windows snap to each other and to the screen edges") },
        { key: "general.snap.window_gap", type: "slider", label: I18n.t("Magnet reach: windows"), desc: I18n.t("How close a window must come to snap to another"), min: 0, max: 60, step: 1, unit: " px", def: 10 },
        { key: "general.snap.monitor_gap", type: "slider", label: I18n.t("Magnet reach: screen edges"), desc: I18n.t("How close a window must come to snap to the edge"), min: 0, max: 60, step: 1, unit: " px", def: 10 },
        { key: "general.snap.border_overlap", type: "toggle", label: I18n.t("Overlap borders"), desc: I18n.t("Snapped windows share one border line instead of two") }
    ]
    readonly property var roundSpec: [
        { key: "decoration.rounding", type: "slider", label: I18n.t("Corner rounding"), desc: I18n.t("Radius of window corners"), min: 0, max: 40, step: 1, unit: " px", def: 10 },
        { key: "decoration.rounding_power", type: "slider", label: I18n.t("Rounding power"), desc: I18n.t("Curve of the corners (2 = circle, 4 = squircle)"), min: 2, max: 10, step: 0.5, dec: 1, def: 2 },
        { key: "decoration.active_opacity", type: "slider", label: I18n.t("Active window opacity"), desc: I18n.t("Opacity of the focused window"), min: 0.3, max: 1, step: 0.05, dec: 2, def: 1 },
        { key: "decoration.inactive_opacity", type: "slider", label: I18n.t("Inactive window opacity"), desc: I18n.t("Opacity of unfocused windows"), min: 0.3, max: 1, step: 0.05, dec: 2, def: 1 },
        { key: "decoration.dim_inactive", type: "toggle", label: I18n.t("Dim inactive windows"), desc: I18n.t("Darken windows that are not focused") },
        { key: "decoration.dim_strength", type: "slider", label: I18n.t("Dim strength"), desc: I18n.t("How dark inactive windows get"), min: 0, max: 1, step: 0.05, dec: 2, def: 0.5 },
        { key: "decoration.shadow.enabled", type: "toggle", label: I18n.t("Window shadows"), desc: I18n.t("Draw a shadow behind windows") },
        { key: "decoration.shadow.range", type: "slider", label: I18n.t("Shadow range"), desc: I18n.t("Size of the shadow"), min: 0, max: 60, step: 1, unit: " px", def: 4 },
        { key: "decoration.shadow.render_power", type: "slider", label: I18n.t("Shadow falloff"), desc: I18n.t("How fast the shadow fades (1 soft, 4 sharp)"), min: 1, max: 4, step: 1, def: 3 }
    ]
    readonly property var blurSpec: [
        { key: "decoration.blur.enabled", type: "toggle", label: I18n.t("Enable blur"), desc: I18n.t("Blur what is behind translucent windows and bars") },
        { key: "decoration.blur.size", type: "slider", label: I18n.t("Blur size"), desc: I18n.t("Radius of the blur"), min: 1, max: 30, step: 1, def: 8 },
        { key: "decoration.blur.passes", type: "slider", label: I18n.t("Blur passes"), desc: I18n.t("More passes look smoother but cost more"), min: 1, max: 8, step: 1, def: 2 },
        { key: "decoration.blur.noise", type: "slider", label: I18n.t("Noise"), desc: I18n.t("Film grain on the blurred area"), min: 0, max: 0.5, step: 0.01, dec: 2, def: 0.01 },
        { key: "decoration.blur.contrast", type: "slider", label: I18n.t("Contrast"), desc: I18n.t("Contrast of the blurred area"), min: 0, max: 2, step: 0.05, dec: 2, def: 0.89 },
        { key: "decoration.blur.brightness", type: "slider", label: I18n.t("Brightness"), desc: I18n.t("Brightness of the blurred area"), min: 0, max: 2, step: 0.05, dec: 2, def: 0.81 },
        { key: "decoration.blur.vibrancy", type: "slider", label: I18n.t("Vibrancy"), desc: I18n.t("Color saturation of the blur"), min: 0, max: 1, step: 0.05, dec: 2, def: 0.17 },
        { key: "decoration.blur.vibrancy_darkness", type: "slider", label: I18n.t("Vibrancy darkness"), desc: I18n.t("How much vibrancy darkens dark areas"), min: 0, max: 1, step: 0.05, dec: 2, def: 0 },
        { key: "decoration.blur.xray", type: "toggle", label: I18n.t("X-ray blur"), desc: I18n.t("Blur only the wallpaper, not other windows") },
        { key: "decoration.blur.ignore_opacity", type: "toggle", label: I18n.t("Ignore opacity"), desc: I18n.t("Blur fully even for very transparent windows") },
        { key: "decoration.blur.new_optimizations", type: "toggle", label: I18n.t("Optimizations"), desc: I18n.t("Faster blur rendering") },
        { key: "decoration.blur.popups", type: "toggle", label: I18n.t("Blur popups"), desc: I18n.t("Also blur menus and popups") }
    ]

    Flow {
        id: tabsFlow
        x: 24
        y: 4
        width: parent.width - 48
        spacing: 6
        Repeater {
            model: page.tabs
            delegate: Rectangle {
                width: tabText.implicitWidth + 24
                height: 30
                radius: 9
                color: page.tab === index ? M3.primary : (tabMouse.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                border.width: 1
                border.color: M3.surfaceHighest
                Behavior on color { ColorAnimation { duration: 140 } }
                T {
                    id: tabText
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 12
                    color: page.tab === index ? M3.inkPrimary : "#F6F5F4"
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.tab = index
                }
            }
        }
    }

    Flickable {
        id: flick
        x: 0
        y: tabsFlow.y + tabsFlow.height + 14
        width: parent.width
        height: parent.height - y - 52
        contentWidth: width
        contentHeight: contentLoader.height + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking && !flickWheel.active
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        WheelScroll { id: flickWheel; flick: flick }

        Loader {
            id: contentLoader
            x: 24
            width: flick.width - 48
            sourceComponent: page.comps[page.tab]
            onSourceComponentChanged: flick.contentY = 0
            onLoaded: tabFade.restart()
            ParallelAnimation {
                id: tabFade
                NumberAnimation { target: contentLoader; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                NumberAnimation { target: contentLoader; property: "y"; from: 14; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }
    }

    Row {
        x: 24
        y: parent.height - 42
        spacing: 8
        Pill { label: I18n.t("Reload ") + page.wmName; onClicked: page.ctl.hrun(["reload"], page.wmName + " reloaded") }
        Pill {
            label: page.confirmReset ? I18n.t("Click again to reset") : I18n.t("Reset everything")
            onClicked: {
                if (page.confirmReset) {
                    page.confirmReset = false
                    page.ctl.hrun(["reset-all"], "All changes reset")
                } else {
                    page.confirmReset = true
                    resetTimer.restart()
                }
            }
        }
    }
    Timer { id: resetTimer; interval: 4000; onTriggered: page.confirmReset = false }

    Component { id: gapsC; OptionsList { ctl: page.ctl; specs: page.fit(page.gapsSpec) } }

    Component {
        id: bordersC
        Column {
            spacing: 10
            OptionsList { width: parent.width; ctl: page.ctl; specs: page.fit(page.bordersSpec) }
            T { kind: "title"; text: I18n.t("Border colors"); font.pixelSize: 16; font.bold: true; topPadding: 8 }
            SegRow {
                width: parent.width
                label: I18n.t("Color source")
                desc: I18n.t("Follow the wallpaper or use your own colors")
                options: [{ label: I18n.t("Wallpaper"), value: "wallpaper" }, { label: I18n.t("Custom"), value: "custom" }]
                current: page.ctl.hb.mode
                onChosen: function(v) { page.ctl.setBorderMode(v) }
            }
            ColorRow {
                width: parent.width
                visible: page.ctl.hb.mode === "custom"
                label: I18n.t("Active border")
                desc: I18n.t("Border of the focused window")
                hex: page.ctl.hb.active
                onCommitted: function(h) { page.ctl.setBorderColor("active", h) }
            }
            ColorRow {
                width: parent.width
                visible: page.ctl.hb.mode === "custom"
                label: I18n.t("Inactive border")
                desc: I18n.t("Border of unfocused windows")
                hex: page.ctl.hb.inactive
                onCommitted: function(h) { page.ctl.setBorderColor("inactive", h) }
            }
        }
    }

    Component { id: layoutC; OptionsList { ctl: page.ctl; specs: page.layoutSpec } }
    Component { id: roundC; OptionsList { ctl: page.ctl; specs: page.fit(page.roundSpec) } }
    Component {
        id: blurC
        Column {
            spacing: 10
            T { visible: page.niri; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; opacity: 0.75
                text: I18n.t("niri blurs from version 26.04: the bar, panels, widgets and the terminal get it where they are see-through.") }
            OptionsList { width: parent.width; ctl: page.ctl; specs: page.fit(page.blurSpec) }
        }
    }

    Component {
        id: animC
        Column {
            spacing: 10
            ToggleRow {
                width: parent.width
                label: I18n.t("Animations")
                desc: I18n.t("Window, workspace and layer animations")
                checked: page.ctl.ha.enabled !== false
                onToggled: function(v) { page.ctl.setAnim("enabled", v) }
            }
            SliderRow {
                width: parent.width
                label: I18n.t("Animation speed")
                desc: I18n.t("100% keeps your current speeds; higher is faster")
                from: 50
                to: 200
                step: 10
                unit: " %"
                value: page.ctl.ha.speed !== undefined ? page.ctl.ha.speed : 100
                onCommitted: function(v) { page.ctl.setAnim("speed", Math.round(v)) }
            }
        }
    }

    Component { id: bindsC; BindsPage { ctl: page.ctl } }
    Component { id: monC; MonitorsPage { ctl: page.ctl } }
}