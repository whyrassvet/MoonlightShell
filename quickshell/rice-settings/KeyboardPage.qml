import Quickshell
import Quickshell.Io
import QtQuick

// Settings > System > Keyboard: the keyboard layouts you type with (up to 4, each with its variant), the one in
// use now, the keys that switch them, and every layout of this computer (xkeyboard-config) with its variants.
// Applied live and saved by hypr-set.
Item {
    id: page
    property var ctl
    property var st: ({ layouts: [], variants: [], active: "", options: "", all: [] })
    property string q: ""
    property string openId: ""          // the layout whose variants are shown
    property var vars: []
    function nameOf(id) { const l = st.all || []; for (let i = 0; i < l.length; i++) if (l[i].id === id) return l[i].name; return id.toUpperCase() }
    function varOf(i) { return st.variants && st.variants[i] ? st.variants[i] : "" }
    readonly property var found: {
        const l = st.all || [], s = q.trim().toLowerCase(), out = []
        for (let i = 0; i < l.length && out.length < 120; i++)
            if (!s || l[i].name.toLowerCase().indexOf(s) >= 0 || l[i].id.indexOf(s) === 0) out.push(l[i])
        return out
    }
    function run(args) {
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" \"$@\" 2>&1", "_"].concat(args)
        setProc.running = true
    }
    function pairs(lays, vs) { return lays.map(function(l, i) { return vs[i] ? l + ":" + vs[i] : l }).join(",") }
    function apply(lays, vs) { const n = Object.assign({}, st); n.layouts = lays; n.variants = vs; st = n; run(["kbd-set", pairs(lays, vs)]) }
    function add(id, variant) {
        const lays = st.layouts.slice(), vs = lays.map(function(l, i) { return page.varOf(i) })
        const at = lays.indexOf(id)
        if (at >= 0) { vs[at] = variant; apply(lays, vs); return }
        if (lays.length >= 4) { page.ctl.status = I18n.t("Up to four layouts"); return }
        lays.push(id); vs.push(variant); apply(lays, vs)
    }
    function remove(i) { if (st.layouts.length <= 1) return; const l = st.layouts.slice(), v = l.map(function(x, k) { return page.varOf(k) }); l.splice(i, 1); v.splice(i, 1); apply(l, v) }
    function first(i) { const l = st.layouts.slice(), v = l.map(function(x, k) { return page.varOf(k) }); const a = l.splice(i, 1), b = v.splice(i, 1); apply(a.concat(l), b.concat(v)) }
    function showVariants(id) {
        if (openId === id) { openId = ""; return }
        openId = id; vars = []
        varProc.command = ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" kbd-variants \"$1\"", "_", id]
        varProc.running = true
    }

    Process {
        id: stProc
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" kbd-state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { } } }
    }
    Process { id: varProc; stdout: StdioCollector { onStreamFinished: { try { page.vars = JSON.parse(text) } catch (e) { page.vars = [] } } } }
    Process {
        id: setProc
        stdout: StdioCollector { onStreamFinished: { page.ctl.status = text.trim(); again.restart() } }
    }
    Timer { id: again; interval: 600; onTriggered: stProc.running = true }
    Timer { interval: 3000; running: page.visible; repeat: true; onTriggered: if (!stProc.running) stProc.running = true }

    PageScroll {
        anchors.fill: parent

        // ---------- the layout in use ----------
        Rectangle {
            width: parent.width
            height: 150
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            Blob { width: 220; height: 220; x: parent.width - 170; y: -40; kind: "puffy"; color: M3.alpha(M3.inkPrimaryC, 0.07)
                RotationAnimator on rotation { from: 0; to: 360; duration: 50000; loops: Animation.Infinite; running: page.visible } }
            Item {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                width: 96; height: 96
                Blob { anchors.fill: parent; kind: Prefs.accentShape; color: M3.primary }
                T { kind: "title"; anchors.centerIn: parent; text: (page.st.layouts[0] || "us").toUpperCase(); font.pixelSize: 26; font.weight: Font.Bold; color: M3.inkPrimary }
            }
            Column {
                x: 140; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 140 - 24
                spacing: 3
                T { text: I18n.t("CURRENT LAYOUT"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "title"; width: parent.width; elide: Text.ElideRight; font.pixelSize: 24; font.weight: Font.Medium; color: M3.inkPrimaryC
                    text: page.st.layouts.length ? page.nameOf(page.st.layouts[0]) : "…" }
                T { font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85); text: page.varOf(0) ? I18n.t("Variant: ") + page.varOf(0) : I18n.t("Default variant") }
                T { font.pixelSize: 11; color: M3.alpha(M3.inkPrimaryC, 0.7); visible: page.st.active !== ""; text: (Quickshell.env("NIRI_SOCKET") ? "niri" : I18n.t("Hyprland")) + I18n.t(" reports: ") + page.st.active }
                Btn { visible: page.st.layouts.length > 1; text: I18n.t("Next layout"); sym: "keyboard_tab"; icon: ""; primary: true; onClicked: page.run(["kbd-next"]) }
            }
        }

        // ---------- your layouts ----------
        SectionTitle { text: I18n.t("Your layouts"); sub: I18n.t("Up to four. The first one is used when you log in.") }
        Repeater {
            model: page.st.layouts
            delegate: SettingRow {
                label: page.nameOf(modelData)
                desc: (index === 0 ? I18n.t("Default") : I18n.t("Layout ") + (index + 1)) + (page.varOf(index) ? "  ·  " + page.varOf(index) : "")
                reserved: 200
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        width: 46; height: 30; radius: 15; color: M3.secondaryContainer
                        T { kind: "code"; anchors.centerIn: parent; text: modelData.toUpperCase(); font.pixelSize: 12; font.weight: Font.Medium; color: M3.inkSecondaryC }
                    }
                    Rectangle {
                        visible: index > 0
                        width: 34; height: 30; radius: 15; color: um.containsMouse ? M3.surfaceHighest : "transparent"
                        Icon { anchors.centerIn: parent; name: "vertical_align_top"; glyph: ""; size: 16; color: M3.inkDim }
                        MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.first(index) }
                    }
                    Rectangle {
                        visible: page.st.layouts.length > 1
                        width: 34; height: 30; radius: 15; color: xm.containsMouse ? M3.alpha(M3.error, 0.15) : "transparent"
                        Icon { anchors.centerIn: parent; name: "close"; glyph: ""; size: 16; color: xm.containsMouse ? M3.error : M3.inkDim }
                        MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.remove(index) }
                    }
                }
            }
        }
        SegRow {
            visible: page.st.layouts.length > 1
            label: I18n.t("Switch with")
            desc: I18n.t("Keys that change the layout")
            options: [{ label: I18n.t("Alt + Shift"), value: "grp:alt_shift_toggle" }, { label: I18n.t("Super + Space"), value: "grp:win_space_toggle" },
                      { label: I18n.t("Caps Lock"), value: "grp:caps_toggle" }]
            current: page.st.options
            onChosen: function(x) { const n = Object.assign({}, page.st); n.options = x; page.st = n; page.run(["kbd-options", x]) }
        }

        // ---------- every layout ----------
        SectionTitle { text: I18n.t("All layouts"); sub: (page.st.all || []).length + I18n.t(" layouts on this computer. Click one for its variants, + adds it.") }
        Field {
            width: parent.width
            placeholder: I18n.t("Search language or layout ...")
            onTextChanged: page.q = text
        }
        Rectangle {
            width: parent.width
            height: Math.min(520, list.contentHeight + 16)
            radius: M3.rL
            color: M3.surfaceC
            clip: true
            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 8
                model: page.found
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                delegate: Column {
                    id: lrow
                    width: list.width
                    readonly property bool have: page.st.layouts.indexOf(modelData.id) >= 0
                    readonly property bool open: page.openId === modelData.id
                    Rectangle {
                        width: parent.width; height: 52; radius: M3.rM
                        color: lrow.open ? M3.surfaceHigh : (rm.containsMouse ? M3.surfaceHigh : "transparent")
                        Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 30; radius: 10; color: lrow.have ? M3.primary : M3.surfaceHighest
                            T { kind: "code"; anchors.centerIn: parent; text: modelData.id.toUpperCase().substring(0, 3); font.pixelSize: 11; font.weight: Font.Medium; color: lrow.have ? M3.inkPrimary : M3.inkDim } }
                        Column {
                            x: 62; anchors.verticalCenter: parent.verticalCenter
                            T { text: modelData.name; font.pixelSize: 13; font.weight: Font.Medium }
                            T { text: (modelData.n || 0) + I18n.t(" variants  ·  ") + modelData.id; font.pixelSize: 11; color: M3.inkDim }
                        }
                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.showVariants(modelData.id) }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Icon { visible: (modelData.n || 0) > 0; name: lrow.open ? "expand_less" : "expand_more"; glyph: ""; size: 18; color: M3.inkDim; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: lrow.have ? M3.secondaryContainer : (am.containsMouse ? M3.primary : M3.surfaceHighest)
                                Icon { anchors.centerIn: parent; name: lrow.have ? "check" : "add"; glyph: lrow.have ? "" : "+"; size: 17; color: lrow.have ? M3.inkSecondaryC : (am.containsMouse ? M3.inkPrimary : M3.ink) }
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!lrow.have) page.add(modelData.id, "") }
                            }
                        }
                    }
                    // its variants
                    Flow {
                        visible: lrow.open
                        width: parent.width - 62; x: 62
                        spacing: 6
                        topPadding: 6; bottomPadding: 10
                        Repeater {
                            model: lrow.open ? [{ id: "", name: "Default" }].concat(page.vars) : []
                            delegate: Rectangle {
                                width: Math.min(lrow.width - 70, vt.implicitWidth + 24); height: 32; radius: 10
                                color: vm.containsMouse ? M3.primary : M3.surfaceHighest
                                T { id: vt; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 20); elide: Text.ElideRight
                                    text: modelData.name.replace(page.nameOf(lrow.ListView.view ? "" : ""), ""); font.pixelSize: 12; color: vm.containsMouse ? M3.inkPrimary : M3.ink }
                                MouseArea { id: vm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { page.add(page.openId, modelData.id); page.ctl.status = I18n.t("Added ") + modelData.name } }
                            }
                        }
                    }
                }
            }
        }
    }
}
