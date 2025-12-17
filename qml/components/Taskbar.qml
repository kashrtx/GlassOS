// GlassOS Taskbar - Fixed & Stable
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: taskbar
    
    signal startClicked()
    signal appClicked(string appName)
    signal taskbarAppClicked(var window)
    signal taskbarAppClosed(var window)
    
    property var runningWindows: []
    property int volumeLevel: Storage.systemVolume // Bind to system volume
    
    // Group windows logic
    function getGroupedApps() {
        var groups = {}
        for (var i = 0; i < runningWindows.length; i++) {
            var win = runningWindows[i]
            if (!win) continue
            var title = win.windowTitle || "Window"
            var key = win.windowIcon || title
            if (!groups[key]) {
                groups[key] = {
                    title: title,
                    icon: win.windowIcon || "🪟",
                    windows: []
                }
            }
            groups[key].windows.push(win)
        }
        var result = []
        for (var k in groups) {
            result.push(groups[k])
        }
        return result
    }
    
    property var groupedApps: getGroupedApps()
    
    onRunningWindowsChanged: groupedApps = getGroupedApps()
    
    // Premium dark glass background
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
            GradientStop { position: 0.5; color: Qt.rgba(0.5, 0.7, 1.0, 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(0.4, 0.6, 0.9, 0.1) }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 0
        
        // Start button
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            radius: 6
            color: "transparent" // handled by inner/gradient
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: startMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.2, 0.4, 0.7, 0.4) }
                GradientStop { position: 1.0; color: startMouse.containsMouse ? Qt.rgba(0.2, 0.4, 0.7, 0.6) : Qt.rgba(0.15, 0.3, 0.6, 0.4) }
            }
            border.width: 1
            border.color: startMouse.containsMouse ? Qt.rgba(0.5, 0.7, 1.0, 0.6) : Qt.rgba(0.4, 0.6, 0.9, 0.3)
            
            Text {
                anchors.centerIn: parent
                text: "⊞"
                font.pixelSize: 22
                font.bold: true
                color: "#ffffff"
            }
            
            MouseArea {
                id: startMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: taskbar.startClicked()
            }
        }
        
        // Separator
        Rectangle {
            Layout.preferredWidth: 1; Layout.preferredHeight: 32; Layout.margins: 8
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        
        // Pinned apps
        Row {
            Layout.preferredHeight: parent.height
            spacing: 4
            Repeater {
                model: [
                    { name: "AeroExplorer", icon: "📁", tooltip: "Explorer" },
                    { name: "AeroBrowser", icon: "🌐", tooltip: "Browser" },
                    { name: "GlassPad", icon: "📝", tooltip: "GlassPad" }
                ]
                Rectangle {
                    width: 42; height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 5
                    color: pMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 20 }
                    MouseArea {
                        id: pMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: taskbar.appClicked(modelData.name)
                    }
                    ToolTip.visible: pMouse.containsMouse
                    ToolTip.text: modelData.tooltip
                    ToolTip.delay: 500
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.preferredWidth: 1; Layout.preferredHeight: 32; Layout.margins: 8
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        
        // Running apps list (ListView for proper overflow handling)
        ListView {
            id: runningList
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            model: groupedApps
            
            delegate: Rectangle {
                id: appGroupItem
                property bool hasMultiple: modelData.windows.length > 1
                // Fixed width for consistency - no shrinking
                width: 160 
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                radius: 5
                
                property bool isActive: {
                    for(var i=0; i<modelData.windows.length; i++) {
                        if(modelData.windows[i].visible && !modelData.windows[i].isMinimized) return true
                    }
                    return false
                }
                
                property bool hovered: groupMouse.containsMouse || (previewPopupLoader.item && previewPopupLoader.item.containsMouse)
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: isActive ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : (hovered ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.05)) }
                    GradientStop { position: 1.0; color: isActive ? Qt.rgba(0.2, 0.4, 0.7, 0.4) : (hovered ? Qt.rgba(1,1,1,0.1) : "transparent") }
                }
                
                border.width: isActive ? 1 : 0
                border.color: Qt.rgba(0.4, 0.6, 0.9, 0.5)
                
                // Bottom indicator
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: 4; height: 2; radius: 1
                    color: isActive ? "#4a9eff" : (modelData.windows.length > 0 ? Qt.rgba(1,1,1,0.3) : "transparent")
                }
                
                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.pixelSize: 18 }
                    Text { 
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        text: modelData.title
                        color: "#ffffff"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                
                // Badge
                Rectangle {
                    visible: hasMultiple
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 2
                    width: 16; height: 14; radius: 7; color: "#4a9eff"
                    Text { anchors.centerIn: parent; text: modelData.windows.length; color: "#fff"; font.pixelSize: 9; font.bold: true }
                }
                
                MouseArea {
                    id: groupMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (!hasMultiple) {
                            var win = modelData.windows[0]
                            if(win.visible && !win.isMinimized) win.minimizeWindow()
                            else { win.visible=true; win.z=100; if(win.isMinimized) win.restoreFromMinimize(); taskbar.taskbarAppClicked(win) }
                        }
                    }
                }
                
                // Logic to show preview
                Timer {
                    id: showTimer
                    interval: 400
                    running: groupMouse.containsMouse && !previewPopup.opened
                    onTriggered: previewPopup.open()
                }
                
                Popup {
                    id: previewPopup
                    y: -height - 10
                    x: (parent.width - width) / 2
                    width: hasMultiple ? Math.min(600, modelData.windows.length * 200) : 200
                    height: 150
                    padding: 0
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    
                    background: Rectangle {
                        color: Qt.rgba(0.1, 0.12, 0.18, 0.95)
                        radius: 8
                        border.width: 1
                        border.color: "#4a9eff"
                    }
                    
                    contentItem: Rectangle {
                        color: "transparent"
                        
                        MouseArea {
                            id: popupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        
                        // Auto-hide logic
                        Timer {
                            interval: 200
                            running: true
                            repeat: true
                            onTriggered: {
                                if (!groupMouse.containsMouse && !popupMouse.containsMouse) {
                                    previewPopup.close()
                                }
                            }
                        }
                        
                        // Content
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 8
                            orientation: ListView.Horizontal
                            spacing: 8
                            model: modelData.windows
                            delegate: Rectangle {
                                width: 180; height: parent.height
                                color: Qt.rgba(1,1,1,0.05)
                                radius: 4
                                
                                Column {
                                    anchors.fill: parent; anchors.margins: 4; spacing: 4
                                    Row {
                                        width: parent.width; spacing: 4
                                        Text { text: modelData.windowIcon; font.pixelSize: 12 }
                                        Text { width: parent.width - 30; text: modelData.windowTitle; color: "#fff"; font.pixelSize: 11; elide: Text.ElideRight }
                                        Text { text: "✕"; color: "#ff5555"; font.bold: true; MouseArea { anchors.fill: parent; onClicked: taskbar.taskbarAppClosed(modelData) } }
                                    }
                                    
                                    // Live preview if not minimized
                                    ShaderEffectSource {
                                        width: parent.width; height: parent.height - 24
                                        sourceItem: modelData.visible && !modelData.isMinimized ? modelData : null
                                        live: true
                                        visible: sourceItem !== null
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "black"
                                            visible: modelData.isMinimized
                                            Text { anchors.centerIn: parent; text: "Minimized"; color: "gray" }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        modelData.visible = true; modelData.z = 100
                                        if(modelData.isMinimized) modelData.restoreFromMinimize()
                                        taskbar.taskbarAppClicked(modelData)
                                        previewPopup.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // System Tray
        Row {
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 10
            spacing: 8
            
            // Network
            Item {
                width: 32; height: 40
                Text { anchors.centerIn: parent; text: "📶"; font.pixelSize: 16; color: "#fff" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; ToolTip.visible: containsMouse; ToolTip.text: "Network: Connected" }
            }
            
            // Volume
            Item {
                width: 32; height: 40
                Text { anchors.centerIn: parent; text: volumeLevel > 0 ? "🔊" : "🔇"; font.pixelSize: 16; color: "#fff" }
                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: volPopup.opened ? volPopup.close() : volPopup.open()
                }
                
                Popup {
                    id: volPopup
                    y: -height - 10
                    x: -width/2 + parent.width/2
                    width: 40
                    height: 120
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    
                    background: Rectangle {
                        color: Qt.rgba(0.1, 0.12, 0.18, 0.95); radius: 6
                        border.width: 1; border.color: "#4a9eff"
                    }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Slider {
                            id: volSlider
                            orientation: Qt.Vertical
                            from: 0; to: 100
                            value: volumeLevel
                            height: 80
                            onMoved: Storage.setSystemVolume(value)
                        }
                        Text { text: Math.round(volumeLevel); color: "#fff"; font.pixelSize: 10 }
                    }
                }
            }
            
            // Clock
            Rectangle {
                width: 70; height: 40
                color: "transparent"
                Column {
                    anchors.centerIn: parent
                    Text { 
                        text: Qt.formatTime(new Date(), "h:mm AP")
                        color: "#fff"; font.pixelSize: 12
                    }
                    Text { 
                        text: Qt.formatDate(new Date(), "M/d/yyyy")
                        color: "#ccc"; font.pixelSize: 10
                    }
                }
                Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.children[0].children[0].text = Qt.formatTime(new Date(), "h:mm AP") }
            }
            
            // Show Desktop
            Rectangle {
                width: 6; height: 40
                color: showDesktopMouse.containsMouse ? Qt.rgba(1,1,1,0.3) : "transparent"
                MouseArea {
                    id: showDesktopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                         for(var i=0; i<runningWindows.length; i++) if(runningWindows[i]) runningWindows[i].minimizeWindow()
                    }
                    ToolTip.visible: containsMouse; ToolTip.text: "Show Desktop"
                }
            }
        }
    }
}
