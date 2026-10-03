// Snap Layouts flyout (hover a window's maximize button): pick a zone in one of
// several layouts; Snap Assist then offers your other windows for the rest.
import QtQuick
import QtQuick.Controls
import "../ui"

Popup {
    id: picker
    signal picked(string zone)
    parent: Overlay.overlay
    padding: 10
    modal: false
    focus: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function show(button) {
        var p = button.mapToItem(null, button.width / 2, button.height)
        var W = parent ? parent.width : 1920
        x = Math.max(6, Math.min(p.x - implicitWidth / 2, W - implicitWidth - 6))
        y = p.y + 6
        open()
        closeTimer.restart()
    }

    // close shortly after the pointer leaves both the button and the flyout
    Timer { id: closeTimer; interval: 900; onTriggered: if (!hover.hovered) picker.close() }
    HoverHandler { id: hover; onHoveredChanged: if (!hovered) closeTimer.restart() }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(120) } }
    background: GlassSurface { sceneX: picker.x; sceneY: picker.y; radius: UI.radius; borderColor: UI.borderStrong }

    contentItem: Grid {
        columns: 3
        spacing: 8
        Repeater {
            model: UI.snapLayouts
            delegate: Item {
                id: layoutTile
                readonly property var zoneList: modelData
                width: 92; height: 58
                Rectangle { anchors.fill: parent; radius: 7; color: Qt.rgba(1, 1, 1, 0.05); border.color: UI.border }
                Repeater {
                    model: layoutTile.zoneList
                    delegate: Rectangle {
                        readonly property var f: UI.zoneFrac(modelData)
                        x: 4 + f[0] * (layoutTile.width - 8) + 1.5
                        y: 4 + f[1] * (layoutTile.height - 8) + 1.5
                        width: f[2] * (layoutTile.width - 8) - 3
                        height: f[3] * (layoutTile.height - 8) - 3
                        radius: 4
                        color: cellMouse.containsMouse ? UI.accent : Qt.rgba(1, 1, 1, 0.16)
                        Behavior on color { ColorAnimation { duration: UI.dur(80) } }
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { picker.close(); picker.picked(modelData) }
                        }
                    }
                }
            }
        }
    }
}
