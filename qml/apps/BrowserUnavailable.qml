// Shown instead of AeroBrowser when QtWebEngine isn't installed.
import QtQuick
import "../ui"
import "../components"

FocusScope {
    property var hostWindow: null
    property string initialUrl: ""
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 460)
        spacing: 14
        Icon { name: "globe"; size: 60; anchors.horizontalCenter: parent.horizontalCenter }
        Text { elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "AeroBrowser needs QtWebEngine"; color: UI.text; font.pixelSize: UI.px(18); font.weight: Font.DemiBold }
        Text {
            font.weight: UI.textWeight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: UI.textDim
            font.pixelSize: UI.px(13)
            text: "Install the full PySide6 package, then restart GlassOS:"
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: cmd.implicitWidth + 30; height: cmd.implicitHeight + 18
            radius: UI.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: UI.border
            TextEdit { id: cmd; anchors.centerIn: parent; readOnly: true; selectByMouse: true; text: "pip install PySide6-Addons"; color: UI.accent; font.family: UI.monoFont; font.pixelSize: UI.px(13) }
        }
        GButton { anchors.horizontalCenter: parent.horizontalCenter; text: "Restart GlassOS"; kind: "primary"; onClicked: UI.wm.requestPower("restart") }
    }
}
