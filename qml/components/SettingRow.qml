// A settings card: title + subtitle on the left, any controls on the right.
import QtQuick
import "../ui"

Rectangle {
    id: row
    property string title: ""
    property string subtitle: ""
    default property alias controls: slot.data

    width: parent ? parent.width : 400
    height: Math.max(UI.px(58), texts.implicitHeight + 22, slot.implicitHeight + 22)
    radius: UI.radius
    color: UI.card
    border.color: UI.border

    Column {
        id: texts
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { font.weight: UI.textWeight; width: parent.width; text: row.title; color: UI.text; font.pixelSize: UI.px(13.5); elide: Text.ElideRight }
        Text { font.weight: UI.textWeight; width: parent.width; text: row.subtitle; visible: row.subtitle !== ""; color: UI.textFaint; font.pixelSize: UI.px(11.5); wrapMode: Text.Wrap }
    }
    Row {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
