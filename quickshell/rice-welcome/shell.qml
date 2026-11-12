import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// The welcome intro, shown once after DarkShadow's Shell is installed (rice-welcome show plays it again).
// Night falls over the desktop from the middle of the screen, a few words rise letter by letter, the moon
// draws itself in, and "Take a look" opens the night up again from the moon. Then Settings opens with a
// short tour.
ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")
    property string distro: "Linux"
    property string version: ""
    property bool leaving: false

    // distro logo (Nerd Font "font logos"): the same ones as the bar and the dashboard
    property string glyph: ""
    readonly property var glyphs: ({
        nixos: "", arch: "", archarm: "", cachyos: "", endeavouros: "", manjaro: "",
        garuda: "", ubuntu: "", fedora: "", nobara: "", bazzite: "", ultramarine: "",
        debian: "", opensuse: "", gentoo: "", void: "", alpine: "", linuxmint: "", pop: ""
    })
    Process {
        command: ["bash", "-c", ". /etc/os-release 2>/dev/null; printf '%s\\n%s\\n' \"${NAME:-Linux}\" \"${ID:-linux} ${ID_LIKE:-}\"; tr -d ' \\r\\n' 2>/dev/null <\"$HOME/.config/rice/version\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                if ((l[0] || "").trim().length > 0) root.distro = l[0].trim()
                const ids = (l[1] || "").toLowerCase().split(/\s+/)
                for (let i = 0; i < ids.length; i++) if (root.glyphs[ids[i]] !== undefined) { root.glyph = root.glyphs[ids[i]]; break }
                root.version = (l[2] || "").trim().replace(/^[vV]/, "")
            }
        }
    }

    // "Take a look": Settings opens with the tour while the night opens up; Esc: just leave
    function finish(tour) {
        if (leaving) return
        leaving = true
        Sfx.play("intro/open", true)
        if (tour) Quickshell.execDetached(["bash", "-c", "sleep 0.6; \"$HOME/.local/bin/rice-welcome\" tour"])
        else Sfx.music(false)       // skipped: no music (with the tour it plays on until the tour ends)
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-welcome\" seen"])
        win.openUp()
    }

    PanelWindow {
        id: win
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-welcome"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // ---------- the night: a circle grows from the middle and covers the desktop ----------
        // at the end the circle turns into a hole that grows out of the moon and gives the desktop back
        property real iris: 0             // 0 → 1
        property bool opening: false
        property real holeX: width / 2
        property real holeY: height / 2
        readonly property real diag: Math.sqrt(width * width + height * height)
        NumberAnimation on iris { from: 0; to: 1; duration: 900; easing.type: Easing.InOutCubic; running: true }
        NumberAnimation {
            id: openOut
            target: win; property: "iris"; from: 0; to: 1
            duration: 900; easing.type: Easing.InCubic
            onFinished: Qt.quit()
        }
        function openUp() {
            const p = logo.mapToItem(scene, logo.width / 2, logo.height / 2)
            holeX = p.x; holeY = p.y
            opening = true
            iris = 0
            openOut.start()
        }

        Item {
            id: maskShape
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                // closing: from the middle out to the corners; opening: from the moon out past the corners
                readonly property real r: win.iris * win.diag * (win.opening ? 1.05 : 0.56) + 1
                x: (win.opening ? win.holeX : win.width / 2) - r
                y: (win.opening ? win.holeY : win.height / 2) - r
                width: 2 * r; height: 2 * r; radius: r
                color: "#ffffff"
            }
        }

        Item {
            id: scene
            anchors.fill: parent
            visible: false
            layer.enabled: true

            // deep night with a faint glow where the moon will be
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#0b0c14" }
                    GradientStop { position: 0.6; color: "#06070b" }
                    GradientStop { position: 1; color: "#030304" }
                }
            }
            Canvas {
                // soft moonlight, no edges
                width: Math.min(parent.width, parent.height) * 1.3; height: width
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.06
                opacity: stage.step >= 3 ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: 1600 } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                    g.addColorStop(0, Qt.rgba(0.54, 0.58, 0.85, 0.16))
                    g.addColorStop(0.5, Qt.rgba(0.54, 0.58, 0.85, 0.05))
                    g.addColorStop(1, Qt.rgba(0.54, 0.58, 0.85, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }
            StarField {
                anchors.fill: parent
                count: 10
                opacity: stage.step >= 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 1200 } }
            }

            Column {
                anchors.centerIn: parent
                opacity: stage.step === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 280 } }
                Rise { text: "Hi, " + root.user + "."; px: 46; shown: stage.step === 1 }
            }
            Column {
                anchors.centerIn: parent
                spacing: 16
                opacity: stage.step === 2 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 450 } }
                Rise { text: "Your new desktop is ready."; px: 38; startDelay: 320; shown: stage.step === 2 }
                T {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Every corner of it is yours to change."
                    font.pixelSize: 16
                    color: "#9a9db0"
                    opacity: stage.step === 2 ? 1 : 0
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 700 } NumberAnimation { duration: 600 } } }
                }
            }

            T {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 26
                kind: "mono"
                text: stage.step >= 4 ? "Enter  take a look      Esc  skip" : "Esc  skip"
                font.pixelSize: 11; font.letterSpacing: 1
                color: "#5c5f6e"
                opacity: stage.step >= 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 800 } }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: scene
            maskEnabled: true
            maskSource: maskShape
            maskInverted: win.opening
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.1
        }

        // a click anywhere before the button is there jumps ahead
        MouseArea {
            anchors.fill: parent
            enabled: stage.step < 4 && !root.leaving
            onClicked: stage.step = Math.min(4, stage.step + 1)
        }

        // ---------- the moon, the name and "Take a look" (on top, so the button can be clicked) ----------
        Column {
            id: hero
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            spacing: 6
            visible: stage.step >= 3
            opacity: root.leaving ? 0 : 1
            scale: root.leaving ? 1.08 : 1
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InCubic } }
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.InCubic } }
            MoonLogo {
                id: logo
                anchors.horizontalCenter: parent.horizontalCenter
                size: 210
                intro: true
            }
            T {
                anchors.horizontalCenter: parent.horizontalCenter
                kind: "title"
                text: "DarkShadow's Shell"
                font.pixelSize: 40
                font.bold: true
                // the letters come together
                font.letterSpacing: name.on ? -0.5 : 16
                opacity: name.on ? 1 : 0
                Behavior on font.letterSpacing { NumberAnimation { duration: 1300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 900 } }
                Timer { id: name; property bool on: false; interval: 650; running: stage.step >= 3; onTriggered: on = true }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                opacity: name.on ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 800 } NumberAnimation { duration: 700 } } }
                T { kind: "icon"; text: root.glyph; font.pixelSize: 14; color: "#9a9db0"; anchors.verticalCenter: parent.verticalCenter }
                T {
                    kind: "mono"
                    text: (root.version ? "V" + root.version + "  ·  " : "") + root.distro + "  ·  " + (Quickshell.env("NIRI_SOCKET") ? "niri" : "Hyprland")
                    font.pixelSize: 12; font.letterSpacing: 2; color: "#7d8092"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Item { width: 1; height: 26 }

            // the preview button: a ring that breathes around it, the arrow moves on hover
            Item {
                id: go
                anchors.horizontalCenter: parent.horizontalCenter
                width: 208; height: 52
                opacity: stage.step >= 4 ? 1 : 0
                scale: stage.step >= 4 ? 1 : 0.85
                Behavior on opacity { NumberAnimation { duration: 500 } }
                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 14; height: parent.height + 14; radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    SequentialAnimation on opacity {
                        running: stage.step >= 4; loops: Animation.Infinite
                        NumberAnimation { from: 0.25; to: 1; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1; to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: goMouse.containsMouse ? "#ffffff" : "#E9EAF1"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: goMouse.containsMouse ? 13 : 8
                        Behavior on spacing { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        T { text: "Take a look"; font.pixelSize: 15; font.bold: true; color: "#0b0c12"; anchors.verticalCenter: parent.verticalCenter }
                        T { kind: "icon"; text: ""; font.pixelSize: 13; color: "#0b0c12"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: stage.step >= 4 && !root.leaving
                    onClicked: root.finish(true)
                }
            }
        }

        // ---------- timeline ----------
        Item {
            id: stage
            property int step: 0
            focus: true
            Keys.onEscapePressed: root.finish(false)
            Keys.onReturnPressed: { if (step >= 4) root.finish(true); else stage.step = 4 }
            Keys.onEnterPressed: { if (step >= 4) root.finish(true); else stage.step = 4 }
            Keys.onSpacePressed: { if (step < 4) stage.step = stage.step + 1 }
            // sounds: night falls, quiet music, the moon draws itself in (Settings > Sfx & sounds)
            onStepChanged: if (step === 3) Sfx.play("intro/reveal")
            Timer { interval: 350; running: true; onTriggered: { Sfx.play("intro/night"); Sfx.music(true) } }
            SequentialAnimation {
                running: true
                PauseAnimation { duration: 950 }
                ScriptAction { script: if (stage.step < 1) stage.step = 1 }
                PauseAnimation { duration: 2300 }
                ScriptAction { script: if (stage.step < 2) stage.step = 2 }
                PauseAnimation { duration: 2900 }
                ScriptAction { script: if (stage.step < 3) stage.step = 3 }
                PauseAnimation { duration: 2100 }
                ScriptAction { script: if (stage.step < 4) stage.step = 4 }
            }
        }
    }
}
