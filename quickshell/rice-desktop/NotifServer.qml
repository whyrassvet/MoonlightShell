import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The shell's notification server. Notifications are kept until dismissed in the control center.
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
