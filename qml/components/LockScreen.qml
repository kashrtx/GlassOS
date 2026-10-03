// Lock screen: frosted wallpaper, big clock. Click, drag up, or press any key to unlock.
import QtQuick
import "../ui"

FocusScope {
    id: lock
    property bool locked: false
    visible: locked || slideOut.running
    signal unlocked()

    function lockNow() {
        slideOut.stop()
        content.y = 0
        content.opacity = 1
        locked = true
        forceActiveFocus()
    }
    function unlock() {
        if (!locked || slideOut.running) return
        if (UI.animations) slideOut.start()
        else { locked = false; unlocked() }
    }

    Keys.onPressed: function (event) { event.accepted = true; unlock() }

    Item {
        id: content
        width: lock.width
        height: lock.height

        Image {
            anchors.fill: parent
            source: UI.blurUrl !== "" ? UI.blurUrl : Prefs.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25) }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: UI.timeText(UI.now).replace(/ ?[AP]M$/i, "")
                color: "white"
                font.pixelSize: UI.px(112)
                font.weight: Font.Light
            }
            Text {
                font.weight: UI.textWeight
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(UI.now, "dddd, MMMM d")
                color: Qt.rgba(1, 1, 1, 0.9)
                font.pixelSize: UI.px(24)
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.12
            spacing: 14
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: UI.px(84); height: width; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.3) }
                    GradientStop { position: 1; color: Qt.darker(UI.accent, 1.5) }
                }
                border.width: 3
                border.color: Qt.rgba(1, 1, 1, 0.5)
                Text { anchors.centerIn: parent; text: Prefs.userName.charAt(0).toUpperCase(); color: "white"; font.pixelSize: UI.px(36); font.bold: true }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Prefs.userName; color: "white"; font.pixelSize: UI.px(20); font.weight: Font.DemiBold }
            Text {
                font.weight: UI.textWeight
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Click or press any key to unlock"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.pixelSize: UI.px(13)
                SequentialAnimation on opacity {
                    running: lock.locked
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        property real pressY: 0
        onPressed: function (mouse) { pressY = mouse.y }
        onPositionChanged: function (mouse) { if (pressed && lock.locked) content.y = Math.min(0, mouse.y - pressY) }
        onReleased: lock.unlock()
        onWheel: function (wheel) { wheel.accepted = true }
    }

    ParallelAnimation {
        id: slideOut
        NumberAnimation { target: content; property: "y"; to: -lock.height; duration: 380; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "opacity"; to: 0.4; duration: 380 }
        onFinished: { lock.locked = false; lock.unlocked() }
    }
}
