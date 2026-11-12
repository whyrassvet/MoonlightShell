import QtQuick

Text {
    property string kind: "body"
    color: "#F6F5F4"
    font.family: Fonts.family(kind)
    font.pixelSize: 14
}
