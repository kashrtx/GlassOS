// GlassOS Glass Button Component
// A beautiful glass-styled button with hover and press effects

import QtQuick
import QtQuick.Controls

Button {
    id: glassButton
    
    property color buttonColor: "transparent"
    property color hoverColor: Theme.accentColor
    property color pressColor: Theme.highlightColor
    property real buttonOpacity: 0.0
    property real hoverOpacity: 0.3
    property real pressOpacity: 0.5
    property int buttonRadius: 6
    
    background: Rectangle {
        radius: buttonRadius
        color: {
            if (glassButton.pressed) return pressColor
            if (glassButton.hovered) return hoverColor
            return buttonColor
        }
        opacity: {
            if (glassButton.pressed) return pressOpacity
            if (glassButton.hovered) return hoverOpacity
            return buttonOpacity
        }
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        
        // Subtle border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.textSecondary
            opacity: glassButton.hovered ? 0.3 : 0.1
            
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
        
        // Top highlight
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 1
            }
            height: parent.height / 2
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, glassButton.hovered ? 0.15 : 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
    
    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: 8
            
            Image {
                id: buttonIcon
                source: glassButton.icon.source
                width: glassButton.icon.width
                height: glassButton.icon.height
                anchors.verticalCenter: parent.verticalCenter
                visible: source != ""
            }
            
            Text {
                text: glassButton.text
                font: glassButton.font
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
                visible: text != ""
            }
        }
    }
    
    // Scale effect on press
    scale: pressed ? 0.95 : 1.0
    
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }
}
