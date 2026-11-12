import Quickshell
import Quickshell.Io
import QtQuick

// Desktop widget "CPU · GPU · RAM": three small shapes with how busy each one is. The GPU shows a dash
// when the computer does not tell its load.
Item {
    id: tw
    property var pal: null
    property real bg: 1
    property bool running: true
    property var st: ({ cpu: 0, ram: 0, gpu: 0 })
    property bool haveGpu: false
    Process {
        command: [Quickshell.env("HOME") + "/.local/bin/rice-stats"]
        running: tw.running
        stdout: SplitParser { onRead: function(l) { try { const j = JSON.parse(l); tw.st = j; if (j.gpu > 0 || j.gtemp > 0) tw.haveGpu = true } catch (e) { } } }
    }
    Row {
        anchors.centerIn: parent
        spacing: Math.round(tw.width * 0.025)
        Repeater {
            model: [
                { k: "cpu", n: "CPU", s: "cookie" },
                { k: "gpu", n: "GPU", s: "circle" },
                { k: "ram", n: "RAM", s: "cookie" }
            ]
            delegate: Item {
                readonly property bool mid: modelData.k === "gpu"
                readonly property bool na: mid && !tw.haveGpu
                width: Math.min(tw.height, (tw.width - 2 * Math.round(tw.width * 0.025)) / 3); height: width
                Blob {
                    anchors.fill: parent
                    kind: modelData.s
                    color: parent.mid ? (tw.pal ? tw.pal.tertiary : "#e8a28c") : (tw.pal ? (tw.bg > 0.02 ? tw.pal.shapeFill : "transparent") : "#22262a")
                    SlowSpin { turn: 360; period: 60000; running: (tw.running && !Look.lite && !parent.mid) && !Look.covered }
                }
                Column {
                    anchors.centerIn: parent
                    readonly property color ink: parent.mid ? (tw.pal ? tw.pal.inkTertiary : "#3a1a12") : (tw.pal ? tw.pal.fg : "#F6F5F4")
                    T { kind: "number"; anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.na ? "—" : tw.st[modelData.k] + "%"
                        font.pixelSize: Math.round(parent.parent.width * 0.24); font.weight: Font.DemiBold; color: parent.ink }
                    T { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n; font.pixelSize: Math.round(parent.parent.width * 0.12); color: parent.ink; opacity: 0.8 }
                }
            }
        }
    }
}
