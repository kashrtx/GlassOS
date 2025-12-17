// GlassOS Start Menu - Premium Modern Design
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: startMenu
    
    signal appLaunched(string appName)
    
    radius: 12
    
    // Premium dark gradient
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.14, 0.16, 0.22, 0.98) }
        GradientStop { position: 1.0; color: Qt.rgba(0.08, 0.10, 0.14, 0.98) }
    }
    
    border.width: 1
    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.3)
    
    // Outer glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(0.3, 0.5, 0.8, 0.15)
        z: -1
    }
    
    // Glass shine
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 80
        radius: parent.radius
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 8
            color: "transparent"
        }
    }
    
    property var apps: [
        { name: "AeroBrowser", icon: "🌐", desc: "Browse the web", color: "#4a9eff" },
        { name: "GlassPad", icon: "📝", desc: "Text editor", color: "#ff9f43" },
        { name: "Calculator", icon: "🧮", desc: "Calculator", color: "#10ac84" },
        { name: "Weather", icon: "🌤", desc: "Weather forecast", color: "#5f27cd" },
        { name: "AeroExplorer", icon: "📁", desc: "File manager", color: "#ffd32a" },
        { name: "Settings", icon: "⚙", desc: "System settings", color: "#636e72" }
    ]
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        
        // User profile header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.05)
            
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                
                // Avatar
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#4a9eff" }
                        GradientStop { position: 1.0; color: "#2a5298" }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "👤"
                        font.pixelSize: 18
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    
                    Text {
                        text: "User"
                        font.pixelSize: 14
                        font.family: "Segoe UI"
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    
                    Text {
                        text: "Welcome to GlassOS"
                        font.pixelSize: 11
                        font.family: "Segoe UI"
                        color: "#888888"
                    }
                }
            }
        }
        
        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: searchFocus.activeFocus ? 2 : 1
            border.color: searchFocus.activeFocus ? Qt.rgba(0.4, 0.6, 0.9, 0.6) : Qt.rgba(1, 1, 1, 0.1)
            
            Behavior on border.color { ColorAnimation { duration: 150 } }
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 10
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🔍"
                    font.pixelSize: 16
                    opacity: 0.7
                }
                
                TextInput {
                    id: searchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    font.pixelSize: 13
                    font.family: "Segoe UI"
                    color: "#ffffff"
                    
                    Text {
                        anchors.fill: parent
                        text: "Search apps and files..."
                        font: parent.font
                        color: "#666666"
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                    
                    FocusScope { id: searchFocus }
                }
            }
        }
        
        // Section label
        Text {
            text: "PINNED"
            font.pixelSize: 11
            font.family: "Segoe UI"
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: "#666666"
            Layout.topMargin: 4
        }
        
        // App grid
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            
            Repeater {
                model: apps
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 8
                    
                    color: appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.03)
                    border.width: appMouse.containsMouse ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        
                        // Icon with colored background
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 36
                            height: 36
                            radius: 8
                            color: modelData.color
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 18
                            }
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            font.pixelSize: 11
                            font.family: "Segoe UI"
                            color: "#ffffff"
                        }
                    }
                    
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: startMenu.appLaunched(modelData.name)
                    }
                    
                    scale: appMouse.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 50 } }
                }
            }
        }
        
        // Flexible space
        Item { Layout.fillHeight: true }
        
        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.1)
        }
        
        // Bottom actions
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 8
            
            // Power button
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 36
                radius: 6
                color: powerMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Qt.rgba(1, 1, 1, 0.05)
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    
                    // Power icon using shapes
                    Item {
                        width: 16
                        height: 16
                        
                        // Circle part
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            color: "transparent"
                            border.width: 2
                            border.color: powerMouse.containsMouse ? "#ff6b6b" : "#ffffff"
                            
                            // Gap at top
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: -1
                                width: 4
                                height: 5
                                color: Qt.rgba(1, 1, 1, 0.05)
                            }
                        }
                        
                        // Vertical line
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: 2
                            height: 8
                            radius: 1
                            color: powerMouse.containsMouse ? "#ff6b6b" : "#ffffff"
                        }
                    }
                }
                
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }

            
            Item { Layout.fillWidth: true }
            
            // All apps button
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                radius: 6
                color: allAppsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: "All apps"
                        font.pixelSize: 12
                        font.family: "Segoe UI"
                        color: "#ffffff"
                    }
                    
                    Text {
                        text: "→"
                        font.pixelSize: 12
                        color: "#888888"
                    }
                }
                
                MouseArea {
                    id: allAppsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
    
    // Appear animation
    scale: visible ? 1.0 : 0.95
    opacity: visible ? 1.0 : 0
    
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }
}
