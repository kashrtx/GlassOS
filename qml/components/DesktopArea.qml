// GlassOS Desktop Area - Consistent Context Menu Style
import QtQuick

Item {
    id: desktopArea
    
    signal openApp(string appName)
    
    property int selectedIndex: -1
    property bool showContextMenu: false
    property real menuX: 0
    property real menuY: 0
    
    property var icons: [
        { name: "Computer", icon: "💻", app: "AeroExplorer" },
        { name: "Documents", icon: "📄", app: "AeroExplorer" },
        { name: "AeroBrowser", icon: "🌐", app: "AeroBrowser" },
        { name: "GlassPad", icon: "📝", app: "GlassPad" },
        { name: "Calculator", icon: "🧮", app: "Calculator" },
        { name: "Recycle Bin", icon: "🗑", app: "" }
    ]
    
    // Desktop background click handler
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: function(mouse) {
            selectedIndex = -1
            
            if (mouse.button === Qt.RightButton) {
                menuX = mouse.x
                menuY = mouse.y
                showContextMenu = true
            } else {
                showContextMenu = false
            }
        }
    }
    
    // Desktop icons column
    Column {
        x: 16
        y: 16
        spacing: 12
        
        Repeater {
            model: icons
            
            Rectangle {
                width: 72
                height: 76
                radius: 4
                
                color: {
                    if (selectedIndex === index) return Qt.rgba(0.3, 0.6, 0.9, 0.4)
                    if (iconMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.15)
                    return "transparent"
                }
                
                border.width: selectedIndex === index ? 1 : 0
                border.color: Qt.rgba(0.4, 0.7, 1, 0.6)
                
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: 32
                    }
                    
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: nameText.width + 6
                        height: nameText.height + 2
                        radius: 2
                        color: selectedIndex === index ? Qt.rgba(0.2, 0.5, 0.9, 0.5) : "transparent"
                        
                        Text {
                            id: nameText
                            anchors.centerIn: parent
                            text: modelData.name
                            font.pixelSize: 11
                            color: "#ffffff"
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.5)
                        }
                    }
                }
                
                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onClicked: {
                        selectedIndex = index
                        showContextMenu = false
                    }
                    
                    onDoubleClicked: {
                        if (modelData.app) {
                            desktopArea.openApp(modelData.app)
                        }
                    }
                }
            }
        }
    }
    
    // Context menu overlay
    MouseArea {
        anchors.fill: parent
        visible: showContextMenu
        z: 99
        onClicked: showContextMenu = false
    }
    
    // Context menu - matching Explorer style
    Rectangle {
        id: contextMenu
        x: Math.min(menuX, desktopArea.width - width - 10)
        y: Math.min(menuY, desktopArea.height - height - 10)
        width: 180
        height: menuColumn.height + 12
        visible: showContextMenu
        z: 100
        radius: 6
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.18, 0.20, 0.25, 0.98) }
            GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.14, 0.18, 0.98) }
        }
        
        border.width: 1
        border.color: Qt.rgba(0.4, 0.6, 0.9, 0.4)
        
        // Shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.5)
            z: -1
        }
        
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            
            ContextMenuItem { text: "View"; icon: "👁"; hasArrow: true }
            ContextMenuItem { text: "Sort by"; icon: "📊"; hasArrow: true }
            ContextMenuItem { 
                text: "Refresh"; icon: "🔄"
                onItemClicked: { showContextMenu = false } 
            }
            
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.15) }
            
            ContextMenuItem { 
                text: "New Folder"; icon: "📁"
                onItemClicked: { showContextMenu = false } 
            }
            ContextMenuItem { 
                text: "New Text File"; icon: "📄"
                onItemClicked: { showContextMenu = false } 
            }
            
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.15) }
            
            ContextMenuItem { 
                text: "Display Settings"; icon: "🖥"
                onItemClicked: { 
                    desktopArea.openApp("Settings")
                    showContextMenu = false 
                }
            }
            
            ContextMenuItem { 
                text: "Personalize"; icon: "🎨"
                onItemClicked: { 
                    desktopArea.openApp("Settings")
                    showContextMenu = false 
                }
            }
        }
        
        scale: visible ? 1.0 : 0.95
        opacity: visible ? 1.0 : 0
        Behavior on scale { NumberAnimation { duration: 80 } }
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }
    
    // Context menu item component - matching Explorer style
    component ContextMenuItem: Rectangle {
        property string text: ""
        property string icon: ""
        property bool hasArrow: false
        property bool enabled: true
        signal itemClicked()
        
        width: parent.width
        height: 28
        radius: 4
        color: ciMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : "transparent"
        opacity: enabled ? 1.0 : 0.4
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 8
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                font.pixelSize: 12
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                font.pixelSize: 11
                color: "#ffffff"
            }
        }
        
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            font.pixelSize: 8
            color: "#888888"
            visible: hasArrow
        }
        
        MouseArea {
            id: ciMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (enabled) parent.itemClicked()
            }
        }
    }
}
