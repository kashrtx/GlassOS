import QtQuick
import QtQuick.Controls
import "../ui"

Popup {
    id: pd
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: UI.px(420)
    modal: true
    focus: true
    padding: 22
    closePolicy: Popup.CloseOnEscape
    property string mode: "shutdown"      // "shutdown" | "restart"
    property int unsaved: 0
    signal confirmed(string mode)

    function ask(m, unsavedCount) { mode = m; unsaved = unsavedCount; open() }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(140) }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: UI.dur(180); easing.type: Easing.OutBack }
    }
    background: Rectangle { radius: UI.radiusLarge; color: "#171c28"; border.color: UI.borderStrong }

    contentItem: Column {
        spacing: 16
        Row {
            spacing: 12
            Icon { name: pd.mode === "restart" ? "refresh" : "power"; size: UI.px(28) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pd.mode === "restart" ? "Restart GlassOS?" : "Shut down GlassOS?"
                color: UI.text; font.pixelSize: UI.px(18); font.weight: Font.DemiBold
            }
        }
        Text {
            font.weight: UI.textWeight
            width: parent.width
            wrapMode: Text.Wrap
            color: pd.unsaved > 0 ? UI.warning : UI.textDim
            font.pixelSize: UI.px(13)
            text: pd.unsaved > 0
                  ? pd.unsaved + (pd.unsaved === 1 ? " window has" : " windows have") + " unsaved changes that will be lost."
                  : "Your files and settings are saved automatically."
        }
        Row {
            anchors.right: parent.right
            spacing: 8
            GButton { text: "Cancel"; onClicked: pd.close() }
            GButton {
                text: pd.mode === "restart" ? "Restart" : "Shut down"
                kind: pd.unsaved > 0 ? "danger" : "primary"
                onClicked: { pd.close(); pd.confirmed(pd.mode) }
            }
        }
    }
}
