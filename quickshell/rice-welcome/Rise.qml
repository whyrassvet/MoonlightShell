import QtQuick

// A line of text where every letter rises into place on its own, a little after the one before it.
Row {
    id: rise
    property string text: ""
    property bool shown: false
    property int px: 34
    property bool bold: true
    property color tint: "#F6F5F4"
    property string kind: "title"
    property int startDelay: 0          // wait this long before the first letter (lets the line before leave)
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    Repeater {
        model: rise.text.length
        T {
            id: ch
            kind: rise.kind
            text: rise.text[index] === " " ? " " : rise.text[index]
            font.pixelSize: rise.px
            font.bold: rise.bold
            color: rise.tint
            property real k: rise.shown ? 1 : 0
            opacity: k
            transform: Translate { y: (1 - ch.k) * rise.px * 0.7 }
            Behavior on k {
                SequentialAnimation {
                    PauseAnimation { duration: rise.shown ? rise.startDelay + index * 34 : index * 6 }
                    NumberAnimation { duration: 460; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
