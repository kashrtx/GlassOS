// GlassOS Taskbar - With Running Apps Display
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: taskbar
    
    signal startClicked()
    signal appClicked(string appName)
    signal taskbarAppClicked(var window)
    signal taskbarAppClosed(var window)
    
    // List of running windows
    property var runningWindows: []
    
    // Premium dark glass effect
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.14, 0.20, 0.95) }
        GradientStop { position: 0.3; color: Qt.rgba(0.08, 0.10, 0.15, 0.95) }
        GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.06, 0.10, 0.95) }
    }
    
    // Top highlight
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.4, 0.6, 0.9, 0.1) }
            GradientStop { position: 0.3; color: Qt.rgba(0.4, 0.6, 0.9, 0.5) }
            GradientStop { position: 0.5; color: Qt.rgba(0.5, 0.7, 1.0, 0.7) }
            GradientStop { position: 0.7; color: Qt.rgba(0.4, 0.6, 0.9, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(0.4, 0.6, 0.9, 0.1) }
        }
    }
    
    // Glass shine
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.4
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 0
        
        // Start button
        Rectangle {
            id: startBtn
            Layout.preferredWidth: 48
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            radius: 6
            
            gradient: Gradient {
                GradientStop { 
                    position: 0.0
                    color: startMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.2, 0.4, 0.7, 0.4)
                }
                GradientStop { 
                    position: 1.0
                    color: startMouse.containsMouse ? Qt.rgba(0.2, 0.4, 0.7, 0.6) : Qt.rgba(0.15, 0.3, 0.6, 0.4)
                }
            }
            
            border.width: 1
            border.color: startMouse.containsMouse ? Qt.rgba(0.5, 0.7, 1.0, 0.6) : Qt.rgba(0.4, 0.6, 0.9, 0.3)
            Behavior on border.color { ColorAnimation { duration: 150 } }
            
            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 2
                
                Repeater {
                    model: 4
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 1
                        color: startMouse.containsMouse ? "#ffffff" : "#e0e0e0"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
            
            MouseArea {
                id: startMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskbar.startClicked()
            }
            
            scale: startMouse.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 50 } }
        }
        
        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        
        // Quick launch
        Row {
            Layout.preferredHeight: parent.height
            spacing: 4
            
            TaskbarButton { 
                icon: "🌐"
                label: "Browser"
                onClicked: taskbar.appClicked("AeroBrowser")
            }
            TaskbarButton { 
                icon: "📁"
                label: "Files"
                onClicked: taskbar.appClicked("AeroExplorer")
            }
            TaskbarButton { 
                icon: "📝"
                label: "Notes"
                onClicked: taskbar.appClicked("GlassPad")
            }
        }
        
        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            Layout.leftMargin: 8
            Layout.rightMargin: 4
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        
        // ===== RUNNING APPS =====
        Row {
            id: runningAppsRow
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height
            Layout.leftMargin: 4
            spacing: 4
            
            Repeater {
                model: runningWindows
                
                Rectangle {
                    width: 160
                    height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 5
                    
                    // Active window indicator
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0
                            color: modelData.visible ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : 
                                   (rwMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05))
                        }
                        GradientStop { 
                            position: 1.0
                            color: modelData.visible ? Qt.rgba(0.2, 0.4, 0.7, 0.3) : 
                                   (rwMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        }
                    }
                    
                    border.width: modelData.visible ? 1 : 0
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.4)
                    
                    // Bottom indicator line for visible windows
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 2
                        radius: 1
                        color: modelData.visible ? "#4a9eff" : Qt.rgba(1, 1, 1, 0.2)
                    }
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 8
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.windowIcon || "🪟"
                            font.pixelSize: 16
                        }
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            text: modelData.windowTitle || "Window"
                            font.pixelSize: 11
                            font.family: "Segoe UI"
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }
                        
                        // Close button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            color: closeWinMouse.containsMouse ? "#e04343" : "transparent"
                            visible: rwMouse.containsMouse
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 9
                                color: "#ffffff"
                            }
                            
                            MouseArea {
                                id: closeWinMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: taskbar.taskbarAppClosed(modelData)
                            }
                        }
                    }
                    
                    MouseArea {
                        id: rwMouse
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Toggle behavior like Windows
                            if (modelData.visible && !modelData.isMinimized) {
                                // Window is visible and not minimized - minimize it
                                modelData.minimizeWindow()
                            } else {
                                // Window is hidden/minimized - restore it
                                modelData.visible = true
                                modelData.z = 100
                                if (modelData.isMinimized) {
                                    modelData.restoreFromMinimize()
                                }
                                taskbar.taskbarAppClicked(modelData)
                            }
                        }
                    }
                    
                    scale: rwMouse.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 50 } }
                }
            }
        }
        
        // System tray
        Row {
            Layout.preferredHeight: parent.height
            spacing: 4
            
            Rectangle {
                width: 80
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: trayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    Text { text: "📶"; font.pixelSize: 14; opacity: 0.9 }
                    Text { text: "🔊"; font.pixelSize: 14; opacity: 0.9 }
                    Text { text: "🔋"; font.pixelSize: 14; opacity: 0.9 }
                }
                
                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
            
            Rectangle {
                width: 1
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.15)
            }
            
            Rectangle {
                width: 90
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: clockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                
                Column {
                    anchors.centerIn: parent
                    spacing: -1
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: System.currentTime
                        font.pixelSize: 13
                        font.family: "Segoe UI"
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: System.shortDate
                        font.pixelSize: 11
                        font.family: "Segoe UI"
                        color: "#aaaaaa"
                    }
                }
                
                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                ToolTip.visible: clockMouse.containsMouse
                ToolTip.text: System.currentDate
                ToolTip.delay: 300
            }
            
            Rectangle {
                width: 8
                height: parent.height
                color: sdMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                
                MouseArea {
                    id: sdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
    
    component TaskbarButton: Rectangle {
        property string icon: ""
        property string label: ""
        signal clicked()
        
        width: 44
        height: 38
        anchors.verticalCenter: parent.verticalCenter
        radius: 5
        
        gradient: Gradient {
            GradientStop { 
                position: 0.0
                color: tbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
            }
            GradientStop { 
                position: 1.0
                color: tbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            }
        }
        
        border.width: tbMouse.containsMouse ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.2)
        Behavior on border.width { NumberAnimation { duration: 100 } }
        
        Text {
            anchors.centerIn: parent
            text: icon
            font.pixelSize: 20
        }
        
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
        
        ToolTip.visible: tbMouse.containsMouse
        ToolTip.text: label
        ToolTip.delay: 400
        
        scale: tbMouse.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 50 } }
    }
}
