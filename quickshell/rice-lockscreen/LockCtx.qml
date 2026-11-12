pragma Singleton
import Quickshell
import QtQuick

// The lock screen's shared state (shell.qml: the password, PAM, the way out), for every screen's view.
Singleton {
    property var root: null
}
