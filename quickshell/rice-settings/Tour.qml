import QtQuick

// The tour (after the welcome intro, from System > Keybinds > Show me around, or: rice-welcome tour).
// Material 3: the window dims, one part gets a glowing outline, and a dialog card explains it, with a picture
// for the parts that live on the desktop (the Dynamic island). Steps can open a page of Settings first.
//   steps: [{ page, rect: function() -> {x, y, w, h} (or nothing: the card in the middle), r, icon, art, spot,
//             title, body }]
//   art: "welcome" | "island" | "islandCard" | "keys"     spot: "island" (the screen's dim leaves the island lit)
Item {
    id: tour
    property var steps: []
    property var nav: null                   // the Settings window (to open pages)
    property int index: 0
    property bool active: false
    readonly property var step: steps.length > 0 ? steps[Math.min(index, steps.length - 1)] : null
    readonly property bool lit: !!(step && step.rect)
    readonly property string spot: active && step && step.spot ? step.spot : ""
    signal finished()
    readonly property bool sfxOwn: true     // Next and Done make their own sounds

    anchors.fill: parent
    visible: opacity > 0.01
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    z: 100

    // the lit part (window coordinates); it glides from one part to the next (emphasized decelerate)
    property real tx: width / 2
    property real ty: height / 2
    property real tw: 0
    property real th: 0
    property real tr: 16
    readonly property var ease: [0.05, 0.7, 0.1, 1, 1, 1]
    Behavior on tx { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
    Behavior on ty { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
    Behavior on tw { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
    Behavior on th { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
    Behavior on tr { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }

    function place() {
        if (!step) return
        if (step.page !== undefined && nav && nav.page !== step.page) nav.page = step.page
        if (step.rect) {
            const r = step.rect()
            tx = r.x; ty = r.y; tw = r.w; th = r.h; tr = step.r !== undefined ? step.r : 16
        } else {
            // nothing lit: the light shrinks into the middle, under the card
            tx = width / 2; ty = height / 2; tw = 0; th = 0; tr = 0
        }
        settle.restart()
    }
    // a page that just opened moves for a moment: look again when it stands still
    Timer { id: settle; interval: 420; onTriggered: if (tour.active && tour.step && tour.step.rect) {
        const r = tour.step.rect(); tour.tx = r.x; tour.ty = r.y; tour.tw = r.w; tour.th = r.h } }
    function start() {
        Sfx.play("intro/tip")
        index = 0
        place()
        active = true
        swap.restart()
        keys.forceActiveFocus()
    }
    function go(i) {
        if (i < 0 || i >= steps.length) return
        Sfx.play("intro/tip")
        index = i
        place()
        swap.restart()
    }
    function next() {
        if (index >= steps.length - 1) { Sfx.play("done"); stop(); return }
        go(index + 1)
    }
    function back() { go(index - 1) }
    function stop() {
        if (!active) return
        active = false
        Sfx.music(false)        // the quiet music from the welcome intro ends with the tour
        finished()
    }

    // ---- the dim around the lit part: one rectangle with a very thick border and a rounded hole
    readonly property real bw: 3000
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            x: tour.tx - tour.bw; y: tour.ty - tour.bw
            width: tour.tw + 2 * tour.bw; height: tour.th + 2 * tour.bw
            radius: tour.tr + tour.bw
            color: "transparent"
            border.width: tour.bw
            border.color: Qt.rgba(0, 0, 0, 0.62)
        }
    }
    // clicks outside the card do nothing while the tour is on
    MouseArea { anchors.fill: parent; enabled: tour.active; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = true } }

    // ---- the outline of the lit part, in your key color
    Rectangle {
        visible: tour.tw > 2
        x: tour.tx - 4; y: tour.ty - 4
        width: tour.tw + 8; height: tour.th + 8
        radius: tour.tr + 4
        color: "transparent"
        border.width: 3
        border.color: M3.primary
        SequentialAnimation on opacity {
            running: tour.active; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.5; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.5; to: 1; duration: 1200; easing.type: Easing.InOutSine }
        }
    }
    Rectangle {
        visible: tour.tw > 2
        x: tour.tx - 12; y: tour.ty - 12
        width: tour.tw + 24; height: tour.th + 24
        radius: tour.tr + 12
        color: "transparent"
        border.width: 8
        border.color: M3.alpha(M3.primary, 0.14)
    }

    // ---- the dialog card
    Rectangle {
        id: bubble
        width: tour.step && tour.step.art ? 400 : 360
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        height: bcol.implicitHeight + 48
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        radius: 28 * M3.shapeK
        color: M3.surfaceHigh
        // a soft shadow under it
        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -1; anchors.topMargin: 3; radius: parent.radius + 1; color: Qt.rgba(0, 0, 0, 0.35) }
        readonly property bool onRight: tour.lit && tour.tx + tour.tw + 28 + width <= tour.width - 16
        readonly property bool onLeft: tour.lit && !onRight && tour.tx - 28 - width >= 16
        x: !tour.lit ? (tour.width - width) / 2
           : onRight ? tour.tx + tour.tw + 28
           : onLeft ? tour.tx - 28 - width
           : Math.max(16, Math.min(tour.width - width - 16, tour.tx + tour.tw / 2 - width / 2))
        y: !tour.lit ? (tour.height - height) / 2
           : (onRight || onLeft) ? Math.max(16, Math.min(tour.height - height - 16, tour.ty + Math.min(tour.th, 160) / 2 - 50))
           : (tour.ty + tour.th + 28 + height <= tour.height - 16 ? tour.ty + tour.th + 28 : Math.max(16, tour.ty - 28 - height))
        Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }

        Column {
            id: bcol
            x: 24; y: 24
            width: parent.width - 48
            spacing: 14
            // a new step: the words come in from the side
            opacity: 1
            transform: Translate { id: slide; x: 0 }
            SequentialAnimation {
                id: swap
                PropertyAction { target: bcol; property: "opacity"; value: 0 }
                PropertyAction { target: slide; property: "x"; value: 18 }
                PauseAnimation { duration: 90 }
                ParallelAnimation {
                    NumberAnimation { target: bcol; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 360; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease }
                }
            }

            // icon and where you are
            Row {
                spacing: 12
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: M3.secondaryContainer
                    Icon { anchors.centerIn: parent; name: tour.step && tour.step.icon ? tour.step.icon : "lightbulb"; glyph: ""; size: 20; color: M3.inkSecondaryC }
                }
                T { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Step ") + (tour.index + 1) + I18n.t(" of ") + tour.steps.length
                    font.pixelSize: 12; font.weight: Font.Medium; color: M3.inkDim }
            }

            // the picture (parts that are not in this window)
            Rectangle {
                visible: !!(tour.step && tour.step.art)
                width: parent.width
                height: visible ? 150 : 0
                radius: 20 * M3.shapeK
                color: M3.surfaceLowest
                clip: true
                Loader {
                    anchors.fill: parent
                    sourceComponent: !tour.step || !tour.step.art ? null
                        : tour.step.art === "island" ? artIsland
                        : tour.step.art === "islandCard" ? artCard
                        : tour.step.art === "keys" ? artKeys : artWelcome
                }
            }

            T { text: tour.step ? tour.step.title : ""; kind: "title"; font.pixelSize: 22; font.weight: Font.Medium
                width: parent.width; wrapMode: Text.WordWrap }
            T { text: tour.step ? tour.step.body : ""; font.pixelSize: 14; color: M3.inkDim; width: parent.width
                wrapMode: Text.WordWrap; lineHeight: 1.2 }

            // progress (Material 3 linear indicator)
            Item {
                width: parent.width; height: 4
                Rectangle { anchors.fill: parent; radius: 2; color: M3.outlineVariant }
                Rectangle {
                    width: Math.max(8, parent.width * (tour.index + 1) / Math.max(1, tour.steps.length)); height: 4; radius: 2
                    color: M3.primary
                    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: tour.ease } }
                }
            }

            // buttons: Skip (text) ... Back (outlined) Next (filled)
            Item {
                width: parent.width
                height: 40
                Rectangle {
                    visible: tour.index < tour.steps.length - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: skipT.implicitWidth + 24; height: 40; radius: 20
                    color: skipM.containsMouse ? M3.alpha(M3.primary, 0.08) : "transparent"
                    T { id: skipT; anchors.centerIn: parent; text: I18n.t("Skip tour"); font.pixelSize: 14; font.weight: Font.Medium; color: M3.primary }
                    MouseArea { id: skipM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tour.stop() }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        visible: tour.index > 0
                        width: backT.implicitWidth + 36; height: 40; radius: 20
                        color: backM.containsMouse ? M3.alpha(M3.primary, 0.08) : "transparent"
                        border.width: 1; border.color: M3.outline
                        T { id: backT; anchors.centerIn: parent; text: I18n.t("Back"); font.pixelSize: 14; font.weight: Font.Medium; color: M3.primary }
                        MouseArea { id: backM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tour.back() }
                    }
                    Rectangle {
                        width: nextT.implicitWidth + 40; height: 40; radius: 20
                        color: nextM.containsMouse ? Qt.lighter(M3.primary, 1.08) : M3.primary
                        Behavior on color { ColorAnimation { duration: 120 } }
                        T {
                            id: nextT
                            anchors.centerIn: parent
                            text: tour.index === 0 ? I18n.t("Let's go") : (tour.index < tour.steps.length - 1 ? I18n.t("Next") : I18n.t("Done"))
                            font.pixelSize: 14; font.weight: Font.DemiBold; color: M3.inkPrimary
                        }
                        MouseArea { id: nextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tour.next() }
                    }
                }
            }
        }
    }

    // ---- pictures
    // the moon and a few stars
    Component {
        id: artWelcome
        Item {
            Repeater {
                model: [[0.12, 0.25, 3], [0.22, 0.7, 2], [0.8, 0.2, 2], [0.9, 0.62, 3], [0.68, 0.82, 2], [0.35, 0.15, 2]]
                Rectangle { x: parent.width * modelData[0]; y: parent.height * modelData[1]; width: modelData[2]; height: width; radius: width / 2
                    color: M3.inkDim; opacity: 0.7 }
            }
            MoonLogo { anchors.centerIn: parent; size: 132; running: tour.active }
        }
    }
    // the bar with the island in the middle, growing for a song
    Component {
        id: artIsland
        Item {
            id: ai
            property real grow: 0
            SequentialAnimation on grow {
                running: tour.active; loops: Animation.Infinite
                PauseAnimation { duration: 700 }
                NumberAnimation { to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                PauseAnimation { duration: 1800 }
                NumberAnimation { to: 0; duration: 380; easing.type: Easing.InOutCubic }
            }
            // the bar
            Rectangle {
                x: 16; width: parent.width - 32; height: 34; radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: M3.surfaceC
                border.width: 1; border.color: M3.outlineVariant
                Row { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Repeater { model: 4; Rectangle { width: index === 0 ? 18 : 7; height: 7; radius: 4; color: index === 0 ? M3.primary : M3.outline } } }
                Row { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Repeater { model: ["wifi", "volume_up", "battery_full"]; Icon { name: modelData; glyph: ""; size: 14; color: M3.inkDim } } }
            }
            // the island
            Rectangle {
                anchors.centerIn: parent
                width: 104 + 120 * ai.grow; height: 26 + 26 * ai.grow
                radius: height / 2
                color: "#050505"
                border.width: 1; border.color: M3.alpha(M3.primary, 0.5)
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Rectangle { visible: ai.grow > 0.5; opacity: ai.grow; width: 30; height: 30; radius: 9; color: M3.primary; anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "music_note"; glyph: ""; size: 16; color: M3.inkPrimary } }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        T { text: ai.grow > 0.5 ? I18n.t("Your song") : "18:22  ·  5°"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#F6F5F4" }
                        T { visible: ai.grow > 0.5; opacity: ai.grow; text: I18n.t("The artist"); font.pixelSize: 10; color: "#9a9aa2" }
                    }
                }
            }
            T { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("In the middle of your bar"); font.pixelSize: 11; color: M3.inkDim }
        }
    }
    // the island's card with its tabs
    Component {
        id: artCard
        Item {
            id: ac
            property int tab: 0
            Timer { running: tour.active; repeat: true; interval: 1400; onTriggered: ac.tab = (ac.tab + 1) % 4 }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 40; height: parent.height - 24
                radius: 22
                color: "#0b0b0c"
                border.width: 1; border.color: M3.outlineVariant
                Row {
                    id: tabs
                    anchors.horizontalCenter: parent.horizontalCenter; y: 12
                    spacing: 4
                    Repeater {
                        model: [["Today", "calendar_today"], ["System", "memory"], ["About", "info"], ["Music", "music_note"]]
                        Rectangle {
                            width: tl.implicitWidth + 36; height: 28; radius: 14
                            color: index === ac.tab ? M3.primary : "transparent"
                            Behavior on color { ColorAnimation { duration: 220 } }
                            Row { anchors.centerIn: parent; spacing: 4
                                Icon { name: modelData[1]; glyph: ""; size: 13; color: index === ac.tab ? M3.inkPrimary : "#c8c8cc"; anchors.verticalCenter: parent.verticalCenter }
                                T { id: tl; text: modelData[0]; font.pixelSize: 11; font.weight: Font.DemiBold; color: index === ac.tab ? M3.inkPrimary : "#c8c8cc" } }
                        }
                    }
                }
                T {
                    anchors.horizontalCenter: parent.horizontalCenter; y: tabs.y + 44
                    width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    font.pixelSize: 12; color: "#c8c8cc"
                    text: ["Calendar, weather and the day", "CPU, GPU and memory, live", "Your computer and updates", "What plays now, with its controls"][ac.tab]
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    spacing: 14
                    T { text: I18n.t("Left click: Today"); font.pixelSize: 10; color: M3.inkDim }
                    T { text: I18n.t("Right click: System"); font.pixelSize: 10; color: M3.inkDim }
                    T { text: I18n.t("Wheel: volume"); font.pixelSize: 10; color: M3.inkDim }
                }
            }
        }
    }
    // a few keys
    Component {
        id: artKeys
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: [["Super", "Return", "Terminal"], ["Super", nav && nav.niri ? "D" : "R", "Apps"], ["Super", "U", "Settings"]]
                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        Repeater {
                            model: [modelData[0], "+", modelData[1]]
                            Rectangle {
                                readonly property bool plus: modelData === "+"
                                width: plus ? 10 : kt.implicitWidth + 20; height: 28; radius: 8
                                color: plus ? "transparent" : M3.surfaceHighest
                                border.width: plus ? 0 : 1; border.color: M3.outlineVariant
                                T { id: kt; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; font.weight: Font.DemiBold
                                    color: parent.plus ? M3.inkDim : M3.ink }
                            }
                        }
                        T { text: "  " + modelData[2]; font.pixelSize: 13; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter; width: 80 }
                    }
                }
            }
        }
    }

    Item {
        id: keys
        focus: tour.active
        Keys.onEscapePressed: tour.stop()
        Keys.onReturnPressed: tour.next()
        Keys.onEnterPressed: tour.next()
        Keys.onRightPressed: tour.next()
        Keys.onSpacePressed: tour.next()
        Keys.onLeftPressed: tour.back()
    }
}
