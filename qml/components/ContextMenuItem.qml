// GlassOS Context Menu Item Component
// Item for context menus with optional icon, shortcut, and submenu indicator

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: menuItem
    
    property string text: ""
    property string icon: ""
    property string shortcut: ""
    property bool hasSubmenu: false
    property bool enabled: true
    
    signal clicked()
    
    width: parent ? parent.width : 200
    height: 28
    radius: 4
    color: enabled && mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
    opacity: enabled ? 1 : 0.5
    
    Behavior on color {
        ColorAnimation { duration: 100 }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: menuItem.enabled
        
        onClicked: {
            if (!hasSubmenu) {
                menuItem.clicked()
            }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8
        
        // Icon
        Text {
            Layout.preferredWidth: icon ? 20 : 0
            text: icon
            font.pixelSize: 14
            visible: icon !== ""
        }
        
        // Spacer for alignment when no icon
        Item {
            Layout.preferredWidth: icon ? 0 : 20
            visible: icon === ""
        }
        
        // Text
        Text {
            Layout.fillWidth: true
            text: menuItem.text
            font {
                pixelSize: 12
                family: "Segoe UI"
            }
            color: Theme.textPrimary
            elide: Text.ElideRight
        }
        
        // Shortcut
        Text {
            text: shortcut
            font {
                pixelSize: 11
                family: "Segoe UI"
            }
            color: Theme.textSecondary
            visible: shortcut !== ""
        }
        
        // Submenu arrow
        Text {
            text: "▸"
            font.pixelSize: 10
            color: Theme.textSecondary
            visible: hasSubmenu
        }
    }
}
