import QtQuick

SettingRow {
    id: row
    property string hex: "#F6F5F4"
    signal committed(string value)
    function valid(t) { return /^#[0-9a-fA-F]{6}$/.test(t) }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
            width: 24
            height: 24
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            color: row.valid(hexIn.text) ? hexIn.text : "#000000"
            border.width: 1
            border.color: M3.outline
        }
        Rectangle {
            width: 112
            height: 34
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            color: M3.surfaceLow
            border.width: 1
            border.color: hexIn.activeFocus ? M3.primary : M3.surfaceHighest
            TextInput {
                id: hexIn
                onTextChanged: if (activeFocus) Sfx.play("type")
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: "#F6F5F4"
                font.family: Fonts.code
                font.pixelSize: 13
                text: row.hex
                maximumLength: 7
                selectByMouse: true
                onAccepted: { if (row.valid(text)) row.committed(text) }
            }
        }
        Pill {
            label: I18n.t("Set")
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { if (row.valid(hexIn.text)) row.committed(hexIn.text) }
        }
    }
}
