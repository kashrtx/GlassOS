// GlassOS Window - With Genie Minimize Animation
import QtQuick
import QtQuick.Controls

Rectangle {
    id: glassWindow
    
    property string windowTitle: "Window"
    property string windowIcon: "🪟"
    property string windowId: ""
    property bool isMaximized: false
    property bool isSnappedLeft: false
    property bool isSnappedRight: false
    property bool isMinimized: false
    
    // Taskbar position for genie animation
    property real taskbarCenterX: parent ? parent.width / 2 : 400
    property real taskbarY: parent ? parent.height : 600
    
    default property alias content: contentArea.children
    
    signal closeRequested()
    signal minimized()
    signal activated()
    
    property real restoreX: x
    property real restoreY: y
    property real restoreWidth: width
    property real restoreHeight: height
    
    radius: (isMaximized || isSnappedLeft || isSnappedRight) ? 0 : 8
    
    // Main window background
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0.15, 0.18, 0.25, 0.98) }
        GradientStop { position: 0.1; color: Qt.rgba(0.12, 0.14, 0.20, 0.98) }
        GradientStop { position: 1.0; color: Qt.rgba(0.08, 0.10, 0.15, 0.98) }
    }
    
    border.width: 1
    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.4)
    
    // Transform for genie effect
    transform: [
        Scale {
            id: genieScale
            origin.x: glassWindow.width / 2
            origin.y: glassWindow.height
            xScale: 1
            yScale: 1
        },
        Translate {
            id: genieTranslate
            x: 0
            y: 0
        }
    ]
    
    // Outer glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(0.3, 0.5, 0.8, 0.2)
        z: -1
        visible: !isMinimized
    }
    
    // Drop shadow
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: parent.radius + 4
        color: Qt.rgba(0, 0, 0, 0.4)
        z: -2
        visible: !isMinimized
    }
    
    // Snap preview
    Rectangle {
        id: snapPreview
        visible: false
        anchors.fill: parent
        color: Qt.rgba(0.3, 0.5, 0.8, 0.3)
        border.width: 2
        border.color: Qt.rgba(0.4, 0.6, 0.9, 0.8)
        radius: 8
        z: 1000
    }
    
    Column {
        anchors.fill: parent
        
        // Title bar
        Rectangle {
            id: titleBar
            width: parent.width
            height: 36
            radius: (isMaximized || isSnappedLeft || isSnappedRight) ? 0 : 8
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.25, 0.30, 0.40, 1.0) }
                GradientStop { position: 0.5; color: Qt.rgba(0.18, 0.22, 0.30, 1.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.15, 0.22, 1.0) }
            }
            
            Rectangle {
                visible: !(isMaximized || isSnappedLeft || isSnappedRight)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 8
                color: Qt.rgba(0.12, 0.15, 0.22, 1.0)
            }
            
            // Glass shine
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height * 0.5
                radius: (isMaximized || isSnappedLeft || isSnappedRight) ? 0 : 8
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.15) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.02) }
                }
            }
            
            // Drag area with snap detection
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 130
                
                property point clickPos
                property bool dragging: false
                
                onPressed: function(mouse) {
                    clickPos = Qt.point(mouse.x, mouse.y)
                    dragging = false
                    glassWindow.z = 100
                    glassWindow.activated()
                }
                
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        dragging = true
                        
                        // Unsnap if dragging from snapped state
                        if (isSnappedLeft || isSnappedRight || isMaximized) {
                            var centerRatio = clickPos.x / glassWindow.width
                            isSnappedLeft = false
                            isSnappedRight = false
                            isMaximized = false
                            glassWindow.width = restoreWidth
                            glassWindow.height = restoreHeight
                            clickPos.x = restoreWidth * centerRatio
                        }
                        
                        glassWindow.x += mouse.x - clickPos.x
                        glassWindow.y += mouse.y - clickPos.y
                        
                        // Detect snap zones
                        var globalX = glassWindow.x + mouse.x
                        var globalY = glassWindow.y + mouse.y
                        var parentW = glassWindow.parent.width
                        
                        snapPreview.visible = (globalX < 20 || globalX > parentW - 20 || globalY < 10)
                    }
                }
                
                onReleased: function(mouse) {
                    if (dragging) {
                        var globalX = glassWindow.x + mouse.x
                        var globalY = glassWindow.y + mouse.y
                        var parentW = glassWindow.parent.width
                        
                        snapPreview.visible = false
                        
                        if (globalX < 20) snapLeft()
                        else if (globalX > parentW - 20) snapRight()
                        else if (globalY < 10) toggleMaximize()
                    }
                }
                
                onDoubleClicked: toggleMaximize()
            }
            
            // Icon and title
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                
                Text {
                    text: windowIcon
                    font.pixelSize: 16
                }
                
                Text {
                    text: windowTitle
                    font.pixelSize: 13
                    font.family: "Segoe UI"
                    font.weight: Font.Medium
                    color: "#ffffff"
                }
            }
            
            // Window control buttons
            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.rightMargin: 4
                spacing: 1
                
                // Minimize
                Rectangle {
                    width: 40
                    height: 28
                    radius: 4
                    color: minMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 2
                        color: "#ffffff"
                        radius: 1
                    }
                    
                    MouseArea {
                        id: minMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: minimizeWindow()
                    }
                }
                
                // Maximize/Restore
                Rectangle {
                    width: 40
                    height: 28
                    radius: 4
                    color: maxMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: 11
                        height: 11
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                        radius: 2
                        visible: !isMaximized && !isSnappedLeft && !isSnappedRight
                    }
                    
                    Item {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        visible: isMaximized || isSnappedLeft || isSnappedRight
                        
                        Rectangle {
                            x: 3; y: 0
                            width: 9; height: 9
                            color: "transparent"
                            border.width: 2
                            border.color: "#ffffff"
                            radius: 1
                        }
                        Rectangle {
                            x: 0; y: 3
                            width: 9; height: 9
                            color: Qt.rgba(0.18, 0.22, 0.30, 1.0)
                            border.width: 2
                            border.color: "#ffffff"
                            radius: 1
                        }
                    }
                    
                    MouseArea {
                        id: maxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleMaximize()
                    }
                }
                
                // Close
                Rectangle {
                    width: 40
                    height: 28
                    radius: 4
                    color: closeMouse.containsMouse ? "#e04343" : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    Item {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 2
                            radius: 1
                            color: "#ffffff"
                            rotation: 45
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 2
                            radius: 1
                            color: "#ffffff"
                            rotation: -45
                        }
                    }
                    
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: glassWindow.closeRequested()
                    }
                }
            }
            
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }
        }
        
        // Content area
        Item {
            id: contentArea
            width: parent.width
            height: parent.height - titleBar.height
            clip: true
        }
    }
    
    // Resize handle
    MouseArea {
        visible: !isMaximized && !isSnappedLeft && !isSnappedRight
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 20
        height: 20
        cursorShape: Qt.SizeFDiagCursor
        
        property point startPos
        property size startSize
        
        onPressed: function(mouse) {
            startPos = Qt.point(mouse.x, mouse.y)
            startSize = Qt.size(glassWindow.width, glassWindow.height)
        }
        
        onPositionChanged: function(mouse) {
            if (pressed) {
                glassWindow.width = Math.max(300, startSize.width + mouse.x - startPos.x)
                glassWindow.height = Math.max(200, startSize.height + mouse.y - startPos.y)
            }
        }
    }
    
    // Resize grip
    Row {
        visible: !isMaximized && !isSnappedLeft && !isSnappedRight && !isMinimized
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        spacing: 2
        
        Column {
            spacing: 2
            Repeater {
                model: 3
                Row {
                    spacing: 2
                    Repeater {
                        model: 3 - index
                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.3)
                        }
                    }
                }
            }
        }
    }
    
    // ===== GENIE MINIMIZE ANIMATION =====
    function minimizeWindow() {
        if (!isMinimized) {
            minimizeAnim.start()
        }
    }
    
    function restoreFromMinimize() {
        if (isMinimized) {
            restoreAnim.start()
        }
    }
    
    ParallelAnimation {
        id: minimizeAnim
        
        NumberAnimation {
            target: genieScale
            property: "xScale"
            to: 0.1
            duration: 300
            easing.type: Easing.InQuad
        }
        
        NumberAnimation {
            target: genieScale
            property: "yScale"
            to: 0.05
            duration: 300
            easing.type: Easing.InQuad
        }
        
        NumberAnimation {
            target: genieTranslate
            property: "x"
            to: taskbarCenterX - glassWindow.x - glassWindow.width / 2
            duration: 300
            easing.type: Easing.InQuad
        }
        
        NumberAnimation {
            target: genieTranslate
            property: "y"
            to: taskbarY - glassWindow.y - glassWindow.height
            duration: 300
            easing.type: Easing.InQuad
        }
        
        NumberAnimation {
            target: glassWindow
            property: "opacity"
            to: 0
            duration: 300
            easing.type: Easing.InQuad
        }
        
        onFinished: {
            isMinimized = true
            glassWindow.visible = false
            glassWindow.minimized()
        }
    }
    
    ParallelAnimation {
        id: restoreAnim
        
        NumberAnimation {
            target: genieScale
            property: "xScale"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: genieScale
            property: "yScale"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: genieTranslate
            property: "x"
            to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: genieTranslate
            property: "y"
            to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: glassWindow
            property: "opacity"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
        
        onStarted: {
            glassWindow.visible = true
        }
        
        onFinished: {
            isMinimized = false
        }
    }
    
    function toggleMaximize() {
        if (isMaximized || isSnappedLeft || isSnappedRight) {
            restoreWindow()
        } else {
            saveGeometry()
            x = 0
            y = 0
            width = parent.width
            height = parent.height
            isMaximized = true
            isSnappedLeft = false
            isSnappedRight = false
        }
    }
    
    function snapLeft() {
        saveGeometry()
        x = 0
        y = 0
        width = parent.width / 2
        height = parent.height
        isSnappedLeft = true
        isSnappedRight = false
        isMaximized = false
    }
    
    function snapRight() {
        saveGeometry()
        x = parent.width / 2
        y = 0
        width = parent.width / 2
        height = parent.height
        isSnappedRight = true
        isSnappedLeft = false
        isMaximized = false
    }
    
    function restoreWindow() {
        x = restoreX
        y = restoreY
        width = restoreWidth
        height = restoreHeight
        isMaximized = false
        isSnappedLeft = false
        isSnappedRight = false
    }
    
    function saveGeometry() {
        if (!isMaximized && !isSnappedLeft && !isSnappedRight) {
            restoreX = x
            restoreY = y
            restoreWidth = width
            restoreHeight = height
        }
    }
    
    // Opening animation
    Component.onCompleted: {
        openAnim.start()
    }
    
    ParallelAnimation {
        id: openAnim
        
        NumberAnimation {
            target: glassWindow
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: glassWindow
            property: "scale"
            from: 0.9
            to: 1.0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    
    // Smooth animations for position/size changes when snapping
    Behavior on x { 
        enabled: !minimizeAnim.running && !restoreAnim.running
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
    }
    Behavior on y { 
        enabled: !minimizeAnim.running && !restoreAnim.running
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
    }
    Behavior on width { 
        enabled: !minimizeAnim.running && !restoreAnim.running
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
    }
    Behavior on height { 
        enabled: !minimizeAnim.running && !restoreAnim.running
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
    }
}
