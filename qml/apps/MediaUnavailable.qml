// Shown instead of the Media Player when QtMultimedia isn't available.
import QtQuick
import "../ui"
import "../components"

FocusScope {
    property var hostWindow: null
    property string filePath: ""
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 460)
        spacing: 14
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "app-media"; size: 72; opacity: 0.6 }
        Text { elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Media playback isn't available"; color: UI.text; font.pixelSize: UI.px(18); font.weight: Font.DemiBold }
        Text {
            font.weight: UI.textWeight
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            color: UI.textDim; font.pixelSize: UI.px(13)
            text: "This PySide6 build has no QtMultimedia module. Reinstall the full package and restart GlassOS:"
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: cmd.implicitWidth + 30; height: cmd.implicitHeight + 18
            radius: UI.radiusSmall
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: UI.border
            TextEdit { id: cmd; anchors.centerIn: parent; readOnly: true; selectByMouse: true; text: "pip install --force-reinstall PySide6"; color: UI.accent; font.family: UI.monoFont; font.pixelSize: UI.px(13) }
        }
    }
}
