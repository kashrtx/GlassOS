import QtQuick
import QtQuick.Controls
import "../ui"

Slider {
    id: s
    hoverEnabled: true
    implicitHeight: UI.px(26)
    background: Rectangle {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.14)
        Rectangle {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: UI.accent
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: UI.px(18)
        height: width
        radius: width / 2
        color: UI.accent
        border.width: 4
        border.color: Qt.rgba(0.1, 0.12, 0.17, 1)
        scale: s.pressed ? 1.15 : (s.hovered ? 1.07 : 1)
        Behavior on scale { NumberAnimation { duration: UI.dur(90) } }
    }
}
