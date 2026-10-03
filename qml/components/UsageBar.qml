import QtQuick
import "../ui"

Rectangle {
    property real value: 0      // 0..100
    width: UI.px(160)
    height: 6
    radius: 3
    color: Qt.rgba(1, 1, 1, 0.12)
    Rectangle {
        width: parent.width * Math.max(0, Math.min(100, parent.value)) / 100
        height: parent.height
        radius: 3
        color: parent.value > 85 ? UI.danger : (parent.value > 65 ? UI.warning : UI.accent)
        Behavior on width { NumberAnimation { duration: UI.dur(400); easing.type: Easing.OutCubic } }
    }
}
