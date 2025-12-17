// GlassOS Glass Panel Component
// A beautiful glass panel with blur, glow, and borders

import QtQuick
import QtQuick.Effects

Rectangle {
    id: glassPanel
    
    // Customization properties
    property int blurRadius: Theme.blurRadius
    property real glassOpacity: Theme.blurOpacity
    property color tintColor: Theme.glassTint
    property real tintOpacity: Theme.glassTintOpacity
    property color borderColor: Theme.windowBorderColor
    property real borderOpacity: Theme.windowBorderOpacity
    property int borderWidth: 1
    property real cornerRadius: 12
    property bool showGlow: true
    property color glowColor: Theme.accentGlow
    
    color: "transparent"
    radius: cornerRadius
    
    // Background blur simulation (since actual blur requires ShaderEffect)
    Rectangle {
        id: blurBackground
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(
            parseInt(tintColor.toString().substr(1,2), 16) / 255,
            parseInt(tintColor.toString().substr(3,2), 16) / 255,
            parseInt(tintColor.toString().substr(5,2), 16) / 255,
            glassOpacity
        )
        
        // Frosted glass gradient overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.15) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
            }
        }
        
        // Light reflection at top
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 1
            }
            height: parent.height * 0.4
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
    
    // Glow effect
    Rectangle {
        id: glowEffect
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        visible: showGlow
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(
                parseInt(glowColor.toString().substr(1,2), 16) / 255,
                parseInt(glowColor.toString().substr(3,2), 16) / 255,
                parseInt(glowColor.toString().substr(5,2), 16) / 255,
                0.3
            )
            opacity: glassPanel.activeFocus ? 0.8 : 0.4
            
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }
    }
    
    // Border
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: borderWidth
        border.color: Qt.rgba(
            parseInt(borderColor.toString().substr(1,2), 16) / 255,
            parseInt(borderColor.toString().substr(3,2), 16) / 255,
            parseInt(borderColor.toString().substr(5,2), 16) / 255,
            borderOpacity
        )
    }
}
