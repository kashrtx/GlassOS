// Archive preview (ZIP / TAR): contents, sizes, and one-click extraction.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"

FocusScope {
    id: av
    anchors.fill: parent
    visible: false
    z: 800
    property string path: ""
    property var info: ({})
    signal extractRequested(string path)

    function openArchive(p) {
        path = p
        info = Storage.archiveInfo(p)
        visible = true
        forceActiveFocus()
    }
    function close() { visible = false }
    Keys.onEscapePressed: close()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent; onClicked: av.close(); onWheel: function (wheel) { wheel.accepted = true } }
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 30, UI.px(600))
        height: Math.min(parent.height - 30, UI.px(480))
        radius: UI.radiusLarge
        color: "#171c28"
        border.color: UI.borderStrong
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon { name: "file-archive"; size: UI.px(36) }
                Column {
                    Layout.fillWidth: true
                    Text { width: parent.width; text: av.path.split("/").pop(); color: UI.text; font.pixelSize: UI.px(15); font.weight: Font.DemiBold; elide: Text.ElideMiddle }
                    Text {
                        font.weight: UI.textWeight
                        text: av.info.ok ? av.info.count + " items  ·  " + UI.fmtSize(av.info.total) + " uncompressed" : ""
                        color: UI.textFaint; font.pixelSize: UI.px(11.5)
                    }
                }
                IconButton { iconName: "close"; onClicked: av.close() }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: UI.radiusSmall
                color: UI.field
                border.color: UI.border
                ListView {
                    id: entries
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    reuseItems: true
                    model: av.info.ok ? av.info.entries : []
                    ScrollBar.vertical: GScrollBar {}
                    delegate: Item {
                        width: entries.width
                        height: UI.px(28)
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 + Math.min(6, modelData.name.split("/").length - 1) * 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Icon { name: modelData.isDir ? "place-folder" : Storage.iconFor(modelData.name); size: UI.px(18) }
                            Text { font.weight: UI.textWeight; text: modelData.name.split("/").pop(); color: UI.text; font.pixelSize: UI.px(12) }
                        }
                        Text {
                            elide: Text.ElideRight
                            font.weight: UI.textWeight
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.isDir ? "" : UI.fmtSize(modelData.size)
                            color: UI.textFaint; font.pixelSize: UI.px(11)
                        }
                    }
                    Column {
                        visible: !av.info.ok
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 8
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "warning-color"; size: 40 }
                        Text { font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: av.info.error || ""; color: UI.textDim; font.pixelSize: UI.px(12.5) }
                    }
                }
            }
            Text { font.weight: UI.textWeight; visible: av.info.ok === true && av.info.truncated === true; text: "Showing the first " + (av.info.entries ? av.info.entries.length : 0) + " items"; color: UI.textFaint; font.pixelSize: UI.px(11) }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                GButton { text: "Close"; onClicked: av.close() }
                GButton { text: "Extract here"; iconName: "import"; kind: "primary"; enabled: av.info.ok === true; onClicked: { av.close(); av.extractRequested(av.path) } }
            }
        }
    }
}
