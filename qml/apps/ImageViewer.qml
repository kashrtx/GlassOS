// GlassOS Image Viewer - Auto-fit to Window
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: imageViewer
    color: "transparent"
    
    property string imagePath: ""
    property string imageName: ""
    property real zoomLevel: 1.0
    property real minZoom: 0.05
    property real maxZoom: 5.0
    property bool autoFit: true
    
    signal setAsWallpaper(string path)
    
    function loadImage(path, name) {
        imagePath = path
        imageName = name
        autoFit = true
        viewerImage.source = Storage.getFileUrl(path)
    }
    
    function calculateFitZoom() {
        if (viewerImage.sourceSize.width > 0 && viewerImage.sourceSize.height > 0) {
            var scaleX = imageContainer.width / viewerImage.sourceSize.width
            var scaleY = imageContainer.height / viewerImage.sourceSize.height
            return Math.min(scaleX, scaleY, 1.0) * 0.9  // 90% to add some padding
        }
        return 1.0
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Qt.rgba(0, 0, 0, 0.3)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                
                // Zoom out
                Rectangle {
                    width: 32
                    height: 28
                    radius: 4
                    color: zoomOutMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: zoomOutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            autoFit = false
                            zoomLevel = Math.max(minZoom, zoomLevel - 0.1)
                        }
                    }
                }
                
                // Zoom level display
                Rectangle {
                    width: 60
                    height: 24
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.3)
                    
                    Text {
                        anchors.centerIn: parent
                        text: Math.round((autoFit ? calculateFitZoom() : zoomLevel) * 100) + "%"
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                }
                
                // Zoom in
                Rectangle {
                    width: 32
                    height: 28
                    radius: 4
                    color: zoomInMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: zoomInMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            autoFit = false
                            zoomLevel = Math.min(maxZoom, zoomLevel + 0.1)
                        }
                    }
                }
                
                Rectangle {
                    width: 1
                    height: 20
                    color: Qt.rgba(1, 1, 1, 0.2)
                }
                
                // Fit to window
                Rectangle {
                    width: 70
                    height: 28
                    radius: 4
                    color: autoFit ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : (fitMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                    border.width: autoFit ? 1 : 0
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.5)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "⤢ Fit"
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: fitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: autoFit = true
                    }
                }
                
                // 100% zoom
                Rectangle {
                    width: 50
                    height: 28
                    radius: 4
                    color: (!autoFit && Math.abs(zoomLevel - 1.0) < 0.01) ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : 
                           (actualMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                    
                    Text {
                        anchors.centerIn: parent
                        text: "100%"
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: actualMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            autoFit = false
                            zoomLevel = 1.0
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Set as wallpaper button
                Rectangle {
                    width: 130
                    height: 28
                    radius: 4
                    color: wpBtnMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.3, 0.5, 0.8, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.5)
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text { text: "🖼"; font.pixelSize: 12 }
                        Text { text: "Set as Wallpaper"; font.pixelSize: 11; color: "#ffffff" }
                    }
                    
                    MouseArea {
                        id: wpBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: imageViewer.setAsWallpaper(imagePath)
                    }
                }
            }
        }
        
        // Image container
        Rectangle {
            id: imageContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0a0f"
            clip: true
            
            // Checkerboard for transparency
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    var size = 12
                    for (var x = 0; x < width; x += size) {
                        for (var y = 0; y < height; y += size) {
                            ctx.fillStyle = ((x / size + y / size) % 2 === 0) ? "#1a1a20" : "#141418"
                            ctx.fillRect(x, y, size, size)
                        }
                    }
                }
            }
            
            // Image with auto-fit
            Image {
                id: viewerImage
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                
                // Auto-fit or manual zoom
                width: autoFit ? parent.width * 0.9 : sourceSize.width * zoomLevel
                height: autoFit ? parent.height * 0.9 : sourceSize.height * zoomLevel
                
                onStatusChanged: {
                    if (status === Image.Ready && autoFit) {
                        // Image loaded, auto-fit is applied via width/height binding
                    }
                }
            }
            
            // Loading indicator
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: viewerImage.status === Image.Loading
                
                BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Loading..."; font.pixelSize: 11; color: "#888888" }
            }
            
            // Error state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: viewerImage.status === Image.Error
                
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "❌"; font.pixelSize: 48 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Failed to load image"; font.pixelSize: 14; color: "#888888" }
            }
            
            // Mouse wheel zoom
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    autoFit = false
                    if (wheel.angleDelta.y > 0) {
                        zoomLevel = Math.min(maxZoom, zoomLevel + 0.1)
                    } else {
                        zoomLevel = Math.max(minZoom, zoomLevel - 0.1)
                    }
                }
            }
        }
        
        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: Qt.rgba(0, 0, 0, 0.3)
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                
                Text {
                    text: imageName
                    font.pixelSize: 10
                    color: "#aaaaaa"
                }
                
                Text {
                    visible: viewerImage.status === Image.Ready
                    text: viewerImage.sourceSize.width + " × " + viewerImage.sourceSize.height + " px"
                    font.pixelSize: 10
                    color: "#888888"
                }
            }
        }
    }
}
