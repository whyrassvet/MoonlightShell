import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Desktop > Idle & Lockscreen: the login screen (SDDM). The shell's own theme, in your wallpaper and
// colors (rice-sddm). Putting it in asks for your password once; after that it follows the wallpaper by itself.
Column {
    id: card
    property var ctl
    width: parent ? parent.width : 400
    spacing: 10

    property var st: ({ sddm: false, installed: false, in_use: false, theme: "", dm: "", writable: false, repo: true, pkg: "" })
    property bool working: false
    Process {
        id: stProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-sddm\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { card.st = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: doProc
        property string what: ""
        stdout: StdioCollector { id: doOut }
        onExited: function(code) {
            card.working = false
            const last = doOut.text.trim().split("\n").pop()
            if (card.ctl) card.ctl.status = code === 0 ? I18n.t("Login screen: done") : (last || I18n.t("Login screen: it did not work (password window closed?)"))
            stProc.running = true
        }
    }
    function run(arg) {
        if (working) return
        working = true
        doProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-sddm\" \"$1\" 2>&1", "_", arg]
        doProc.running = true
        if (card.ctl) card.ctl.status = I18n.t("A password window opens: SDDM's files belong to the system")
    }
    readonly property bool usingSddm: st.dm === "sddm"

    SectionTitle { text: I18n.t("Login screen"); sub: I18n.t("The screen before your desktop (SDDM): the shell's own, in your wallpaper and its colors.") }

    Rectangle {
        width: parent.width
        height: Math.max(150, info.implicitHeight + 36)
        radius: M3.rXL
        clip: true
        color: M3.surfaceC
        // a little drawing of it: a big clock, a card in the middle
        Rectangle {
            id: mini
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 192; height: 118; radius: 16; clip: true
            gradient: Gradient { GradientStop { position: 0; color: M3.primaryContainer } GradientStop { position: 1; color: M3.surfaceHigh } }
            T { x: 12; y: 10; text: Qt.formatTime(new Date(), "HH:mm"); font.pixelSize: 15; font.weight: Font.DemiBold; color: M3.inkPrimaryC }
            Rectangle {
                anchors.centerIn: parent; anchors.verticalCenterOffset: 10
                width: 84; height: 64; radius: 14; color: M3.alpha(M3.surface, 0.85)
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 22; height: 22; radius: 11; color: M3.primary }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 38; width: 64; height: 14; radius: 7; color: M3.surfaceHighest
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: M3.primary } }
            }
        }
        Column {
            id: info
            x: 228; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 228 - 20
            spacing: 6
            T {
                kind: "title"; font.pixelSize: 18; font.weight: Font.Medium; width: parent.width; wrapMode: Text.WordWrap
                text: card.st.in_use ? (card.usingSddm ? I18n.t("In use") : I18n.t("Ready: SDDM is not the one that starts"))
                    : card.st.installed && card.st.outdated ? I18n.t("A newer login screen came with the update")
                    : card.st.installed ? I18n.t("Installed, but SDDM uses another theme")
                    : I18n.t("Not installed")
            }
            T {
                kind: "reading"; font.pixelSize: 12; color: M3.inkDim; width: parent.width; wrapMode: Text.WordWrap
                text: !card.st.sddm ? I18n.t("SDDM is not installed. Install it first: ") + card.st.pkg
                    : card.st.in_use && !card.usingSddm ? I18n.t("Your computer starts ") + (card.st.dm || I18n.t("another login screen")) + I18n.t(". Make SDDM the one that starts to see it.")
                    : card.st.in_use ? I18n.t("It follows your wallpaper and colors by itself. Press a key on it to sign in.")
                    : (card.st.theme ? I18n.t("SDDM now uses: ") + card.st.theme + ". " : "") + I18n.t("Asks for your password once (the theme goes into /usr/share/sddm/themes).")
            }
            Flow {
                width: parent.width
                spacing: 8
                Btn {
                    visible: card.st.sddm && (!card.st.in_use || card.st.outdated)
                    text: card.working ? I18n.t("Working...") : (card.st.outdated && card.st.in_use ? I18n.t("Update it") : I18n.t("Use it")); sym: "login"; icon: ""; primary: true
                    onClicked: card.run("install")
                }
                Btn {
                    visible: card.st.sddm && !card.usingSddm
                    property bool armed: false
                    text: armed ? I18n.t("Click again: SDDM from the next boot") : I18n.t("Make SDDM start at boot"); sym: "power_settings_new"; icon: "\uf011"
                    variant: armed ? "danger" : "outlined"
                    onClicked: { if (!armed) { armed = true; disarm.restart(); return } armed = false; card.run("use-sddm") }
                    Timer { id: disarm; interval: 5000; onTriggered: parent.armed = false }
                }
                Btn {
                    visible: card.st.installed && card.st.writable
                    text: I18n.t("Update colors"); sym: "sync"; icon: ""
                    onClicked: card.run("sync")
                }
                Btn {
                    visible: card.st.installed && card.st.sddm
                    text: I18n.t("Preview"); sym: "visibility"; icon: ""; variant: "text"
                    onClicked: Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-sddm\" preview"])
                }
                Btn {
                    visible: card.st.in_use
                    text: I18n.t("Back to SDDM's theme"); variant: "text"
                    onClicked: card.run("remove")
                }
            }
        }
    }
}
