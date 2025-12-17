// GlassOS Desktop Icon - Fixed highlight state

import QtQuick

Rectangle {
    id: desktopIcon
    
    property string iconText: "📄"
    property string labelText: "File"
    property bool isSelected: false
    
    signal clicked()
    signal doubleClicked()
    
    width: 76
    height: 80
    radius: 6
    
    // Only show selection when actually selected, clear on mouse leave
    color: isSelected ? Qt.rgba(0.3, 0.7, 0.9, 0.3) : 
           (iconMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
    border.width: isSelected ? 1 : 0
    border.color: Qt.rgba(0.3, 0.7, 0.9, 0.5)
    
    Column {
        anchors.centerIn: parent
        spacing: 4
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: iconText
            font.pixelSize: 32
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: labelText
            font {
                pixelSize: 11
                family: "Segoe UI"
            }
            color: "#ffffff"
            width: 70
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            
            // Text shadow for visibility
            layer.enabled: true
            layer.effect: Item {
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    color: Qt.rgba(0, 0, 0, 0.5)
                    radius: 2
                    z: -1
                }
            }
        }
    }
    
    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            desktopIcon.isSelected = true
            desktopIcon.clicked()
        }
        
        onDoubleClicked: {
            desktopIcon.doubleClicked()
        }
        
        // Clear selection when clicking elsewhere is handled by parent
    }
}
