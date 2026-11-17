import QtQuick 2.15

// Moonlight Shell: the login screen (SDDM). Material 3, in the colors of your wallpaper.
// Resting: your wallpaper and a big clock. Press a key or click: it wakes, the wallpaper blurs and the
// login card comes up. rice-sddm sync puts your wallpaper, its colors and the shell's font in user/.
// Works on SDDM with Qt 6 and with Qt 5 (only QtQuick, no effects modules).
Rectangle {
    id: root
    width: 1920
    height: 1080
    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080) * 1.0)

    function cfg(k, d) { const v = config[k]; return v !== undefined && v !== null && String(v).length > 0 ? String(v) : d }
    readonly property color primary: cfg("primary", "#b7c8e8")
    readonly property color inkPrimary: cfg("onPrimary", "#20314c")
    readonly property color primaryContainer: cfg("primaryContainer", "#374863")
    readonly property color inkPrimaryC: cfg("onPrimaryContainer", "#d6e3ff")
    readonly property color secondaryContainer: cfg("secondaryContainer", "#3d4758")
    readonly property color surface: cfg("surface", "#111318")
    readonly property color surfaceContainer: cfg("surfaceContainer", "#1d2024")
    readonly property color surfaceHigh: cfg("surfaceHigh", "#282a2f")
    readonly property color surfaceHighest: cfg("surfaceHighest", "#33353a")
    readonly property color ink: cfg("onSurface", "#e2e2e9")
    readonly property color inkVariant: cfg("onSurfaceVariant", "#c4c6d0")
    readonly property color outline: cfg("outline", "#8e9099")
    readonly property color errorColor: cfg("error", "#ffb4ab")
    readonly property bool clock24: cfg("clock24", "true") !== "false"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // the words, in the shell's language (rice-sddm sync writes lang)
    readonly property var words: ({
        pl: { "Press any key to sign in": "Naciśnij dowolny klawisz, aby się zalogować", "Password": "Hasło",
              "That's not the password": "To nie jest hasło", "Caps Lock is on": "Caps Lock jest włączony",
              "Signing in...": "Logowanie...", "Sleep": "Uśpij", "Restart": "Uruchom ponownie", "Shut down": "Wyłącz" },
        de: { "Press any key to sign in": "Drücke eine Taste zum Anmelden", "Password": "Passwort",
              "That's not the password": "Das ist nicht das Passwort", "Caps Lock is on": "Feststelltaste ist an",
              "Signing in...": "Anmelden...", "Sleep": "Ruhezustand", "Restart": "Neu starten", "Shut down": "Herunterfahren" },
        es: { "Press any key to sign in": "Pulsa una tecla para entrar", "Password": "Contraseña",
              "That's not the password": "Esa no es la contraseña", "Caps Lock is on": "Bloq Mayús activado",
              "Signing in...": "Entrando...", "Sleep": "Suspender", "Restart": "Reiniciar", "Shut down": "Apagar" }
    })
    readonly property var loc: Qt.locale(cfg("lang", "en") === "en" ? "en_US" : cfg("lang", "en").replace("-", "_"))
    function tr(t) { const l = words[cfg("lang", "en")]; return l && l[t] ? l[t] : t }

    FontLoader { id: shellFont; source: root.cfg("font", "") }
    readonly property string fontName: shellFont.status === FontLoader.Ready ? shellFont.name : "sans-serif"

    color: surface

    // ---------------- state ----------------
    property bool awake: false
    property bool busy: false
    property string message: ""
    function wake() { if (!awake) { awake = true; pw.forceActiveFocus() } idle.restart() }
    function rest() { if (pw.text.length === 0 && !busy) { awake = false; message = ""; root.forceActiveFocus() } }
    Timer { id: idle; interval: 40000; onTriggered: root.rest() }

    // the users and the sessions (read through hidden lists: the models only give their data to delegates)
    ListView {
        id: users
        visible: false; width: 1; height: 1
        model: userModel
        currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        delegate: Item {
            property string uname: model.name
            property string rname: model.realName || ""
            property string uicon: model.icon || ""
        }
    }
    ListView {
        id: sessions
        visible: false; width: 1; height: 1
        model: sessionModel
        currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        delegate: Item { property string sname: model.name }
    }
    readonly property string userName: users.currentItem ? users.currentItem.uname : (userModel.lastUser || "")
    readonly property string userShown: users.currentItem && users.currentItem.rname.length > 0 ? users.currentItem.rname : userName
    readonly property string sessionName: sessions.currentItem ? sessions.currentItem.sname : ""

    function login() {
        if (busy) return
        if (pw.text.length === 0) { shake.restart(); return }
        busy = true
        message = ""
        sddm.login(userName, pw.text, sessions.currentIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.message = root.tr("That's not the password")
            pw.text = ""
            shake.restart()
            pw.forceActiveFocus()
        }
        function onLoginSucceeded() { root.message = "" }
    }

    // ---------------- wallpaper ----------------
    Image {
        id: bg
        anchors.fill: parent
        source: root.cfg("background", "")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        scale: root.awake ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }
    // no wallpaper yet: a soft gradient in the theme colors
    Rectangle {
        anchors.fill: parent
        visible: bg.status !== Image.Ready
        gradient: Gradient {
            GradientStop { position: 0; color: root.primaryContainer }
            GradientStop { position: 1; color: root.surface }
        }
    }
    Image {
        id: blur
        anchors.fill: parent
        source: root.cfg("backgroundBlur", "")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: root.awake && status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }
    // a veil in the surface color, stronger when awake (and stronger still without the blurred picture)
    Rectangle {
        anchors.fill: parent
        color: root.surface
        opacity: root.awake ? (blur.status === Image.Ready ? 0.42 : 0.66) : 0.0
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }
    // resting: a gradient behind the clock
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: parent.height * 0.55
        opacity: root.awake ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 500 } }
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.alpha(root.surface, 0.82) }
        }
    }

    // ---------------- the clock ----------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    function two(n) { return n < 10 ? "0" + n : "" + n }
    readonly property string hours: clock24 ? two(now.getHours()) : String(((now.getHours() + 11) % 12) + 1)
    readonly property string minutes: two(now.getMinutes())

    Item {
        id: clock
        // resting: big, bottom left; awake: small, top center
        width: clockCol.width; height: clockCol.height
        x: root.awake ? (root.width - width) / 2 : 96 * root.s
        y: root.awake ? 72 * root.s : root.height - height - 96 * root.s
        scale: root.awake ? 0.42 : 1
        transformOrigin: root.awake ? Item.Top : Item.BottomLeft
        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }
        Column {
            id: clockCol
            spacing: 4 * root.s
            Row {
                spacing: 0
                Text { text: root.hours; color: root.ink; font.family: root.fontName; font.pixelSize: 210 * root.s; font.weight: Font.DemiBold }
                Text { text: ":"; color: root.primary; font.family: root.fontName; font.pixelSize: 210 * root.s; font.weight: Font.Light
                       opacity: root.now.getSeconds() % 2 === 0 ? 1 : 0.45
                       Behavior on opacity { NumberAnimation { duration: 300 } } }
                Text { text: root.minutes; color: root.primary; font.family: root.fontName; font.pixelSize: 210 * root.s; font.weight: Font.DemiBold }
            }
            Text {
                x: 10 * root.s
                text: { const t = root.now.toLocaleDateString(root.loc, "dddd, d MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) }
                color: root.inkVariant
                font.family: root.fontName
                font.pixelSize: 40 * root.s
                opacity: root.awake ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
    // the resting hint
    Row {
        anchors.right: parent.right; anchors.rightMargin: 96 * root.s
        anchors.bottom: parent.bottom; anchors.bottomMargin: 110 * root.s
        spacing: 12 * root.s
        opacity: root.awake ? 0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Rectangle {
            width: 44 * root.s; height: 44 * root.s; radius: width / 2
            color: root.alpha(root.primary, 0.9)
            anchors.verticalCenter: parent.verticalCenter
            Glyph { anchors.centerIn: parent; kind: "arrow"; color: root.inkPrimary }
            SequentialAnimation on anchors.verticalCenterOffset {
                running: !root.awake; loops: Animation.Infinite
                NumberAnimation { to: -5; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 900; easing.type: Easing.InOutSine }
            }
        }
        Text { text: root.tr("Press any key to sign in"); color: root.ink; font.family: root.fontName; font.pixelSize: 20 * root.s; anchors.verticalCenter: parent.verticalCenter }
    }

    // ---------------- the card ----------------
    Rectangle {
        id: card
        width: 440 * root.s
        height: cardCol.height + 64 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - height) / 2 + (root.awake ? 30 * root.s : 120 * root.s)
        radius: 40 * root.s
        color: root.alpha(root.surfaceContainer, 0.88)
        border.width: 1
        border.color: root.alpha(root.outline, 0.25)
        opacity: root.awake ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: 650; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 400 } }
        transform: Translate { id: shakeT; x: 0 }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeT; property: "x"; to: -14; duration: 50 }
            NumberAnimation { target: shakeT; property: "x"; to: 12; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
        }

        Column {
            id: cardCol
            width: parent.width - 64 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            y: 32 * root.s
            spacing: 18 * root.s

            // the avatar, in a slowly turning Material "cookie" shape
            Item {
                width: 150 * root.s; height: 150 * root.s
                anchors.horizontalCenter: parent.horizontalCenter
                Canvas {
                    id: cookie
                    anchors.fill: parent
                    property real turn: 0
                    NumberAnimation on turn { from: 0; to: Math.PI * 2; duration: 30000; loops: Animation.Infinite; running: root.awake }
                    onTurnChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"), cx = width / 2, cy = height / 2, R = width / 2 - 2
                        c.reset()
                        c.fillStyle = root.busy ? root.primary : root.primaryContainer
                        c.beginPath()
                        for (let i = 0; i <= 120; i++) {
                            const a = i / 120 * Math.PI * 2
                            const r = R - 6 * (1 - Math.cos(9 * (a + turn))) / 2
                            const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a)
                            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
                        }
                        c.closePath(); c.fill()
                    }
                }
                Canvas {
                    id: face
                    anchors.centerIn: parent
                    width: 116 * root.s; height: width
                    // the shell's copy of your picture first, then the one SDDM knows
                    readonly property var tries: [root.cfg("avatarDir", "") ? root.cfg("avatarDir", "") + "/" + root.userName + ".png" : "",
                                                  users.currentItem ? users.currentItem.uicon : ""].filter(function(p) { return p.length > 0 })
                    property string src: ""
                    property int at: 0
                    property bool ok: false
                    function next() {
                        ok = false
                        if (at >= tries.length) { src = ""; requestPaint(); return }
                        src = tries[at].indexOf("/") === 0 ? "file://" + tries[at] : tries[at]
                        at++
                        if (isImageLoaded(src)) { ok = true; requestPaint() } else loadImage(src)
                    }
                    onTriesChanged: { at = 0; next() }
                    Component.onCompleted: if (at === 0) next()
                    onImageLoaded: { if (src.length === 0) return; if (isImageLoaded(src) && !isImageError(src)) { ok = true; requestPaint() } else next() }
                    onPaint: {
                        const c = getContext("2d")
                        c.reset()
                        if (!ok) return
                        c.save()
                        c.beginPath(); c.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2, false); c.closePath()
                        c.clip()
                        c.drawImage(src, 0, 0, width, height)
                        c.restore()
                    }
                }
                Text {
                    visible: !face.ok
                    anchors.centerIn: parent
                    text: root.userShown.length ? root.userShown.charAt(0).toUpperCase() : "?"
                    color: root.inkPrimaryC
                    font.family: root.fontName
                    font.pixelSize: 56 * root.s
                    font.weight: Font.DemiBold
                }
            }

            // the name, with arrows when there are more users
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * root.s
                IconButton {
                    visible: users.count > 1
                    width: 36 * root.s; height: width; kind: "left"
                    tone: "transparent"; hoverTone: root.surfaceHighest; ink: root.inkVariant
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { users.currentIndex = (users.currentIndex + users.count - 1) % users.count; pw.text = ""; root.message = ""; pw.forceActiveFocus() }
                }
                Text {
                    text: root.userShown
                    color: root.ink
                    font.family: root.fontName
                    font.pixelSize: 30 * root.s
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                IconButton {
                    visible: users.count > 1
                    width: 36 * root.s; height: width; kind: "right"
                    tone: "transparent"; hoverTone: root.surfaceHighest; ink: root.inkVariant
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { users.currentIndex = (users.currentIndex + 1) % users.count; pw.text = ""; root.message = ""; pw.forceActiveFocus() }
                }
            }

            // the password
            Rectangle {
                width: parent.width
                height: 60 * root.s
                radius: height / 2
                color: root.surfaceHigh
                border.width: pw.activeFocus ? 2 : 1
                border.color: root.message.length > 0 ? root.errorColor : (pw.activeFocus ? root.primary : root.alpha(root.outline, 0.5))
                Behavior on border.color { ColorAnimation { duration: 160 } }
                TextInput {
                    id: pw
                    anchors.left: parent.left; anchors.leftMargin: 26 * root.s
                    anchors.right: go.left; anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.ink
                    selectionColor: root.primary
                    font.family: root.fontName
                    font.pixelSize: 20 * root.s
                    font.letterSpacing: 3
                    clip: true
                    enabled: !root.busy
                    onTextChanged: { if (text.length) root.message = ""; idle.restart() }
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                    Keys.onEscapePressed: { text = ""; root.rest() }
                }
                Text {
                    visible: pw.text.length === 0
                    anchors.left: pw.left; anchors.verticalCenter: parent.verticalCenter
                    text: root.tr("Password")
                    color: root.inkVariant
                    opacity: 0.8
                    font.family: root.fontName
                    font.pixelSize: 18 * root.s
                }
                // sign in: the arrow turns into a spinner while it checks
                Rectangle {
                    id: go
                    width: 46 * root.s; height: width
                    radius: goM.pressed ? 14 * root.s : width / 2
                    anchors.right: parent.right; anchors.rightMargin: 7 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    color: pw.text.length > 0 || root.busy ? root.primary : root.surfaceHighest
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on radius { NumberAnimation { duration: 160 } }
                    Glyph { anchors.centerIn: parent; kind: "arrow"; visible: !root.busy; color: pw.text.length > 0 ? root.inkPrimary : root.inkVariant }
                    Canvas {
                        id: spin
                        anchors.centerIn: parent
                        width: 24 * root.s; height: width
                        visible: root.busy
                        RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.busy }
                        onPaint: { const c = getContext("2d"); c.reset(); c.strokeStyle = root.inkPrimary; c.lineWidth = 3; c.lineCap = "round"
                                   c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.4, false); c.stroke() }
                    }
                    MouseArea { id: goM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                }
            }

            // what went wrong, or caps lock
            Item {
                width: parent.width
                height: 22 * root.s
                visible: msgText.text.length > 0
                Text {
                    id: msgText
                    anchors.centerIn: parent
                    text: root.message.length > 0 ? root.message : (keyboard.capsLock ? root.tr("Caps Lock is on") : (root.busy ? root.tr("Signing in...") : ""))
                    color: root.message.length > 0 ? root.errorColor : root.inkVariant
                    font.family: root.fontName
                    font.pixelSize: 15 * root.s
                }
            }
        }
    }

    // ---------------- the bottom row: session, keyboard, power ----------------
    Item {
        id: bottom
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 40 * root.s
        height: 56 * root.s
        opacity: root.awake ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        property string fontName: root.fontName

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s
            // the session: click to go to the next one
            Rectangle {
                visible: sessions.count > 0
                height: 48 * root.s
                width: sRow.width + 36 * root.s
                radius: sM.pressed ? 14 * root.s : height / 2
                color: sM.containsMouse ? root.surfaceHighest : root.alpha(root.surfaceHigh, 0.9)
                Behavior on radius { NumberAnimation { duration: 160 } }
                Row {
                    id: sRow
                    anchors.centerIn: parent
                    spacing: 10 * root.s
                    Glyph { kind: "desktop"; color: root.primary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.sessionName; color: root.ink; font.family: root.fontName; font.pixelSize: 16 * root.s; anchors.verticalCenter: parent.verticalCenter }
                    Glyph { kind: "right"; visible: sessions.count > 1; color: root.inkVariant; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: sM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { sessions.currentIndex = (sessions.currentIndex + 1) % Math.max(1, sessions.count); pw.forceActiveFocus() } }
            }
            // the keyboard layout
            Rectangle {
                visible: keyboard.layouts && keyboard.layouts.length > 1
                height: 48 * root.s
                width: kRow.width + 36 * root.s
                radius: kM.pressed ? 14 * root.s : height / 2
                color: kM.containsMouse ? root.surfaceHighest : root.alpha(root.surfaceHigh, 0.9)
                Row {
                    id: kRow
                    anchors.centerIn: parent
                    spacing: 10 * root.s
                    Glyph { kind: "keyboard"; color: root.primary; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: keyboard.layouts && keyboard.layouts.length > keyboard.currentLayout ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
                        color: root.ink; font.family: root.fontName; font.pixelSize: 16 * root.s; anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea { id: kM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; pw.forceActiveFocus() } }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s
            property string fontName: root.fontName
            IconButton { kind: "sleep"; tip: root.tr("Sleep"); visible: sddm.canSuspend; width: 52 * root.s; height: width
                         tone: root.alpha(root.surfaceHigh, 0.9); hoverTone: root.surfaceHighest; ink: root.ink; onClicked: sddm.suspend() }
            IconButton { kind: "restart"; tip: root.tr("Restart"); visible: sddm.canReboot; width: 52 * root.s; height: width
                         tone: root.alpha(root.surfaceHigh, 0.9); hoverTone: root.surfaceHighest; ink: root.ink; onClicked: sddm.reboot() }
            IconButton { kind: "power"; tip: root.tr("Shut down"); visible: sddm.canPowerOff; width: 52 * root.s; height: width
                         tone: root.secondaryContainer; hoverTone: Qt.lighter(root.secondaryContainer, 1.25); ink: root.ink; onClicked: sddm.powerOff() }
        }
    }

    // the big on-screen keyboard (Qt's qtvirtualkeyboard, which SDDM starts when its config says so, often because of
    // another theme) is put away as soon as it opens: this login screen is for a keyboard. theme.conf
    // virtualKeyboard=true leaves it for a touch screen.
    Connections {
        target: Qt.inputMethod
        function onVisibleChanged() { if (Qt.inputMethod.visible && root.cfg("virtualKeyboard", "false") !== "true") Qt.inputMethod.hide() }
    }
    Timer {
        interval: 400; running: root.awake; repeat: true
        onTriggered: if (Qt.inputMethod.visible && root.cfg("virtualKeyboard", "false") !== "true") Qt.inputMethod.hide()
    }

    // ---------------- waking it up ----------------
    focus: true
    Keys.onPressed: function(event) {
        if (root.awake) return
        root.wake()
        // the key you pressed is the first letter of the password
        if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) pw.insert(pw.cursorPosition, event.text)
        event.accepted = true
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !root.awake
        onClicked: root.wake()
    }
    MouseArea {
        anchors.fill: parent
        z: 100
        enabled: root.awake
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: idle.restart()
    }
    Component.onCompleted: root.forceActiveFocus()
}
