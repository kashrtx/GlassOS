// AeroBrowser: Chromium (QtWebEngine) with tabs, autocomplete, built-in ad &
// tracker blocking (EasyList/EasyPrivacy), downloads, history, find-in-page,
// DevTools, permission prompts and background-tab freezing.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import QtQuick.Dialogs
import "../ui"
import "../components"

FocusScope {
    id: browser
    property var hostWindow: null
    property string initialUrl: ""
    property int current: 0
    property int uidCounter: 0
    property var closedTabs: []
    property string panel: ""            // "", "downloads", "history", "settings"
    property bool devtoolsOpen: false
    property bool fullScreen: false
    property var suggestions: []
    property int suggestIndex: -1
    property var permission: null        // pending site permission request
    property int findMatches: 0
    property int findActive: 0
    property var bookmarks: {
        var stored = Prefs.value("browser.bookmarks", null)
        if (!UI.isList(stored)) return defaultBookmarks
        return UI.arr(stored).filter(function (x) { return x && typeof x.url === "string" && typeof x.title === "string" })
    }
    readonly property var defaultBookmarks: [
        { title: "DuckDuckGo", url: "https://duckduckgo.com" },
        { title: "Wikipedia", url: "https://www.wikipedia.org" },
        { title: "YouTube", url: "https://www.youtube.com" },
        { title: "GitHub", url: "https://github.com" },
        { title: "Reddit", url: "https://www.reddit.com" },
        { title: "Hacker News", url: "https://news.ycombinator.com" }
    ]
    readonly property var view: tabRepeater.count > current && tabRepeater.itemAt(current) ? tabRepeater.itemAt(current).web : null
    readonly property string currentUrl: current < tabs.count ? tabs.get(current).url : ""
    readonly property bool isActive: hostWindow ? hostWindow.active : true
    readonly property bool cosmeticOn: Prefs.value("browser.cosmetic", true) !== false
    readonly property var wm: UI.wm
    // extensions live in ExtensionHost.qml (owned by the window manager); null when switched off
    readonly property var ext: wm ? wm.extHost : null
    readonly property bool extOn: Extensions.experimental && ext !== null && ext !== undefined
    readonly property string extStatus: !Extensions.experimental
        ? "Chrome extensions are switched off. Turn them on in Shields & settings (experimental)."
        : (ext && ext.problem ? ext.problem : "")
    function extInstalled(id) { return extOn && ext.items.some(function (e) { return e.id === id }) }

    ListModel { id: tabs }

    Component.onCompleted: {
        newTab(initialUrl, false)
        if (!initialUrl) address.forceActiveFocus()
    }
    function sessionState() { return currentUrl && currentUrl.indexOf("http") === 0 ? { initialUrl: currentUrl } : {} }
    function handleArgs(props) { if (props.initialUrl) newTab(props.initialUrl, false) }
    function acceptDrop(paths, urls) {
        paths.forEach(function (p) { if (!Storage.isDir(p)) newTab(Storage.fileUrl(p), false) })
        urls.forEach(function (u) { newTab(u, false) })
    }

    // ------------------------------------------------------------ tabs
    function prettyHost(u) { var m = String(u).match(/^[a-z]+:\/\/([^\/?#]+)/i); return m ? m[1].replace(/^www\./, "") : String(u) }

    function newTab(url, background) {
        var target = url ? (url.indexOf("://") > 0 || url.indexOf("file:") === 0 ? url : Web.normalize(url)) : ""
        tabs.append({ uid: uidCounter++, url: target, title: target ? prettyHost(target) : "New tab", loading: !!target, icon: "", muted: false, audible: false })
        if (!background) current = tabs.count - 1
        updateAddress()
    }
    function closeTab(i) {
        if (i < 0 || i >= tabs.count) return
        var t = tabs.get(i)
        if (t.url) closedTabs = closedTabs.concat([t.url]).slice(-20)
        if (tabs.count === 1) { if (hostWindow) hostWindow.forceClose(); return }
        tabs.remove(i)
        if (current >= tabs.count) current = tabs.count - 1
        else if (i < current) current--
        updateAddress()
    }
    function reopenClosed() {
        if (!closedTabs.length) return
        var u = closedTabs[closedTabs.length - 1]
        closedTabs = closedTabs.slice(0, -1)
        newTab(u, false)
    }
    function moveTab(from, to) {
        if (to < 0 || to >= tabs.count || from === to) return
        tabs.move(from, to, 1)
        current = to
    }
    function go(text) {
        var url = text.indexOf("://") > 0 ? text : Web.normalize(text)
        if (!url) return
        closeSuggestions()
        tabs.setProperty(current, "url", url)
        tabs.setProperty(current, "title", prettyHost(url))
        if (view) { view.url = url; view.forceActiveFocus() }
        updateAddress()
    }
    function goHome() {
        tabs.setProperty(current, "url", "")
        tabs.setProperty(current, "title", "New tab")
        updateAddress()
        address.forceActiveFocus()
    }
    function updateAddress() {
        if (!address.activeFocus) address.text = currentUrl
        if (hostWindow && current < tabs.count) hostWindow.title = tabs.get(current).title + " — AeroBrowser"
    }
    onCurrentChanged: { updateAddress(); permission = null; if (findBar.visible) runFind(true) }

    // ------------------------------------------------------------ bookmarks
    function isBookmarked(u) { return bookmarks.some(function (b) { return b.url === u }) }
    function toggleBookmark() {
        if (!currentUrl) return
        var list = bookmarks.filter(function (b) { return b.url !== currentUrl })
        if (list.length === bookmarks.length)
            list.push({ title: (tabs.get(current).title || prettyHost(currentUrl)).slice(0, 40), url: currentUrl })
        Prefs.setValue("browser.bookmarks", list)
        bookmarks = list
    }
    function removeBookmark(u) {
        var l = bookmarks.filter(function (b) { return b.url !== u })
        Prefs.setValue("browser.bookmarks", l)
        bookmarks = l
    }

    // ------------------------------------------------------------ suggestions
    // The omnibox: whichever search field is active (address bar or the new-tab search box)
    property var omni: address
    property var onlineSuggestions: []
    property int iconRev: 0                       // bumps when favicons / thumbnails arrive

    function looksLikeUrl(q) { return q.indexOf("://") > 0 || (/^[^\s]+\.[a-z]{2,}(\/|:|$)/i.test(q)) || /^localhost(:|\/|$)/i.test(q) }
    function refreshSuggestions(text) {
        var q = (text || "").trim()
        if (!q) { closeSuggestions(); return }
        suggestTimer.query = q
        suggestTimer.restart()
        rebuildSuggestions(q)
    }
    function rebuildSuggestions(q) {
        var out = [], seen = {}
        function add(item) { if (!seen[item.url] && out.length < 9) { seen[item.url] = true; out.push(item) } }
        if (looksLikeUrl(q)) add({ kind: "go", url: Web.normalize(q), title: q })
        add({ kind: "search", url: Web.searchUrl(q), title: q })
        var ql = q.toLowerCase()
        if (onlineSuggestions.length && suggestTimer.answered === q)
            onlineSuggestions.slice(0, 5).forEach(function (sg) { if (sg.toLowerCase() !== ql) add({ kind: "search", url: Web.searchUrl(sg), title: sg }) })
        bookmarks.forEach(function (b) {
            if (b.title.toLowerCase().indexOf(ql) >= 0 || b.url.toLowerCase().indexOf(ql) >= 0) add({ kind: "bookmark", url: b.url, title: b.title })
        })
        Web.suggest(q, 5).forEach(function (h) { add({ kind: "history", url: h.url, title: h.title || prettyHost(h.url) }) })
        suggestions = out
        if (suggestIndex >= out.length) suggestIndex = -1
    }
    function closeSuggestions() { suggestions = []; suggestIndex = -1; onlineSuggestions = [] }
    function acceptOmni(text) {
        var s = suggestIndex >= 0 && suggestIndex < suggestions.length ? suggestions[suggestIndex] : null
        var q = (text || "").trim()
        if (!s && !q) return
        go(s ? s.url : q)
    }
    function omniKey(event) {
        if (!suggestions.length) return
        if (event.key === Qt.Key_Down) { suggestIndex = Math.min(suggestIndex + 1, suggestions.length - 1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { suggestIndex = Math.max(suggestIndex - 1, -1); event.accepted = true }
    }
    Timer {   // debounce live suggestions while typing
        id: suggestTimer
        interval: 140
        property string query: ""
        property string answered: ""
        onTriggered: Web.requestSuggestions(query)
    }
    Connections {
        target: Web
        function onSuggestionsReady(query, items) {
            if (!browser.omni || query !== browser.omni.text.trim()) return   // stale answer
            suggestTimer.answered = query
            browser.onlineSuggestions = items
            browser.rebuildSuggestions(query)
        }
        function onFaviconReady(host, url) { browser.iconRev++ }
        function onThumbnailReady(host, url) { browser.iconRev++ }
    }

    // ------------------------------------------------------------ speed dial
    function addShortcutDialog() {
        dialog.ask({ title: "Add shortcut", message: "Website address", input: true, text: "",
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Add", value: "ok", kind: "primary" }] },
                   function (v, url) {
                       url = (url || "").trim()
                       if (v === "ok" && url) Web.addShortcut(browser.prettyHost(Web.normalize(url)), url)
                   })
    }
    function shortcutMenu(item, mx, my, sc) {
        menu.show(item, mx, my, [
            { text: "Open in new tab", icon: "plus", action: function () { browser.newTab(sc.url, false) } },
            { text: "Rename…", icon: "edit", action: function () {
                dialog.ask({ title: "Rename shortcut", input: true, text: sc.title,
                             buttons: [{ text: "Cancel", value: "cancel" }, { text: "Save", value: "ok", kind: "primary" }] },
                           function (v, t) { if (v === "ok" && t.trim()) Web.updateShortcut(sc.url, t.trim(), sc.url) })
            } },
            { text: "Remove", icon: "trash", danger: true, action: function () { Web.removeShortcut(sc.url) } },
            { separator: true },
            { text: "Restore default shortcuts", icon: "undo", action: function () { Web.resetShortcuts() } }
        ])
    }

    // ------------------------------------------------------------ page helpers
    function injectCosmetic(v) {
        if (!v || !cosmeticOn || !AdBlocker || !AdBlocker.enabled || AdBlocker.cosmeticCss === "") return
        v.runJavaScript("(function(c){if(document.getElementById('glassos-adblock'))return;var s=document.createElement('style');" +
                        "s.id='glassos-adblock';s.textContent=c;(document.head||document.documentElement).appendChild(s);})(" +
                        JSON.stringify(AdBlocker.cosmeticCss) + ")")
    }
    function runFind(forward) {
        if (!view) return
        var flags = (forward ? 0 : 1) | (findCase.checked ? 2 : 0)   // FindBackward = 1, FindCaseSensitively = 2
        view.findText(findField.text, flags)
    }
    function stopFind() { if (view) view.findText(""); findBar.visible = false; findMatches = 0; findActive = 0 }
    // DevTools need the persistent profile (see devtoolsView); without it they'd crash Qt 6.10.1
    readonly property bool devtoolsAvailable: BrowserProfile !== null && BrowserProfile !== undefined
    function toggleDevtools() { if (devtoolsOpen) closeDevtools(); else if (devtoolsAvailable && view) devtoolsOpen = true }
    function closeDevtools() {
        // detach before the view is destroyed
        if (devtoolsLoader.item) devtoolsLoader.item.inspectedView = null
        Qt.callLater(function () { browser.devtoolsOpen = false })
    }
    function zoomBy(d) { if (view) view.zoomFactor = Math.max(0.3, Math.min(3, Math.round((view.zoomFactor + d) * 10) / 10)) }
    function permissionLabel(n, legacy) {
        var modern = ["something", "your microphone", "your camera", "your camera and microphone", "your screen",
                      "your screen and audio", "your mouse pointer", "to show notifications", "your location", "your clipboard", "your fonts"]
        var old = ["to show notifications", "your location", "your microphone", "your camera", "your camera and microphone",
                   "your mouse pointer", "your screen", "your screen and audio", "your clipboard", "your fonts"]
        var list = legacy ? old : modern
        return n >= 0 && n < list.length ? list[n] : "extra permissions"
    }
    function answerPermission(allow) {
        var p = permission
        permission = null
        if (!p) return
        if (p.legacy) p.view.grantFeaturePermission(p.origin, p.feature, allow)
        else if (allow) p.obj.grant(); else p.obj.deny()
    }

    // ------------------------------------------------------------ shortcuts (only for the focused window)
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+T"; onActivated: { browser.newTab("", false); address.forceActiveFocus() } }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+W"; onActivated: browser.closeTab(browser.current) }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+Shift+T"; onActivated: browser.reopenClosed() }
    Shortcut { enabled: browser.isActive; sequences: ["Ctrl+L", "F6", "Alt+D"]; onActivated: { address.forceActiveFocus(); address.selectAll() } }
    Shortcut { enabled: browser.isActive; sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: browser.current = (browser.current + 1) % tabs.count }
    Shortcut { enabled: browser.isActive; sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: browser.current = (browser.current - 1 + tabs.count) % tabs.count }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+Shift+PgDown"; onActivated: browser.moveTab(browser.current, browser.current + 1) }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+Shift+PgUp"; onActivated: browser.moveTab(browser.current, browser.current - 1) }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequences: ["F5", "Ctrl+R"]; onActivated: browser.view.reload() }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequences: ["Ctrl+F5", "Ctrl+Shift+R"]; onActivated: browser.view.reloadAndBypassCache() }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequence: "Alt+Left"; onActivated: browser.view.goBack() }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequence: "Alt+Right"; onActivated: browser.view.goForward() }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+D"; onActivated: browser.toggleBookmark() }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequences: ["Ctrl+F", "F3"]; onActivated: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll() } }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+H"; onActivated: browser.panel = browser.panel === "history" ? "" : "history" }
    Shortcut { enabled: browser.isActive; sequence: "Ctrl+J"; onActivated: browser.panel = browser.panel === "downloads" ? "" : "downloads" }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequences: ["F12", "Ctrl+Shift+I"]; onActivated: browser.toggleDevtools() }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequences: ["Ctrl++", "Ctrl+="]; onActivated: browser.zoomBy(0.1) }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequence: "Ctrl+-"; onActivated: browser.zoomBy(-0.1) }
    Shortcut { enabled: browser.isActive && browser.view !== null; sequence: "Ctrl+0"; onActivated: browser.view.zoomFactor = 1 }
    Shortcut {
        // (fullscreen Esc belongs to the window manager)
        enabled: browser.isActive && !browser.fullScreen && (browser.panel !== "" || findBar.visible)
        sequence: "Esc"
        onActivated: { if (findBar.visible) browser.stopFind(); else browser.panel = "" }
    }
    Connections {   // the window manager left fullscreen (Esc forced, Alt+Tab...): tell the page
        target: browser.wm
        function onFullscreenWindowChanged() {
            if (browser.fullScreen && browser.wm.fullscreenWindow !== browser.hostWindow) {
                browser.fullScreen = false
                if (browser.view) browser.view.triggerWebAction(WebEngineView.ExitFullScreen)
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0.05, 0.06, 0.09, 0.55) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ======================================================== tab strip
        RowLayout {
            id: tabRow
            visible: !browser.fullScreen
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: UI.px(38)
            Layout.maximumHeight: UI.px(38)
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 4
            ListView {
                id: tabStrip
                // only as wide as its tabs, so the "+" button sits right after the last one
                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(contentWidth, tabRow.width - UI.px(44))
                Layout.fillHeight: true
                Layout.topMargin: 4
                orientation: ListView.Horizontal
                spacing: 3
                clip: true
                model: tabs
                interactive: contentWidth > width
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: browser.current
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: AbstractButton {
                    id: tab
                    width: Math.max(UI.px(120), Math.min(UI.px(230), (tabRow.width - UI.px(48)) / Math.max(1, tabs.count) - 3))
                    height: tabStrip.height
                    hoverEnabled: true
                    readonly property bool selected: index === browser.current
                    onClicked: browser.current = index
                    background: Rectangle {
                        radius: UI.radiusSmall
                        color: tab.selected ? UI.cardStrong : (tab.hovered ? UI.hover : "transparent")
                        border.color: tab.selected ? UI.border : "transparent"
                        Rectangle { visible: tab.selected; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: UI.accent; radius: 1 }
                    }
                    contentItem: Row {
                        leftPadding: 10
                        spacing: 7
                        Item {
                            width: UI.px(16); height: UI.px(16)
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: favicon
                                anchors.fill: parent
                                visible: !model.loading && status === Image.Ready
                                source: model.icon !== "" ? model.icon : (browser.iconRev >= 0 && model.url ? Web.favicon(model.url) : "")
                                sourceSize: Qt.size(32, 32)
                            }
                            Icon {
                                anchors.fill: parent
                                visible: !favicon.visible
                                name: model.url === "" ? "sparkles" : "globe"
                                size: UI.px(16)
                                opacity: model.loading ? 0.5 : 0.8
                                RotationAnimation on rotation { running: model.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                            }
                        }
                        Text {
                            font.weight: UI.textWeight
                            width: tab.width - UI.px(model.audible || model.muted ? 86 : 64)
                            text: model.title
                            color: tab.selected ? UI.text : UI.textDim
                            font.pixelSize: UI.px(12)
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    IconButton {   // audio indicator / per-tab mute
                        visible: model.audible || model.muted
                        anchors.right: closeBtn.left
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: model.muted ? "mute" : "volume"
                        size: 22; glyphSize: 11
                        tip: model.muted ? "Unmute tab" : "Mute tab"
                        onClicked: tabs.setProperty(index, "muted", !model.muted)
                    }
                    IconButton {
                        id: closeBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "close"; size: 22; glyphSize: 10
                        visible: tab.hovered || tab.selected
                        onClicked: browser.closeTab(index)
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.MiddleButton | Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.MiddleButton) { browser.closeTab(index); return }
                            var i = index
                            menu.show(tab, mouse.x, mouse.y, [
                                { text: "New tab", icon: "plus", shortcut: "Ctrl+T", action: function () { browser.newTab("", false) } },
                                { text: "Reload", icon: "refresh", action: function () { browser.current = i; if (browser.view) browser.view.reload() } },
                                { text: "Duplicate", icon: "copy", action: function () { browser.newTab(tabs.get(i).url, false) } },
                                { text: tabs.get(i).muted ? "Unmute tab" : "Mute tab", icon: "mute", action: function () { tabs.setProperty(i, "muted", !tabs.get(i).muted) } },
                                { separator: true },
                                { text: "Close tab", icon: "close", shortcut: "Ctrl+W", danger: true, action: function () { browser.closeTab(i) } }
                            ])
                        }
                    }
                }
            }
            IconButton { iconName: "plus"; tip: "New tab (Ctrl+T)"; onClicked: { browser.newTab("", false); address.forceActiveFocus() } }
            Item { Layout.fillWidth: true }
        }

        // ======================================================== navigation bar
        RowLayout {
            visible: !browser.fullScreen
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: UI.px(46)
            Layout.maximumHeight: UI.px(46)
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 3
            IconButton { iconName: "back"; tip: "Back (Alt+Left)"; enabled: browser.view && browser.view.canGoBack; onClicked: browser.view.goBack() }
            IconButton { iconName: "forward"; tip: "Forward (Alt+Right)"; enabled: browser.view && browser.view.canGoForward; onClicked: browser.view.goForward() }
            IconButton {
                iconName: browser.view && browser.view.loading ? "close" : "refresh"
                tip: browser.view && browser.view.loading ? "Stop" : "Reload (F5)"
                enabled: browser.view !== null
                onClicked: browser.view.loading ? browser.view.stop() : browser.view.reload()
            }
            IconButton { iconName: "home"; tip: "New tab page"; onClicked: browser.goHome() }
            GTextField {
                id: address
                Layout.fillWidth: true
                Layout.preferredHeight: UI.px(34)
                radiusOverride: 17
                leading: browser.currentUrl.indexOf("https://") === 0 ? "lock" : (browser.currentUrl === "" ? "search" : "info")
                placeholderText: "Search " + Web.searchEngine + " or enter an address"
                onTextEdited: { browser.omni = address; browser.refreshSuggestions(text) }
                onAccepted: browser.acceptOmni(text)
                onActiveFocusChanged: {
                    if (activeFocus) { browser.omni = address; selectAll() }
                    else { browser.updateAddress(); if (browser.omni === address) browser.closeSuggestions() }
                }
                Keys.onPressed: function (event) { browser.omniKey(event) }
                Keys.onEscapePressed: { browser.closeSuggestions(); browser.updateAddress(); if (browser.view) browser.view.forceActiveFocus() }
                Rectangle {   // load progress
                    visible: browser.view !== null && browser.view.loading
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    height: 2
                    radius: 1
                    width: browser.view ? (parent.width - 28) * browser.view.loadProgress / 100 : 0
                    color: UI.accent
                    Behavior on width { NumberAnimation { duration: UI.dur(200) } }
                }
            }
            Text {
                font.weight: UI.textWeight
                visible: browser.view !== null && Math.abs(browser.view.zoomFactor - 1) > 0.01
                text: browser.view ? Math.round(browser.view.zoomFactor * 100) + "%" : ""
                color: UI.textDim; font.pixelSize: UI.px(11)
                MouseArea { anchors.fill: parent; onClicked: browser.view.zoomFactor = 1; cursorShape: Qt.PointingHandCursor }
            }
            IconButton {
                iconName: browser.isBookmarked(browser.currentUrl) ? "star-filled" : "star"
                tip: "Bookmark (Ctrl+D)"; enabled: browser.currentUrl !== ""
                onClicked: browser.toggleBookmark()
            }
            AbstractButton {
                id: shield
                visible: AdBlocker !== null
                implicitHeight: UI.px(32)
                implicitWidth: shieldRow.implicitWidth + 14
                hoverEnabled: true
                onClicked: browser.panel = browser.panel === "settings" ? "" : "settings"
                background: Rectangle { radius: UI.radiusSmall; color: shield.hovered ? UI.hover : "transparent" }
                contentItem: Row {
                    id: shieldRow
                    spacing: 5
                    leftPadding: 7
                    Icon { name: AdBlocker && AdBlocker.enabled ? "shield-on" : "shield"; size: UI.px(18); opacity: AdBlocker && AdBlocker.enabled ? 1 : 0.45; anchors.verticalCenter: parent.verticalCenter }
                    Text { font.weight: UI.textWeight; text: AdBlocker && AdBlocker.enabled ? AdBlocker.blockedCount : "off"; color: UI.textDim; font.pixelSize: UI.px(11); anchors.verticalCenter: parent.verticalCenter }
                }
                GTip { visible: shield.hovered; text: AdBlocker && AdBlocker.enabled ? "Shields up: " + AdBlocker.blockedCount + " ads and trackers blocked this session" : "Shields down" }
            }
            IconButton {
                id: dlButton
                iconName: "download"
                tip: "Downloads (Ctrl+J)"
                active: browser.panel === "downloads"
                onClicked: browser.panel = browser.panel === "downloads" ? "" : "downloads"
                Rectangle {
                    visible: browser.wm.activeDownloads > 0
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3
                    width: 8; height: 8; radius: 4; color: UI.accent
                }
            }
            IconButton {
                id: extButton
                visible: Extensions.experimental
                iconName: "puzzle"
                tip: "Extensions"
                onClicked: {
                    var items = []
                    var list = (browser.extOn ? browser.ext.items : [])
                    list.forEach(function (e) {
                        items.push({ text: e.name + (e.enabled ? "" : "  (off)"), icon: "puzzle", enabled: e.enabled && e.popup !== "",
                                     action: function () { extPopup.openFor(e) } })
                    })
                    if (!list.length) items.push({ text: browser.extOn ? (Extensions.busy ? "Installing…" : "No extensions yet") : "Extensions unavailable", icon: "info", enabled: false })
                    if (browser.extOn && !browser.extInstalled("ddkjiahejlhfcafbddmgiahcphecmpfh"))
                        items.push({ text: "Install uBlock Origin Lite", icon: "shield-on", action: function () { Extensions.prepareFromStore("ddkjiahejlhfcafbddmgiahcphecmpfh") } })
                    items.push({ separator: true })
                    items.push({ text: "Manage extensions", icon: "settings", action: function () { browser.panel = "extensions" } })
                    items.push({ text: "Chrome Web Store", icon: "external", action: function () { browser.newTab("https://chromewebstore.google.com/category/extensions", false) } })
                    menu.menuWidth = 260
                    menu.show(extButton, 0, extButton.height, items)
                }
            }
            IconButton {
                id: moreButton
                iconName: "more"
                tip: "Menu"
                onClicked: menu.show(moreButton, 0, moreButton.height, [
                    { text: "New tab", icon: "plus", shortcut: "Ctrl+T", action: function () { browser.newTab("", false) } },
                    { text: "Reopen closed tab", icon: "history", shortcut: "Ctrl+Shift+T", enabled: browser.closedTabs.length > 0, action: browser.reopenClosed },
                    { separator: true },
                    { text: "Find in page…", icon: "search", shortcut: "Ctrl+F", enabled: browser.view !== null, action: function () { findBar.visible = true; findField.forceActiveFocus() } },
                    { text: "Zoom in", icon: "zoom-in", shortcut: "Ctrl++", enabled: browser.view !== null, action: function () { browser.zoomBy(0.1) } },
                    { text: "Zoom out", icon: "zoom-out", shortcut: "Ctrl+-", enabled: browser.view !== null, action: function () { browser.zoomBy(-0.1) } },
                    { separator: true },
                    { text: "History", icon: "history", shortcut: "Ctrl+H", action: function () { browser.panel = "history" } },
                    { text: "Downloads", icon: "download", shortcut: "Ctrl+J", action: function () { browser.panel = "downloads" } },
                    { text: "Developer tools", icon: "devtools", shortcut: "F12", visible: browser.devtoolsAvailable, enabled: browser.view !== null, action: browser.toggleDevtools },
                    { separator: true },
                    { text: "Extensions", icon: "puzzle", visible: Extensions.allowed, action: function () { browser.panel = "extensions" } },
                    { text: "Shields & settings", icon: "settings", action: function () { browser.panel = "settings" } }
                ])
            }
        }

        // ======================================================== bookmarks bar
        Flow {
            visible: !browser.fullScreen && browser.bookmarks.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 4
            spacing: 2
            clip: true
            Repeater {
                model: browser.bookmarks
                delegate: AbstractButton {
                    id: bm
                    implicitHeight: UI.px(26)
                    implicitWidth: Math.min(UI.px(170), bmRow.implicitWidth + 16)
                    hoverEnabled: true
                    onClicked: browser.go(modelData.url)
                    background: Rectangle { radius: UI.radiusSmall; color: bm.hovered ? UI.hover : "transparent" }
                    contentItem: Row {
                        id: bmRow
                        leftPadding: 6
                        spacing: 6
                        FaviconChip {
                            id: bmIcon
                            size: UI.px(13)
                            anchors.verticalCenter: parent.verticalCenter
                            source: browser.iconRev >= 0 ? Web.favicon(modelData.url) : ""
                            visible: ready
                        }
                        Icon { visible: !bmIcon.visible; name: "bookmark"; size: UI.px(13); anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
                        Text { font.weight: UI.textWeight; text: modelData.title; color: UI.textDim; font.pixelSize: UI.px(11.5); elide: Text.ElideRight; width: Math.min(implicitWidth, UI.px(130)); anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        onClicked: function (mouse) {
                            var url = modelData.url
                            if (mouse.button === Qt.MiddleButton) { browser.newTab(url, true); return }
                            menu.show(bm, mouse.x, mouse.y, [
                                { text: "Open in new tab", icon: "plus", action: function () { browser.newTab(url, false) } },
                                { text: "Remove bookmark", icon: "trash", danger: true, action: function () { browser.removeBookmark(url) } }
                            ])
                        }
                    }
                }
            }
        }

        // ======================================================== permission prompt
        Rectangle {
            visible: browser.permission !== null && !browser.fullScreen
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(46)
            color: UI.accentFaint
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                Icon { name: "privacy"; size: UI.px(18) }
                Text {
                    font.weight: UI.textWeight
                    Layout.fillWidth: true
                    text: browser.permission ? browser.prettyHost(browser.permission.origin) + " wants " + browser.permission.label : ""
                    color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideRight
                }
                GButton { text: "Block"; onClicked: browser.answerPermission(false) }
                GButton { text: "Allow"; kind: "primary"; onClicked: browser.answerPermission(true) }
            }
        }

        // ======================================================== Chrome Web Store install bar
        Rectangle {
            readonly property string storeId: Extensions.allowed ? Extensions.storeId(browser.currentUrl) : ""
            visible: storeId !== "" && !browser.fullScreen
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(46)
            color: UI.accentFaint
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                Icon { name: "puzzle"; size: UI.px(18) }
                Text {
                    font.weight: UI.textWeight
                    Layout.fillWidth: true
                    text: browser.extOn ? "Install this extension in AeroBrowser" : (Extensions.experimental ? browser.extStatus : "AeroBrowser can run Chrome extensions (experimental) - switch them on in settings")
                    color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideRight
                }
                GButton {
                    visible: !Extensions.experimental
                    text: "Extension settings"
                    onClicked: browser.panel = "settings"
                }
                GButton {
                    visible: Extensions.experimental
                    readonly property bool have: browser.extInstalled(parent.parent.storeId) && (browser.extOn ? browser.ext.items : []).length >= 0
                    text: have ? "Installed" : (Extensions.busy ? "Installing…" : "Add to AeroBrowser")
                    kind: have ? "normal" : "primary"
                    enabled: browser.extOn && !Extensions.busy && !have
                    onClicked: Extensions.prepareFromStore(parent.parent.storeId)
                }
            }
        }

        // ======================================================== find bar
        Rectangle {
            id: findBar
            visible: false
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(44)
            color: Qt.rgba(0, 0, 0, 0.18)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 6
                GTextField {
                    id: findField
                    Layout.preferredWidth: UI.px(240)
                    leading: "search"
                    placeholderText: "Find in page"
                    onTextChanged: browser.runFind(true)
                    onAccepted: browser.runFind(true)
                    Keys.onEscapePressed: browser.stopFind()
                }
                Text {
                    font.weight: UI.textWeight
                    text: findField.text === "" ? "" : (browser.findMatches > 0 ? browser.findActive + " of " + browser.findMatches : "No matches")
                    color: browser.findMatches > 0 || findField.text === "" ? UI.textDim : UI.warning
                    font.pixelSize: UI.px(12)
                }
                IconButton { iconName: "chevron-up"; tip: "Previous (Shift+Enter)"; onClicked: browser.runFind(false) }
                IconButton { iconName: "chevron-down"; tip: "Next (Enter)"; onClicked: browser.runFind(true) }
                CheckBox {
                    id: findCase
                    text: "Match case"
                    onToggled: browser.runFind(true)
                    contentItem: Text { font.weight: UI.textWeight; text: findCase.text; color: UI.text; leftPadding: findCase.indicator.width + 4; verticalAlignment: Text.AlignVCenter; font.pixelSize: UI.px(12) }
                }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; onClicked: browser.stopFind() }
            }
        }

        // ======================================================== pages (+ devtools)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true          // nothing inside the page area may paint over the toolbar

                Repeater {
                    id: tabRepeater
                    model: tabs
                    delegate: Item {
                        id: page
                        anchors.fill: parent
                        visible: index === browser.current
                        readonly property bool isCurrent: index === browser.current
                        readonly property var web: loader.item
                        readonly property int tabIndex: index
                        property bool crashed: false
                        property bool cosmeticDone: false
                        property string errorMessage: ""
                        Timer {   // speed-dial thumbnail: capture the page once it has settled
                            id: thumbTimer
                            interval: 1800
                            onTriggered: {
                                var v = page.web
                                if (!v || v.loading || !page.isCurrent || browser.fullScreen || !browser.visible) return
                                var u = v.url.toString(), target = Web.thumbnailTarget(u)
                                if (!target) return
                                v.grabToImage(function (result) { if (result.saveToFile(target)) Web.thumbnailSaved(u, target) }, Qt.size(480, 300))
                            }
                        }
                        property string errorUrl: ""
                        property string prevSnap: ""

                        Loader {
                            id: loader
                            anchors.fill: parent
                            active: model.url !== ""
                            sourceComponent: WebEngineView {
                                id: webView
                                audioMuted: Prefs.muted || model.muted
                                // memory/CPU saver: background tabs are frozen (they resume instantly)
                                // (Qt: a page inspected by DevTools must stay Active, so nothing freezes while they're open)
                                lifecycleState: page.isCurrent || recentlyAudible || browser.devtoolsOpen ? 0 : (recommendedState >= 1 ? 1 : 0)
                                settings.fullScreenSupportEnabled: true
                                settings.pluginsEnabled: true
                                settings.pdfViewerEnabled: true
                                settings.focusOnNavigationEnabled: true
                                settings.scrollAnimatorEnabled: true
                                settings.dnsPrefetchEnabled: true
                                settings.javascriptCanAccessClipboard: true
                                Component.onCompleted: {
                                    if (BrowserProfile) profile = BrowserProfile   // persistent profile with ad blocking
                                    url = model.url
                                }
                                onUrlChanged: {
                                    var u = url.toString()
                                    if (u && u !== model.url) tabs.setProperty(page.tabIndex, "url", u)
                                    if (page.isCurrent) browser.updateAddress()
                                }
                                onTitleChanged: {
                                    tabs.setProperty(page.tabIndex, "title", title || browser.prettyHost(url))
                                    Web.setTitle(url.toString(), title)
                                    if (page.isCurrent) browser.updateAddress()
                                }
                                onIconChanged: tabs.setProperty(page.tabIndex, "icon", icon.toString())
                                onRecentlyAudibleChanged: function () { tabs.setProperty(page.tabIndex, "audible", webView.recentlyAudible) }
                                onLoadProgressChanged: if (loadProgress > 35 && !page.cosmeticDone) { page.cosmeticDone = true; browser.injectCosmetic(webView) }
                                onLoadingChanged: function (info) {
                                    tabs.setProperty(page.tabIndex, "loading", loading)
                                    // status: 0 started, 1 stopped, 2 succeeded, 3 failed (stable across Qt 6 versions)
                                    if (info.status === 0) { page.cosmeticDone = false; page.crashed = false }
                                    else if (info.status === 2) {
                                        page.errorMessage = ""
                                        thumbTimer.restart()
                                        Web.addVisit(url.toString(), title)
                                        if (!page.cosmeticDone) { page.cosmeticDone = true; browser.injectCosmetic(webView) }
                                    } else if (info.status === 3 && info.errorCode !== -3 /* net::ERR_ABORTED */) {
                                        page.errorMessage = info.errorString
                                        page.errorUrl = info.url.toString()
                                    }
                                }
                                onNewWindowRequested: function (request) { browser.newTab(request.requestedUrl.toString(), false) }
                                onFullScreenRequested: function (request) {
                                    request.accept()
                                    browser.fullScreen = request.toggleOn
                                    if (request.toggleOn)
                                        browser.wm.enterFullscreen(browser.hostWindow, function () { webView.triggerWebAction(WebEngineView.ExitFullScreen) })
                                    else browser.wm.exitFullscreen(browser.hostWindow)
                                }
                                onRenderProcessTerminated: function (terminationStatus, exitCode) { if (terminationStatus !== 0) page.crashed = true }

                                // version-dependent signals: ignored where this Qt doesn't have them
                                Connections {
                                    target: webView
                                    ignoreUnknownSignals: true
                                    function onPermissionRequested(perm) {   // Qt 6.8+
                                        browser.permission = { legacy: false, obj: perm, origin: perm.origin.toString(), label: browser.permissionLabel(perm.permissionType, false) }
                                    }
                                    function onFeaturePermissionRequested(securityOrigin, feature) {   // Qt < 6.8
                                        browser.permission = { legacy: true, view: webView, origin: securityOrigin.toString(), feature: feature, label: browser.permissionLabel(feature, true) }
                                    }
                                    function onFindTextFinished(result) {
                                        browser.findMatches = result.numberOfMatches
                                        browser.findActive = result.activeMatch
                                    }
                                }
                            }
                        }

                        // ---------------------------------- error & crash pages
                        Rectangle {
                            visible: page.errorMessage !== "" || page.crashed
                            anchors.fill: parent
                            color: "#10141d"
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                width: Math.min(parent.width - 60, 460)
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: page.crashed ? "error-color" : "wifi"; size: 64; opacity: 0.8 }
                                Text { elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: page.crashed ? "This tab crashed" : "This page couldn't load"; color: UI.text; font.pixelSize: UI.px(18); font.weight: Font.DemiBold }
                                Text { font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; text: page.errorUrl; visible: !page.crashed; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
                                Text { font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: page.crashed ? "Something went wrong while displaying this page." : page.errorMessage; color: UI.textDim; font.pixelSize: UI.px(13) }
                                GButton { anchors.horizontalCenter: parent.horizontalCenter; text: "Reload"; iconName: "refresh"; kind: "primary"; onClicked: { page.crashed = false; page.errorMessage = ""; if (page.web) page.web.reload() } }
                            }
                        }

                        // ---------------------------------- new-tab page
                        Flickable {
                            id: ntp
                            visible: model.url === ""
                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: ntpCol.height + UI.px(64)
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: GScrollBar {}
                            Column {
                                id: ntpCol
                                // centered while it fits, top-anchored (and scrollable) once it doesn't
                                x: (ntp.width - width) / 2
                                y: Math.max(UI.px(32), (ntp.height - height) / 2 - UI.px(24))
                                spacing: 22
                                width: Math.min(ntp.width - 60, UI.px(720))
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: UI.greeting() + ", " + Prefs.userName
                                    color: UI.text
                                    font.pixelSize: UI.px(28)
                                    font.weight: Font.Light
                                }
                                GTextField {
                                    id: ntpSearch
                                    width: parent.width
                                    height: UI.px(48)
                                    radiusOverride: 24
                                    leading: "search"
                                    placeholderText: "Search " + Web.searchEngine + " or type an address"
                                    font.pixelSize: UI.px(15)
                                    onTextEdited: { browser.omni = ntpSearch; browser.refreshSuggestions(text) }
                                    onAccepted: { var t = text; text = ""; browser.acceptOmni(t) }
                                    onActiveFocusChanged: { if (activeFocus) browser.omni = ntpSearch; else if (browser.omni === ntpSearch) browser.closeSuggestions() }
                                    Keys.onPressed: function (event) { browser.omniKey(event) }
                                    Keys.onEscapePressed: { text = ""; browser.closeSuggestions() }
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8
                                    visible: AdBlocker !== null && AdBlocker.enabled
                                    Icon { name: "shield-on"; size: UI.px(16); anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: AdBlocker ? AdBlocker.blockedCount + " ads and trackers blocked" + (AdBlocker.ruleCount ? "  ·  " + AdBlocker.ruleCount.toLocaleString(Qt.locale(), "f", 0) + " rules (uBlock Origin + EasyList)" : "") : ""
                                        color: UI.textDim; font.pixelSize: UI.px(12); anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Grid {
                                    id: dialGrid
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    columns: Math.max(2, Math.min(4, Math.floor((ntp.width - 40) / UI.px(166))))
                                    spacing: 14
                                    Repeater {
                                        model: Web.shortcuts.concat([{ add: true, title: "Add shortcut", url: "" }])
                                        delegate: MouseArea {
                                            id: dial
                                            width: UI.px(152); height: UI.px(124)
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            cursorShape: Qt.PointingHandCursor
                                            readonly property bool isAdd: modelData.add === true
                                            readonly property string thumbUrl: browser.iconRev >= 0 && !isAdd ? Web.thumbnail(modelData.url) : ""
                                            readonly property string iconUrl: browser.iconRev >= 0 && !isAdd ? Web.favicon(modelData.url) : ""
                                            onClicked: function (mouse) {
                                                if (isAdd) { browser.addShortcutDialog(); return }
                                                if (mouse.button === Qt.MiddleButton) { browser.newTab(modelData.url, true); return }
                                                if (mouse.button === Qt.RightButton) { browser.shortcutMenu(dial, mouse.x, mouse.y, modelData); return }
                                                browser.go(modelData.url)
                                            }
                                            Rectangle {
                                                id: card
                                                anchors.fill: parent
                                                radius: UI.radiusLarge
                                                color: dial.containsMouse ? UI.cardStrong : UI.card
                                                border.color: dial.containsMouse ? UI.alpha(UI.accent, 0.55) : UI.border
                                                clip: true
                                                scale: dial.pressed ? 0.97 : 1
                                                Behavior on scale { NumberAnimation { duration: UI.dur(90) } }
                                                // page preview (captured when you visited the site)
                                                Item {
                                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                                    anchors.margins: 1
                                                    height: parent.height - UI.px(34)
                                                    clip: true
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: !preview.visible
                                                        gradient: Gradient {
                                                            GradientStop { position: 0; color: dial.isAdd ? "transparent" : Qt.rgba(1, 1, 1, 0.06) }
                                                            GradientStop { position: 1; color: "transparent" }
                                                        }
                                                    }
                                                    Image {
                                                        id: preview
                                                        anchors.fill: parent
                                                        source: dial.thumbUrl
                                                        visible: status === Image.Ready
                                                        fillMode: Image.PreserveAspectCrop
                                                        verticalAlignment: Image.AlignTop
                                                        asynchronous: true
                                                        sourceSize.width: 320
                                                    }
                                                    Rectangle {   // no preview yet: the site's icon, big
                                                        visible: !preview.visible && !dial.isAdd
                                                        anchors.centerIn: parent
                                                        width: UI.px(46); height: width; radius: UI.radius
                                                        color: Qt.rgba(1, 1, 1, 0.94)
                                                        Image {
                                                            id: bigIcon
                                                            anchors.centerIn: parent
                                                            width: UI.px(28); height: width
                                                            source: dial.iconUrl
                                                            sourceSize: Qt.size(64, 64)
                                                            visible: status === Image.Ready
                                                        }
                                                        Text { visible: !bigIcon.visible; anchors.centerIn: parent; text: browser.prettyHost(modelData.url).charAt(0).toUpperCase(); color: "#1e293b"; font.pixelSize: UI.px(20); font.bold: true }
                                                    }
                                                    Icon { visible: dial.isAdd; anchors.centerIn: parent; name: "plus"; size: UI.px(30); opacity: 0.8 }
                                                }
                                                Row {   // favicon + title
                                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                                    anchors.leftMargin: 10; anchors.rightMargin: 8; anchors.bottomMargin: 9
                                                    spacing: 7
                                                    FaviconChip {
                                                        id: smallIcon
                                                        size: UI.px(14)
                                                        visible: !dial.isAdd && ready
                                                        source: dial.iconUrl
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Text {
                                                        width: parent.width - (smallIcon.visible ? UI.px(24) : 0)
                                                        text: modelData.title || browser.prettyHost(modelData.url)
                                                        color: dial.isAdd ? UI.textDim : UI.text
                                                        font.pixelSize: UI.px(12)
                                                        elide: Text.ElideRight
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                            }
                                            IconButton {   // quick remove
                                                visible: dial.containsMouse && !dial.isAdd
                                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                                                iconName: "close"; size: 24; glyphSize: 10
                                                tip: "Remove shortcut"
                                                onClicked: Web.removeShortcut(modelData.url)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // omnibox suggestions (address bar or new-tab search box)
                Rectangle {
                    id: sugBox
                    readonly property var anchorItem: browser.omni
                    readonly property point at: {
                        var n = browser.suggestions.length   // re-evaluate when the list changes
                        return anchorItem ? anchorItem.mapToItem(pages, 0, anchorItem === address ? 0 : anchorItem.height) : Qt.point(0, 0)
                    }
                    visible: browser.suggestions.length > 0 && anchorItem !== null && anchorItem.activeFocus
                    x: at.x
                    y: anchorItem === address ? 2 : at.y + 6
                    z: 50
                    width: anchorItem ? anchorItem.width : 300
                    height: sugCol.implicitHeight + 10
                    radius: UI.radius
                    color: "#161b27"
                    border.color: UI.borderStrong
                    Column {
                        id: sugCol
                        x: 5; y: 5
                        width: parent.width - 10
                        Repeater {
                            model: browser.suggestions
                            delegate: Rectangle {
                                width: sugCol.width
                                height: UI.px(36)
                                radius: UI.radiusSmall
                                color: index === browser.suggestIndex ? UI.accentSoft : (sugMouse.containsMouse ? UI.hover : "transparent")
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Item {
                                        width: UI.px(16); height: width
                                        anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            id: sugIcon
                                            anchors.fill: parent
                                            visible: (modelData.kind === "history" || modelData.kind === "bookmark" || modelData.kind === "go") && status === Image.Ready
                                            source: modelData.kind !== "search" && browser.iconRev >= 0 ? Web.favicon(modelData.url) : ""
                                            sourceSize: Qt.size(32, 32)
                                        }
                                        Icon {
                                            anchors.fill: parent
                                            visible: !sugIcon.visible
                                            name: ({ search: "search", go: "globe", bookmark: "star-filled", history: "history" })[modelData.kind] || "search"
                                            size: UI.px(15)
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: sugCol.width - UI.px(52)
                                        textFormat: Text.PlainText
                                        text: modelData.kind === "search" ? modelData.title
                                              : (modelData.kind === "go" ? modelData.url : modelData.title + "  —  " + browser.prettyHost(modelData.url))
                                        color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    elide: Text.ElideRight
                                    visible: modelData.kind === "search" && index === browser.suggestions.findIndex(function (x) { return x.kind === "search" })
                                    anchors.right: parent.right; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Web.searchEngine + " search"
                                    color: UI.textFaint; font.pixelSize: UI.px(11)
                                }
                                MouseArea { id: sugMouse; anchors.fill: parent; hoverEnabled: true; onPressed: browser.go(modelData.url) }
                            }
                        }
                    }
                }

                // ---------------------------------------------- side panels
                Rectangle {
                    visible: browser.panel !== ""
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.min(UI.px(380), parent.width)
                    z: 40
                    color: "#141925"
                    border.color: UI.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                text: ({ downloads: "Downloads", history: "History", settings: "Shields & settings", extensions: "Extensions" })[browser.panel] || ""
                                color: UI.text; font.pixelSize: UI.px(16); font.weight: Font.DemiBold
                            }
                            IconButton { iconName: "close"; onClicked: browser.panel = "" }
                        }

                        // downloads
                        ListView {
                            id: dlList
                            visible: browser.panel === "downloads"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            model: browser.panel === "downloads" ? browser.wm.downloads : []
                            ScrollBar.vertical: GScrollBar {}
                            delegate: Rectangle {
                                width: dlList.width
                                height: dlCol.implicitHeight + 18
                                radius: UI.radius
                                color: UI.card
                                id: dlItem
                                readonly property var d: modelData
                                readonly property bool done: d.isFinished && d.state === WebEngineDownloadRequest.DownloadCompleted
                                Column {
                                    id: dlCol
                                    x: 12; y: 9
                                    width: parent.width - 24
                                    spacing: 5
                                    Row {
                                        spacing: 10
                                        width: parent.width
                                        Icon { name: Storage.iconFor(dlItem.d.downloadFileName); size: UI.px(28) }
                                        Column {
                                            width: parent.width - UI.px(40)
                                            Text { font.weight: UI.textWeight; width: parent.width; text: dlItem.d.downloadFileName; color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideMiddle }
                                            Text {
                                                elide: Text.ElideRight
                                                font.weight: UI.textWeight
                                                width: parent.width
                                                color: UI.textFaint; font.pixelSize: UI.px(11)
                                                text: {
                                                    var d = dlItem.d
                                                    if (d.state === WebEngineDownloadRequest.DownloadCompleted) return UI.fmtSize(d.totalBytes) + "  ·  Done"
                                                    if (d.state === WebEngineDownloadRequest.DownloadCancelled) return "Cancelled"
                                                    if (d.state === WebEngineDownloadRequest.DownloadInterrupted) return "Failed: " + d.interruptReasonString
                                                    return UI.fmtSize(d.receivedBytes) + (d.totalBytes > 0 ? " of " + UI.fmtSize(d.totalBytes) : "") + (d.isPaused ? "  ·  Paused" : "")
                                                }
                                            }
                                        }
                                    }
                                    UsageBar {
                                        visible: !dlItem.d.isFinished
                                        width: parent.width
                                        value: dlItem.d.totalBytes > 0 ? dlItem.d.receivedBytes / dlItem.d.totalBytes * 100 : 0
                                    }
                                    Row {
                                        spacing: 6
                                        GButton { visible: dlItem.done; text: "Open"; kind: "primary"; onClicked: browser.wm.openPath("/Downloads/" + dlItem.d.downloadFileName) }
                                        GButton { visible: dlItem.done; text: "Show in Files"; onClicked: browser.wm.openApp("AeroExplorer", { initialPath: "/Downloads" }) }
                                        GButton { visible: !dlItem.d.isFinished; text: dlItem.d.isPaused ? "Resume" : "Pause"; onClicked: dlItem.d.isPaused ? dlItem.d.resume() : dlItem.d.pause() }
                                        GButton { visible: !dlItem.d.isFinished; text: "Cancel"; kind: "danger"; onClicked: dlItem.d.cancel() }
                                    }
                                }
                            }
                            Text { font.weight: UI.textWeight; visible: dlList.count === 0; anchors.centerIn: parent; text: "No downloads yet"; color: UI.textFaint; font.pixelSize: UI.px(12) }
                        }

                        // history
                        GTextField {
                            id: histSearch
                            visible: browser.panel === "history"
                            Layout.fillWidth: true
                            leading: "search"
                            placeholderText: "Search history"
                        }
                        ListView {
                            id: histList
                            visible: browser.panel === "history"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            reuseItems: true
                            property int rev: 0
                            Connections { target: Browser; function onHistoryChanged() { histList.rev++ } }
                            model: {
                                var r = rev
                                if (browser.panel !== "history") return []
                                var q = histSearch.text.toLowerCase()
                                var all = Web.recent(500)
                                return q ? all.filter(function (e) { return e.url.toLowerCase().indexOf(q) >= 0 || e.title.toLowerCase().indexOf(q) >= 0 }) : all
                            }
                            ScrollBar.vertical: GScrollBar {}
                            delegate: Rectangle {
                                width: histList.width
                                height: UI.px(44)
                                radius: UI.radiusSmall
                                color: hMouse.containsMouse ? UI.hover : "transparent"
                                MouseArea { id: hMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: browser.go(modelData.url) }
                                Column {
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - UI.px(50)
                                    Text { font.weight: UI.textWeight; width: parent.width; text: modelData.title || browser.prettyHost(modelData.url); color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideRight }
                                    Text { font.weight: UI.textWeight; width: parent.width; text: browser.prettyHost(modelData.url) + "  ·  " + UI.fmtDate(modelData.last); color: UI.textFaint; font.pixelSize: UI.px(10.5); elide: Text.ElideRight }
                                }
                                IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; iconName: "close"; size: 26; glyphSize: 10; tip: "Remove"; onClicked: Web.removeHistory(modelData.url) }
                            }
                            Text { font.weight: UI.textWeight; visible: histList.count === 0; anchors.centerIn: parent; text: "Nothing here yet"; color: UI.textFaint; font.pixelSize: UI.px(12) }
                        }
                        GButton { visible: browser.panel === "history"; text: "Clear all history"; iconName: "trash"; kind: "danger"; onClicked: Web.clearHistory() }

                        // extensions
                        ColumnLayout {
                            visible: browser.panel === "extensions"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8
                            Text {
                                font.weight: UI.textWeight
                                visible: !browser.extOn
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: browser.extStatus
                                color: UI.warning; font.pixelSize: UI.px(12)
                            }
                            ListView {
                                id: extList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
                                model: (browser.extOn ? browser.ext.items : [])
                                delegate: Rectangle {
                                    width: extList.width
                                    height: extCol.implicitHeight + 18
                                    radius: UI.radius
                                    color: UI.card
                                    border.color: modelData.error ? UI.alpha(UI.danger, 0.5) : UI.border
                                    RowLayout {
                                        id: extCol
                                        x: 12; y: 9
                                        width: parent.width - 24
                                        spacing: 10
                                        Icon { name: "puzzle"; size: UI.px(26); opacity: modelData.enabled ? 1 : 0.4 }
                                        Column {
                                            Layout.fillWidth: true
                                            Text { font.weight: UI.textWeight; width: parent.width; text: modelData.name; color: UI.text; font.pixelSize: UI.px(13); elide: Text.ElideRight }
                                            Text { font.weight: UI.textWeight; width: parent.width; text: modelData.error || modelData.description; color: modelData.error ? UI.danger : UI.textFaint; font.pixelSize: UI.px(11); wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                                        }
                                        GToggle { checked: modelData.enabled; onToggled: browser.ext.setEnabled(modelData.id, checked) }
                                        IconButton { iconName: "trash"; tip: "Remove"; onClicked: browser.ext.remove(modelData.id) }
                                    }
                                }
                                Text { font.weight: UI.textWeight; visible: extList.count === 0 && browser.extOn; anchors.centerIn: parent; text: "No extensions installed"; color: UI.textFaint; font.pixelSize: UI.px(12) }
                            }
                            GButton { Layout.fillWidth: true; text: "Get extensions from the Chrome Web Store"; iconName: "external"; kind: "primary"; onClicked: { browser.panel = ""; browser.newTab("https://chromewebstore.google.com/category/extensions", false) } }
                            RowLayout {
                                Layout.fillWidth: true
                                GButton { Layout.fillWidth: true; text: "Install .zip / .crx…"; enabled: browser.extOn; onClicked: extFileDialog.open() }
                                GButton { Layout.fillWidth: true; text: "Load unpacked…"; enabled: browser.extOn; onClicked: extFolderDialog.open() }
                            }
                        }

                        // shields & settings
                        Flickable {
                            visible: browser.panel === "settings"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: setCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            Column {
                                id: setCol
                                width: parent.width
                                spacing: 10
                                SettingRow {
                                    title: "Ad & tracker blocking"
                                    subtitle: AdBlocker ? (AdBlocker.ruleCount ? AdBlocker.ruleCount + " EasyList/EasyPrivacy rules" : "Built-in list (filter lists download in the background)") : "Unavailable"
                                    GToggle { enabled: AdBlocker !== null; checked: AdBlocker ? AdBlocker.enabled : false; onToggled: AdBlocker.setEnabled(checked) }
                                }
                                SettingRow {
                                    title: "Hide ad placeholders"
                                    subtitle: "Removes empty boxes left behind by blocked ads"
                                    GToggle { checked: browser.cosmeticOn; onToggled: Prefs.setValue("browser.cosmetic", checked) }
                                }
                                SettingRow {
                                    title: "Filter lists"
                                    subtitle: AdBlocker && AdBlocker.updating ? "Updating…" : (AdBlocker && AdBlocker.listsUpdated ? "Updated " + AdBlocker.listsUpdated : "Not downloaded yet")
                                    GButton { text: "Update now"; enabled: AdBlocker !== null && !AdBlocker.updating; onClicked: AdBlocker.updateLists() }
                                }
                                SettingRow {
                                    visible: Extensions.allowed
                                    title: "Chrome extensions (experimental)"
                                    subtitle: "Qt's extension support is a technology preview and has known bugs in Qt/PySide 6.10. If GlassOS ever stops unexpectedly while they're on, they switch off automatically. Shields keep blocking ads either way."
                                    GToggle { checked: Extensions.experimental; onToggled: Extensions.setExperimental(checked) }
                                }
                                SettingRow {
                                    title: "Search suggestions"
                                    subtitle: "Show " + Web.searchEngine + " suggestions while you type"
                                    GToggle { checked: Web.suggestionsEnabled; onToggled: Web.setSuggestionsEnabled(checked) }
                                }
                                SectionTitle { text: "Search engine" }
                                Flow {
                                    width: parent.width
                                    spacing: 6
                                    Repeater {
                                        model: Web.searchEngines
                                        GButton { text: modelData; kind: Web.searchEngine === modelData ? "primary" : "normal"; onClicked: Web.setSearchEngine(modelData) }
                                    }
                                }
                                SectionTitle { text: "Privacy" }
                                SettingRow {
                                    title: "Clear browsing data"
                                    subtitle: "History, cache and cookies (you'll be signed out of websites)"
                                    GButton { text: "Clear"; kind: "danger"; onClicked: { Web.clearBrowsingData(); browser.wm.notify("Browsing data cleared", "", "broom") } }
                                }
                                Text {
                                    font.weight: UI.textWeight
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    color: UI.textFaint
                                    font.pixelSize: UI.px(11)
                                    text: BrowserProfile ? "Your sessions are kept between restarts. Typed addresses use HTTPS by default." : "Running with a temporary profile: sessions end when GlassOS closes."
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { visible: browser.devtoolsOpen && !browser.fullScreen; Layout.fillHeight: true; Layout.preferredWidth: 1; color: UI.border }
            ColumnLayout {
                visible: browser.devtoolsOpen && !browser.fullScreen   // fullscreen video gets the whole screen
                Layout.fillHeight: true
                Layout.fillWidth: false
                // sized from the browser (outside this layout): sizing from the sibling page area
                // fed back into itself and the layout never settled (polish loop, heavy lag)
                Layout.preferredWidth: browser.devtoolsOpen && !browser.fullScreen ? Math.round(Math.max(UI.px(360), Math.min(browser.width * 0.38, browser.width - UI.px(320)))) : 0
                Layout.maximumWidth: browser.devtoolsOpen && !browser.fullScreen ? Layout.preferredWidth : 0
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: UI.px(32)
                    color: "#202124"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        Icon { name: "devtools"; size: UI.px(15) }
                        Text { elide: Text.ElideRight; font.weight: UI.textWeight; Layout.fillWidth: true; text: "Developer tools"; color: UI.textDim; font.pixelSize: UI.px(12) }
                        IconButton { iconName: "close"; size: 26; glyphSize: 10; tip: "Close developer tools (F12)"; onClicked: browser.closeDevtools() }
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    id: devtoolsLoader
                    active: browser.devtoolsOpen
                    sourceComponent: WebEngineView {
                        id: devtoolsView
                        // Must use the persistent profile: on Qt 6.10.1 DevTools in the default
                        // off-the-record profile crash the process (QTBUG-142247, extension data
                        // of off-the-record profiles). Profile first, then attach.
                        Component.onCompleted: {
                            profile = BrowserProfile
                            inspectedView = Qt.binding(function () { return browser.devtoolsOpen ? browser.view : null })
                        }
                        Component.onDestruction: inspectedView = null
                        onWindowCloseRequested: browser.closeDevtools()   // the X inside DevTools
                    }
                }
            }
        }
    }

    // Downloads go to /Downloads inside GlassOS (all browser windows share one list)
    Connections {
        target: browser.view ? browser.view.profile : null
        function onDownloadRequested(download) {
            if (download.state !== WebEngineDownloadRequest.DownloadRequested) return   // another window took it
            download.downloadDirectory = Storage.downloadsDir
            download.accept()
            browser.wm.addDownload(download)
            browser.panel = "downloads"
        }
    }

    // extension toolbar popups (e.g. uBlock Origin's panel)
    Popup {
        id: extPopup
        property string url: ""
        function openFor(e) { url = e.popup; var p = extButton.mapToItem(null, 0, extButton.height); x = Math.max(6, p.x - width + extButton.width); y = p.y + 4; open() }
        parent: Overlay.overlay
        width: UI.px(380)
        height: UI.px(560)
        padding: 1
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#1b1f2a"; radius: UI.radiusSmall; border.color: UI.borderStrong }
        contentItem: Loader {
            active: extPopup.opened && extPopup.url !== ""
            sourceComponent: WebEngineView {
                Component.onCompleted: { if (BrowserProfile) profile = BrowserProfile; url = extPopup.url }
                onWindowCloseRequested: extPopup.close()
            }
        }
    }
    FileDialog {
        id: extFileDialog
        title: "Install an extension (.zip or .crx)"
        nameFilters: ["Chrome extensions (*.zip *.crx)"]
        onAccepted: Extensions.prepareFromFile(selectedFile.toString())
    }
    FolderDialog {
        id: extFolderDialog
        title: "Load an unpacked extension folder"
        onAccepted: Extensions.prepareFromFile(selectedFolder.toString())
    }
    Connections {
        target: Extensions
        function onMessage(title, body) { browser.wm.notify(title, body, "puzzle") }
    }

    GDialog { id: dialog }
    GMenu { id: menu }
}
