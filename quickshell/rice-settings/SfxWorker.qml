import Quickshell
import Quickshell.Io
import QtQuick

// Runs in a child process: loading QtMultimedia must never block the settings window.
ShellRoot {
    id: worker
    property string pack: "tap"
    property int volume: 45
    property var bank: null
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/rice/sounds/sfx/"
    function file(ev) { return dir + pack + "/" + ev + ".wav" }
    function play(line) {
        try {
            const msg = JSON.parse(line)
            if (!["click", "select", "done", "switch-on", "switch-off", "slide", "type"].includes(msg.event)) return
            if (typeof msg.pack !== "string" || !/^[a-z0-9-]+$/.test(msg.pack)) return
            pack = msg.pack
            volume = Math.max(0, Math.min(100, Number(msg.volume) || 0))
            if (bank && bank.play(msg.event)) return
            Quickshell.execDetached(["bash", "-c",
                "f=\"$1\"; v=\"$2\"; [ -f \"$f\" ] || exit 0; if command -v pw-play >/dev/null; then exec pw-play --media-role Event --volume \"$v\" \"$f\"; " +
                "elif command -v paplay >/dev/null; then exec paplay --volume \"$(awk -v v=\"$v\" 'BEGIN{print int(v*65536)}')\" \"$f\"; fi",
                "_", file(msg.event), (volume / 100).toFixed(2)])
        } catch (e) { console.warn("Sfx worker:", e) }
    }
    Component.onCompleted: {
        const c = Qt.createComponent("SfxBank.qml")
        if (c.status === Component.Ready) bank = c.createObject(worker, { sfx: worker })
        socket.connected = true
    }
    Socket {
        id: socket
        path: Quickshell.env("MOONLIGHT_SFX_SOCKET")
        onConnectedChanged: if (!connected) Qt.quit()
        onError: Qt.quit()
        parser: SplitParser { onRead: function(line) { worker.play(line) } }
    }
}
