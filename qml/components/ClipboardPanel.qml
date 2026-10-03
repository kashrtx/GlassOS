// Clipboard history (Ctrl+Alt+V). Picking an item pastes it straight into the
// text field you were typing in (or copies it, if that's not possible).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"

Popup {
    id: panel
    parent: Overlay.overlay
    width: Math.min(UI.px(400), parent ? parent.width - 20 : 400)
    height: Math.min(UI.px(520), parent ? parent.height - UI.taskbarHeight - 30 : 520)
    x: parent ? parent.width - width - 10 : 0
    // slide-in offset: animating y directly would replace this binding with a fixed number,
    // so a popup that grows after opening (e.g. notifications) would hang off the screen
    property real slide: 0
    y: (parent ? parent.height - UI.taskbarHeight - height - 10 : 0) + slide
    padding: 14
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property var target: null          // item that had focus when the panel opened
    property int selected: 0
    signal pick(string text, var target)

    readonly property var items: {
        var all = Clipboard ? Clipboard.history : []
        var q = filter.text.toLowerCase()
        return q ? all.filter(function (i) { return i.text.toLowerCase().indexOf(q) >= 0 }) : all
    }

    function openFor(item) { target = item; filter.text = ""; selected = 0; open(); list.forceActiveFocus() }
    function choose(i) { if (i >= 0 && i < items.length) { var t = items[i].text, tg = target; close(); pick(t, tg) } }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(140) }
        NumberAnimation { property: "slide"; from: 24; to: 0; duration: UI.dur(200); easing.type: Easing.OutCubic }
    }
    background: GlassSurface { sceneX: panel.x; sceneY: panel.y; radius: UI.radiusLarge; borderColor: UI.borderStrong }

    contentItem: ColumnLayout {
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Icon { name: "paste"; size: UI.px(18) }
            Text { elide: Text.ElideRight; Layout.fillWidth: true; text: "Clipboard"; color: UI.text; font.pixelSize: UI.px(15); font.weight: Font.DemiBold }
            GButton { text: "Clear"; kind: "flat"; enabled: Clipboard !== null && Clipboard.history.length > 0; onClicked: Clipboard.clear() }
        }
        GTextField {
            id: filter
            Layout.fillWidth: true
            leading: "search"
            placeholderText: "Search clipboard"
            Keys.onDownPressed: list.forceActiveFocus()
            onAccepted: panel.choose(0)
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: panel.items
            currentIndex: panel.selected
            ScrollBar.vertical: GScrollBar {}
            Keys.onUpPressed: panel.selected = Math.max(0, panel.selected - 1)
            Keys.onDownPressed: panel.selected = Math.min(panel.items.length - 1, panel.selected + 1)
            Keys.onReturnPressed: panel.choose(panel.selected)
            Keys.onEnterPressed: panel.choose(panel.selected)
            Keys.onDeletePressed: if (panel.items[panel.selected]) Clipboard.remove(panel.items[panel.selected].id)
            delegate: Rectangle {
                width: list.width
                height: Math.min(UI.px(84), clipText.implicitHeight + 22)
                radius: UI.radius
                color: index === panel.selected ? UI.accentSoft : (rowMouse.containsMouse ? UI.cardStrong : UI.card)
                border.color: modelData.pinned ? UI.alpha(UI.accent, 0.5) : UI.border
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: panel.selected = index
                    onClicked: panel.choose(index)
                }
                Text {
                    font.weight: UI.textWeight
                    id: clipText
                    anchors.left: parent.left
                    anchors.right: actions.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 11
                    text: modelData.text.length > 400 ? modelData.text.slice(0, 400) + "…" : modelData.text
                    textFormat: Text.PlainText
                    color: UI.text
                    font.pixelSize: UI.px(12.5)
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    IconButton { iconName: modelData.pinned ? "star-filled" : "pin"; size: 26; glyphSize: 11; tip: modelData.pinned ? "Unpin" : "Pin (kept after restart)"; onClicked: Clipboard.togglePin(modelData.id) }
                    IconButton { iconName: "close"; size: 26; glyphSize: 10; tip: "Remove"; onClicked: Clipboard.remove(modelData.id) }
                }
            }
            Column {
                visible: list.count === 0
                anchors.centerIn: parent
                spacing: 8
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "paste"; size: 44; opacity: 0.5 }
                Text { font.weight: UI.textWeight; text: Clipboard ? "Copy some text and it shows up here" : "Clipboard unavailable"; color: UI.textFaint; font.pixelSize: UI.px(12) }
            }
        }
        Text { font.weight: UI.textWeight; text: "Enter pastes  ·  Del removes  ·  pinned items survive restarts"; color: UI.textFaint; font.pixelSize: UI.px(10.5) }
    }
}
