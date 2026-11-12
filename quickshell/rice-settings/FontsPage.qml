import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Appearance > Fonts: the families used for text, titles, numbers, code and icons, each shown as a
// sample in its own font. Type a family or pick one of the suggestions. (Moved here from Services.)
Item {
    id: page
    property var ctl
    property var fonts: ({})
    readonly property var fams: Qt.fontFamilies()
    function have(f) { return fams.indexOf(f) >= 0 }

    readonly property var roles: [
        { key: "title", label: I18n.t("Titles"), desc: I18n.t("Headings and big numbers"), sample: "Make it yours", px: 30, sym: "title", g: "" },
        { key: "main", label: I18n.t("Text"), desc: I18n.t("Everything you read in the interface"), sample: "The quick brown fox jumps over the lazy dog", px: 17, sym: "text_fields", g: "" },
        { key: "reading", label: I18n.t("Descriptions"), desc: I18n.t("The small lines under settings"), sample: "Lower is more see-through. Blur sits behind it.", px: 14, sym: "notes", g: "" },
        { key: "numbers", label: I18n.t("Numbers"), desc: I18n.t("Clocks and stats"), sample: "12:45  ·  98%  ·  3.14", px: 26, sym: "pin", g: "" },
        { key: "mono", label: I18n.t("Monospace"), desc: I18n.t("Terminal (kitty) and code"), sample: "~/shadows-shell $ rice-update", px: 15, sym: "terminal", g: "" },
        { key: "icons", label: I18n.t("Icon font"), desc: I18n.t("Nerd Font symbols in the bar and widgets"), sample: "        ", px: 20, sym: "emoji_symbols", g: "" }
    ]
    readonly property var suggestions: ["Google Sans Flex", "Google Sans Code", "Rubik", "Inter", "Google Sans", "Outfit", "Space Grotesk", "Gabarito", "Readex Pro", "Manrope", "JetBrainsMono Nerd Font", "Iosevka Nerd Font"]

    function applyFont(key, value) {
        if (!value || value.trim() === "") return
        const n = Object.assign({}, fonts); n[key] = value.trim(); fonts = n
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/font-set\" set \"$1\" \"$2\" 2>&1", "_", key, value.trim()]
        setProc.running = true
    }
    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.fonts = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: setProc
        stdout: StdioCollector { onStreamFinished: { page.ctl.status = text.trim(); refresh.restart() } }
    }
    Process {
        id: resetProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" reset 2>&1"]
        stdout: StdioCollector { onStreamFinished: { page.ctl.status = text.trim(); refresh.restart() } }
    }
    Timer { id: refresh; interval: 500; onTriggered: stateProc.running = true }

    property string openKey: ""     // the card whose suggestions are open
    property string sampleText: "DarkShadow's Shell — made for you"
    // the 15 roles of the Material 3 type scale: name, size, weight
    readonly property var scale: [
        ["displayLarge", 57, Font.Normal], ["displayMedium", 45, Font.Normal], ["displaySmall", 36, Font.Normal],
        ["headlineLarge", 32, Font.Normal], ["headlineMedium", 28, Font.Normal], ["headlineSmall", 24, Font.Normal],
        ["titleLarge", 22, Font.Normal], ["titleMedium", 16, Font.Medium], ["titleSmall", 14, Font.Medium],
        ["bodyLarge", 16, Font.Normal], ["bodyMedium", 14, Font.Normal], ["bodySmall", 12, Font.Normal],
        ["labelLarge", 14, Font.Medium], ["labelMedium", 12, Font.Medium], ["labelSmall", 11, Font.Medium]
    ]
    function useGoogle() {
        setProc.command = ["bash", "-c", "for k in main title numbers reading; do \"$HOME/.local/bin/font-set\" set $k 'Google Sans Flex' >/dev/null 2>&1 || { echo 'Google Sans Flex is not installed'; exit 0; }; done; echo 'Google Sans Flex everywhere'"]
        setProc.running = true
    }

    PageScroll {
        anchors.fill: parent

        // ---------- the font you read ----------
        Rectangle {
            width: parent.width
            height: 150
            radius: M3.rXL
            color: M3.primaryContainer
            clip: true
            T {
                id: aa
                x: 26; anchors.verticalCenter: parent.verticalCenter
                scaled: false
                text: I18n.t("Aa")
                font.family: Fonts.main
                font.pixelSize: 92
                font.weight: hov.hovered ? Font.Black : Font.Normal
                color: M3.inkPrimaryC
                HoverHandler { id: hov }
            }
            Column {
                x: 26 + 150; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 24
                spacing: 6
                T { text: I18n.t("INTERFACE FONT"); font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: M3.alpha(M3.inkPrimaryC, 0.75) }
                T { kind: "title"; text: Fonts.main; font.pixelSize: 26; font.weight: Font.Medium; color: M3.inkPrimaryC }
                T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.alpha(M3.inkPrimaryC, 0.85)
                    text: page.have("Google Sans Flex") ? I18n.t("Settings, the bar, the launcher, notifications, the island and widgets all use it. Point at Aa to see it bold.")
                                                         : "Google Sans Flex is not installed yet: run rice-fonts (the installer does it for you)." }
                Btn { visible: page.have("Google Sans Flex") && Fonts.main !== "Google Sans Flex"; text: I18n.t("Use Google Sans Flex"); sym: "font_download"; icon: ""; primary: true; onClicked: page.useGoogle() }
            }
        }
        T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: M3.inkDim; topPadding: 6
            text: I18n.t("Type an installed family and press Enter, or pick a suggestion. Monospace is for kitty and code.") }

        Repeater {
            model: page.roles
            delegate: Rectangle {
                id: card
                readonly property string fam: page.fonts[modelData.key] || ""
                readonly property bool open: page.openKey === modelData.key
                width: parent.width
                height: col.implicitHeight + 32
                radius: M3.rL
                color: M3.surfaceC
                Behavior on height { NumberAnimation { duration: M3.d(260); easing.type: Easing.OutCubic } }
                clip: true
                Column {
                    id: col
                    x: 18; y: 16
                    width: parent.width - 36
                    spacing: 10
                    Item {
                        width: parent.width; height: 40
                        Rectangle { width: 40; height: 40; radius: 20; color: M3.secondaryContainer
                            Icon { anchors.centerIn: parent; name: modelData.sym; glyph: modelData.g; size: 18; color: M3.inkSecondaryC } }
                        Column {
                            x: 52; anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            T { text: modelData.label; font.pixelSize: 14; font.weight: Font.Medium }
                            T { text: modelData.desc; font.pixelSize: 11; color: M3.inkDim }
                        }
                        Field {
                            width: Math.min(260, parent.width * 0.4)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.fam
                            placeholder: I18n.t("Font family")
                            onAccepted: page.applyFont(modelData.key, text)
                        }
                    }
                    // the sample, in that font
                    T {
                        width: parent.width
                        text: modelData.sample
                        font.family: modelData.key === "icons" ? (card.fam || Fonts.icons) : (card.fam || Fonts.family("body"))
                        font.pixelSize: modelData.px
                        elide: Text.ElideRight
                        color: M3.ink
                    }
                    Row {
                        spacing: 8
                        T { text: card.fam !== "" && !page.have(card.fam) ? I18n.t("Not installed: ") + card.fam : ""; visible: text !== ""; font.pixelSize: 11; color: M3.error; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            visible: modelData.key !== "icons"
                            width: st.implicitWidth + 24; height: 30; radius: 15
                            color: sm.containsMouse ? M3.surfaceHighest : M3.surfaceHigh
                            T { id: st; anchors.centerIn: parent; text: card.open ? I18n.t("Hide suggestions") : I18n.t("Suggestions"); font.pixelSize: 12 }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openKey = card.open ? "" : modelData.key }
                        }
                    }
                    Flow {
                        visible: card.open
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: page.suggestions.filter(function(f) { return page.have(f) && (modelData.key === "mono" ? f.indexOf("Mono") >= 0 || f.indexOf("Iosevka") >= 0 || f.indexOf("Code") >= 0 : f.indexOf("Code") < 0) })
                            delegate: Rectangle {
                                readonly property bool on: card.fam === modelData
                                width: sg.implicitWidth + 28; height: 36; radius: on ? 18 : 10
                                color: on ? M3.primary : (sgm.containsMouse ? M3.surfaceHighest : M3.surfaceHigh)
                                Behavior on radius { NumberAnimation { duration: M3.d(220) } }
                                T { id: sg; anchors.centerIn: parent; text: modelData; font.family: modelData; font.pixelSize: 14; color: parent.on ? M3.inkPrimary : M3.ink }
                                MouseArea { id: sgm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.applyFont(card.open ? page.openKey : "", modelData) }
                            }
                        }
                    }
                }
            }
        }
        Row {
            spacing: 8
            topPadding: 4
            Btn { text: I18n.t("Reset fonts"); sym: "restart_alt"; icon: ""; onClicked: resetProc.running = true }
        }

        // ---------- text ----------
        SectionTitle { text: I18n.t("Text"); sub: I18n.t("Size and weight of every label in Settings.") }
        SliderRow {
            label: I18n.t("Text size")
            desc: I18n.t("100 % is the normal size")
            from: 85; to: 130; step: 5; unit: " %"
            value: Math.round(Prefs.textScale * 100)
            onCommitted: function(v) { Prefs.setTextScale(v / 100) }
        }
        ToggleRow { label: I18n.t("Emphasized headings"); desc: I18n.t("Titles and headlines one step heavier"); checked: Prefs.emphHeadings; onToggled: function(v) { Prefs.setEmphHeadings(v) } }
        ToggleRow { label: I18n.t("Rounded letters"); desc: I18n.t("Google Sans Flex with soft, round stroke ends"); checked: Prefs.roundText; onToggled: function(v) { Prefs.setRoundText(v) } }

        // ---------- the type scale ----------
        SectionTitle { text: I18n.t("Type scale"); sub: I18n.t("The 15 text roles of Material 3 in your fonts. Type to try your own words.") }
        Field {
            width: parent.width
            text: page.sampleText
            placeholder: I18n.t("Sample text")
            onAccepted: page.sampleText = text
            onTextChanged: if (text.length) page.sampleText = text
        }
        Rectangle {
            width: parent.width
            height: tsCol.implicitHeight + 28
            radius: M3.rL
            color: M3.surfaceC
            clip: true
            Column {
                id: tsCol
                x: 18; y: 14
                width: parent.width - 36
                spacing: 6
                Repeater {
                    model: page.scale
                    delegate: Item {
                        width: tsCol.width
                        height: Math.max(30, smp.implicitHeight)
                        Column {
                            width: 128
                            anchors.verticalCenter: parent.verticalCenter
                            T { text: modelData[0]; font.pixelSize: 12; font.weight: Font.Medium; color: M3.primary }
                            T { kind: "code"; text: modelData[1] + " / " + modelData[2]; font.pixelSize: 10; color: M3.inkDim }
                        }
                        T {
                            id: smp
                            scaled: false
                            x: 140
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.sampleText
                            elide: Text.ElideRight
                            font.family: index < 9 ? Fonts.title : Fonts.main
                            font.pixelSize: Math.round(modelData[1] * Prefs.textScale)
                            font.weight: index < 6 && Prefs.emphHeadings ? Font.DemiBold : modelData[2]
                        }
                    }
                }
            }
        }

    }
}
