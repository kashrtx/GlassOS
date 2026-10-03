import QtQuick
import QtQuick.Controls
import "../ui"

ScrollBar {
    id: sb
    policy: ScrollBar.AsNeeded
    minimumSize: 0.06
    contentItem: Rectangle {
        implicitWidth: sb.orientation === Qt.Vertical ? (sb.hovered || sb.pressed ? 8 : 5) : 40
        implicitHeight: sb.orientation === Qt.Horizontal ? (sb.hovered || sb.pressed ? 8 : 5) : 40
        radius: 4
        color: sb.pressed ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, sb.hovered ? 0.4 : 0.25)
        opacity: sb.active || sb.hovered ? 1 : 0.0
        Behavior on opacity { NumberAnimation { duration: UI.dur(250) } }
    }
    background: Item {}
}
