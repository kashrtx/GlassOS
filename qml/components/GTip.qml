import QtQuick
import QtQuick.Controls
import "../ui"

ToolTip {
    id: tip
    delay: 550
    timeout: 6000
    padding: 7
    contentItem: Text {
        font.weight: UI.textWeight
        text: tip.text
        color: UI.text
        font.pixelSize: UI.px(12)
    }
    background: Rectangle {
        color: Qt.rgba(0.08, 0.1, 0.14, 0.96)
        radius: 6
        border.color: UI.borderStrong
    }
}
