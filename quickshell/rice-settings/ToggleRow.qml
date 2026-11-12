import QtQuick

SettingRow {
    id: row
    property bool checked: false
    signal toggled(bool value)
    reserved: 96

    Tog {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        checked: row.checked
        onToggled: function(v) { row.toggled(v) }
    }
}