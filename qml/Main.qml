// GlassOS Main - With Wallpaper and Animations
import QtQuick
import QtQuick.Controls
import "components"
import "apps"

ApplicationWindow {
    id: root
    visible: true
    visibility: Window.FullScreen
    title: "GlassOS"
    color: "transparent"
    
    property var openWindows: []
    property int windowCounter: 0
    
    // Update taskbar when windows change
    function updateTaskbar() {
        taskbar.runningWindows = openWindows.filter(function(w) { return w !== null })
    }
    
    // ===== WALLPAPER BACKGROUND =====
    Item {
        id: backgroundContainer
        anchors.fill: parent
        z: -10
        
        // Fallback gradient
        Rectangle {
            id: gradientBg
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1e3c72" }
                GradientStop { position: 0.5; color: "#2a5298" }
                GradientStop { position: 1.0; color: "#1e3c72" }
            }
        }
        
        // Custom wallpaper image
        Image {
            id: wallpaperImage
            anchors.fill: parent
            source: Storage.getWallpaperUrl()
            fillMode: Image.PreserveAspectCrop
            visible: source !== ""
            asynchronous: true
            
            // Fade in animation
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500 } }
        }
        
        // Animated light overlay for liveliness
        Rectangle {
            anchors.fill: parent
            opacity: 0.08
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: lightPos.value - 0.3; color: "transparent" }
                GradientStop { position: lightPos.value; color: "#ffffff" }
                GradientStop { position: lightPos.value + 0.3; color: "transparent" }
            }
            
            NumberAnimation on opacity {
                id: lightPos
                property real value: 0
                from: 0
                to: 1
                duration: 8000
                loops: Animation.Infinite
                easing.type: Easing.InOutSine
                
                onRunningChanged: if (!running) value = 0
            }
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.12; duration: 4000 }
                NumberAnimation { to: 0.08; duration: 4000 }
            }
        }
        
        // Subtle vignette
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.3) }
                GradientStop { position: 0.15; color: "transparent" }
                GradientStop { position: 0.85; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
            }
        }
    }
    
    // Desktop Area
    DesktopArea {
        id: desktopArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: taskbar.top
        z: 0
        
        onOpenApp: function(appName) {
            launchApp(appName)
        }
    }
    
    // Window container
    Item {
        id: windowContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: taskbar.top
        z: 10
    }
    
    // ===== AERO WARNING DIALOG =====
    Rectangle {
        id: errorDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: false
        z: 9999
        
        property string errorTitle: "System Alert"
        property string errorMessage: "An error has occurred."
        
        MouseArea { anchors.fill: parent; onClicked: {} }
        
        Rectangle {
            anchors.centerIn: parent
            width: 450
            height: 200
            radius: 10
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2a3040" }
                GradientStop { position: 1.0; color: "#1a2030" }
            }
            
            border.width: 2
            border.color: "#e04343"
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                
                Row {
                    spacing: 12
                    
                    Text {
                        text: "⚠️"
                        font.pixelSize: 32
                    }
                    
                    Column {
                        spacing: 4
                        
                        Text {
                            text: errorDialog.errorTitle
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "GlassOS has encountered an issue"
                            font.pixelSize: 11
                            color: "#aaaaaa"
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 70
                    radius: 5
                    color: Qt.rgba(0, 0, 0, 0.3)
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        
                        Text {
                            text: errorDialog.errorMessage
                            font.pixelSize: 11
                            color: "#cccccc"
                            wrapMode: Text.Wrap
                            width: 400
                        }
                    }
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    
                    Rectangle {
                        width: 100
                        height: 32
                        radius: 4
                        color: dismissMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.3, 0.5, 0.8, 0.4)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Dismiss"
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: dismissMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: errorDialog.visible = false
                        }
                    }
                }
            }
            
            scale: errorDialog.visible ? 1.0 : 0.9
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }
    
    // Connect to Sentinel error signal
    Connections {
        target: typeof Sentinel !== 'undefined' ? Sentinel : null
        
        function onErrorOccurred(title, message) {
            errorDialog.errorTitle = title
            errorDialog.errorMessage = message
            errorDialog.visible = true
        }
    }
    
    // Start Menu
    StartMenu {
        id: startMenu
        anchors.left: parent.left
        anchors.bottom: taskbar.top
        anchors.leftMargin: 8
        anchors.bottomMargin: 8
        width: 380
        height: Math.min(500, parent.height * 0.7)
        visible: false
        z: 500
        
        onAppLaunched: function(appName) {
            launchApp(appName)
            startMenu.visible = false
        }
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: 400
        visible: startMenu.visible
        onClicked: startMenu.visible = false
    }
    
    // Taskbar
    Taskbar {
        id: taskbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 48
        z: 100
        
        onStartClicked: {
            startMenu.visible = !startMenu.visible
        }
        
        onAppClicked: function(appName) {
            launchApp(appName)
        }
        
        onTaskbarAppClicked: function(win) {
            if (win) {
                win.visible = true
                win.z = 100
            }
        }
        
        onTaskbarAppClosed: function(win) {
            if (win) {
                closeWindow(win)
            }
        }
    }
    
    // Close a window with animation
    function closeWindow(win) {
        // Animate out
        closeAnim.target = win
        closeAnim.start()
    }
    
    ParallelAnimation {
        id: closeAnim
        property var target: null
        
        NumberAnimation {
            target: closeAnim.target
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: closeAnim.target
            property: "scale"
            to: 0.9
            duration: 150
            easing.type: Easing.OutCubic
        }
        
        onFinished: {
            if (target) {
                var idx = openWindows.indexOf(target)
                if (idx !== -1) {
                    openWindows.splice(idx, 1)
                }
                target.destroy()
                updateTaskbar()
            }
        }
    }
    
    // Launch app function
    function launchApp(appName) {
        console.log("Launching:", appName)
        
        var xPos = 80 + (windowCounter % 6) * 35
        var yPos = 50 + (windowCounter % 6) * 30
        var win = null
        
        try {
            switch(appName) {
                case "Calculator":
                    win = calcComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "Calculator",
                        windowIcon: "🧮",
                        width: 320, height: 450
                    })
                    break
                case "GlassPad":
                    win = notepadComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "GlassPad",
                        windowIcon: "📝",
                        width: 700, height: 500
                    })
                    break
                case "AeroExplorer":
                    win = explorerComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "AeroExplorer",
                        windowIcon: "📁",
                        width: 800, height: 500
                    })
                    break
                case "Weather":
                    win = weatherComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "Weather",
                        windowIcon: "🌤",
                        width: 500, height: 400
                    })
                    break
                case "AeroBrowser":
                    win = browserComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "AeroBrowser",
                        windowIcon: "🌐",
                        width: 850, height: 550
                    })
                    break
                case "Settings":
                    win = settingsComponent.createObject(windowContainer, {
                        x: xPos, y: yPos,
                        windowTitle: "Settings",
                        windowIcon: "⚙",
                        width: 600, height: 480
                    })
                    break
                default:
                    showError("Not Found", "Application '" + appName + "' not found.")
                    return
            }
            
            if (win) {
                win.closeRequested.connect(function() { 
                    closeWindow(win)
                })
                win.activated.connect(function() {
                    for (var i = 0; i < openWindows.length; i++) {
                        if (openWindows[i]) openWindows[i].z = 10
                    }
                    win.z = 100
                })
                openWindows.push(win)
                windowCounter++
                updateTaskbar()
            } else {
                showError("Error", "Failed to launch " + appName)
            }
        } catch (e) {
            showError("Error", "Could not launch " + appName + ": " + e.message)
        }
    }
    
    // Set wallpaper function (called from Settings)
    function setWallpaper(path) {
        Storage.setWallpaper(path)
        wallpaperImage.source = Storage.getWallpaperUrl()
    }
    
    // Window components
    Component {
        id: calcComponent
        GlassWindow {
            Calculator { anchors.fill: parent }
        }
    }
    
    Component {
        id: notepadComponent
        GlassWindow {
            Notepad { anchors.fill: parent }
        }
    }
    
    Component {
        id: explorerComponent
        GlassWindow {
            Explorer { 
                anchors.fill: parent
                onSetAsWallpaper: function(path) {
                    root.setWallpaper(path)
                }
                onOpenFileRequest: function(path, name, isImage, isText) {
                    root.openFile(path, name, isImage, isText)
                }
            }
        }
    }
    
    Component {
        id: weatherComponent
        GlassWindow {
            Weather { anchors.fill: parent }
        }
    }
    
    Component {
        id: browserComponent
        GlassWindow {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🌐"
                        font.pixelSize: 64
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "AeroBrowser"
                        font.pixelSize: 24
                        font.family: "Segoe UI"
                        color: "#ffffff"
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Web browsing coming soon!"
                        font.pixelSize: 14
                        color: "#888888"
                    }
                }
            }
        }
    }
    
    Component {
        id: settingsComponent
        GlassWindow {
            SettingsApp { 
                anchors.fill: parent
                onWallpaperSelected: function(path) {
                    root.setWallpaper(path)
                }
            }
        }
    }
    
    // Image Viewer Component
    Component {
        id: imageViewerComponent
        GlassWindow {
            property string imagePath: ""
            property string imageName: ""
            
            ImageViewer { 
                id: viewer
                anchors.fill: parent
                onSetAsWallpaper: function(path) {
                    root.setWallpaper(path)
                }
            }
            
            Component.onCompleted: {
                if (imagePath && imageName) {
                    viewer.loadImage(imagePath, imageName)
                }
            }
        }
    }
    
    // Text Editor Component (using Notepad for editing)
    Component {
        id: textViewerComponent
        GlassWindow {
            property string filePath: ""
            property string fileName: ""
            
            Notepad { 
                id: notepadEditor
                anchors.fill: parent
            }
            
            Component.onCompleted: {
                if (filePath && fileName) {
                    notepadEditor.loadFile(filePath, fileName)
                }
            }
        }
    }
    
    // Open file in appropriate viewer
    function openFile(path, name, isImage, isText) {
        var xPos = 100 + (windowCounter % 5) * 30
        var yPos = 60 + (windowCounter % 5) * 25
        var win = null
        
        try {
            if (isImage) {
                win = imageViewerComponent.createObject(windowContainer, {
                    x: xPos, y: yPos,
                    windowTitle: name,
                    windowIcon: "🖼",
                    width: 700, height: 500,
                    imagePath: path,
                    imageName: name
                })
            } else if (isText) {
                win = textViewerComponent.createObject(windowContainer, {
                    x: xPos, y: yPos,
                    windowTitle: name,
                    windowIcon: "📄",
                    width: 650, height: 450,
                    filePath: path,
                    fileName: name
                })
            }
            
            if (win) {
                win.closeRequested.connect(function() { 
                    closeWindow(win)
                })
                win.activated.connect(function() {
                    for (var i = 0; i < openWindows.length; i++) {
                        if (openWindows[i]) openWindows[i].z = 10
                    }
                    win.z = 100
                })
                openWindows.push(win)
                windowCounter++
                updateTaskbar()
            }
        } catch (e) {
            showError("Error", "Could not open file: " + e.message)
        }
    }

    
    // Error dialog
    function showError(title, message) {
        errorTitleText.text = title
        errorMessageText.text = message
        errorOverlay.visible = true
    }
    
    Rectangle {
        id: errorOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: false
        z: 9000
        
        MouseArea { anchors.fill: parent; onClicked: { } }
        
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 160
            radius: 8
            color: Qt.rgba(0.15, 0.15, 0.2, 0.98)
            border.width: 1
            border.color: "#cc3333"
            
            Column {
                anchors.fill: parent
                spacing: 0
                
                Rectangle {
                    width: parent.width
                    height: 32
                    color: "#aa2222"
                    radius: 8
                    
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 10
                        color: parent.color
                    }
                    
                    Text {
                        id: errorTitleText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Error"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 26
                        height: 22
                        radius: 4
                        color: closeErrorMouse.containsMouse ? "#ff5555" : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: closeErrorMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: errorOverlay.visible = false
                        }
                    }
                }
                
                Item {
                    width: parent.width
                    height: parent.height - 32
                    
                    Row {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 16
                        
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: "#cc3333"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#ffffff"
                            }
                        }
                        
                        Text {
                            id: errorMessageText
                            width: 260
                            text: "An error occurred."
                            font.pixelSize: 13
                            color: "#ffffff"
                            wrapMode: Text.Wrap
                        }
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 16
                        width: 80
                        height: 30
                        radius: 4
                        color: okBtnMouse.containsMouse ? Qt.rgba(1,1,1,0.2) : Qt.rgba(1,1,1,0.1)
                        border.width: 1
                        border.color: Qt.rgba(1,1,1,0.3)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "OK"
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: okBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: errorOverlay.visible = false
                        }
                    }
                }
            }
            
            scale: errorOverlay.visible ? 1.0 : 0.9
            opacity: errorOverlay.visible ? 1.0 : 0
            Behavior on scale { NumberAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
    
    // Shortcuts
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
    }
    
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (errorOverlay.visible) {
                errorOverlay.visible = false
            } else if (startMenu.visible) {
                startMenu.visible = false
            }
        }
    }
    
    // Startup animation
    Component.onCompleted: {
        console.log("GlassOS Desktop loaded successfully!")
        startupAnim.start()
    }
    
    SequentialAnimation {
        id: startupAnim
        
        PauseAnimation { duration: 100 }
        
        ParallelAnimation {
            NumberAnimation {
                target: desktopArea
                property: "opacity"
                from: 0
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: taskbar
                property: "y"
                from: root.height
                to: root.height - taskbar.height
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
