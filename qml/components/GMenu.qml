// Context menu. Usage:
//   menu.show(someItem, mouse.x, mouse.y, [
//       { text: "Open", icon: "folder-open", shortcut: "Enter", action: function() { ... } },
//       { separator: true },
//       { text: "Delete", danger: true, enabled: false, action: ... } ])
import QtQuick
import QtQuick.Controls
import "../ui"

Popup {
    id: menu
    property var items: []
    property int menuWidth: 236

    parent: Overlay.overlay
    width: menuWidth
    padding: 5
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function show(item, px, py, list) {
        // items may carry visible: false; separators never lead, trail or double up
        if (list !== undefined) {
            var shown = list.filter(function (it) { return it && it.visible !== false })
            var clean = []
            for (var i = 0; i < shown.length; i++) {
                if (shown[i].separator && (clean.length === 0 || clean[clean.length - 1].separator)) continue
                clean.push(shown[i])
            }
            while (clean.length && clean[clean.length - 1].separator) clean.pop()
            items = clean
        }
        var p = item.mapToItem(null, px, py)
        var W = parent ? parent.width : 1920, H = parent ? parent.height : 1080
        var h = implicitHeight
        x = Math.max(4, Math.min(p.x, W - width - 4))
        y = (p.y + h > H - 4) ? Math.max(4, p.y - h) : p.y
        open()
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(110) }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: UI.dur(110); easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: UI.dur(80) } }

    background: GlassSurface {
        sceneX: menu.x
        sceneY: menu.y
        radius: UI.radius
        borderColor: UI.borderStrong
    }

    contentItem: Column {
        Repeater {
            model: menu.items
            delegate: Item {
                width: menu.availableWidth
                height: modelData.separator ? 9 : UI.px(32)
                readonly property bool itemEnabled: modelData.enabled === undefined || modelData.enabled

                Rectangle {
                    visible: modelData.separator === true
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: UI.border
                }
                Rectangle {
                    visible: !modelData.separator
                    anchors.fill: parent
                    radius: UI.radiusSmall
                    color: itemMouse.containsMouse && parent.itemEnabled
                           ? (modelData.danger ? UI.alpha(UI.danger, 0.22) : UI.hover) : "transparent"
                }
                Row {
                    visible: !modelData.separator
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    opacity: parent.itemEnabled ? 1 : 0.4
                    Item {
                        width: UI.px(18)
                        height: UI.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: modelData.icon || ""; size: UI.px(16) }
                    }
                    Text {
                        font.weight: UI.textWeight
                        text: modelData.text || ""
                        color: modelData.danger ? UI.danger : UI.text
                        font.pixelSize: UI.px(13)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    elide: Text.ElideRight
                    font.weight: UI.textWeight
                    visible: !modelData.separator && !!modelData.shortcut
                    text: modelData.shortcut || ""
                    color: UI.textFaint
                    font.pixelSize: UI.px(11)
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !modelData.separator
                    cursorShape: parent.itemEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!parent.itemEnabled) return
                        var act = modelData.action
                        menu.close()
                        if (act) act()
                    }
                }
            }
        }
    }
}
