// GlassOS Start Menu - Premium Modern Design with Working Features
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: startMenu
    
    signal appLaunched(string appName)
    signal openAppsFolder()
    
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
    
    // All available apps
    property var allApps: [
        { name: "AeroBrowser", icon: "🌐", desc: "Browse the web", color: "#4a9eff", category: "internet" },
        { name: "GlassPad", icon: "📝", desc: "Text editor", color: "#ff9f43", category: "productivity" },
        { name: "Calculator", icon: "🧮", desc: "Calculator", color: "#10ac84", category: "utility" },
        { name: "Weather", icon: "🌤", desc: "Weather forecast", color: "#5f27cd", category: "utility" },
        { name: "AeroExplorer", icon: "📁", desc: "File manager", color: "#ffd32a", category: "system" },
        { name: "Settings", icon: "⚙", desc: "System settings", color: "#636e72", category: "system" }
    ]
    
    // Pinned apps (shown in grid)
    property var pinnedApps: allApps
    
    // Search functionality
    property string searchQuery: ""
    property var filteredApps: {
        if (!searchQuery || searchQuery.trim() === "") {
            return pinnedApps
        }
        var query = searchQuery.toLowerCase()
        return allApps.filter(function(app) {
            return app.name.toLowerCase().includes(query) ||
                   app.desc.toLowerCase().includes(query) ||
                   app.category.toLowerCase().includes(query)
        })
    }
    
    // Current time for display
    property string currentTime: ""
    property string currentDate: ""
    
    Timer {
        interval: 1000
        running: startMenu.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            currentTime = now.toLocaleTimeString(Qt.locale(), "HH:mm")
            currentDate = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // User profile header with time
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 10
            
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.25, 0.35, 0.55, 0.4) }
                GradientStop { position: 1.0; color: Qt.rgba(0.15, 0.2, 0.3, 0.4) }
            }
            
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                // Avatar
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#4a9eff" }
                        GradientStop { position: 1.0; color: "#2a5298" }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "👤"
                        font.pixelSize: 20
                    }
                }
                
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        text: "User"
                        font.pixelSize: 15
                        font.family: "Segoe UI"
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    
                    Text {
                        text: currentDate
                        font.pixelSize: 11
                        font.family: "Segoe UI"
                        color: "#888888"
                    }
                }
                
                // Time display
                Column {
                    spacing: 0
                    
                    Text {
                        anchors.right: parent.right
                        text: currentTime
                        font.pixelSize: 22
                        font.family: "Segoe UI"
                        font.weight: Font.Light
                        color: "#ffffff"
                    }
                }
            }
        }
        
        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Qt.rgba(0.4, 0.6, 0.9, 0.7) : Qt.rgba(1, 1, 1, 0.12)
            
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                
                Text {
                    text: "🔍"
                    font.pixelSize: 16
                    opacity: 0.7
                }
                
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    font.family: "Segoe UI"
                    color: "#ffffff"
                    clip: true
                    
                    onTextChanged: searchQuery = text
                    
                    Keys.onEscapePressed: {
                        text = ""
                        focus = false
                    }
                    
                    Keys.onReturnPressed: {
                        if (filteredApps.length > 0) {
                            startMenu.appLaunched(filteredApps[0].name)
                        }
                    }
                }
                
                // Clear button
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 20
                    height: 20
                    radius: 10
                    color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 14
                        color: "#888888"
                    }
                    
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
            
            // Placeholder
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "Type to search apps..."
                font.pixelSize: 14
                font.family: "Segoe UI"
                color: "#555555"
                visible: !searchInput.text && !searchInput.activeFocus
            }
        }
        
        // Section label
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            
            Text {
                text: searchQuery ? "SEARCH RESULTS" : "PINNED"
                font.pixelSize: 11
                font.family: "Segoe UI"
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                color: "#666666"
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: filteredApps.length + " apps"
                font.pixelSize: 10
                color: "#555555"
                visible: searchQuery
            }
        }
        
        // App grid - responsive
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // No results message
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: filteredApps.length === 0
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🔍"
                    font.pixelSize: 48
                    opacity: 0.4
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No apps found"
                    font.pixelSize: 14
                    color: "#666666"
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Try a different search"
                    font.pixelSize: 12
                    color: "#555555"
                }
            }
            
            // App grid
            GridLayout {
                anchors.fill: parent
                visible: filteredApps.length > 0
                columns: 3
                rowSpacing: 10
                columnSpacing: 10
                
                Repeater {
                    model: filteredApps
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        radius: 10
                        
                        color: appMouse.containsMouse 
                            ? Qt.rgba(1, 1, 1, 0.12) 
                            : Qt.rgba(1, 1, 1, 0.04)
                        border.width: appMouse.containsMouse ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            // Icon with colored background
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 40
                                height: 40
                                radius: 10
                                
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: modelData.color }
                                    GradientStop { position: 1.0; color: Qt.darker(modelData.color, 1.3) }
                                }
                                
                                // Glow on hover
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: parent.radius + 3
                                    color: "transparent"
                                    border.width: 2
                                    border.color: modelData.color
                                    opacity: appMouse.containsMouse ? 0.4 : 0
                                    
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 20
                                }
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                font.pixelSize: 12
                                font.family: "Segoe UI"
                                font.weight: appMouse.containsMouse ? Font.DemiBold : Font.Normal
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
                        
                        scale: appMouse.pressed ? 0.95 : (appMouse.containsMouse ? 1.02 : 1.0)
                        
                        // Tooltip with description
                        ToolTip {
                            visible: appMouse.containsMouse
                            delay: 800
                            text: modelData.desc
                        }
                    }
                }
            }
        }
        
        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.1)
        }
        
        // Bottom actions
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 10
            
            // Power/Shutdown button - using clear text icon
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 40
                radius: 8
                color: powerMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Qt.rgba(1, 1, 1, 0.05)
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                // Power icon using Canvas for consistent rendering
                Canvas {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        
                        var centerX = width / 2
                        var centerY = height / 2
                        var radius = 7
                        
                        ctx.strokeStyle = powerMouse.containsMouse ? "#ff6b6b" : "#ffffff"
                        ctx.lineWidth = 2
                        ctx.lineCap = "round"
                        
                        // Circle (with gap at top)
                        ctx.beginPath()
                        ctx.arc(centerX, centerY + 1, radius, Math.PI * 0.3, Math.PI * 2.7, false)
                        ctx.stroke()
                        
                        // Vertical line
                        ctx.beginPath()
                        ctx.moveTo(centerX, 2)
                        ctx.lineTo(centerX, 10)
                        ctx.stroke()
                    }
                }
                
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                    
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Shut down"
                    ToolTip.delay: 500
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // All apps button - opens apps folder
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                radius: 8
                color: allAppsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.width: allAppsMouse.containsMouse ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.15)
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text {
                        text: "📂"
                        font.pixelSize: 14
                    }
                    
                    Text {
                        text: "All apps"
                        font.pixelSize: 13
                        font.family: "Segoe UI"
                        color: "#ffffff"
                    }
                    
                    Text {
                        text: "→"
                        font.pixelSize: 14
                        color: allAppsMouse.containsMouse ? "#ffffff" : "#888888"
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                
                MouseArea {
                    id: allAppsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Close start menu and open explorer to apps folder
                        startMenu.visible = false
                        startMenu.appLaunched("AeroExplorer")
                    }
                    
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Open apps folder"
                    ToolTip.delay: 500
                }
            }
        }
    }
    
    // Appear animation
    scale: visible ? 1.0 : 0.95
    opacity: visible ? 1.0 : 0
    transformOrigin: Item.Bottom
    
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }
    
    // Focus search on open
    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            searchQuery = ""
        }
    }
}
