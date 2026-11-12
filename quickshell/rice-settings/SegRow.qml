import QtQuick

SettingRow {
    id: row
    property var options: []
    property string current: ""
    signal chosen(string value)
    reserved: segc.implicitWidth + 48

    Seg {
        id: segc
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        options: row.options
        current: row.current
        onChosen: function(v) { row.chosen(v) }
    }
}