// GlassOS Taskbar Button Component
// Button for running apps in the taskbar

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

GlassButton {
    id: taskbarButton
    
    property string windowId: ""
    property string windowTitle: ""
    property bool isActive: false
    property bool isMinimized: false
    property string appIcon: ""
    
    implicitWidth: Math.min(180, Math.max(100, titleText.implicitWidth + 40))
    implicitHeight: 36
    
    buttonColor: isActive ? Theme.accentColor : "transparent"
    buttonOpacity: isActive ? 0.4 : 0
    hoverOpacity: isActive ? 0.5 : 0.3
    buttonRadius: 4
    
    // Active indicator bar
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 8
            rightMargin: 8
        }
        height: 3
        radius: 1.5
        color: Theme.accentColor
        visible: isActive
        
        // Glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: 3
            color: Theme.accentGlow
            opacity: 0.5
            z: -1
        }
    }
    
    // Minimized indicator
    Rectangle {
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: 4
            bottomMargin: 4
        }
        width: 4
        height: 4
        radius: 2
        color: Theme.textSecondary
        visible: isMinimized && !isActive
    }
    
    contentItem: Row {
        anchors.centerIn: parent
        spacing: 6
        leftPadding: 8
        rightPadding: 8
        
        // App icon placeholder
        Text {
            text: "🪟"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Title
        Text {
            id: titleText
            text: windowTitle
            font {
                pixelSize: 12
                family: "Segoe UI"
            }
            color: isActive ? Theme.textPrimary : Theme.textSecondary
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 140)
            
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }
    
    ToolTip.visible: hovered && windowTitle.length > 0
    ToolTip.text: windowTitle
    ToolTip.delay: 500
    
    onClicked: {
        WindowManager.toggle_minimize(windowId)
    }
}
