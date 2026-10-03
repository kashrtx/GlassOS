// Alt+Tab overlay. Each press of the shortcut advances; it commits after a
// short pause (Qt can't see the Alt release reliably), on click, or on Enter.
import QtQuick
import "../ui"

FocusScope {
    id: sw
    visible: false
    property var items: []
    property int index: 0

    function advance(windowsByRecency) {
        if (!visible) {
            if (windowsByRecency.length < 1) return
            items = windowsByRecency
            index = windowsByRecency.length > 1 ? 1 : 0
            visible = true
            forceActiveFocus()
        } else {
            index = (index + 1) % items.length
        }
        commitTimer.restart()
    }
    function commit() {
        commitTimer.stop()
        if (!visible) return
        visible = false
        var w = items[index]
        items = []
        if (w && UI.wm) UI.wm.focusWindow(w)
    }
    function cancel() { commitTimer.stop(); visible = false; items = [] }

    Timer { id: commitTimer; interval: 900; onTriggered: sw.commit() }
    Keys.onReturnPressed: commit()
    Keys.onEscapePressed: cancel()
    Keys.onLeftPressed: { index = (index - 1 + items.length) % items.length; commitTimer.restart() }
    Keys.onRightPressed: { index = (index + 1) % items.length; commitTimer.restart() }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: sw.cancel() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, row.implicitWidth + 40)
        height: UI.px(150)
        radius: UI.radiusLarge
        color: Qt.rgba(0.08, 0.1, 0.15, 0.94)
        border.color: UI.borderStrong
        clip: true
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: sw.items
                delegate: Rectangle {
                    width: UI.px(132); height: UI.px(118)
                    radius: UI.radius
                    color: index === sw.index ? UI.accentSoft : (tileMouse.containsMouse ? UI.hover : "transparent")
                    border.width: index === sw.index ? 2 : 0
                    border.color: UI.accent
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { name: modelData.icon; size: UI.px(38); anchors.horizontalCenter: parent.horizontalCenter; opacity: modelData.minimized ? 0.5 : 1 }
                        Text {
                            font.weight: UI.textWeight
                            width: UI.px(118)
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.title
                            color: UI.text; font.pixelSize: UI.px(11.5)
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { sw.index = index; sw.commit() } }
                }
            }
        }
    }
}
