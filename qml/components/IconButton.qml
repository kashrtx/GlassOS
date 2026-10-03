// Square glyph button with an optional tooltip.
import QtQuick
import QtQuick.Controls
import "../ui"

AbstractButton {
    id: b
    property string iconName: ""      // icon from qml/icons (preferred)
    property string glyph: ""         // or a short text glyph such as "1:1"
    property string tip: ""
    property int size: 32
    property int glyphSize: 15
    property bool active: false
    property color glyphColor: UI.text
    property color hoverColor: UI.hover

    implicitWidth: UI.px(size)
    implicitHeight: UI.px(size)
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.35

    background: Rectangle {
        radius: UI.radiusSmall
        color: b.down ? UI.pressed : (b.active ? UI.accentSoft : (b.hovered ? b.hoverColor : "transparent"))
        Behavior on color { ColorAnimation { duration: UI.dur(80) } }
    }
    contentItem: Item {
        Icon {
            visible: b.iconName !== ""
            anchors.centerIn: parent
            name: b.iconName
            size: UI.px(b.glyphSize + 3)
            opacity: b.enabled ? 1 : 0.6
        }
        Text {
            font.weight: UI.textWeight
            visible: b.iconName === ""
            anchors.centerIn: parent
            text: b.glyph
            color: b.glyphColor
            font.pixelSize: UI.px(b.glyphSize)
        }
    }

    GTip { text: b.tip; visible: b.hovered && b.tip !== "" }
}
