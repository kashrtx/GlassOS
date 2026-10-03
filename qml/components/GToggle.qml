import QtQuick
import QtQuick.Controls
import "../ui"

Switch {
    id: s
    hoverEnabled: true
    padding: 0
    spacing: 10
    indicator: Rectangle {
        implicitWidth: UI.px(40)
        implicitHeight: UI.px(22)
        x: s.leftPadding
        y: (s.height - height) / 2
        radius: height / 2
        color: s.checked ? UI.accent : (s.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.1))
        border.color: s.checked ? "transparent" : UI.borderStrong
        Behavior on color { ColorAnimation { duration: UI.dur(140) } }
        Rectangle {
            width: parent.height - 8
            height: width
            radius: width / 2
            y: 4
            x: s.checked ? parent.width - width - 4 : 4
            color: s.checked ? UI.accentText : UI.textDim
            Behavior on x { NumberAnimation { duration: UI.dur(140); easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        font.weight: UI.textWeight
        text: s.text
        visible: s.text !== ""
        leftPadding: s.indicator.width + s.spacing
        color: UI.text
        font.pixelSize: UI.px(13)
        verticalAlignment: Text.AlignVCenter
    }
}
