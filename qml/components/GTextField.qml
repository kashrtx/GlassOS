import QtQuick
import QtQuick.Controls
import "../ui"

TextField {
    id: f
    property string leading: ""      // optional icon name shown at the start (e.g. "search")
    property int radiusOverride: -1

    implicitHeight: UI.px(34)
    color: UI.text
    placeholderTextColor: UI.textFaint
    selectionColor: UI.alpha(UI.accent, 0.45)
    selectedTextColor: "white"
    selectByMouse: true
    font.pixelSize: UI.px(13)
    leftPadding: leading !== "" ? UI.px(32) : 10
    rightPadding: 10
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: f.radiusOverride >= 0 ? f.radiusOverride : UI.radiusSmall
        color: UI.field
        border.width: f.activeFocus ? 1.5 : 1
        border.color: f.activeFocus ? UI.accent : UI.border
        Behavior on border.color { ColorAnimation { duration: UI.dur(120) } }
        Icon {
            visible: f.leading !== ""
            name: f.leading
            size: UI.px(15)
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            opacity: 0.7
        }
    }
}
