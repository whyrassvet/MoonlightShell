import Quickshell
import QtQuick

// Settings > Appearance > Components: how the controls look (switch icons, slider and progress thickness, wavy
// progress, how round things are), each with a live sample you can play with.
Item {
    id: page
    property var ctl
    // the samples have their own state, they change nothing
    property bool demoOn: true
    property bool demoOff: false
    property real demoSlide: 0.6
    property bool box1: true
    property bool box2: false
    property int radioSel: 0
    property var filters: ({ Music: true, Videos: false, Games: true })
    property real prog: 0.0
    Timer { interval: 60; running: page.visible; repeat: true; onTriggered: page.prog = page.prog >= 1 ? 0 : page.prog + 0.004 }

    PageScroll {
        anchors.fill: parent

        // ---------- switches ----------
        SectionTitle { text: I18n.t("Selection"); sub: I18n.t("Switches, check boxes, radio buttons and filter chips.") }
        ToggleRow { label: I18n.t("Icons in switches"); desc: I18n.t("A check when on, a cross when off"); checked: Prefs.switchIcons; onToggled: function(v) { Prefs.setSwitchIcons(v) } }
        Rectangle {
            width: parent.width; height: 76; radius: M3.rL; color: M3.stageTop
            Row {
                anchors.centerIn: parent
                spacing: 22
                Tog { anchors.verticalCenter: parent.verticalCenter; checked: page.demoOn; onToggled: function(v) { page.demoOn = v } }
                Tog { anchors.verticalCenter: parent.verticalCenter; checked: page.demoOff; onToggled: function(v) { page.demoOff = v } }
                // check boxes
                Repeater {
                    model: [{ k: "box1", n: "Checkbox" }, { k: "box2", n: "Another" }]
                    delegate: Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool on: page[modelData.k]
                        Rectangle {
                            width: 20; height: 20; radius: 5 * M3.shapeK + 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: parent.on ? M3.primary : "transparent"
                            border.width: parent.on ? 0 : 2; border.color: M3.outline
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Icon { anchors.centerIn: parent; name: "check"; glyph: ""; size: 14; color: M3.inkPrimary; scale: parent.parent.on ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: M3.d(220); easing.type: M3.springy; easing.overshoot: 2 * Prefs.bounce } } }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: page[modelData.k] = !page[modelData.k] }
                        }
                        T { text: modelData.n; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                // radio buttons
                Repeater {
                    model: ["Radio", "Other"]
                    delegate: Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"; border.width: 2; border.color: page.radioSel === index ? M3.primary : M3.outline
                            Rectangle { anchors.centerIn: parent; width: page.radioSel === index ? 10 : 0; height: width; radius: width / 2; color: M3.primary
                                Behavior on width { NumberAnimation { duration: M3.d(220); easing.type: M3.springy; easing.overshoot: 2 * Prefs.bounce } } }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: page.radioSel = index }
                        }
                        T { text: modelData; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        // filter chips
        Rectangle {
            width: parent.width; height: 64; radius: M3.rL; color: M3.surfaceC
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                spacing: 8
                T { text: I18n.t("Filter chips"); font.pixelSize: 13; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter; rightPadding: 8 }
                Repeater {
                    model: Object.keys(page.filters)
                    delegate: Rectangle {
                        readonly property bool on: page.filters[modelData] === true
                        height: 34; width: fr.implicitWidth + 28; radius: 10 * M3.shapeK
                        anchors.verticalCenter: parent.verticalCenter
                        color: on ? M3.secondaryContainer : "transparent"
                        border.width: on ? 0 : 1; border.color: M3.outline
                        Behavior on width { NumberAnimation { duration: M3.d(200); easing.type: Easing.OutCubic } }
                        Row {
                            id: fr; anchors.centerIn: parent; spacing: 6
                            Icon { visible: parent.parent.on; name: "check"; glyph: ""; size: 15; color: M3.inkSecondaryC; anchors.verticalCenter: parent.verticalCenter }
                            T { text: modelData; font.pixelSize: 13; color: parent.parent.on ? M3.inkSecondaryC : M3.ink; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { const n = Object.assign({}, page.filters); n[modelData] = !n[modelData]; page.filters = n } }
                    }
                }
            }
        }

        // ---------- shape: now on its own page ----------
        SettingRow {
            label: I18n.t("Corners and shapes")
            desc: I18n.t("How round things are, and your shape: Appearance > Shapes")
            reserved: 140
            Btn { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Shapes"); sym: "interests"; icon: ""; onClicked: page.ctl.page = 24 }
        }

        // ---------- sliders ----------
        SectionTitle { text: I18n.t("Sliders"); sub: I18n.t("Thicker tracks are easier to grab on a touchpad.") }
        SliderRow {
            label: I18n.t("Slider thickness")
            desc: "×" + Number(Prefs.sliderThick).toFixed(1)
            from: 0.6; to: 1.6; step: 0.1; decimals: 1; unit: "×"
            value: Prefs.sliderThick
            onCommitted: function(v) { Prefs.setSliderThick(v) }
        }
        Rectangle {
            width: parent.width; height: 70; radius: M3.rL; color: M3.stageTop
            Row {
                anchors.centerIn: parent
                spacing: 16
                Icon { name: "volume_down"; glyph: ""; size: 20; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                Slide { width: Math.min(420, page.width - 200); from: 0; to: 1; step: 0.01; value: page.demoSlide; anchors.verticalCenter: parent.verticalCenter
                    onReleased: function(v) { page.demoSlide = v } }
                Icon { name: "volume_up"; glyph: ""; size: 20; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ---------- progress ----------
        SectionTitle { text: I18n.t("Progress indicators"); sub: I18n.t("Music, loaders and gauges. The wave calms down near 0 % and 100 %.") }
        Row {
            spacing: 8
            Btn { text: I18n.t("Reset components"); sym: "restart_alt"; icon: ""; variant: "text"
                onClicked: { Prefs.setSwitchIcons(true); Prefs.setSliderThick(1); Prefs.setWavy(true); Prefs.setProgressThick(4) } }
        }
        ToggleRow { label: I18n.t("Wavy progress"); desc: I18n.t("Off: flat lines everywhere"); checked: Prefs.wavy; onToggled: function(v) { Prefs.setWavy(v) } }
        SliderRow {
            label: I18n.t("Thickness")
            desc: I18n.t("Of progress lines and rings")
            from: 2; to: 8; step: 1; unit: " px"
            value: Prefs.progressThick
            onCommitted: function(v) { Prefs.setProgressThick(v) }
        }
        Rectangle {
            width: parent.width; height: 150; radius: M3.rL; color: M3.stageTop
            Column {
                x: 22; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 150
                spacing: 12
                WavyBar { width: parent.width; height: 20; value: page.prog }
                WavyBar { width: parent.width; height: 20; value: 0.62; color: M3.tertiary }
                WavyBar { width: parent.width; height: 20; value: 0.97; color: M3.secondary }
            }
            Column {
                anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                WavyRing { width: 48; height: 48 }
                WavyRing { width: 48; height: 48; value: page.prog; color: M3.tertiary }
            }
        }

        // ---------- buttons ----------
        SectionTitle { text: I18n.t("Buttons"); sub: I18n.t("Filled for the main action, tonal for the rest, outlined and text for quiet ones.") }
        Rectangle {
            width: parent.width; height: bflow.implicitHeight + 36; radius: M3.rL; color: M3.surfaceC
            Flow {
                id: bflow
                x: 18; y: 18; width: parent.width - 36
                spacing: 10
                Btn { text: I18n.t("Filled"); variant: "filled"; sym: "add"; icon: "+" }
                Btn { text: I18n.t("Tonal"); sym: "tune"; icon: "" }
                Btn { text: I18n.t("Outlined"); variant: "outlined" }
                Btn { text: I18n.t("Text"); variant: "text" }
                Btn { text: I18n.t("Delete"); variant: "danger"; sym: "delete"; icon: "" }
                // icon buttons and a floating action button
                Repeater {
                    model: [{ s: "favorite", g: "" }, { s: "share", g: "" }]
                    delegate: Rectangle {
                        width: 40; height: 40; radius: im.pressed ? 12 : 20
                        color: index === 0 ? M3.primary : M3.surfaceHighest
                        Behavior on radius { NumberAnimation { duration: 160 } }
                        Icon { anchors.centerIn: parent; name: modelData.s; glyph: modelData.g; size: 18; filled: index === 0; color: index === 0 ? M3.inkPrimary : M3.ink }
                        MouseArea { id: im; anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                    }
                }
                Rectangle {
                    width: 56; height: 56; radius: fm.pressed ? 28 : 16 * M3.shapeK
                    color: M3.primaryContainer
                    Behavior on radius { NumberAnimation { duration: M3.d(260); easing.type: M3.springy; easing.overshoot: 1.6 * Prefs.bounce } }
                    Icon { anchors.centerIn: parent; name: "edit"; glyph: ""; size: 22; color: M3.inkPrimaryC }
                    MouseArea { id: fm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
