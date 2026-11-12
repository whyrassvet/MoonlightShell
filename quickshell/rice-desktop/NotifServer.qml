import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The notification server of the shell (only while Settings > Notifications says the shell shows them; swaync is
// stopped then). Every notification is kept until you dismiss it in the control center.
NotificationServer {
    id: srv
    signal arrived(var n)
    property bool islandVolume: false
    keepOnReload: true
    actionsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    imageSupported: true
    persistenceSupported: true
    onNotification: function(n) {
        if (islandVolume && n.appName === "rice-media" && (n.summary === "Volume" || n.summary === "Muted")) {
            n.dismiss()
            return
        }
        n.tracked = true; srv.arrived(n)
    }
}
