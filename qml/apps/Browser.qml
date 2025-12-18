// GlassOS Web Browser (AeroBrowser) - Full-Featured Chromium Browser
// Comprehensive web browser with tabs, bookmarks, history, downloads, and extension support

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtWebEngine
import "../components"

Item {
    id: browserApp
    
    // ===== BROWSER STATE =====
    property string currentUrl: "https://www.google.com"
    property string pageTitle: "New Tab"
    property bool isLoading: false
    property int loadProgress: 0
    property bool canGoBack: false
    property bool canGoForward: false
    property bool isSecure: false
    property bool webEngineAvailable: true
    
    // Tab management - each tab now contains its own WebEngineView via the model
    property int activeTabIndex: 0
    property int tabCounter: 0
    
    // Bookmarks
    property var bookmarks: [
        { title: "Google", url: "https://www.google.com", icon: "🔍", favicon: "" },
        { title: "YouTube", url: "https://www.youtube.com", icon: "▶️", favicon: "" },
        { title: "GitHub", url: "https://www.github.com", icon: "🐙", favicon: "" },
        { title: "Wikipedia", url: "https://www.wikipedia.org", icon: "📚", favicon: "" },
        { title: "Reddit", url: "https://www.reddit.com", icon: "🔶", favicon: "" }
    ]
    
    // History
    property var history: []
    
    // Downloads
    property var downloads: []
    property bool showDownloads: false
    
    // Settings
    property var browserSettings: {
        "homepage": "https://www.google.com",
        "searchEngine": "https://www.google.com/search?q=",
        "enableJavaScript": true,
        "enableCookies": true,
        "blockPopups": true,
        "enableDarkMode": false,
        "zoomLevel": 1.0
    }
    
    // Tab model for dynamic tab creation
    ListModel {
        id: tabModel
    }
    
    // ===== INITIALIZATION =====
    Component.onCompleted: {
        // Create initial tab
        addNewTab("https://www.google.com")
    }
    
    // Get current active WebView
    function getCurrentWebView() {
        if (tabStack.count > 0 && activeTabIndex >= 0 && activeTabIndex < tabStack.count) {
            var item = tabStack.itemAt(activeTabIndex)
            if (item && item.webEngine) {
                return item.webEngine
            }
        }
        return null
    }
    
    // ===== TAB MANAGEMENT =====
    function addNewTab(url) {
        var tabUrl = url || browserSettings.homepage
        var tabId = tabCounter++
        
        tabModel.append({
            tabId: tabId,
            tabUrl: tabUrl,
            tabTitle: "New Tab",
            tabIsLoading: true,
            tabFavicon: ""
        })
        
        activeTabIndex = tabModel.count - 1
        currentUrl = tabUrl
        pageTitle = "New Tab"
        
        console.log("Added tab", tabId, "at index", activeTabIndex, "with URL:", tabUrl)
    }
    
    function closeTab(index) {
        if (tabModel.count <= 1) {
            // Don't close last tab, just navigate to home
            var webView = getCurrentWebView()
            if (webView) {
                webView.url = browserSettings.homepage
            }
            tabModel.setProperty(0, "tabUrl", browserSettings.homepage)
            tabModel.setProperty(0, "tabTitle", "New Tab")
            currentUrl = browserSettings.homepage
            pageTitle = "New Tab"
            return
        }
        
        tabModel.remove(index)
        
        if (activeTabIndex >= tabModel.count) {
            activeTabIndex = tabModel.count - 1
        }
        
        // Update current URL from new active tab
        if (tabModel.count > 0) {
            currentUrl = tabModel.get(activeTabIndex).tabUrl
            pageTitle = tabModel.get(activeTabIndex).tabTitle
        }
    }
    
    function switchTab(index) {
        if (index >= 0 && index < tabModel.count) {
            activeTabIndex = index
            var tabData = tabModel.get(index)
            currentUrl = tabData.tabUrl
            pageTitle = tabData.tabTitle
            isLoading = tabData.tabIsLoading
            
            // Update navigation state from the tab's webview
            var webView = getCurrentWebView()
            if (webView) {
                canGoBack = webView.canGoBack
                canGoForward = webView.canGoForward
            }
        }
    }
    
    // ===== NAVIGATION =====
    function navigate(url) {
        var processedUrl = url.trim()
        
        if (!processedUrl) return
        
        // Handle different URL formats
        if (!processedUrl.startsWith("http://") && 
            !processedUrl.startsWith("https://") && 
            !processedUrl.startsWith("file://")) {
            
            if (processedUrl.includes(".") && !processedUrl.includes(" ")) {
                // Looks like a URL
                processedUrl = "https://" + processedUrl
            } else {
                // Treat as search query
                processedUrl = browserSettings.searchEngine + encodeURIComponent(processedUrl)
            }
        }
        
        currentUrl = processedUrl
        
        // Navigate the current tab's WebView
        var webView = getCurrentWebView()
        if (webView) {
            webView.url = processedUrl
        }
        
        // Update tab model
        if (activeTabIndex >= 0 && activeTabIndex < tabModel.count) {
            tabModel.setProperty(activeTabIndex, "tabUrl", processedUrl)
        }
    }
    
    function addToHistory(url, title) {
        var entry = {
            url: url,
            title: title || url,
            timestamp: new Date().toISOString()
        }
        history.unshift(entry)
        // Keep last 100 entries
        if (history.length > 100) {
            history = history.slice(0, 100)
        }
    }
    
    function toggleBookmark() {
        var existingIndex = -1
        for (var i = 0; i < bookmarks.length; i++) {
            if (bookmarks[i].url === currentUrl) {
                existingIndex = i
                break
            }
        }
        
        if (existingIndex >= 0) {
            bookmarks.splice(existingIndex, 1)
        } else {
            bookmarks.push({
                title: pageTitle,
                url: currentUrl,
                icon: "📄",
                favicon: ""
            })
        }
        bookmarks = bookmarks.slice()
    }
    
    function isBookmarked(url) {
        for (var i = 0; i < bookmarks.length; i++) {
            if (bookmarks[i].url === url) return true
        }
        return false
    }
    
    // ===== MAIN LAYOUT =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== TAB BAR (Vivaldi-Style) =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: Qt.rgba(0.08, 0.09, 0.12, 0.98)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 0
                
                // Tab list - fills available space
                ListView {
                    id: tabListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 1
                    clip: true
                    
                    model: tabModel
                    
                    delegate: Rectangle {
                        id: tabDelegate
                        width: Math.min(220, Math.max(120, (tabListView.width - 50) / Math.max(1, tabModel.count)))
                        height: 34
                        radius: 6
                        
                        property bool isActive: index === activeTabIndex
                        property bool isHovered: tabMouse.containsMouse
                        
                        // Tab background with subtle gradient
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: isActive ? Qt.rgba(0.18, 0.20, 0.26, 1) : (isHovered ? Qt.rgba(0.14, 0.16, 0.20, 1) : "transparent") }
                            GradientStop { position: 1.0; color: isActive ? Qt.rgba(0.15, 0.17, 0.22, 1) : "transparent" }
                        }
                        
                        // Top rounded corners for active tab
                        Rectangle {
                            visible: isActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.radius
                            color: Qt.rgba(0.18, 0.20, 0.26, 1)
                        }
                        
                        // Active indicator (colored bottom line)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 3
                            radius: 1.5
                            visible: isActive
                            color: Theme.accentColor
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 8
                            
                            // Loading spinner or favicon
                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                
                                // Loading spinner
                                Text {
                                    anchors.centerIn: parent
                                    text: "◐"
                                    font.pixelSize: 14
                                    color: Theme.accentColor
                                    visible: model.tabIsLoading
                                    
                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: model.tabIsLoading
                                    }
                                }
                                
                                // Favicon placeholder
                                Text {
                                    anchors.centerIn: parent
                                    text: "🌐"
                                    font.pixelSize: 12
                                    visible: !model.tabIsLoading
                                }
                            }
                            
                            // Tab title
                            Text {
                                Layout.fillWidth: true
                                text: model.tabTitle || "New Tab"
                                font.pixelSize: 12
                                font.family: "Segoe UI"
                                font.weight: isActive ? Font.Medium : Font.Normal
                                color: isActive ? "#ffffff" : "#b0b0b0"
                                elide: Text.ElideRight
                            }
                            
                            // Close button - more prominent
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: closeTabMouse.containsMouse ? Qt.rgba(0.9, 0.3, 0.3, 0.8) : (isHovered || isActive ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: closeTabMouse.containsMouse ? "#ffffff" : "#888888"
                                }
                                
                                MouseArea {
                                    id: closeTabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: closeTab(index)
                                }
                            }
                        }
                        
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            anchors.rightMargin: 24
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switchTab(index)
                            
                            // Double-click to close
                            onDoubleClicked: closeTab(index)
                        }
                    }
                }
                
                // ===== NEW TAB BUTTON - Prominent & Visible =====
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 32
                    Layout.leftMargin: 4
                    radius: 6
                    
                    color: newTabMouse.containsMouse 
                        ? Qt.rgba(0.95, 0.55, 0.15, 0.9)  // Orange on hover
                        : Qt.rgba(0.2, 0.22, 0.28, 1)
                    
                    border.width: 1
                    border.color: newTabMouse.containsMouse 
                        ? Qt.rgba(1, 0.7, 0.3, 0.8)
                        : Qt.rgba(1, 1, 1, 0.1)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 22
                        font.bold: true
                        color: newTabMouse.containsMouse ? "#ffffff" : "#cccccc"
                    }
                    
                    MouseArea {
                        id: newTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addNewTab()
                        
                        ToolTip.visible: containsMouse
                        ToolTip.text: "New Tab (Ctrl+T)"
                        ToolTip.delay: 500
                    }
                    
                    // Subtle glow effect on hover
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: newTabMouse.containsMouse ? Qt.rgba(1, 0.6, 0.2, 0.3) : "transparent"
                        visible: newTabMouse.containsMouse
                    }
                }
            }
        }
        
        // ===== NAVIGATION BAR =====
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
                
                // Back button
                NavButton {
                    navIcon: "←"
                    enabled: canGoBack
                    onClicked: {
                        var wv = getCurrentWebView()
                        if (wv) wv.goBack()
                    }
                    tooltip: "Back (Alt+Left)"
                }
                
                // Forward button
                NavButton {
                    navIcon: "→"
                    enabled: canGoForward
                    onClicked: {
                        var wv = getCurrentWebView()
                        if (wv) wv.goForward()
                    }
                    tooltip: "Forward (Alt+Right)"
                }
                
                // Reload/Stop button
                NavButton {
                    navIcon: isLoading ? "✕" : "↻"
                    onClicked: {
                        var wv = getCurrentWebView()
                        if (wv) {
                            if (isLoading) {
                                wv.stop()
                            } else {
                                wv.reload()
                            }
                        }
                    }
                    tooltip: isLoading ? "Stop (Esc)" : "Reload (F5)"
                }
                
                // Home button
                NavButton {
                    navIcon: "🏠"
                    onClicked: navigate(browserSettings.homepage)
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
                            text: {
                                if (currentUrl.startsWith("https://")) return "🔒"
                                if (currentUrl.startsWith("http://")) return "⚠️"
                                return "ℹ️"
                            }
                            font.pixelSize: 12
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                ToolTip.visible: containsMouse
                                ToolTip.text: currentUrl.startsWith("https://") 
                                    ? "Secure connection (HTTPS)" 
                                    : "Connection is not secure"
                                ToolTip.delay: 500
                            }
                        }
                        
                        // URL input
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
                            
                            Keys.onEscapePressed: {
                                text = currentUrl
                                focus = false
                            }
                        }
                        
                        // Bookmark button
                        Text {
                            text: isBookmarked(currentUrl) ? "⭐" : "☆"
                            font.pixelSize: 16
                            opacity: bookmarkBtnMouse.containsMouse ? 1 : 0.7
                            color: isBookmarked(currentUrl) ? "#FFD700" : Theme.textPrimary
                            
                            MouseArea {
                                id: bookmarkBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleBookmark()
                                
                                ToolTip.visible: containsMouse
                                ToolTip.text: isBookmarked(currentUrl) ? "Remove bookmark" : "Add bookmark"
                                ToolTip.delay: 500
                            }
                        }
                    }
                }
                
                // Downloads button
                NavButton {
                    navIcon: "⬇️"
                    onClicked: showDownloads = !showDownloads
                    tooltip: "Downloads"
                    
                    // Download count badge
                    Rectangle {
                        visible: downloads.length > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 2
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.accentColor
                        
                        Text {
                            anchors.centerIn: parent
                            text: downloads.length
                            font.pixelSize: 9
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }
                
                // AdBlocker shield button
                NavButton {
                    id: adBlockerBtn
                    navIcon: "🛡️"
                    onClicked: {
                        if (typeof AdBlocker !== 'undefined') {
                            AdBlocker.setEnabled(!AdBlocker.enabled)
                        }
                    }
                    tooltip: {
                        if (typeof AdBlocker !== 'undefined') {
                            return AdBlocker.enabled 
                                ? "AdBlocker ON - " + AdBlocker.blockedCount + " blocked\nClick to disable"
                                : "AdBlocker OFF\nClick to enable"
                        }
                        return "AdBlocker"
                    }
                    
                    // Shield color based on state
                    Rectangle {
                        anchors.fill: parent
                        radius: 17
                        color: {
                            if (typeof AdBlocker !== 'undefined' && AdBlocker.enabled) {
                                return Qt.rgba(0.2, 0.8, 0.4, 0.3) // Green glow when active
                            }
                            return "transparent"
                        }
                        z: -1
                    }
                    
                    // Blocked count badge
                    Rectangle {
                        visible: typeof AdBlocker !== 'undefined' && AdBlocker.enabled && AdBlocker.blockedCount > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 0
                        width: 16
                        height: 16
                        radius: 8
                        color: "#22c55e" // Green
                        
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (typeof AdBlocker !== 'undefined') {
                                    var count = AdBlocker.blockedCount
                                    return count > 99 ? "99+" : count.toString()
                                }
                                return "0"
                            }
                            font.pixelSize: 8
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }
                
                // Menu button
                NavButton {
                    navIcon: "⋮"
                    onClicked: browserMenu.visible = !browserMenu.visible
                    tooltip: "Menu"
                }
            }
        }
        
        // ===== BOOKMARKS BAR =====
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
                    model: bookmarks.slice(0, 8) // Show first 8 bookmarks
                    
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
                                elide: Text.ElideRight
                            }
                        }
                        
                        onClicked: navigate(modelData.url)
                        
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.url
                        ToolTip.delay: 800
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }
        
        // ===== LOADING BAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            color: "transparent"
            
            Rectangle {
                id: loadingBar
                height: parent.height
                width: parent.width * loadProgress / 100
                color: Theme.accentColor
                visible: isLoading
                
                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
                
                // Animated gradient overlay
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.4) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    
                    NumberAnimation on x {
                        from: -parent.width
                        to: parent.width
                        duration: 1000
                        loops: Animation.Infinite
                        running: isLoading
                    }
                }
            }
        }
        
        // ===== WEB CONTENT - Stack of WebViews (one per tab) =====
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // StackLayout to hold multiple WebEngineViews
            StackLayout {
                id: tabStack
                anchors.fill: parent
                currentIndex: activeTabIndex
                
                Repeater {
                    model: tabModel
                    
                    delegate: Item {
                        id: tabContainer
                        property alias webEngine: webEngineLoader.item
                        
                        // Store tab index for reference
                        property int myIndex: index
                        // IMPORTANT: Don't bind to model.tabUrl - it causes refresh loops!
                        // Only read initial URL, then the WebView manages its own URL
                        property string initialUrl: model.tabUrl
                        
                        Loader {
                            id: webEngineLoader
                            anchors.fill: parent
                            active: webEngineAvailable
                            
                            sourceComponent: Component {
                                WebEngineView {
                                    id: webView
                                    // Set URL only once via Component.onCompleted to avoid binding loops
                                    // url: tabContainer.initialUrl // DON'T do this - causes loops!
                                    
                                    Component.onCompleted: {
                                        // Load initial URL only once
                                        url = tabContainer.initialUrl
                                    }
                                    
                                    // Zoom level
                                    zoomFactor: browserSettings.zoomLevel
                                    
                                    // Performance & Compatibility Settings
                                    settings.javascriptEnabled: browserSettings.enableJavaScript
                                    settings.autoLoadImages: true
                                    settings.pluginsEnabled: true
                                    settings.fullScreenSupportEnabled: true
                                    settings.localStorageEnabled: true
                                    settings.webGLEnabled: true
                                    settings.accelerated2dCanvasEnabled: true
                                    settings.webRTCPublicInterfacesOnly: false
                                    settings.playbackRequiresUserGesture: false
                                    settings.pdfViewerEnabled: true
                                    
                                    onLoadingChanged: function(loadRequest) {
                                        // Update this tab's loading state
                                        if (myIndex >= 0 && myIndex < tabModel.count) {
                                            var isTabLoading = (loadRequest.status === WebEngineView.LoadStartedStatus)
                                            tabModel.setProperty(myIndex, "tabIsLoading", isTabLoading)
                                            
                                            // If this is the active tab, update global state
                                            if (myIndex === activeTabIndex) {
                                                browserApp.isLoading = isTabLoading
                                                
                                                if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                                                    browserApp.loadProgress = 0
                                                } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                                                    browserApp.loadProgress = 100
                                                    addToHistory(url.toString(), title)
                                                } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                                                    browserApp.loadProgress = 0
                                                    console.log("Load failed:", loadRequest.errorString)
                                                }
                                            }
                                        }
                                    }
                                    
                                    onLoadProgressChanged: {
                                        if (myIndex === activeTabIndex) {
                                            browserApp.loadProgress = loadProgress
                                        }
                                    }
                                    
                                    onTitleChanged: {
                                        // Update tab title in model
                                        if (myIndex >= 0 && myIndex < tabModel.count) {
                                            tabModel.setProperty(myIndex, "tabTitle", title || "New Tab")
                                        }
                                        
                                        // Update global state if active
                                        if (myIndex === activeTabIndex) {
                                            browserApp.pageTitle = title || "New Tab"
                                        }
                                    }
                                    
                                    onUrlChanged: {
                                        var urlStr = url.toString()
                                        
                                        // Update tab URL in model
                                        if (myIndex >= 0 && myIndex < tabModel.count) {
                                            tabModel.setProperty(myIndex, "tabUrl", urlStr)
                                        }
                                        
                                        // Update global state and URL bar if active
                                        if (myIndex === activeTabIndex) {
                                            browserApp.currentUrl = urlStr
                                            urlInput.text = urlStr
                                        }
                                    }
                                    
                                    onCanGoBackChanged: {
                                        if (myIndex === activeTabIndex) {
                                            browserApp.canGoBack = canGoBack
                                        }
                                    }
                                    
                                    onCanGoForwardChanged: {
                                        if (myIndex === activeTabIndex) {
                                            browserApp.canGoForward = canGoForward
                                        }
                                    }
                                    
                                    // Handle new tab/window requests
                                    onNewWindowRequested: function(request) {
                                        // Open in new tab
                                        addNewTab(request.requestedUrl.toString())
                                    }
                                    
                                    // Handle downloads
                                    profile.onDownloadRequested: function(download) {
                                        download.accept()
                                        
                                        var dlInfo = {
                                            id: download.id,
                                            url: download.url.toString(),
                                            filename: download.downloadFileName,
                                            totalBytes: download.totalBytes,
                                            receivedBytes: download.receivedBytes,
                                            state: "downloading"
                                        }
                                        downloads.push(dlInfo)
                                        downloads = downloads.slice()
                                        
                                        console.log("Download started:", download.downloadFileName)
                                    }
                                    
                                    // Full screen support
                                    onFullScreenRequested: function(request) {
                                        request.accept()
                                    }
                                    
                                    // Context menu
                                    onContextMenuRequested: function(request) {
                                        // Defer to default context menu for now
                                        request.accepted = false
                                    }
                                }
                            }
                        }
                        
                        // Fallback when loader is not active
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0.1, 0.12, 0.16, 0.95)
                            visible: !webEngineLoader.active
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "⏳"
                                    font.pixelSize: 48
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Loading..."
                                    font.pixelSize: 16
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }
                }
            }
            
            // ===== FALLBACK WHEN WEBENGINE NOT AVAILABLE =====
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.1, 0.12, 0.16, 0.95)
                visible: !webEngineAvailable || tabModel.count === 0
                
                Column {
                    anchors.centerIn: parent
                    spacing: 20
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🌐"
                        font.pixelSize: 80
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "AeroBrowser"
                        font {
                            pixelSize: 28
                            family: "Segoe UI"
                            weight: Font.Light
                        }
                        color: "#ffffff"
                    }
                    
                    Rectangle {
                        width: 400
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.2)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "WebEngine is not available"
                        font.pixelSize: 16
                        color: "#ff6b6b"
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Please ensure PySide6-WebEngine is installed:\npip install PySide6-WebEngine"
                        font.pixelSize: 13
                        color: Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    GlassButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200
                        height: 40
                        
                        contentItem: Text {
                            text: "Retry"
                            color: "#ffffff"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            webEngineAvailable = true
                        }
                    }
                }
            }
        }
    }
    
    // ===== BROWSER MENU POPUP =====
    GlassPanel {
        id: browserMenu
        visible: false
        anchors {
            right: parent.right
            top: parent.top
            topMargin: 120
            rightMargin: 8
        }
        width: 240
        height: menuColumn.height + 16
        cornerRadius: 8
        glassOpacity: 0.98
        z: 1000
        
        Column {
            id: menuColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 2
            
            ContextMenuItem { 
                text: "New Tab"
                icon: "➕"
                shortcut: "Ctrl+T"
                onClicked: { addNewTab(); browserMenu.visible = false }
            }
            
            ContextMenuItem { 
                text: "New Window"
                icon: "🪟"
                shortcut: "Ctrl+N"
                onClicked: browserMenu.visible = false 
            }
            
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            
            ContextMenuItem { 
                text: "History"
                icon: "📜"
                shortcut: "Ctrl+H"
                onClicked: { 
                    historyPanel.visible = !historyPanel.visible
                    browserMenu.visible = false 
                }
            }
            
            ContextMenuItem { 
                text: "Downloads"
                icon: "⬇️"
                shortcut: "Ctrl+J"
                onClicked: { 
                    showDownloads = !showDownloads
                    browserMenu.visible = false 
                }
            }
            
            ContextMenuItem { 
                text: "Bookmarks"
                icon: "⭐"
                shortcut: "Ctrl+B"
                onClicked: browserMenu.visible = false 
            }
            
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            
            // AdBlocker toggle
            ContextMenuItem { 
                text: {
                    if (typeof AdBlocker !== 'undefined') {
                        return AdBlocker.enabled 
                            ? "AdBlocker ✓ (" + AdBlocker.blockedCount + " blocked)"
                            : "AdBlocker (disabled)"
                    }
                    return "AdBlocker"
                }
                icon: "🛡️"
                onClicked: {
                    if (typeof AdBlocker !== 'undefined') {
                        AdBlocker.setEnabled(!AdBlocker.enabled)
                    }
                    browserMenu.visible = false
                }
            }
            
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            
            ContextMenuItem { 
                text: "Zoom In"
                icon: "🔍+"
                shortcut: "Ctrl++"
                onClicked: {
                    browserSettings.zoomLevel = Math.min(3.0, browserSettings.zoomLevel + 0.1)
                    browserSettings = browserSettings // Force update
                }
            }
            
            ContextMenuItem { 
                text: "Zoom Out"
                icon: "🔍-"
                shortcut: "Ctrl+-"
                onClicked: {
                    browserSettings.zoomLevel = Math.max(0.25, browserSettings.zoomLevel - 0.1)
                    browserSettings = browserSettings
                }
            }
            
            ContextMenuItem { 
                text: "Reset Zoom"
                icon: "🔍"
                shortcut: "Ctrl+0"
                onClicked: {
                    browserSettings.zoomLevel = 1.0
                    browserSettings = browserSettings
                }
            }
            
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            
            ContextMenuItem { 
                text: "Find in Page"
                icon: "🔎"
                shortcut: "Ctrl+F"
                onClicked: { 
                    findBar.visible = !findBar.visible
                    browserMenu.visible = false 
                }
            }
            
            ContextMenuItem { 
                text: "Print"
                icon: "🖨️"
                shortcut: "Ctrl+P"
                onClicked: browserMenu.visible = false 
            }
            
            Rectangle { width: parent.width; height: 1; color: Theme.textSecondary; opacity: 0.2 }
            
            ContextMenuItem { 
                text: "Settings"
                icon: "⚙️"
                onClicked: browserMenu.visible = false 
            }
            
            ContextMenuItem { 
                text: "About AeroBrowser"
                icon: "ℹ️"
                onClicked: {
                    navigate("about:version")
                    browserMenu.visible = false
                }
            }
        }
        
        // Close when clicking outside
        MouseArea {
            parent: browserApp
            anchors.fill: parent
            visible: browserMenu.visible
            z: 999
            onClicked: browserMenu.visible = false
        }
    }
    
    // ===== FIND BAR =====
    Rectangle {
        id: findBar
        visible: false
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 120
        anchors.rightMargin: 60
        width: 320
        height: 40
        radius: 8
        color: Qt.rgba(0.15, 0.18, 0.22, 0.98)
        border.width: 1
        border.color: Qt.rgba(0.3, 0.5, 0.8, 0.4)
        z: 500
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: Qt.rgba(0.1, 0.12, 0.16, 1)
                
                TextInput {
                    id: findInput
                    anchors.fill: parent
                    anchors.margins: 8
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    clip: true
                    
                    onTextChanged: {
                        var wv = getCurrentWebView()
                        if (wv && text.length > 0) {
                            wv.findText(text)
                        }
                    }
                    
                    onAccepted: {
                        var wv = getCurrentWebView()
                        if (wv) {
                            wv.findText(text)
                        }
                    }
                }
                
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 8
                    text: "Find..."
                    color: Theme.textSecondary
                    visible: findInput.text === ""
                }
            }
            
            Text {
                text: "▲"
                font.pixelSize: 14
                color: findPrevMouse.containsMouse ? "#ffffff" : "#888888"
                MouseArea {
                    id: findPrevMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: {
                        var wv = getCurrentWebView()
                        if (wv) wv.findText(findInput.text, WebEngineView.FindBackward)
                    }
                }
            }
            
            Text {
                text: "▼"
                font.pixelSize: 14
                color: findNextMouse.containsMouse ? "#ffffff" : "#888888"
                MouseArea {
                    id: findNextMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: {
                        var wv = getCurrentWebView()
                        if (wv) wv.findText(findInput.text)
                    }
                }
            }
            
            Text {
                text: "×"
                font.pixelSize: 18
                font.bold: true
                color: closeFindMouse.containsMouse ? "#ff6b6b" : "#888888"
                MouseArea {
                    id: closeFindMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: {
                        findBar.visible = false
                        findInput.text = ""
                        var wv = getCurrentWebView()
                        if (wv) wv.findText("")
                    }
                }
            }
        }
    }
    
    // ===== HISTORY PANEL =====
    Rectangle {
        id: historyPanel
        visible: false
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 80
        anchors.bottomMargin: 48
        width: 320
        color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
        border.width: 1
        border.color: Qt.rgba(0.3, 0.5, 0.8, 0.3)
        z: 100
        
        Column {
            anchors.fill: parent
            
            // Header
            Rectangle {
                width: parent.width
                height: 40
                color: Qt.rgba(0.15, 0.18, 0.22, 1)
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "📜 History"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }
                
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    font.pixelSize: 18
                    color: closeHistoryMouse.containsMouse ? "#ff6b6b" : "#888888"
                    
                    MouseArea {
                        id: closeHistoryMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: historyPanel.visible = false
                    }
                }
            }
            
            // History list
            ListView {
                width: parent.width
                height: parent.height - 40
                clip: true
                model: history
                
                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: 50
                    color: historyItemMouse.containsMouse ? Qt.rgba(0.2, 0.24, 0.3, 1) : "transparent"
                    
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 4
                        
                        Text {
                            width: parent.width
                            text: modelData.title
                            font.pixelSize: 12
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            width: parent.width
                            text: modelData.url
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                    
                    MouseArea {
                        id: historyItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            navigate(modelData.url)
                            historyPanel.visible = false
                        }
                    }
                }
                
                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: "No history yet"
                    color: Theme.textSecondary
                    visible: history.length === 0
                }
            }
        }
    }
    
    // ===== DOWNLOADS PANEL =====
    Rectangle {
        id: downloadsPanel
        visible: showDownloads
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        width: 350
        height: Math.min(300, downloads.length * 60 + 50)
        radius: 8
        color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
        border.width: 1
        border.color: Qt.rgba(0.3, 0.5, 0.8, 0.3)
        z: 100
        
        Column {
            anchors.fill: parent
            
            // Header
            Rectangle {
                width: parent.width
                height: 40
                color: Qt.rgba(0.15, 0.18, 0.22, 1)
                radius: 8
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 8
                    color: parent.color
                }
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⬇️ Downloads"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }
                
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    font.pixelSize: 18
                    color: closeDownloadsMouse.containsMouse ? "#ff6b6b" : "#888888"
                    
                    MouseArea {
                        id: closeDownloadsMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: showDownloads = false
                    }
                }
            }
            
            // Downloads list
            ListView {
                width: parent.width
                height: parent.height - 40
                clip: true
                model: downloads
                
                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: 55
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10
                        
                        Text {
                            text: "📄"
                            font.pixelSize: 24
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Text {
                                text: modelData.filename
                                font.pixelSize: 12
                                color: "#ffffff"
                                elide: Text.ElideMiddle
                            }
                            
                            // Progress bar
                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Qt.rgba(0.2, 0.24, 0.3, 1)
                                
                                Rectangle {
                                    width: parent.width * (modelData.receivedBytes / Math.max(1, modelData.totalBytes))
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accentColor
                                }
                            }
                            
                            Text {
                                text: modelData.state === "downloading" 
                                    ? Math.round(modelData.receivedBytes / 1024) + " KB / " + Math.round(modelData.totalBytes / 1024) + " KB"
                                    : "Complete"
                                font.pixelSize: 10
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
                
                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: downloads.length === 0
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "⬇️"
                        font.pixelSize: 32
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No downloads yet"
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
    
    // ===== KEYBOARD SHORTCUTS =====
    Shortcut {
        sequence: "Ctrl+T"
        onActivated: addNewTab()
    }
    
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: closeTab(activeTabIndex)
    }
    
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: switchTab((activeTabIndex + 1) % tabModel.count)
    }
    
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: switchTab((activeTabIndex - 1 + tabModel.count) % tabModel.count)
    }
    
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            urlInput.forceActiveFocus()
            urlInput.selectAll()
        }
    }
    
    Shortcut {
        sequence: "F5"
        onActivated: {
            var wv = getCurrentWebView()
            if (wv) wv.reload()
        }
    }
    
    Shortcut {
        sequence: "Ctrl+R"
        onActivated: {
            var wv = getCurrentWebView()
            if (wv) wv.reload()
        }
    }
    
    Shortcut {
        sequence: "Alt+Left"
        onActivated: {
            var wv = getCurrentWebView()
            if (wv && canGoBack) wv.goBack()
        }
    }
    
    Shortcut {
        sequence: "Alt+Right"
        onActivated: {
            var wv = getCurrentWebView()
            if (wv && canGoForward) wv.goForward()
        }
    }
    
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            findBar.visible = true
            findInput.forceActiveFocus()
        }
    }
    
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (findBar.visible) {
                findBar.visible = false
                findInput.text = ""
                var wv = getCurrentWebView()
                if (wv) wv.findText("")
            } else if (isLoading) {
                var wv = getCurrentWebView()
                if (wv) wv.stop()
            }
        }
    }
    
    Shortcut {
        sequence: "Ctrl+D"
        onActivated: toggleBookmark()
    }
    
    Shortcut {
        sequence: "Ctrl+H"
        onActivated: historyPanel.visible = !historyPanel.visible
    }
    
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: {
            browserSettings.zoomLevel = 1.0
            browserSettings = browserSettings
        }
    }
    
    Shortcut {
        sequence: "Ctrl++"
        onActivated: {
            browserSettings.zoomLevel = Math.min(3.0, browserSettings.zoomLevel + 0.1)
            browserSettings = browserSettings
        }
    }
    
    Shortcut {
        sequence: "Ctrl+-"
        onActivated: {
            browserSettings.zoomLevel = Math.max(0.25, browserSettings.zoomLevel - 0.1)
            browserSettings = browserSettings
        }
    }
    
    // Tab switching shortcuts (1-8)
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: if (tabModel.count >= 1) switchTab(0)
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: if (tabModel.count >= 2) switchTab(1)
    }
    Shortcut {
        sequence: "Ctrl+3"
        onActivated: if (tabModel.count >= 3) switchTab(2)
    }
    Shortcut {
        sequence: "Ctrl+4"
        onActivated: if (tabModel.count >= 4) switchTab(3)
    }
    Shortcut {
        sequence: "Ctrl+5"
        onActivated: if (tabModel.count >= 5) switchTab(4)
    }
    Shortcut {
        sequence: "Ctrl+6"
        onActivated: if (tabModel.count >= 6) switchTab(5)
    }
    Shortcut {
        sequence: "Ctrl+7"
        onActivated: if (tabModel.count >= 7) switchTab(6)
    }
    Shortcut {
        sequence: "Ctrl+8"
        onActivated: if (tabModel.count >= 8) switchTab(7)
    }
    Shortcut {
        sequence: "Ctrl+9"
        onActivated: if (tabModel.count > 0) switchTab(tabModel.count - 1) // Last tab
    }
    
    // ===== NAVIGATION BUTTON COMPONENT =====
    component NavButton: GlassButton {
        property string navIcon: ""
        property string tooltip: ""
        
        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: 17
        
        Text {
            anchors.centerIn: parent
            text: navIcon
            font.pixelSize: 16
            color: enabled ? Theme.textPrimary : Theme.textDisabled
        }
        
        ToolTip.visible: hovered && tooltip
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
}
