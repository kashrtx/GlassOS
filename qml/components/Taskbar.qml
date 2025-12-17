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
    // Premium glass background
    color: Qt.rgba(0.08, 0.10, 0.15, 0.85) // Translucent dark glass
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)
    
    /* Removed old gradient
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.14, 0.20, 0.95) }
        GradientStop { position: 0.3; color: Qt.rgba(0.08, 0.10, 0.15, 0.95) }
        GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.06, 0.10, 0.95) }
    } */
    
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
                
                property bool hovered: groupMouse.containsMouse || previewPopup.opened
                
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            taskbarContextMenu.open()
                        } else {
                            if (!hasMultiple) {
                                var win = modelData.windows[0]
                                if(win.visible && !win.isMinimized) win.minimizeWindow()
                                else { win.visible=true; win.z=100; if(win.isMinimized) win.restoreFromMinimize(); taskbar.taskbarAppClicked(win) }
                            } else {
                                if (previewPopup.opened) previewPopup.close()
                                else previewPopup.open()
                            }
                        }
                    }
                }
                
                Popup {
                    id: taskbarContextMenu
                    y: -height - 10
                    x: 0
                    width: 180
                    height: 40
                    padding: 0
                    modal: true
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    
                    background: Rectangle {
                        color: Qt.rgba(0.1, 0.12, 0.18, 0.95)
                        radius: 6
                        border.width: 1
                        border.color: "#666"
                    }
                    
                    Rectangle {
                        width: parent.width - 4
                        height: 32
                        anchors.centerIn: parent
                        color: "transparent"
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 12
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "❌"; font.pixelSize: 12 }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Close All Windows"; color: "#fff"; font.pixelSize: 11 }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            color: closeAllMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                            radius: 4
                        }
                        
                        MouseArea {
                            id: closeAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Close all windows in this group
                                var wins = []
                                for(var i=0; i<modelData.windows.length; i++) wins.push(modelData.windows[i])
                                for(var j=0; j<wins.length; j++) taskbar.taskbarAppClosed(wins[j])
                                taskbarContextMenu.close()
                            }
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
                    property bool useListMode: modelData.windows.length > 5
                    
                    y: -height - 10
                    x: (parent.width - width) / 2
                    
                    width: useListMode ? 220 : Math.min(600, modelData.windows.length * 200)
                    height: useListMode ? Math.min(400, modelData.windows.length * 36 + 16) : 150
                    
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
                                if (!groupMouse.containsMouse && !popupMouse.containsMouse && !previewPopup.opened) {
                                    previewPopup.close()
                                }
                            }
                        }
                        
                        // Content
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 8
                            orientation: previewPopup.useListMode ? ListView.Vertical : ListView.Horizontal
                            spacing: previewPopup.useListMode ? 4 : 8
                            model: modelData.windows
                            clip: true
                            
                            delegate: Rectangle {
                                width: previewPopup.useListMode ? parent.width : 180
                                height: previewPopup.useListMode ? 32 : parent.height
                                color: Qt.rgba(0.2, 0.22, 0.28, 0.6)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                radius: 4
                                
                                // Main click handler (Background)
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        modelData.visible = true; modelData.z = 100
                                        if(modelData.isMinimized) modelData.restoreFromMinimize()
                                        taskbar.taskbarAppClicked(modelData)
                                        previewPopup.close()
                                    }
                                }
                                
                                // List Mode Layout
                                Row {
                                    visible: previewPopup.useListMode
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    spacing: 8
                                    
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.windowIcon; font.pixelSize: 14 
                                    }
                                    
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 40
                                        text: modelData.windowTitle
                                        color: "#fff"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight 
                                    }
                                    
                                    Rectangle {
                                        width: 18; height: 18
                                        color: closeListMouse.containsMouse ? "#cc3333" : "transparent"
                                        radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        z: 5
                                        
                                        Text { anchors.centerIn: parent; text: "✕"; color: "#fff"; font.pixelSize: 10 }
                                        MouseArea {
                                            id: closeListMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            z: 10
                                            onClicked: {
                                                console.log("Taskbar: Closing app from list preview")
                                                taskbar.taskbarAppClosed(modelData)
                                            }
                                        }
                                    }
                                }
                                
                                // Grid Mode Layout
                                Item {
                                    visible: !previewPopup.useListMode
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    
                                    // Header
                                    Item {
                                        id: header
                                        width: parent.width
                                        height: 20
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: closeBtn.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            
                                            Text { text: modelData.windowIcon; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                            Text { 
                                                width: parent.width - 25
                                                text: modelData.windowTitle
                                                color: "#fff"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            id: closeBtn
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 18; height: 18
                                            radius: 3
                                            color: closeMouse.containsMouse ? "#cc3333" : "transparent"
                                            
                                            Text { anchors.centerIn: parent; text: "✕"; color: "#fff"; font.pixelSize: 10 }
                                            
                                            MouseArea {
                                                id: closeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                z: 10
                                                onClicked: {
                                                    console.log("Taskbar: Closing app from grid preview")
                                                    taskbar.taskbarAppClosed(modelData)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Live preview if not minimized
                                    ShaderEffectSource {
                                        anchors.top: header.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.topMargin: 4
                                        sourceItem: modelData.visible && !modelData.isMinimized ? modelData : null
                                        live: true
                                        visible: sourceItem !== null
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0,0,0,0.5)
                                            visible: modelData.isMinimized
                                            Text { anchors.centerIn: parent; text: "Minimized"; color: "#888"; font.pixelSize: 10 }
                                        }
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
            Layout.rightMargin: 0
            spacing: 0
            
            // Network
            Item {
                width: 32; height: 48
                Text { anchors.centerIn: parent; text: "📶"; font.pixelSize: 14; color: "#fff"; opacity: 0.8 }
                MouseArea { anchors.fill: parent; hoverEnabled: true; ToolTip.visible: containsMouse; ToolTip.text: "Connected" }
            }
            
            // Volume
            Item {
                width: 36; height: 48
                Text { 
                    anchors.centerIn: parent
                    text: volumeLevel === 0 ? "🔇" : (volumeLevel < 33 ? "🔈" : (volumeLevel < 66 ? "🔉" : "🔊"))
                    font.pixelSize: 14; color: "#fff"; opacity: 0.8 
                }
                
                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: volPopup.opened ? volPopup.close() : volPopup.open()
                }
                
                Popup {
                    id: volPopup
                    y: -height - 12
                    x: -width + parent.width + 5
                    width: 200
                    height: 50
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    
                    background: Rectangle {
                        color: Qt.rgba(0.1, 0.12, 0.18, 0.95); radius: 8
                        border.width: 1; border.color: Qt.rgba(0.4, 0.6, 0.9, 0.3)
                        
                        // Shadow
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -4; z: -1; radius: 12; color: Qt.rgba(0,0,0,0.5)
                        }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        Text { text: "🔊"; font.pixelSize: 14; color: "#fff" }
                        
                        Slider {
                            id: volSlider
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: volumeLevel
                            onMoved: Storage.setSystemVolume(value)
                            
                            background: Rectangle {
                                x: volSlider.leftPadding
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: volSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: Qt.rgba(1,1,1,0.1)
                                
                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#4a9eff"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: volSlider.pressed ? "#fff" : "#eee"
                                border.width: 1
                                border.color: "#4a9eff"
                            }
                        }
                        
                        Text { 
                            text: Math.round(volumeLevel)
                            color: "#fff"; font.pixelSize: 11; font.bold: true
                            Layout.preferredWidth: 25
                        }
                    }
                }
            }
            
            // Clock
            Rectangle {
                width: 80; height: 48
                color: clockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                
                Column {
                    anchors.centerIn: parent
                    spacing: -2
                    Text { 
                        text: Qt.formatTime(new Date(), "h:mm AP")
                        color: "#fff"; font.pixelSize: 12; font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text { 
                        text: Qt.formatDate(new Date(), "M/d/yyyy")
                        color: "#aaa"; font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                Timer { interval: 1000; running: true; repeat: true; onTriggered: {} }
            }
            
            // Show Desktop Button (Windows style)
            Rectangle {
                width: 12; height: 48
                color: showDesktopMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                
                MouseArea {
                    id: showDesktopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        for(var i=0; i<runningWindows.length; i++) {
                            if(runningWindows[i]) runningWindows[i].minimizeWindow()
                        }
                    }
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Show Desktop"
                    ToolTip.delay: 1000
                }
            }
        }
    }
}
