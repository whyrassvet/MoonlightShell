pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The screen the shell lives on: the bar, the island, the dock, the menus (Settings > System > Monitors > Main
// screen; ~/.config/rice/screens.json "main"), and the screen of the desktop widgets ("widgets", the main one when
// not chosen). With no choice, or when that screen is not plugged in: always the same one (the first by its
// connector name, DP-1 before HDMI-A-1), never "whichever came first" (that changed from boot to boot).
Singleton {
    id: mon
    property string want: ""
    property string wantWidgets: ""
    readonly property var screen: pick(Quickshell.screens, want)
    readonly property var widgetScreen: wantWidgets !== "" ? pick(Quickshell.screens, wantWidgets) : screen
    function pick(l, n) {
        if (!l || l.length === 0) return null
        if (n !== "") for (let i = 0; i < l.length; i++) if (l[i].name === n) return l[i]
        let best = l[0]
        for (let i = 1; i < l.length; i++) if (String(l[i].name) < String(best.name)) best = l[i]
        return best
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice/screens.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); mon.want = j.main || ""; mon.wantWidgets = j.widgets || "" } catch (e) { mon.want = ""; mon.wantWidgets = "" } }
        onLoadFailed: { mon.want = ""; mon.wantWidgets = "" }
    }
}
