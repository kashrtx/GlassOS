import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"

Popup {
    id: qs
    parent: Overlay.overlay
    width: UI.px(360)
    x: parent ? parent.width - width - 10 : 0
    // slide-in offset: animating y directly would replace this binding with a fixed number,
    // so a popup that grows after opening (e.g. notifications) would hang off the screen
    property real slide: 0
    y: (parent ? parent.height - UI.taskbarHeight - height - 10 : 0) + slide
    padding: 16
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property double closedAt: 0      // lets the taskbar button toggle without instantly reopening
    onClosed: closedAt = Date.now()

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(140) }
        NumberAnimation { property: "slide"; from: 24; to: 0; duration: UI.dur(200); easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: UI.dur(90) } }
    background: GlassSurface { sceneX: qs.x; sceneY: qs.y; radius: UI.radiusLarge; borderColor: UI.borderStrong }

    contentItem: Column {
        spacing: 14

        Grid {
            columns: 3
            spacing: 8
            width: parent.width
            Repeater {
                model: [
                    { label: "Night light", icon: "moon", on: Prefs.nightLight, act: function () { Prefs.setNightLight(!Prefs.nightLight) } },
                    { label: "Glass", icon: "diamond", on: Prefs.glass, act: function () { Prefs.setGlass(!Prefs.glass) } },
                    { label: "Animations", icon: "sparkles", on: Prefs.animations, act: function () { Prefs.setAnimations(!Prefs.animations) } },
                    { label: "Ad blocker", icon: "shield-on", on: AdBlocker ? AdBlocker.enabled : false, act: function () { if (AdBlocker) AdBlocker.setEnabled(!AdBlocker.enabled) } },
                    { label: "Mute", icon: "mute", on: Prefs.muted, act: function () { Prefs.setMuted(!Prefs.muted) } },
                    { label: "24-hour", icon: "clock", on: Prefs.use24h, act: function () { Prefs.setUse24h(!Prefs.use24h) } }
                ]
                delegate: MouseArea {
                    id: tileMouse
                    width: (qs.availableWidth - 16) / 3
                    height: UI.px(64)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: modelData.label !== "Ad blocker" || AdBlocker !== null
                    opacity: enabled ? 1 : 0.4
                    onClicked: modelData.act()
                    Rectangle {
                        anchors.fill: parent
                        radius: UI.radius
                        color: modelData.on ? UI.accent : (tileMouse.containsMouse ? UI.cardStrong : UI.card)
                        border.color: modelData.on ? "transparent" : UI.border
                        Behavior on color { ColorAnimation { duration: UI.dur(140) } }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { name: modelData.icon; size: UI.px(17); anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            font.weight: UI.textWeight
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: modelData.on ? UI.accentText : UI.text
                            font.pixelSize: UI.px(11.5)
                        }
                    }
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 10
            IconButton {
                iconName: Prefs.muted || Prefs.volume === 0 ? "mute" : "volume"
                tip: Prefs.muted ? "Unmute" : "Mute"
                onClicked: Prefs.setMuted(!Prefs.muted)
            }
            GSlider {
                Layout.fillWidth: true
                from: 0; to: 100; stepSize: 1
                value: Prefs.volume
                onMoved: { Prefs.setVolume(value); if (Prefs.muted) Prefs.setMuted(false) }
            }
            Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: Prefs.volume; color: UI.textDim; font.pixelSize: UI.px(12); Layout.preferredWidth: UI.px(26) }
        }

        RowLayout {
            width: parent.width
            spacing: 10
            Icon { name: "sun"; size: UI.px(16); Layout.preferredWidth: UI.px(32) }
            GSlider {
                id: brightness
                Layout.fillWidth: true
                from: 30; to: 100; stepSize: 1
                value: UI.wm ? UI.wm.brightness : 100
                onMoved: if (UI.wm) UI.wm.brightness = value
            }
            Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: Math.round(brightness.value); color: UI.textDim; font.pixelSize: UI.px(12); Layout.preferredWidth: UI.px(26) }
        }

        Rectangle { width: parent.width; height: 1; color: UI.border }

        Row {
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: Prefs.accentPresets
                delegate: Rectangle {
                    width: UI.px(28); height: width; radius: width / 2
                    color: modelData
                    border.width: Prefs.accent.toString() === Qt.lighter(modelData, 1.0).toString() ? 3 : 0
                    border.color: "white"
                    scale: dotMouse.containsMouse ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: UI.dur(100) } }
                    MouseArea { id: dotMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.setAccent(modelData) }
                }
            }
        }

        Row {
            width: parent.width
            Text {
                elide: Text.ElideRight
                font.weight: UI.textWeight
                width: parent.width - settingsButton.width
                anchors.verticalCenter: parent.verticalCenter
                text: System.hasStats ? "CPU " + Math.round(System.cpuPercent) + "%  ·  RAM " + Math.round(System.memPercent) + "%" : "GlassOS " + System.version
                color: UI.textFaint
                font.pixelSize: UI.px(11.5)
            }
            IconButton { id: settingsButton; iconName: "settings"; tip: "All settings"; onClicked: { qs.close(); UI.wm.openApp("Settings", {}) } }
        }
    }
}
