import QtQuick
import "../ui"

Rectangle {
    id: boot
    color: "#05070c"
    signal finished()

    function start() {
        if (!UI.animations) { visible = false; finished(); return }
        seq.start()
    }

    Column {
        id: logo
        anchors.centerIn: parent
        spacing: 26
        opacity: 0
        scale: 0.9

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            spacing: 7
            Repeater {
                model: 4
                Rectangle {
                    width: 46; height: 46; radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.4) }
                        GradientStop { position: 1; color: UI.alpha(UI.accent, 0.55) }
                    }
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GlassOS"
            color: "white"
            font.pixelSize: 30
            font.weight: Font.Light
            font.letterSpacing: 6
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9
            Repeater {
                model: 5
                Rectangle {
                    id: dot
                    width: 7; height: 7; radius: 3.5
                    color: UI.accent
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        id: spinning
                        running: boot.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 120 }
                        NumberAnimation { to: 1; duration: 300 }
                        NumberAnimation { to: 0.25; duration: 450 }
                        PauseAnimation { duration: (4 - index) * 120 }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: seq
        ParallelAnimation {
            NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 450 }
            NumberAnimation { target: logo; property: "scale"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 900 }
        ParallelAnimation {
            NumberAnimation { target: boot; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InQuad }
            NumberAnimation { target: logo; property: "scale"; to: 1.15; duration: 420; easing.type: Easing.InQuad }
        }
        ScriptAction { script: { boot.visible = false; boot.finished() } }
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function (wheel) { wheel.accepted = true } }
}
