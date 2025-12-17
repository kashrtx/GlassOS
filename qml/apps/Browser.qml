// GlassOS Web Browser (AeroBrowser) Application UI
// Full-featured glass web browser

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtWebEngine
import "../components"

Item {
    id: browserApp
    
    // Browser state
    property string currentUrl: "https://www.google.com"
    property string pageTitle: "New Tab"
    property bool isLoading: false
    property var bookmarks: [
        { title: "Google", url: "https://www.google.com", icon: "🔍" },
        { title: "YouTube", url: "https://www.youtube.com", icon: "▶️" },
        { title: "GitHub", url: "https://www.github.com", icon: "🐙" },
        { title: "Wikipedia", url: "https://www.wikipedia.org", icon: "📚" }
    ]
    
    function navigate(url) {
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            if (url.includes(".")) {
                url = "https://" + url
            } else {
                url = "https://www.google.com/search?q=" + encodeURIComponent(url)
            }
        }
        currentUrl = url
        webView.url = url
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Navigation bar
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            cornerRadius: 0
            glassOpacity: 0.4
            showGlow: false
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6
                
                // Navigation buttons
                NavButton {
                    icon: "←"
                    enabled: webView.canGoBack
                    onClicked: webView.goBack()
                    tooltip: "Back"
                }
                
                NavButton {
                    icon: "→"
                    enabled: webView.canGoForward
                    onClicked: webView.goForward()
                    tooltip: "Forward"
                }
                
                NavButton {
                    icon: isLoading ? "✕" : "↻"
                    onClicked: isLoading ? webView.stop() : webView.reload()
                    tooltip: isLoading ? "Stop" : "Reload"
                }
                
                NavButton {
                    icon: "🏠"
                    onClicked: navigate("https://www.google.com")
                    tooltip: "Home"
                }
                
                // URL bar
                GlassPanel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    cornerRadius: 17
                    glassOpacity: 0.3
                    showGlow: urlInput.activeFocus
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        
                        // Security indicator
                        Text {
                            text: currentUrl.startsWith("https") ? "🔒" : "ℹ️"
                            font.pixelSize: 12
                        }
                        
                        TextInput {
                            id: urlInput
                            Layout.fillWidth: true
                            text: currentUrl
                            font {
                                pixelSize: 13
                                family: "Segoe UI"
                            }
                            color: Theme.textPrimary
                            selectionColor: Theme.accentColor
                            selectedTextColor: "#ffffff"
                            clip: true
                            
                            onAccepted: {
                                navigate(text)
                            }
                            
                            onActiveFocusChanged: {
                                if (activeFocus) selectAll()
                            }
                        }
                        
                        // Bookmark button
                        Text {
                            text: "⭐"
                            font.pixelSize: 14
                            opacity: bookmarkMouse.containsMouse ? 1 : 0.6
                            
                            MouseArea {
                                id: bookmarkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    bookmarks.push({ 
                                        title: pageTitle, 
                                        url: currentUrl, 
                                        icon: "📄" 
                                    })
                                }
                            }
                        }
                    }
                }
                
                // Menu button
                NavButton {
                    icon: "⋮"
                    onClicked: browserMenu.visible = !browserMenu.visible
                    tooltip: "Menu"
                }
            }
        }
        
        // Bookmarks bar
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            cornerRadius: 0
            glassOpacity: 0.2
            showGlow: false
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4
                
                Repeater {
                    model: bookmarks
                    
                    GlassButton {
                        Layout.preferredHeight: 26
                        buttonRadius: 4
                        
                        contentItem: Row {
                            spacing: 4
                            anchors.centerIn: parent
                            leftPadding: 8
                            rightPadding: 8
                            
                            Text {
                                text: modelData.icon
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: modelData.title
                                font.pixelSize: 11
                                color: Theme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        onClicked: navigate(modelData.url)
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }
        
        // Loading bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: "transparent"
            visible: isLoading
            
            Rectangle {
                id: loadingBar
                height: parent.height
                color: Theme.accentColor
                width: parent.width * webView.loadProgress / 100
                
                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
        }
        
        // Web content
        WebEngineView {
            id: webView
            Layout.fillWidth: true
            Layout.fillHeight: true
            url: currentUrl
            
            onLoadingChanged: function(loadRequest) {
                isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus)
            }
            
            onTitleChanged: {
                pageTitle = title || "New Tab"
            }
            
            onUrlChanged: {
                currentUrl = url.toString()
                urlInput.text = currentUrl
            }
            
            // New tab handling
            onNewWindowRequested: function(request) {
                // Would open in new window/tab
                request.openIn(webView)
            }
        }
        
        // Fallback when WebEngine is not available
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: typeof WebEngineView === "undefined"
            
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
                    text: "WebEngine not available"
                    font {
                        pixelSize: 18
                        family: "Segoe UI"
                    }
                    color: Theme.textPrimary
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Install PySide6-WebEngine to enable web browsing"
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
            }
        }
    }
    
    // Browser menu popup
    GlassPanel {
        id: browserMenu
        visible: false
        anchors {
            right: parent.right
            top: parent.top
            topMargin: 56
            rightMargin: 8
        }
        width: 200
        height: menuColumn.height + 16
        cornerRadius: 8
        glassOpacity: 0.95
        z: 100
        
        Column {
            id: menuColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 2
            
            ContextMenuItem { text: "New Tab"; icon: "➕"; onClicked: browserMenu.visible = false }
            ContextMenuItem { text: "New Window"; icon: "🪟"; onClicked: browserMenu.visible = false }
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            ContextMenuItem { text: "History"; icon: "📜"; onClicked: browserMenu.visible = false }
            ContextMenuItem { text: "Downloads"; icon: "⬇️"; onClicked: browserMenu.visible = false }
            ContextMenuItem { text: "Bookmarks"; icon: "⭐"; onClicked: browserMenu.visible = false }
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            ContextMenuItem { text: "Settings"; icon: "⚙️"; onClicked: browserMenu.visible = false }
        }
    }
    
    // Navigation button component
    component NavButton: GlassButton {
        property string icon: ""
        property string tooltip: ""
        
        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: 17
        
        Text {
            anchors.centerIn: parent
            text: icon
            font.pixelSize: 16
            color: enabled ? Theme.textPrimary : Theme.textDisabled
        }
        
        ToolTip.visible: hovered && tooltip
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
}
