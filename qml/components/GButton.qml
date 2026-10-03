// Text button. kind: "normal" | "primary" | "danger" | "flat"
import QtQuick
import QtQuick.Controls
import "../ui"

AbstractButton {
    id: b
    property string kind: "normal"
    property string iconName: ""
    property int fontSize: 13

    implicitHeight: UI.px(32)
    implicitWidth: Math.max(UI.px(76), row.implicitWidth + 26)
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        radius: UI.radiusSmall
        color: {
            if (b.kind === "primary") return b.down ? Qt.darker(UI.accent, 1.25) : (b.hovered ? Qt.lighter(UI.accent, 1.12) : UI.accent)
            if (b.kind === "danger") return b.down ? Qt.darker(UI.danger, 1.3) : (b.hovered ? Qt.lighter(UI.danger, 1.08) : UI.alpha(UI.danger, 0.85))
            if (b.kind === "flat") return b.down ? UI.pressed : (b.hovered ? UI.hover : "transparent")
            return b.down ? UI.pressed : (b.hovered ? UI.cardStrong : UI.card)
        }
        border.width: b.kind === "normal" || b.visualFocus ? 1 : 0
        border.color: b.visualFocus ? UI.accent : UI.border
        Behavior on color { ColorAnimation { duration: UI.dur(90) } }
    }

    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Icon {
                visible: b.iconName !== ""
                name: b.iconName
                size: UI.px(b.fontSize + 3)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: b.text
                visible: b.text !== ""
                color: b.kind === "primary" ? UI.accentText : (b.kind === "danger" ? "white" : UI.text)
                font.pixelSize: UI.px(b.fontSize)
                font.weight: b.kind === "primary" ? Font.DemiBold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
