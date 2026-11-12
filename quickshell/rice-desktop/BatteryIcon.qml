import QtQuick

// Material Symbols battery levels, with Nerd Fonts as a fallback.
MIcon {
    property real percentage: 0
    property bool charging: false
    size: 17
    readonly property int level: Math.max(0, Math.min(10, Math.round(percentage / 10)))
    readonly property int materialLevel: Math.max(0, Math.min(7, Math.round(percentage * 7 / 100)))
    readonly property var materialIcons: ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"]
    readonly property var materialChargingIcons: ["battery_charging_20", "battery_charging_20", "battery_charging_30", "battery_charging_50", "battery_charging_60", "battery_charging_80", "battery_charging_90", "battery_charging_full"]
    readonly property var batteryIcons: [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    readonly property var chargingIcons: [0xF089F, 0xF089C, 0xF0086, 0xF0087, 0xF0088, 0xF089D, 0xF0089, 0xF089E, 0xF008A, 0xF008B, 0xF0085]
    name: charging ? materialChargingIcons[materialLevel] : materialIcons[materialLevel]
    glyph: String.fromCodePoint(charging ? chargingIcons[level] : batteryIcons[level])
}
