import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Recorder: size, quality, sound and encoder of screen recordings (SUPER + SHIFT + R / the hot corner)
Item {
    id: page
    property var ctl
    property var hc: ({})
    property var info: ({ recording: false, start: 0, recordings: [], tools: {}, gpu: false })
    property real tick: Date.now() / 1000

    function v(k, d) { return hc[k] !== undefined ? hc[k] : d }
    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, hc); n[key] = page.norm(value); hc = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = I18n.t("Applied")
    }
    function rec(mode) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" record \"$1\"", "_", mode])
        Qt.quit()
    }
    function stopRec() {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" record stop"])
        page.info = Object.assign({}, page.info, { recording: false })
        infoDelay.restart()
    }

    // ---------- what the numbers mean on screen ----------
    readonly property int srcH: page.ctl && page.ctl.sh0 ? page.ctl.sh0 : 1080
    readonly property string res: v("rec_res", "native")
    readonly property int outH: res === "native" ? srcH : Math.min(srcH, parseInt(res))
    readonly property int fps: parseInt(v("rec_fps", "60"))
    readonly property string quality: v("rec_quality", "high")
    readonly property var mbps: ({ best: 35, high: 18, balanced: 9, small: 4.5 })
    // rough: the bitrate of that quality at 1080p / 60 fps, scaled to the size and frame rate
    readonly property real perMin: {
        const w = outH * 16 / 9
        const m = (mbps[quality] || 18) * (w * outH) / (1920 * 1080) * (0.55 + 0.45 * fps / 60) + 0.15
        return m * 60 / 8
    }
    function fmtSize(mb) { return mb >= 1000 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB" }
    function fmtTime(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
    readonly property bool recording: info.recording === true
    readonly property real elapsed: recording ? Math.max(0, tick - info.start) : 0
    readonly property string soundText: {
        const s = v("rec_sound", true) === true, m = v("rec_mic", false) === true
        return s && m ? "Computer + microphone" : s ? "Computer sound" : m ? "Microphone" : "No sound"
    }
    readonly property bool noTool: info.tools && info.tools["wf-recorder"] === false && info.tools["gpu-screen-recorder"] === false

    Process {
        id: cfgProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" config"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.hc = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: infoProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" rec-info"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.info = JSON.parse(text) } catch (e) { } } }
    }
    Timer { interval: 3000; running: page.visible; repeat: true; onTriggered: if (!infoProc.running) infoProc.running = true }
    Timer { id: infoDelay; interval: 1200; onTriggered: infoProc.running = true }
    Timer { interval: 1000; running: page.visible && page.recording; repeat: true; onTriggered: page.tick = Date.now() / 1000 }

    PageScroll {
        anchors.fill: parent

        // ---------- preview ----------
        Rectangle {
            id: prev
            width: parent.width
            height: 214
            radius: M3.rL
            clip: true
            border.width: 0
            border.color: M3.outlineVariant
            gradient: Gradient {
                GradientStop { position: 0; color: M3.stageTop }
                GradientStop { position: 1; color: M3.stageBottom }
            }

            // a little screen showing what you get
            Rectangle {
                id: mock
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 232
                height: 130
                radius: 10
                color: "#0d0d10"
                border.width: 2
                border.color: page.recording ? "#e5484d" : "#3a3a44"
                Behavior on border.color { ColorAnimation { duration: 200 } }
                // pretend windows
                Rectangle { x: 14; y: 14; width: 104; height: 70; radius: 6; color: "#1b1b22"; border.width: 1; border.color: "#2a2a33" }
                Rectangle { x: 82; y: 44; width: 120; height: 66; radius: 6; color: "#22222b"; border.width: 1; border.color: "#33333e" }
                Rectangle { x: 0; y: parent.height - 12; width: parent.width; height: 12; radius: 0; color: "#16161b" }
                // size and speed, the thing this page changes
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.top: parent.top; anchors.topMargin: 8
                    height: 22; radius: 11
                    width: badge.implicitWidth + 18
                    color: Qt.rgba(0, 0, 0, 0.55)
                    T { id: badge; anchors.centerIn: parent; text: page.outH + "p · " + page.fps + I18n.t(" fps"); font.pixelSize: 11; font.bold: true }
                }
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.top: parent.top; anchors.topMargin: 10
                    spacing: 5
                    visible: page.recording
                    Rectangle {
                        id: dot
                        width: 9; height: 9; radius: 5; color: "#e5484d"
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: page.recording && page.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600 }
                            NumberAnimation { to: 1; duration: 600 }
                        }
                    }
                    T { text: page.fmtTime(page.elapsed); font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                anchors.left: mock.right
                anchors.leftMargin: 26
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                T { text: page.recording ? I18n.t("Recording… ") + page.fmtTime(page.elapsed) : I18n.t("Screen recorder"); font.pixelSize: 20; font.bold: true }
                T {
                    width: parent.width
                    text: page.outH + I18n.t("p at ") + page.fps + I18n.t(" fps · ") + ({ best: I18n.t("Best"), high: I18n.t("High"), balanced: I18n.t("Balanced"), small: I18n.t("Small") })[page.quality] + I18n.t(" quality")
                    font.pixelSize: 13; color: "#d8d8e0"; elide: Text.ElideRight
                }
                T {
                    width: parent.width
                    text: page.soundText + I18n.t(" · about ") + page.fmtSize(page.perMin) + I18n.t(" per minute")
                    font.pixelSize: 12; color: "#b0b0bc"; elide: Text.ElideRight
                }
                Row {
                    topPadding: 8
                    spacing: 8
                    Btn { visible: !page.recording; primary: true; icon: ""; text: I18n.t("Record screen"); onClicked: page.rec("full") }
                    Btn { visible: !page.recording; icon: ""; text: I18n.t("Record region"); onClicked: page.rec("region") }
                    Btn { visible: page.recording; primary: true; icon: ""; text: I18n.t("Stop recording"); onClicked: page.stopRec() }
                }
                T {
                    width: parent.width
                    visible: !page.recording
                    text: I18n.t("Settings closes so it is not in the video. Stop with the same shortcut.")
                    font.pixelSize: 11; color: "#8a8a98"; wrapMode: Text.WordWrap
                }
            }
        }

        // ---------- video ----------
        SectionTitle { text: I18n.t("Video"); sub: I18n.t("Bigger and sharper videos are heavier for the computer and take more space.") }
        SegRow {
            label: I18n.t("Resolution")
            desc: I18n.t("Native keeps your screen's size; smaller is lighter")
            options: [{ label: I18n.t("Native"), value: "native" }, { label: "1440p", value: "1440" }, { label: "1080p", value: "1080" }, { label: "720p", value: "720" }]
            current: page.v("rec_res", "native")
            onChosen: function(x) { page.setv("rec_res", x) }
        }
        SegRow {
            label: I18n.t("Frame rate")
            desc: I18n.t("60 fps is smoother for games and moving windows")
            options: [{ label: I18n.t("30 fps"), value: "30" }, { label: I18n.t("60 fps"), value: "60" }]
            current: page.v("rec_fps", "60")
            onChosen: function(x) { page.setv("rec_fps", x) }
        }
        SegRow {
            label: I18n.t("Quality")
            desc: I18n.t("How sharp the picture stays; the file size follows")
            options: [{ label: I18n.t("Best"), value: "best" }, { label: I18n.t("High"), value: "high" }, { label: I18n.t("Balanced"), value: "balanced" }, { label: I18n.t("Small"), value: "small" }]
            current: page.v("rec_quality", "high")
            onChosen: function(x) { page.setv("rec_quality", x) }
        }
        SegRow {
            label: I18n.t("Encoder")
            desc: page.info.gpu === true ? I18n.t("CPU: sharpest picture. GPU (VAAPI): much lighter while you play") : I18n.t("CPU only here: no graphics card encoder was found")
            options: page.info.gpu === true ? [{ label: "CPU", value: "cpu" }, { label: "GPU", value: "gpu" }] : [{ label: "CPU", value: "cpu" }]
            current: page.info.gpu === true ? page.v("rec_encoder", "cpu") : "cpu"
            onChosen: function(x) { page.setv("rec_encoder", x) }
        }

        // ---------- sound ----------
        SectionTitle { text: I18n.t("Sound") }
        ToggleRow { label: I18n.t("Record sound"); desc: I18n.t("The sound of your computer: games, videos, calls"); checked: page.v("rec_sound", true) === true; onToggled: function(x) { page.setv("rec_sound", x ? "on" : "off") } }
        ToggleRow { label: I18n.t("Record microphone"); desc: I18n.t("Your voice instead (with wf-recorder only one of the two; gpu-screen-recorder can take both)"); checked: page.v("rec_mic", false) === true; onToggled: function(x) { page.setv("rec_mic", x ? "on" : "off") } }

        T {
            visible: page.noTool
            width: parent.width
            text: I18n.t("No screen recorder found. Install wf-recorder (and slurp for regions).")
            color: "#e0a050"; font.pixelSize: 12; wrapMode: Text.WordWrap
        }

        // ---------- recent ----------
        SectionTitle { text: I18n.t("Recent recordings"); sub: I18n.t("Click one to play it. They are saved in ") + (page.info.dir || "Videos/Recordings") + "." }
        Flow {
            id: flow
            width: parent.width
            spacing: 10
            Repeater {
                model: page.info.recordings || []
                delegate: Rectangle {
                    id: rc
                    width: (flow.width - 20) / 3
                    height: 150
                    radius: 14
                    clip: true
                    color: rcMouse.containsMouse ? M3.surfaceHigh : M3.surfaceC
                    border.width: 1
                    border.color: rcMouse.containsMouse ? M3.outline : M3.outlineVariant
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        id: th
                        x: 1; y: 1
                        width: parent.width - 2
                        height: 96
                        color: "#0d0d10"
                        Image {
                            anchors.fill: parent
                            source: modelData.thumb ? "file://" + modelData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        T { visible: !modelData.thumb; anchors.centerIn: parent; kind: "icon"; text: ""; font.pixelSize: 22; color: "#555560" }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 34; height: 34; radius: 17
                            color: Qt.rgba(0, 0, 0, 0.55)
                            opacity: rcMouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            T { kind: "icon"; anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: ""; font.pixelSize: 13 }
                        }
                    }
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.top: th.bottom; anchors.topMargin: 8
                        spacing: 2
                        T { width: parent.width; text: modelData.name; font.pixelSize: 12; font.bold: true; elide: Text.ElideMiddle }
                        T {
                            width: parent.width
                            text: page.fmtSize(modelData.mb) + (modelData.sec > 0 ? " · " + page.fmtTime(modelData.sec) : "") + " · " + modelData.time
                            font.pixelSize: 10; color: M3.inkDim; elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: rcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" show \"$1\"", "_", modelData.path])
                    }
                }
            }
        }
        T {
            visible: (page.info.recordings || []).length === 0
            width: parent.width
            text: I18n.t("Nothing recorded yet. Use Record screen above, or your record shortcut.")
            color: M3.inkDim; font.pixelSize: 12; wrapMode: Text.WordWrap
        }
        Row {
            topPadding: 4
            spacing: 8
            Btn { icon: ""; text: I18n.t("Open folder"); onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-hotcorner\" folder recordings"]) }
        }
        T {
            width: parent.width
            topPadding: 6
            text: I18n.t("Tip: Reddit, Discord and other sites compress videos again. For posts, 1080p at 60 fps with High quality is a good balance.")
            color: M3.inkDim; font.pixelSize: 11; wrapMode: Text.WordWrap
        }
    }
}
