// Snap Assist: after a window snaps into part of a layout, the empty zones show
// your other windows; click one to snap it there. Esc or a click elsewhere dismisses.
import QtQuick
import "../ui"

FocusScope {
    id: assist
    visible: false
    property var zones: []          // remaining zone names
    property var candidates: []     // GlassWindow objects
    property real areaW: width
    property real areaH: height
    signal chosen(string zone, var window)

    function open(zoneList, wins) {
        zones = zoneList
        candidates = wins
        visible = zoneList.length > 0 && wins.length > 0
        if (visible) forceActiveFocus()
    }
    function close() { visible = false; zones = []; candidates = [] }

    Keys.onEscapePressed: close()
    MouseArea { anchors.fill: parent; onClicked: assist.close() }

    Repeater {
        model: assist.zones
        delegate: Item {
            id: zoneItem
            readonly property var f: UI.zoneFrac(modelData)
            readonly property string zone: modelData
            x: f[0] * assist.areaW + 8
            y: f[1] * assist.areaH + 8
            width: f[2] * assist.areaW - 16
            height: f[3] * assist.areaH - 16

            GlassSurface {
                anchors.fill: parent
                sceneX: zoneItem.x
                sceneY: zoneItem.y
                radius: UI.radiusLarge
                borderColor: UI.alpha(UI.accent, 0.6)
            }
            MouseArea { anchors.fill: parent }   // clicks inside a zone don't dismiss
            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: tiles.implicitHeight
                clip: true
                Flow {
                    id: tiles
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: assist.candidates
                        delegate: MouseArea {
                            id: tile
                            width: Math.min(UI.px(150), Math.max(UI.px(110), (tiles.width - 20) / 3))
                            height: UI.px(104)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: assist.chosen(zoneItem.zone, modelData)
                            Rectangle {
                                anchors.fill: parent
                                radius: UI.radius
                                color: tile.containsMouse ? UI.accentSoft : UI.card
                                border.color: tile.containsMouse ? UI.accent : UI.border
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: UI.px(40) }
                                Text {
                                    font.weight: UI.textWeight
                                    width: tile.width - 14
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.title
                                    color: UI.text
                                    font.pixelSize: UI.px(11.5)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
