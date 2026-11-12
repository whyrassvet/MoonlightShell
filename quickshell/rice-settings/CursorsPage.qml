import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var cs: ({ theme: "", size: 24, themes: [] })
    property string pick: ""          // theme shown in the preview (hovered or current)

    readonly property var current: {
        const id = pick.length > 0 ? pick : cs.theme
        const l = cs.themes || []
        for (let i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return l.length > 0 ? l[0] : null
    }
    function img(t, role) { return t && t.preview && t.preview[role] ? "file://" + t.preview[role] : "" }
    function apply(id) {
        const n = Object.assign({}, cs); n.theme = id; cs = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-cursor\" set \"$1\"", "_", id])
        page.ctl.status = I18n.t("Cursor: ") + id.replace(/-/g, " ")
    }

    // cursor packs from GitHub (rice-cursor get)
    property string getting: ""
    function getPack(id) {
        getting = id
        getProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-cursor\" get \"$1\" 2>&1", "_", id]
        getProc.running = true
        page.ctl.status = I18n.t("Downloading cursors...")
    }
    Process {
        id: getProc
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").pop()
                page.ctl.status = l.indexOf("could not") >= 0 ? l : I18n.t("Installed: ") + l.replace(/^[^:]*: /, "")
                page.getting = ""
                stateProc.running = true
            }
        }
    }
    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-cursor\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.cs = JSON.parse(text) } catch (e) { } } }
    }

    PageScroll {
        anchors.fill: parent

        // ---------- preview ----------
        Rectangle {
            visible: Prefs.previews
            width: parent.width
            height: 210
            radius: M3.rL
            clip: true
            border.width: 0
            border.color: M3.outlineVariant
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: M3.stageTop }
                GradientStop { position: 1; color: M3.stageBottom }
            }
            T {
                x: 22; y: 18
                text: I18n.t("Preview")
                font.pixelSize: 12
                color: M3.inkDim
            }
            T {
                x: 22; y: 36
                text: page.current ? page.current.name : I18n.t("No cursor themes found")
                font.pixelSize: 20
                font.bold: true
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                spacing: 34
                Repeater {
                    model: [{ r: "default", n: "Normal" }, { r: "pointer", n: "Link" }, { r: "text", n: "Text" },
                            { r: "wait", n: "Busy" }, { r: "grab", n: "Move" }]
                    delegate: Column {
                        spacing: 10
                        Item {
                            width: 64; height: 64
                            anchors.horizontalCenter: parent.horizontalCenter
                            Rectangle { anchors.fill: parent; radius: 16; color: Qt.rgba(1, 1, 1, 0.05) }
                            Image {
                                anchors.centerIn: parent
                                width: Math.min(56, page.cs.size * 1.4); height: width
                                source: page.img(page.current, modelData.r)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                cache: false
                            }
                        }
                        T { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n; font.pixelSize: 11; color: M3.inkDim }
                    }
                }
            }
        }

        SectionTitle { text: I18n.t("Size") }
        SliderRow {
            label: I18n.t("Cursor size")
            desc: I18n.t("24 is normal, bigger is easier to see")
            from: 16; to: 64; step: 2; unit: " px"
            value: page.cs.size || 24
            onCommitted: function(x) {
                const n = Object.assign({}, page.cs); n.size = Math.round(x); page.cs = n
                Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-cursor\" size \"$1\"", "_", String(Math.round(x))])
                page.ctl.status = I18n.t("Cursor size ") + Math.round(x)
            }
        }

        SectionTitle { text: I18n.t("Themes"); sub: I18n.t("Hover to preview, click to use. Applies to ") + (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(" and all apps.") }
        Flow {
            id: grid
            width: parent.width
            spacing: 10
            Repeater {
                model: page.cs.themes || []
                delegate: Rectangle {
                    readonly property bool on: page.cs.theme === modelData.id
                    width: (grid.width - 20) / 3
                    height: 92
                    radius: 14
                    color: tm.containsMouse ? M3.surfaceHigh : M3.surfaceC
                    border.width: on ? 2 : 1
                    border.color: on ? M3.primary : (tm.containsMouse ? M3.outline : M3.surfaceHighest)
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Row {
                        x: 14; y: 14
                        spacing: 10
                        Image { width: 26; height: 26; fillMode: Image.PreserveAspectFit; source: page.img(modelData, "default") }
                        Image { width: 26; height: 26; fillMode: Image.PreserveAspectFit; source: page.img(modelData, "pointer") }
                        Image { width: 26; height: 26; fillMode: Image.PreserveAspectFit; source: page.img(modelData, "text") }
                    }
                    Rectangle {
                        visible: modelData.kind === "hyprcursor" || modelData.kind === "both"
                        anchors.right: parent.right; anchors.rightMargin: on ? 34 : 10
                        y: 10
                        width: hb.implicitWidth + 12; height: 18; radius: 9
                        color: Qt.rgba(1, 1, 1, 0.08)
                        T { id: hb; anchors.centerIn: parent; text: I18n.t("Hyprcursor"); font.pixelSize: 9; color: "#cfcfcf" }
                    }
                    T {
                        x: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        width: parent.width - 40
                        text: modelData.name
                        font.pixelSize: 12
                        font.bold: on
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: on
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                        width: 18; height: 18; radius: 9
                        color: "#F6F5F4"
                        T { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; font.bold: true; color: "#0d0d0d" }
                    }
                    MouseArea {
                        id: tm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: page.pick = modelData.id
                        onExited: if (page.pick === modelData.id) page.pick = ""
                        onClicked: page.apply(modelData.id)
                    }
                }
            }
        }
        SectionTitle { text: I18n.t("Get more cursors"); sub: I18n.t("Downloaded from GitHub into ~/.local/share/icons. Hyprcursor themes are drawn by Hyprland itself (sharp at any size); apps use Bibata meanwhile.") }
        Repeater {
            model: page.cs.packs || []
            delegate: Rectangle {
                width: parent ? parent.width : 400
                height: 64
                radius: 14
                color: M3.surfaceC
                border.width: 1
                border.color: M3.outlineVariant
                Column {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    T { text: modelData.name; font.pixelSize: 14; font.bold: true }
                    T { kind: "reading"; text: modelData.installed ? I18n.t("Installed  ·  ") + modelData.themes.join(", ") : modelData.desc; font.pixelSize: 11; color: M3.inkDim }
                }
                Btn {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    primary: !modelData.installed && page.getting === ""
                    text: page.getting === modelData.id ? I18n.t("Downloading...") : (modelData.installed ? I18n.t("Update") : I18n.t("Install"))
                    onClicked: if (page.getting === "") page.getPack(modelData.id)
                }
            }
        }
        T {
            visible: !(page.cs.themes && page.cs.themes.length > 0)
            width: parent.width
            text: I18n.t("No cursor themes found. Install Bibata: bibata-cursor-theme-bin (Arch, AUR) or bibata-cursors (NixOS).")
            color: "#e0a050"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
