import QtQuick
import QtQuick.Effects

Item {
    id: ri
    property string source: ""
    property real cornerRadius: width / 2
    property int res: 256        // the size it is decoded at (bigger for big pictures)
    property string fallback: ""

    Image {
        id: img
        anchors.fill: parent
        source: ri.source
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
        cache: false
        sourceSize.width: ri.res
        sourceSize.height: ri.res
    }
    Item {
        id: msk
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: ri.cornerRadius }
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: msk
        visible: img.status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        radius: ri.cornerRadius
        color: M3.outlineVariant
        visible: img.status !== Image.Ready
        T { scaled: false; anchors.centerIn: parent; text: ri.fallback; font.pixelSize: parent.width * 0.42; color: M3.inkDim }
    }
}
