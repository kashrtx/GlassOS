// GlassOS Desktop Area - Clean version
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
                id: iconItem
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
                            font.family: "Segoe UI"
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
    
    // Context menu
    Rectangle {
        id: contextMenu
        x: Math.min(menuX, desktopArea.width - width - 10)
        y: Math.min(menuY, desktopArea.height - height - 10)
        width: 180
        height: menuColumn.height + 12
        visible: showContextMenu
        z: 100
        radius: 6
        color: Qt.rgba(0.12, 0.15, 0.22, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2)
        
        // Glass effect
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            
            ContextItem { text: "View"; icon: "👁"; hasArrow: true }
            ContextItem { text: "Sort by"; icon: "📊"; hasArrow: true }
            ContextItem { text: "Refresh"; icon: "🔄"; onClicked: { showContextMenu = false } }
            
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.1) }
            
            ContextItem { text: "New folder"; icon: "📁"; onClicked: { showContextMenu = false } }
            ContextItem { text: "New document"; icon: "📄"; onClicked: { showContextMenu = false } }
            
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.1) }
            
            ContextItem { 
                text: "Display settings"; icon: "🖥"
                onClicked: { 
                    desktopArea.openApp("Settings")
                    showContextMenu = false 
                }
            }
            
            ContextItem { 
                text: "Personalize"; icon: "🎨"
                onClicked: { 
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
    
    // Context menu item component
    component ContextItem: Rectangle {
        property string text: ""
        property string icon: ""
        property bool hasArrow: false
        signal clicked()
        
        width: parent.width
        height: 26
        radius: 3
        color: ciMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
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
            anchors.rightMargin: 8
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
            onClicked: parent.clicked()
        }
    }
}
