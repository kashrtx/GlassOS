// GlassOS shell: wallpaper, desktop, window manager, taskbar and overlays.
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "ui"
import "components"
import "js/Apps.js" as Apps

ApplicationWindow {
    id: root
    width: 1440
    height: 900
    minimumWidth: 800
    minimumHeight: 560
    visible: true
    title: "GlassOS"
    color: "#05070c"
    font.pixelSize: UI.px(13)
    font.weight: UI.textWeight

    property bool forceWindowed: LaunchArgs.windowed
    visibility: (!forceWindowed && Prefs.fullscreen) ? Window.FullScreen : Window.Windowed

    // ================================================================ state
    property var windows: []
    property var activeWindow: null
    property int topZ: 1
    property int cascade: 0
    property var hiddenByShowDesktop: []
    property var notificationHistory: []
    property int unreadCount: 0
    property real brightness: 100
    property bool allowQuit: false
    property var lastLaunch: ({})        // appId -> ms timestamp (double-click guard)
    property int workspace: 0             // virtual desktops 0..3
    readonly property int workspaceCount: 4
    property bool restoringSession: false
    property var fullscreenWindow: null
    property var fullscreenExit: null
    readonly property int maxWindows: 32  // each browser window is a full Chromium renderer

    // ======================================================== theme binding
    Binding { target: UI; property: "wm"; value: root }
    Binding { target: UI; property: "accent"; value: Prefs.accent }
    Binding { target: UI; property: "textScale"; value: Prefs.textScale }
    Binding { target: UI; property: "animations"; value: Prefs.animations }
    Binding { target: UI; property: "glass"; value: Prefs.glass }
    Binding { target: UI; property: "use24h"; value: Prefs.use24h }
    Binding { target: UI; property: "bold"; value: Prefs.boldText }
    Binding { target: UI; property: "tempUnit"; value: Prefs.weatherUnit === "F" ? "F" : "C" }
    Binding { target: UI; property: "blurUrl"; value: Prefs.blurredWallpaperUrl }
    Binding { target: UI; property: "sceneWidth"; value: root.width }
    Binding { target: UI; property: "sceneHeight"; value: root.height }
    Binding { target: UI; property: "monoFont"; value: System.monoFont }

    // ======================================================= window manager
    function openApp(appId, props) {
        var info = Apps.get(appId)
        if (!info) { notify("Can't open app", "Unknown app “" + appId + "”", "warning-color"); return null }
        props = props || {}

        // reuse an existing window when it makes sense
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (w.appId !== appId || w.closing) continue
            if (info.single || (props.filePath && w.app && w.app.filePath === props.filePath)) {
                focusWindow(w)
                if (w.app && typeof w.app.handleArgs === "function") w.app.handleArgs(props)
                return w
            }
        }

        // an accidental double-click shouldn't open two copies
        var now = Date.now()
        if (!restoringSession && now - (lastLaunch[appId] || 0) < 400 && !props.filePath && !props.initialPath && !props.initialUrl) return null
        lastLaunch[appId] = now
        if (windows.length >= maxWindows) {
            notify("Too many windows", "Close a few windows before opening more (limit " + maxWindows + ").", "tab")
            return null
        }

        var source = (info.needsWeb && !HasWebEngine) ? "apps/BrowserUnavailable.qml"
                   : (info.needsMedia && !HasMultimedia) ? "apps/MediaUnavailable.qml" : info.source
        var W = Math.max(windowLayer.width, 640), H = Math.max(windowLayer.height, 400)
        var ww = Math.min(info.w, W - 40), wh = Math.min(info.h, H - 40)
        var off = (cascade++ % 8) * 28
        var wx = Math.max(0, Math.round((W - ww) / 2) - 100 + off)
        var wy = Math.max(0, Math.round((H - wh) / 2) - 70 + off)
        if (wx + ww > W) wx = Math.max(0, W - ww)
        if (wy + wh > H) wy = Math.max(0, H - wh)

        var win = windowComponent.createObject(windowLayer, {
            appId: appId, title: info.name, icon: info.icon,
            x: wx, y: wy, width: ww, height: wh,
            minW: info.minW || 320, minH: info.minH || 220, workspace: workspace,
            appSource: Qt.resolvedUrl(source), appProps: props
        })
        if (!win) { notify("Can't open " + info.name, "The window could not be created.", "warning-color"); return null }
        win.focusRequested.connect(function () { root.focusWindow(win) })
        win.closed.connect(function () { root.removeWindow(win) })
        win.snapHint.connect(function (zone) { root.showSnapHint(win, zone) })
        windows = windows.concat([win])
        focusWindow(win)
        return win
    }

    function openPath(path) {
        if (!Storage.exists(path)) { notify("Not found", path, "warning-color"); return }
        if (Storage.isDir(path)) { openApp("AeroExplorer", { initialPath: path }); return }
        var kind = Storage.kindOf(path)
        var media = kind === "pdf" || kind === "audio" || kind === "video"
        if (kind === "image") openApp("ImageViewer", { filePath: path })
        else if ((kind === "audio" || kind === "video" || kind === "playlist") && HasMultimedia) openApp("MediaPlayer", { filePath: path })
        else if (media && HasWebEngine) openApp("AeroBrowser", { initialUrl: Storage.fileUrl(path) })
        else if (kind === "archive" && Storage.canExtract(path)) {
            openApp("AeroExplorer", { initialPath: Storage.parentOf(path), initialArchive: path })
            return
        }
        else if (media || kind === "archive") {
            notify("No app for this file", path.split("/").pop() + " can't be opened in GlassOS yet.", "info-color")
            return
        }
        else openApp("GlassPad", { filePath: path })
        rememberRecent(path)
    }

    function rememberRecent(path) {
        var list = UI.arr(Prefs.value("recent.files", [])).filter(function (p) { return typeof p === "string" && p !== path })
        list.unshift(path)
        Prefs.setValue("recent.files", list.slice(0, 12))
    }

    // ================================================= true fullscreen
    // A window covers the whole screen (taskbar hidden); Esc always gets you out.
    function enterFullscreen(win, onExit) {
        if (!win || win.closing) return
        if (fullscreenWindow && fullscreenWindow !== win) exitFullscreen(fullscreenWindow)
        fullscreenWindow = win
        fullscreenExit = onExit || null
        focusWindow(win)
        win.enterFullscreen()
        fsHint.show()
    }
    function exitFullscreen(win) {
        if (!fullscreenWindow || (win && win !== fullscreenWindow)) return
        var w = fullscreenWindow
        fullscreenWindow = null
        fullscreenExit = null
        fsForce.stop()
        w.exitFullscreen()
    }
    // Esc: ask the app to leave fullscreen (e.g. the web page), and force it if it doesn't
    function requestExitFullscreen() {
        if (!fullscreenWindow) return
        var cb = fullscreenExit
        if (cb) { try { cb() } catch (e) { console.warn("fullscreen exit:", e) } }
        if (fullscreenWindow) fsForce.restart()
    }
    Timer { id: fsForce; interval: 400; onTriggered: root.exitFullscreen(root.fullscreenWindow) }

    function focusWindow(win) {
        if (!win || win.closing) return
        if (fullscreenWindow && win !== fullscreenWindow) requestExitFullscreen()
        if (win.workspace !== workspace) switchWorkspace(win.workspace, true)
        if (win.minimized) win.restore()
        win.z = ++topZ
        activeWindow = win
        hiddenByShowDesktop = []
        win.takeFocus()
    }

    function topmost(except) {
        var best = null
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (w === except || w.minimized || w.closing || w.workspace !== workspace) continue
            if (!best || w.z > best.z) best = w
        }
        return best
    }

    function minimizeWindow(win) {
        if (!win) return
        win.minimize()
        if (activeWindow === win) {
            var next = topmost(win)
            if (next) focusWindow(next)
            else { activeWindow = null; desktop.forceActiveFocus() }
        }
    }

    function closeWindow(win) { if (win) win.requestClose() }

    function removeWindow(win) {
        if (fullscreenWindow === win) { fullscreenWindow = null; fullscreenExit = null }
        windows = windows.filter(function (w) { return w !== win })
        if (snapPreview.owner === win) showSnapHint(win, "")
        if (activeWindow === win) {
            var next = topmost(win)
            if (next) focusWindow(next)
            else { activeWindow = null; desktop.forceActiveFocus() }
        }
        win.destroy()
    }

    function showDesktop() {
        var shown = windows.filter(function (w) { return !w.minimized && w.workspace === workspace })
        if (shown.length > 0) {
            shown.forEach(function (w) { w.minimize() })
            activeWindow = null
            desktop.forceActiveFocus()
            hiddenByShowDesktop = shown
        } else if (hiddenByShowDesktop.length > 0) {
            var again = hiddenByShowDesktop.slice().sort(function (a, b) { return a.z - b.z })
            again.forEach(function (w) { if (windows.indexOf(w) >= 0) focusWindow(w) })
        }
    }

    function windowsByRecency() {
        return windows.filter(function (w) { return !w.closing && w.workspace === workspace }).sort(function (a, b) { return b.z - a.z })
    }

    function snapActive(dir) {
        var w = activeWindow
        if (!w) return
        // Windows-style: from a half, up/down goes to a quarter; from a quarter, sideways moves across
        var next = {
            left:  { "": "left", right: "", tr: "tl", br: "bl", max: "left", top: "tl", bottom: "bl" },
            right: { "": "right", left: "", tl: "tr", bl: "br", max: "right", top: "tr", bottom: "br" },
            up:    { "": "max", left: "tl", right: "tr", bl: "left", br: "right", bottom: "", tl: "tl", tr: "tr", max: "max" },
            down:  { left: "bl", right: "br", tl: "left", tr: "right", max: "", top: "", bl: "bl", br: "br" }
        }[dir]
        var z = next[w.snap]
        if (z === undefined) z = dir === "down" ? "min" : (dir === "up" ? "max" : dir)
        if (z === "min") { minimizeWindow(w); return }
        if (z === w.snap) return
        w.setSnap(z)
        if (z !== "" && z !== "max") offerSnapAssist(w, z)
    }

    function showSnapHint(win, zone) {
        if (zone === "") { snapPreview.owner = null; snapPreview.opacity = 0; return }
        var r = win.zoneRect(zone)
        var wasHidden = snapPreview.opacity === 0
        snapPreview.owner = win
        if (wasHidden) {   // grow out of the cursor area instead of flying in from the old spot
            snapPreview.animate = false
            snapPreview.x = r.x + r.width / 2 - 40; snapPreview.y = r.y + r.height / 2 - 40
            snapPreview.width = 80; snapPreview.height = 80
            snapPreview.animate = true
        }
        snapPreview.x = r.x + 8; snapPreview.y = r.y + 8
        snapPreview.width = r.width - 16; snapPreview.height = r.height - 16
        snapPreview.opacity = 1
    }

    // ================================================= file drag & drop
    // One shared drag "hotspot" item for the whole shell. Sources (Files, Desktop)
    // call begin/move/endFileDrag from their MouseArea; DropAreas anywhere in the
    // scene (other windows, desktop, folders, Recycle Bin) receive it through Qt's
    // normal drag machinery, so z-order and overlapping windows just work.
    readonly property alias fileDrag: fileDragItem

    function beginFileDrag(opts) {
        fileDragItem.paths = opts.paths || []
        fileDragItem.sourceDir = opts.sourceDir || ""
        fileDragItem.sourceKey = opts.sourceKey || ""
        fileDragItem.icon = opts.icon || "file-generic"
        fileDragItem.label = opts.label || ""
        fileDragItem.target = ""
        fileDragItem.copy = false
        fileDragItem.x = opts.x
        fileDragItem.y = opts.y
        fileDragItem.active = true
    }
    function moveFileDrag(x, y, modifiers) {
        if (!fileDragItem.active) return
        fileDragItem.copy = (modifiers & Qt.ControlModifier) !== 0
        fileDragItem.x = x
        fileDragItem.y = y
    }
    function endFileDrag(x, y, modifiers) {
        if (!fileDragItem.active) return Qt.IgnoreAction
        moveFileDrag(x, y, modifiers)
        var result = fileDragItem.Drag.drop()
        fileDragItem.active = false
        fileDragItem.target = ""
        return result
    }
    function cancelFileDrag() {
        if (!fileDragItem.active) return
        fileDragItem.Drag.cancel()
        fileDragItem.active = false
        fileDragItem.target = ""
    }
    function setDropTarget(name) { fileDragItem.target = name || "" }
    function isFileDrag(ev) { return ev !== null && ev !== undefined && ev.source === fileDragItem }

    // Would dropping `ev` (DragEvent) into folder `dest` do anything?
    function canDropOn(ev, dest) {
        if (isFileDrag(ev)) {
            var paths = fileDragItem.paths
            if (!paths.length) return false
            if (dest === "/Recycle Bin") return paths.every(function (p) { return p.indexOf("/Recycle Bin/") !== 0 })
            return paths.some(function (p) {
                var intoItself = dest === p || dest.indexOf(p + "/") === 0
                return !intoItself && (fileDragItem.copy || Storage.parentOf(p) !== dest)
            })
        }
        return ev.hasUrls === true && dest !== "/Recycle Bin"
    }

    // Executes a drop into `dest`. The actual file operation is deferred: it refreshes
    // views, which can destroy the very delegate whose handler is still running.
    function dropInto(dest, ev) {
        if (!canDropOn(ev, dest)) return false
        if (isFileDrag(ev)) {
            var paths = fileDragItem.paths.slice(), copy = fileDragItem.copy
            Qt.callLater(function () { root.transferFiles(paths, dest, copy) })
            return true
        }
        var urls = []
        for (var i = 0; i < ev.urls.length; i++) urls.push(ev.urls[i].toString())
        Qt.callLater(function () { root.importInto(urls, dest) })
        return true
    }

    function folderName(p) { return p === "/" ? "Home" : p.split("/").pop() }

    function transferFiles(paths, dest, copy) {
        if (!paths.length) return 0
        var n
        if (dest === "/Recycle Bin") {
            n = Storage.trash(paths)
            if (n) notify("Moved to Recycle Bin", n === 1 ? paths[0].split("/").pop() : n + " items", "trash")
            else notify("Can't delete", "System folders are protected.", "shield-on")
            return n
        }
        var todo = paths.filter(function (p) {
            return dest !== p && dest.indexOf(p + "/") !== 0 && (copy || Storage.parentOf(p) !== dest)
        })
        if (!todo.length) return 0
        // runs on the background worker: big copies never freeze the desktop
        var job = Storage.startTransfer(copy ? "copy" : "move", todo, dest)
        if (job) jobLabels[job] = todo.length === 1 ? todo[0].split("/").pop() : todo.length + " items"
        return job
    }

    function importInto(urls, dest) {
        if (!urls.length) return 0
        var job = Storage.startTransfer("import", urls, dest)
        if (job) jobLabels[job] = urls.length === 1 ? decodeURIComponent(urls[0].split("/").pop()) : urls.length + " items"
        return job
    }

    function pasteInto(dest) {
        var paths = Storage.clipboardPaths, cut = Storage.clipboardMode === "cut"
        if (!paths.length && Clipboard !== null && Clipboard.hostFiles.length) { importInto(Clipboard.hostFiles, dest); return }
        if (!paths.length) return
        if (cut) Storage.copy([])      // a cut is consumed by the paste
        transferFiles(paths, dest, !cut)
    }

    property var jobLabels: ({})
    Connections {
        target: Storage
        function onTransferStarted(job, op, count) {
            if (count >= 5) root.notify(({ copy: "Copying", move: "Moving", "import": "Importing", "export": "Exporting", extract: "Extracting", compress: "Compressing" })[op] + " " + count + " items…", "This happens in the background.", "clock")
        }
        function onTransferFinished(job, op, count, dest) {
            var label = root.jobLabels[job] || (count + " items")
            delete root.jobLabels[job]
            var verbs = { copy: "Copied", move: "Moved", "import": "Imported", "export": "Exported", extract: "Extracted", compress: "Compressed" }
            var icons = { copy: "copy", move: "folder", "import": "import", "export": "export", extract: "file-archive", compress: "file-archive" }
            var err = Storage.jobError(job)
            if (count > 0) root.notify(verbs[op] + " " + (count === 1 ? label : count + " items"),
                                       op === "export" ? "to your computer" : (op === "compress" ? "into a ZIP in " : "to ") + root.folderName(dest), icons[op])
            else root.notify("Nothing was " + verbs[op].toLowerCase(), err || "Those items are protected, missing or already there.", "warning-color")
        }
    }
    function openImportDialog(dest) { importDialog.dest = dest || "/Documents"; importDialog.open() }
    function openExportDialog(paths) { if (paths && paths.length) { exportDialog.paths = paths; exportDialog.open() } }

    // ================================================= snap assist (multi-way split)
    function offerSnapAssist(win, zone) {
        var layout = UI.layoutFor(zone)
        if (!layout || restoringSession) return
        var taken = {}
        taken[zone] = true
        windows.forEach(function (w) {
            if (w !== win && !w.minimized && !w.closing && w.workspace === workspace && layout.indexOf(w.snap) >= 0) taken[w.snap] = true
        })
        var free = layout.filter(function (z) { return !taken[z] })
        var candidates = windows.filter(function (w) {
            return w !== win && !w.closing && w.workspace === workspace && layout.indexOf(w.snap) < 0
        }).sort(function (a, b) { return b.z - a.z })
        snapAssist.open(free, candidates)
    }
    function assistChose(zone, w) {
        var layout = UI.layoutFor(zone)
        focusWindow(w)
        w.setSnap(zone)
        var remaining = snapAssist.zones.filter(function (z) { return z !== zone })
        var candidates = snapAssist.candidates.filter(function (c) { return c !== w })
        if (remaining.length && candidates.length) snapAssist.open(remaining, candidates)
        else snapAssist.close()
    }

    // ================================================= workspaces
    function switchWorkspace(n, keepFocus) {
        n = (n + workspaceCount) % workspaceCount
        if (n === workspace) return
        var dir = n > workspace ? 1 : -1
        snapAssist.close()
        workspace = n
        wsAnim.from = dir * 60
        wsAnim.restart()
        wsToast.show()
        if (!keepFocus) {
            var top = topmost(null)
            if (top) focusWindow(top)
            else { activeWindow = null; desktop.forceActiveFocus() }
        }
    }
    function moveToWorkspace(win, n) {
        if (!win || n < 0 || n >= workspaceCount || win.workspace === n) return
        win.workspace = n
        if (activeWindow === win && n !== workspace) {
            var top = topmost(win)
            if (top) focusWindow(top); else { activeWindow = null; desktop.forceActiveFocus() }
        }
        notify("Moved to workspace " + (n + 1), win.title, "tab")
    }
    function workspaceWindowCount(n) { return windows.filter(function (w) { return w.workspace === n && !w.closing }).length }

    // ================================================= session restore
    function sessionEntries() {
        return windows.filter(function (w) { return !w.closing }).sort(function (a, b) { return a.z - b.z }).map(function (w) {
            var props = {}
            if (w.app && typeof w.app.sessionState === "function") {
                try { props = w.app.sessionState() || {} } catch (e) { props = {} }
            }
            var r = w.normalRect || Qt.rect(w.x, w.y, w.width, w.height)
            return { app: w.appId, props: props, x: r.x, y: r.y, w: r.width, h: r.height,
                     snap: w.snap, ws: w.workspace, min: w.minimized }
        })
    }
    function saveSession() {
        Prefs.setValue("session.windows", sessionEntries())
        Prefs.setValue("session.workspace", workspace)
    }
    function restoreSession() {
        if (Prefs.value("session.restore", true) === false) return
        var list = UI.arr(Prefs.value("session.windows", []))
        if (!list.length) return
        restoringSession = true
        var focusLast = null
        list.slice(0, 16).forEach(function (s) {
            if (!s || typeof s.app !== "string" || !Apps.get(s.app)) return
            var props = UI.obj(s.props)
            if (props.filePath && !Storage.exists(props.filePath)) return       // file is gone
            if (props.initialPath && !Storage.isDir(props.initialPath)) props.initialPath = "/"
            var w = openApp(s.app, props)
            if (!w) return
            var W = windowLayer.width, H = windowLayer.height
            w.width = Math.max(w.minW, Math.min(Number(s.w) || w.width, W))
            w.height = Math.max(w.minH, Math.min(Number(s.h) || w.height, H))
            w.x = Math.max(0, Math.min(Number(s.x) || 0, W - 120))
            w.y = Math.max(0, Math.min(Number(s.y) || 0, H - 60))
            w.workspace = Math.max(0, Math.min(workspaceCount - 1, Number(s.ws) || 0))
            if (typeof s.snap === "string" && s.snap !== "" && UI.zoneFrac(s.snap)) {
                w.normalRect = Qt.rect(w.x, w.y, w.width, w.height)
                w.snap = s.snap
                var z = w.zoneRect(s.snap)
                w.x = z.x; w.y = z.y; w.width = z.width; w.height = z.height
            }
            if (s.min) w.minimize(); else focusLast = w
        })
        restoringSession = false
        workspace = Math.max(0, Math.min(workspaceCount - 1, Number(Prefs.value("session.workspace", 0)) || 0))
        var top = topmost(null)
        if (top) focusWindow(top)
        else { activeWindow = null; desktop.forceActiveFocus() }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.saveSession() }   // crash safety

    // ================================================= screenshots & clipboard
    function screenshot(activeOnly) {
        var target = activeOnly && activeWindow ? activeWindow : root.contentItem
        var dest = Storage.newScreenshotPath()
        var ok = target.grabToImage(function (result) {
            if (result.saveToFile(dest.real)) {
                shutter.restart()
                var copied = Clipboard !== null && Clipboard.copyImageFile(dest.real)
                Storage.notifyChanged("/Pictures/Screenshots")
                root.notify("Screenshot saved", (copied ? "Copied to the clipboard · " : "") + "Pictures ▸ Screenshots", "image")
            } else root.notify("Screenshot failed", "Couldn't write the image file.", "warning-color")
        })
        if (!ok) notify("Screenshot failed", "Nothing to capture.", "warning-color")
    }
    function showShortcuts() { shortcutHelp.open() }
    function openClipboard() { clipboardPanel.openFor(root.activeFocusItem) }
    // paste a history item into the field you were typing in
    function pasteText(text, target) {
        if (Clipboard) Clipboard.copyText(text)
        if (target && typeof target.insert === "function" && target.cursorPosition !== undefined && !target.readOnly) {
            target.forceActiveFocus()
            if (target.selectedText) target.remove(target.selectionStart, target.selectionEnd)
            target.insert(target.cursorPosition, text)
        } else if (target && typeof target.triggerWebAction === "function") {
            target.forceActiveFocus()
            target.triggerWebAction(webPasteAction)
        } else notify("Copied", "Press Ctrl+V to paste it.", "paste")
    }
    readonly property int webPasteAction: 6   // WebEngineView.Paste (QtWebEngine isn't imported here)
    function canPaste() { return Storage.canPaste || (Clipboard !== null && Clipboard.hostFiles.length > 0) }

    // ================================================= browser downloads
    property var downloads: []            // WebEngineDownloadRequest objects, newest first
    readonly property int activeDownloads: {
        var n = 0
        for (var i = 0; i < downloads.length; i++) if (downloads[i] && !downloads[i].isFinished) n++
        return n
    }
    function addDownload(d) {
        downloads = [d].concat(downloads).slice(0, 50)
        var name = d.downloadFileName
        notify("Downloading", name, "download")
        d.isFinishedChanged.connect(function () {
            if (!d.isFinished) return
            Storage.notifyChanged("/Downloads")
            downloads = downloads.slice()           // refresh bindings (activeDownloads)
            if (d.state === 2 /* DownloadCompleted */) notify("Download complete", name + " is in Downloads", "success")
            else if (d.state === 4 /* DownloadInterrupted */) notify("Download failed", name, "warning-color")
        })
    }

    // ================================================= pins & desktop shortcuts
    function pinnedApps() { return UI.arr(Prefs.value("taskbar.pinned", Apps.defaultPinned)).filter(function (id) { return Apps.get(id) !== null }) }
    function isPinned(id) { return pinnedApps().indexOf(id) >= 0 }
    function togglePin(id) {
        var p = pinnedApps(), i = p.indexOf(id)
        if (i >= 0) p.splice(i, 1); else p.push(id)
        Prefs.setValue("taskbar.pinned", p)
    }
    readonly property var defaultDesktopApps: ["AeroBrowser", "Terminal", "Snake"]
    function desktopApps() { return UI.arr(Prefs.value("desktop.apps", defaultDesktopApps)).filter(function (id) { return Apps.get(id) !== null }) }
    function isOnDesktop(id) { return desktopApps().indexOf(id) >= 0 }
    function toggleDesktopApp(id) {
        var d = desktopApps(), i = d.indexOf(id)
        if (i >= 0) d.splice(i, 1); else d.push(id)
        Prefs.setValue("desktop.apps", d)
        if (i < 0) notify("Added to desktop", Apps.get(id).name, Apps.get(id).icon)
    }

    // ===================================================== notifications etc
    function notify(title, body, icon, action) {
        toasts.show(title, body, icon, action)
        var h = notificationHistory.slice(0, 29)
        h.unshift({ title: title || "", body: body || "", icon: icon || "bell", time: Date.now(), action: action || null })
        notificationHistory = h
        if (!calendarPanel.opened) unreadCount++
    }

    function lock() {
        startMenu.close(); quickSettings.close(); calendarPanel.close()
        lockScreen.lockNow()
    }

    function cycleWallpaper() {
        var walls = Storage.wallpapers()
        if (!walls.length) return
        var idx = 0
        for (var i = 0; i < walls.length; i++) if (walls[i].path === Prefs.wallpaper) idx = (i + 1) % walls.length
        Prefs.setWallpaper(walls[idx].path)
    }

    function unsavedCount() {
        return windows.filter(function (w) { return w.app && w.app.hasUnsavedChanges === true }).length
    }

    function requestPower(mode) {
        startMenu.close()
        powerDialog.ask(mode, unsavedCount())
    }

    // A press outside a popup closes it before the toggle button's click arrives,
    // so ignore a re-open request that follows a close within a few hundred ms.
    function togglePopup(p) {
        if (p.opened) p.close()
        else if (Date.now() - p.closedAt > 350) p.open()
    }
    function toggleStart() { togglePopup(startMenu) }

    onClosing: function (close) {
        if (allowQuit) return
        close.accepted = false
        requestPower("shutdown")
    }

    Connections {
        target: System
        function onErrorOccurred(title, message) { root.notify(title, message, "shield-on") }
    }

    Timer {   // keep the weather chip fresh
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: WeatherService.refreshIfStale()
    }

    // ============================================================ layers
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Prefs.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: Math.ceil(Math.max(root.width, root.height * 2) * Screen.devicePixelRatio)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: UI.dur(500) } }
    }
    Rectangle {   // gentle vignette so white text stays readable on bright wallpapers
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
            GradientStop { position: 0.25; color: "transparent" }
            GradientStop { position: 0.8; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
        }
    }

    Desktop {
        id: desktop
        anchors.fill: parent
        anchors.bottomMargin: root.fullscreenWindow ? 0 : taskbar.height
        focus: true
    }

    Item {
        id: windowLayer
        anchors.fill: desktop
        transform: Translate { id: wsShift }   // workspace switch slide (anchored items can't animate x)

        Rectangle {
            id: snapPreview
            property var owner: null
            property bool animate: true
            z: 1000000000
            opacity: 0
            visible: opacity > 0
            radius: UI.radiusLarge
            color: UI.alpha(UI.accent, 0.16)
            border.width: 2
            border.color: UI.alpha(UI.accent, 0.75)
            Behavior on opacity { NumberAnimation { duration: UI.dur(120) } }
            Behavior on x { enabled: snapPreview.animate; NumberAnimation { duration: UI.dur(150); easing.type: Easing.OutCubic } }
            Behavior on y { enabled: snapPreview.animate; NumberAnimation { duration: UI.dur(150); easing.type: Easing.OutCubic } }
            Behavior on width { enabled: snapPreview.animate; NumberAnimation { duration: UI.dur(150); easing.type: Easing.OutCubic } }
            Behavior on height { enabled: snapPreview.animate; NumberAnimation { duration: UI.dur(150); easing.type: Easing.OutCubic } }
        }
    }

    SnapAssist {
        id: snapAssist
        parent: windowLayer
        anchors.fill: parent
        z: 999999999
        onChosen: function (zone, w) { root.assistChose(zone, w) }
        onVisibleChanged: if (!visible && root.activeWindow) root.activeWindow.takeFocus()
    }

    NumberAnimation { id: wsAnim; target: wsShift; property: "x"; to: 0; duration: UI.dur(220); easing.type: Easing.OutCubic }

    Rectangle {   // "Workspace 2" indicator
        id: wsToast
        function show() { opacity = 1; wsHide.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: taskbar.top
        anchors.bottomMargin: 24
        z: 55
        width: wsRow.implicitWidth + 32
        height: UI.px(44)
        radius: height / 2
        color: Qt.rgba(0.08, 0.1, 0.15, 0.94)
        border.color: UI.borderStrong
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: UI.dur(180) } }
        Timer { id: wsHide; interval: 900; onTriggered: wsToast.opacity = 0 }
        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 10
            Text { text: "Workspace " + (root.workspace + 1); color: UI.text; font.pixelSize: UI.px(13); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: root.workspaceCount
                Rectangle {
                    width: index === root.workspace ? 18 : 8; height: 8; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: index === root.workspace ? UI.accent : Qt.rgba(1, 1, 1, 0.3)
                }
            }
        }
    }

    Rectangle {   // screenshot shutter flash
        anchors.fill: parent
        z: 95
        color: "white"
        opacity: 0
        visible: opacity > 0
        SequentialAnimation on opacity {
            id: shutter
            running: false
            NumberAnimation { to: 0.55; duration: 60 }
            NumberAnimation { to: 0; duration: 260 }
        }
    }

    Rectangle {   // "Press Esc to exit full screen"
        id: fsHint
        function show() { opacity = 1; fsHintHide.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        z: 96
        width: fsHintRow.implicitWidth + 36
        height: UI.px(42)
        radius: height / 2
        color: Qt.rgba(0.05, 0.06, 0.09, 0.9)
        border.color: UI.borderStrong
        opacity: 0
        visible: opacity > 0 && root.fullscreenWindow !== null
        Behavior on opacity { NumberAnimation { duration: UI.dur(250) } }
        Timer { id: fsHintHide; interval: 2600; onTriggered: fsHint.opacity = 0 }
        Row {
            id: fsHintRow
            anchors.centerIn: parent
            spacing: 8
            Text { font.weight: UI.textWeight; text: "Press"; color: UI.textDim; font.pixelSize: UI.px(13); anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                width: escText.implicitWidth + 14; height: UI.px(24); radius: 5
                color: Qt.rgba(1, 1, 1, 0.14); border.color: UI.borderStrong
                anchors.verticalCenter: parent.verticalCenter
                Text { id: escText; anchors.centerIn: parent; text: "Esc"; color: "white"; font.pixelSize: UI.px(12); font.bold: true }
            }
            Text { font.weight: UI.textWeight; text: "to exit full screen"; color: UI.textDim; font.pixelSize: UI.px(13); anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Taskbar {
        id: taskbar
        visible: root.fullscreenWindow === null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        startOpen: startMenu.opened
        onStartRequested: root.toggleStart()
        onQuickSettingsRequested: root.togglePopup(quickSettings)
        onCalendarRequested: root.togglePopup(calendarPanel)
    }

    Toasts {
        id: toasts
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        z: 50
    }

    WindowSwitcher {
        id: switcher
        anchors.fill: parent
        z: 60
        onVisibleChanged: if (!visible) { if (root.activeWindow) root.activeWindow.takeFocus(); else desktop.forceActiveFocus() }
    }

    Rectangle {   // brightness
        anchors.fill: parent
        z: 80
        color: "black"
        opacity: (100 - root.brightness) / 100 * 0.75
        visible: opacity > 0
    }
    Rectangle {   // night light
        anchors.fill: parent
        z: 81
        color: "#ff8a2b"
        opacity: Prefs.nightLight ? 0.13 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: UI.dur(600) } }
    }

    LockScreen {
        id: lockScreen
        anchors.fill: parent
        z: 90
        onUnlocked: { if (root.activeWindow) root.activeWindow.takeFocus(); else desktop.forceActiveFocus() }
    }

    BootSplash {
        id: boot
        anchors.fill: parent
        z: 100
        onFinished: {
            desktop.forceActiveFocus()
            root.restoreSession()
            if (Extensions.crashedLastTime)
                root.notify("Browser extensions were switched off",
                            "GlassOS stopped unexpectedly while they were running. You can turn them back on in AeroBrowser ▸ Shields & settings.",
                            "warning-color")
            WeatherService.refreshIfStale()
            if (!Prefs.value("welcomed", false)) {
                Prefs.setValue("welcomed", true)
                root.notify("Welcome to GlassOS",
                            "Ctrl+Space searches everything. Drag windows to screen edges to snap them. Try the Terminal!", "sparkles")
            }
        }
    }

    StartMenu { id: startMenu }

    // Chrome extensions (experimental, opt-in): the only code that touches Qt's extension manager
    Loader {
        id: extHostLoader
        active: HasWebEngine && BrowserProfile !== null && Extensions.experimental
        source: "components/ExtensionHost.qml"
    }
    readonly property var extHost: extHostLoader.status === Loader.Ready ? extHostLoader.item : null
    Connections {
        target: root.extHost
        ignoreUnknownSignals: true
        function onNotify(title, body) { root.notify(title, body, "puzzle") }
    }
    ClipboardPanel { id: clipboardPanel; property double closedAt: 0; onClosed: closedAt = Date.now(); onPick: function (text, target) { root.pasteText(text, target) } }
    ShortcutHelp { id: shortcutHelp }
    QuickSettings { id: quickSettings }
    CalendarPanel { id: calendarPanel }
    PowerDialog {
        id: powerDialog
        onConfirmed: function (mode) {
            root.saveSession()
            Prefs.flush()
            root.allowQuit = true
            if (mode === "restart") System.restart(); else System.quit()
        }
    }

    Component { id: windowComponent; GlassWindow {} }

    FileDialog {
        id: importDialog
        property string dest: "/Documents"
        title: "Import into GlassOS (" + root.folderName(dest) + ")"
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            var urls = []
            for (var i = 0; i < selectedFiles.length; i++) urls.push(selectedFiles[i].toString())
            root.importInto(urls, dest)
        }
    }
    FolderDialog {
        id: exportDialog
        property var paths: []
        title: "Export from GlassOS to…"
        onAccepted: Storage.startTransfer("export", paths, selectedFolder.toString())
    }

    // The shared drag hotspot + ghost (see "file drag & drop" above)
    Item {
        id: fileDragItem
        property bool active: false
        property var paths: []
        property string sourceDir: ""
        property string sourceKey: ""     // desktop icon key when dragging from the desktop
        property string icon: "file"
        property string label: ""
        property string target: ""        // set by the DropArea under the cursor
        property bool copy: false
        z: 75
        width: 1
        height: 1
        visible: active
        Drag.active: active
        Drag.hotSpot.x: 0
        Drag.hotSpot.y: 0
        Drag.keys: ["glassos/files"]
        Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
        Drag.proposedAction: copy ? Qt.CopyAction : Qt.MoveAction

        Rectangle {
            x: 14
            y: 14
            width: ghostRow.implicitWidth + 22
            height: UI.px(38)
            radius: UI.radius
            color: Qt.rgba(0.09, 0.11, 0.16, 0.94)
            border.color: fileDragItem.target !== "" ? UI.accent : UI.borderStrong
            Row {
                id: ghostRow
                anchors.centerIn: parent
                spacing: 8
                Icon { name: fileDragItem.icon; size: UI.px(18); anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: fileDragItem.label; color: UI.text; font.pixelSize: UI.px(12); font.weight: Font.Medium }
                    Text {
                        font.weight: UI.textWeight
                        visible: fileDragItem.target !== ""
                        text: (fileDragItem.target === "Recycle Bin" ? "Delete → " : (fileDragItem.copy ? "Copy to " : "Move to ")) + fileDragItem.target
                        color: UI.accent
                        font.pixelSize: UI.px(11)
                    }
                }
            }
            Rectangle {
                visible: fileDragItem.copy
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -6
                width: 18; height: 18; radius: 9
                color: UI.accent
                Icon { name: "plus"; size: 13; anchors.centerIn: parent }
            }
        }
    }
    Shortcut { sequence: "Esc"; enabled: fileDragItem.active; onActivated: root.cancelFileDrag() }
    Shortcut { sequence: "Esc"; enabled: root.fullscreenWindow !== null && !fileDragItem.active; onActivated: root.requestExitFullscreen() }

    // ============================================================ shortcuts
    Shortcut { sequence: "Ctrl+Q"; onActivated: root.requestPower("shutdown") }
    Shortcut { sequence: "Ctrl+Space"; onActivated: root.toggleStart() }
    Shortcut { sequences: ["Alt+Tab", "Alt+`"]; onActivated: switcher.advance(root.windowsByRecency()) }
    Shortcut { sequence: "Ctrl+Alt+T"; onActivated: root.openApp("Terminal", {}) }
    Shortcut { sequence: "Ctrl+Alt+E"; onActivated: root.openApp("AeroExplorer", {}) }
    Shortcut { sequence: "Ctrl+Alt+L"; onActivated: root.lock() }
    Shortcut { sequence: "Ctrl+Alt+D"; onActivated: root.showDesktop() }
    Shortcut { sequence: "Ctrl+Alt+W"; onActivated: root.closeWindow(root.activeWindow) }
    Shortcut { sequences: ["Print", "Ctrl+Alt+S"]; onActivated: root.screenshot(false) }
    Shortcut { sequences: ["Alt+Print", "Ctrl+Alt+Shift+S"]; onActivated: root.screenshot(true) }
    Shortcut { sequence: "Ctrl+Alt+V"; onActivated: clipboardPanel.opened ? clipboardPanel.close() : root.openClipboard() }
    Shortcut { sequence: "F1"; onActivated: shortcutHelp.opened ? shortcutHelp.close() : shortcutHelp.open() }
    Shortcut { sequence: "Ctrl+Alt+PgDown"; onActivated: root.switchWorkspace(root.workspace + 1) }
    Shortcut { sequence: "Ctrl+Alt+PgUp"; onActivated: root.switchWorkspace(root.workspace - 1) }
    Shortcut { sequence: "Ctrl+Alt+1"; onActivated: root.switchWorkspace(0) }
    Shortcut { sequence: "Ctrl+Alt+2"; onActivated: root.switchWorkspace(1) }
    Shortcut { sequence: "Ctrl+Alt+3"; onActivated: root.switchWorkspace(2) }
    Shortcut { sequence: "Ctrl+Alt+4"; onActivated: root.switchWorkspace(3) }
    Shortcut { sequence: "Ctrl+Alt+Shift+1"; onActivated: root.moveToWorkspace(root.activeWindow, 0) }
    Shortcut { sequence: "Ctrl+Alt+Shift+2"; onActivated: root.moveToWorkspace(root.activeWindow, 1) }
    Shortcut { sequence: "Ctrl+Alt+Shift+3"; onActivated: root.moveToWorkspace(root.activeWindow, 2) }
    Shortcut { sequence: "Ctrl+Alt+Shift+4"; onActivated: root.moveToWorkspace(root.activeWindow, 3) }
    Shortcut { sequence: "Ctrl+Alt+Left"; onActivated: root.snapActive("left") }
    Shortcut { sequence: "Ctrl+Alt+Right"; onActivated: root.snapActive("right") }
    Shortcut { sequence: "Ctrl+Alt+Up"; onActivated: root.snapActive("up") }
    Shortcut { sequence: "Ctrl+Alt+Down"; onActivated: root.snapActive("down") }
    Shortcut {
        sequence: "F11"
        onActivated: {
            var full = root.visibility === Window.FullScreen
            root.forceWindowed = false
            Prefs.setFullscreen(!full)
        }
    }

    Component.onCompleted: {
        if (LaunchArgs.skipBoot) { boot.visible = false; boot.finished() }
        else boot.start()
    }
}
