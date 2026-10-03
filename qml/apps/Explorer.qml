import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: ex
    property var hostWindow: null
    property string initialPath: "/"
    property string initialArchive: ""
    property string initialSelect: ""

    property string path: "/"
    property var history: []
    property int historyIndex: -1
    property var entries: []
    property var shown: []
    property string filter: ""
    property string viewMode: Prefs.value("explorer.view", "grid")
    property string sortKey: "name"
    property bool sortDesc: false
    property var selected: ({})
    property int anchorIndex: -1
    property string lastReloadPath: ""
    property bool showDetails: Prefs.value("explorer.details", true) !== false
    readonly property bool inTrash: path === "/Recycle Bin"
    readonly property int selectedCount: Object.keys(selected).length
    readonly property string dropTargetDir: path      // used by GlassWindow for drops on the title bar
    readonly property var wm: UI.wm
    // paths currently "cut" - one shared lookup instead of a Python call per delegate
    readonly property var cutSet: {
        var m = {}
        if (Storage.clipboardMode === "cut") Storage.clipboardPaths.forEach(function (p) { m[p] = true })
        return m
    }

    Component.onCompleted: {
        navigate(Storage.isDir(initialPath) ? initialPath : "/")
        if (initialArchive) archiveView.openArchive(initialArchive)
        if (initialSelect) selectPath(initialSelect)
    }
    function openWithMenu(e, item) {
        var items = [{ text: "GlassPad", icon: "app-notepad", action: function () { wm.openApp("GlassPad", { filePath: e.path }) } }]
        if (e.kind === "image") items.unshift({ text: "Photos", icon: "app-photos", action: function () { wm.openApp("ImageViewer", { filePath: e.path }) } })
        if (e.kind === "audio" || e.kind === "video" || e.kind === "playlist") items.unshift({ text: "Media Player", icon: "app-media", action: function () { wm.openApp("MediaPlayer", { filePath: e.path }) } })
        if (HasWebEngine) items.push({ text: "AeroBrowser", icon: "app-browser", action: function () { wm.openApp("AeroBrowser", { initialUrl: Storage.fileUrl(e.path) }) } })
        menu.show(item, 0, item.height, items)
    }
    function selectPath(p) {
        for (var i = 0; i < shown.length; i++) if (shown[i].path === p) {
            var s = {}; s[p] = true; selected = s; anchorIndex = i
            Qt.callLater(function () { if (viewMode === "grid") grid.positionViewAtIndex(i, GridView.Contain); else list.positionViewAtIndex(i, ListView.Contain) })
            return
        }
    }
    function handleArgs(props) {
        if (props.initialPath && Storage.isDir(props.initialPath)) navigate(props.initialPath)
        if (props.initialArchive) archiveView.openArchive(props.initialArchive)
        if (props.initialSelect) selectPath(props.initialSelect)
    }
    function sessionState() { return { initialPath: path } }
    function extractArchive(p) { Storage.startTransfer("extract", [p], Storage.parentOf(p)) }
    function compressSelection() {
        var paths = selectedPaths()
        if (paths.length && !inTrash) Storage.startTransfer("compress", paths, path)
    }

    Connections {
        target: Storage
        function onChanged(dir) {
            if (!Storage.isDir(ex.path)) ex.navigate(Storage.isDir(Storage.parentOf(ex.path)) ? Storage.parentOf(ex.path) : "/")
            else if (dir === ex.path) ex.reload()
        }
    }

    // ------------------------------------------------------------ navigation
    function navigate(p, fromHistory) {
        if (!Storage.isDir(p)) {
            wm.notify("Folder not found", p, "warning-color")
            if (!Storage.isDir(path)) navigate("/")   // the folder we were in vanished too
            return
        }
        path = p
        if (!fromHistory) {
            var h = history.slice(0, historyIndex + 1)
            h.push(p)
            history = h
            historyIndex = h.length - 1
        }
        filter = ""
        searchField.text = ""
        selected = {}
        anchorIndex = -1
        reload()
        if (hostWindow) hostWindow.title = (p === "/" ? "Home" : p.split("/").pop()) + " — Files"
        Storage.watch(p)   // live refresh when the folder changes, even from outside GlassOS
    }
    function back() { if (historyIndex > 0) { historyIndex--; navigate(history[historyIndex], true) } }
    function forward() { if (historyIndex < history.length - 1) { historyIndex++; navigate(history[historyIndex], true) } }
    function up() { if (path !== "/") navigate(Storage.parentOf(path)) }

    // Re-reads the folder. Keeps the scroll position when the folder itself didn't
    // change (rename, paste, delete...), instead of jumping back to the top.
    function reload() {
        var keepY = viewMode === "grid" ? grid.contentY : list.contentY
        var samePath = lastReloadPath === path
        lastReloadPath = path
        entries = Storage.list(path)
        applyView()
        if (samePath) Qt.callLater(function () {
            var v = viewMode === "grid" ? grid : list
            v.contentY = Math.max(0, Math.min(keepY, v.contentHeight - v.height))
        })
    }

    function applyView() {
        var q = filter.toLowerCase()
        var list = q ? entries.filter(function (e) { return e.name.toLowerCase().indexOf(q) >= 0 }) : entries.slice()
        var key = sortKey, dir = sortDesc ? -1 : 1
        list.sort(function (a, b) {
            if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
            var va = key === "name" ? a.name.toLowerCase() : key === "kind" ? a.kind : key === "size" ? a.size : (inTrash ? a.deletedAt : a.modified)
            var vb = key === "name" ? b.name.toLowerCase() : key === "kind" ? b.kind : key === "size" ? b.size : (inTrash ? b.deletedAt : b.modified)
            return va < vb ? -dir : va > vb ? dir : 0
        })
        shown = list
        var keep = {}
        for (var i = 0; i < list.length; i++) if (selected[list[i].path]) keep[list[i].path] = true
        selected = keep
    }
    onFilterChanged: applyView()
    function setSort(k) { if (sortKey === k) sortDesc = !sortDesc; else { sortKey = k; sortDesc = false }; applyView() }
    function setView(m) { viewMode = m; Prefs.setValue("explorer.view", m) }

    // ------------------------------------------------------------ selection
    function clickItem(index, mods) {
        var e = shown[index], s
        if (mods & Qt.ShiftModifier && anchorIndex >= 0) {
            s = (mods & Qt.ControlModifier) ? Object.assign({}, selected) : {}
            var a = Math.min(anchorIndex, index), b = Math.max(anchorIndex, index)
            for (var i = a; i <= b; i++) s[shown[i].path] = true
        } else if (mods & Qt.ControlModifier) {
            s = Object.assign({}, selected)
            if (s[e.path]) delete s[e.path]; else s[e.path] = true
            anchorIndex = index
        } else {
            s = {}; s[e.path] = true
            anchorIndex = index
        }
        selected = s
        ex.forceActiveFocus()
    }
    function startDrag(e, x, y) {
        if (!selected[e.path]) { var s = {}; s[e.path] = true; selected = s }
        var paths = selectedPaths()
        UI.wm.beginFileDrag({ paths: paths, sourceDir: path, icon: e.icon, x: x, y: y,
                              label: paths.length === 1 ? e.name : paths.length + " items" })
    }

    function selectedEntries() { return shown.filter(function (e) { return selected[e.path] }) }
    function selectedPaths() { return selectedEntries().map(function (e) { return e.path }) }
    function selectAll() { var s = {}; shown.forEach(function (e) { s[e.path] = true }); selected = s }

    // ------------------------------------------------------------ actions
    function open(e) {
        if (inTrash) { propertiesFor(e); return }
        if (e.isDir) navigate(e.path)
        else if (e.kind === "archive" && Storage.canExtract(e.path)) archiveView.openArchive(e.path)
        else wm.openPath(e.path)
    }
    function openSelected() { var s = selectedEntries(); if (s.length === 1 && s[0].isDir) navigate(s[0].path); else s.forEach(open) }

    function newFolder() {
        var p = Storage.createFolder(path, "New folder")
        if (p) { reload(); var s = {}; s[p] = true; selected = s; renameEntry(Storage.info(p)) }
    }
    function newFile() {
        var p = Storage.createFile(path, "New text document.txt")
        if (p) { reload(); var s = {}; s[p] = true; selected = s; renameEntry(Storage.info(p)) }
    }

    function renameEntry(e) {
        if (!e || inTrash) return
        dialog.ask({ title: "Rename", icon: "edit", input: true, text: e.name, selectStem: !e.isDir,
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Rename", value: "ok", kind: "primary" }] },
                   function (v, text) {
                       if (v !== "ok" || text === e.name) return
                       if (!Storage.isValidName(text)) { wm.notify("Can't rename", "Names can't contain / \\ : * ? \" < > |", "warning-color"); return }
                       var np = Storage.rename(e.path, text)
                       if (!np) wm.notify("Can't rename", "“" + text + "” already exists or the item is protected.", "warning-color")
                       else { var s = {}; s[np] = true; selected = s }
                   })
    }

    function deleteSelection() {
        var paths = selectedPaths()
        if (!paths.length) return
        if (inTrash) {
            dialog.ask({ title: "Delete permanently?", icon: "trash",
                         message: (paths.length === 1 ? "“" + selectedEntries()[0].name + "”" : paths.length + " items") + " will be gone forever.",
                         buttons: [{ text: "Cancel", value: "cancel" }, { text: "Delete", value: "ok", kind: "danger" }] },
                       function (v) { if (v === "ok") Storage.deletePermanently(paths) })
            return
        }
        var n = Storage.trash(paths)
        if (n) wm.notify("Moved to Recycle Bin", n === 1 ? paths[0].split("/").pop() : n + " items", "trash")
        else wm.notify("Can't delete", "System folders are protected.", "shield-on")
    }

    function restoreSelection() { restorePaths(selectedPaths()) }
    // tell the user exactly where restored items went (click the toast to go there)
    function restorePaths(paths) {
        var dest = Storage.restoreItems(paths)
        if (!dest.length) return
        var folder = Storage.parentOf(dest[0])
        var same = dest.every(function (d) { return Storage.parentOf(d) === folder })
        var what = dest.length === 1 ? dest[0].split("/").pop() : dest.length + " items"
        wm.notify("Restored " + what, "to " + (same ? (folder === "/" ? "Home" : folder) : "their original folders"), "undo",
                  function () { wm.openApp("AeroExplorer", { initialPath: folder, initialSelect: dest[0] }) })
    }

    function emptyTrash() {
        dialog.ask({ title: "Empty the Recycle Bin?", icon: "broom",
                     message: Storage.trashCount + " item(s) will be permanently deleted.",
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Empty", value: "ok", kind: "danger" }] },
                   function (v) { if (v === "ok") Storage.emptyTrash() })
    }

    function propertiesFor(e) {
        var info = Storage.info(e.path)
        var lines = []
        lines.push("Type: " + (info.isDir ? "Folder" : (info.ext ? info.ext.toUpperCase() + " file" : "File")))
        lines.push("Location: " + (inTrash && e.originalPath ? Storage.parentOf(e.originalPath) + "  (deleted)" : Storage.parentOf(e.path)))
        lines.push("Size: " + UI.fmtSize(info.size))
        if (info.isDir) lines.push("Contains: " + info.files + " files, " + info.folders + " folders")
        lines.push((inTrash ? "Deleted: " + UI.fmtDate(e.deletedAt) : "Modified: " + UI.fmtDate(info.modified)))
        var buttons = [{ text: "Close", value: "close", kind: "primary" }]
        if (inTrash) buttons = [{ text: "Close", value: "close" }, { text: "Restore", value: "restore", kind: "primary" }]
        dialog.ask({ title: e.name, icon: e.icon, message: lines.join("\n"), buttons: buttons },
                   function (v) { if (v === "restore") ex.restorePaths([e.path]) })
    }

    function itemMenu(e, item, mx, my) {
        if (!selected[e.path]) { var s = {}; s[e.path] = true; selected = s }
        var many = selectedCount > 1
        var items
        if (inTrash) {
            items = [
                { text: "Restore", icon: "undo", action: restoreSelection },
                { text: "Properties", icon: "info", enabled: !many, action: function () { propertiesFor(e) } },
                { separator: true },
                { text: "Delete permanently", icon: "trash", danger: true, shortcut: "Del", action: deleteSelection }
            ]
        } else {
            items = [{ text: e.isDir ? "Open" : "Open", icon: "folder-open", shortcut: "Enter", action: openSelected }]
            if (e.isDir) items.push({ text: "Open in new window", icon: "external", action: function () { wm.openApp("AeroExplorer", { initialPath: e.path }) } })
            if (e.isDir) items.push({ text: "Open Terminal here", icon: "terminal", action: function () { wm.openApp("Terminal", { initialCwd: e.path }) } })
            if (!e.isDir) items.push({ text: "Edit in GlassPad", icon: "edit", action: function () { wm.openApp("GlassPad", { filePath: e.path }) } })
            if (e.kind === "image") items.push({ text: "Set as wallpaper", icon: "image", action: function () { Prefs.setWallpaper(e.path); wm.notify("Wallpaper changed", e.name, "image") } })
            items = items.concat([
                { separator: true },
                { text: "Extract here", icon: "file-archive", enabled: !many && Storage.canExtract(e.path), action: function () { ex.extractArchive(e.path) } },
                { text: many ? "Compress " + selectedCount + " items to ZIP" : "Compress to ZIP", icon: "file-archive", action: ex.compressSelection },
                { separator: true },
                { text: "Cut", icon: "cut", shortcut: "Ctrl+X", action: function () { Storage.cut(selectedPaths()) } },
                { text: "Copy", icon: "paste", shortcut: "Ctrl+C", action: function () { Storage.copy(selectedPaths()) } },
                { text: "Rename", icon: "edit", shortcut: "F2", enabled: !many, action: function () { renameEntry(e) } },
                { text: "Properties", icon: "info", enabled: !many, action: function () { propertiesFor(e) } },
                { text: "Export to computer…", icon: "export", action: function () { wm.openExportDialog(selectedPaths()) } },
                { separator: true },
                { text: many ? "Delete " + selectedCount + " items" : "Delete", icon: "trash", shortcut: "Del", danger: true, action: deleteSelection }
            ])
        }
        menu.show(item, mx, my, items)
    }

    function backgroundMenu(item, mx, my) {
        selected = {}
        var items = inTrash ? [
            { text: "Empty Recycle Bin", icon: "broom", danger: true, enabled: Storage.trashCount > 0, action: emptyTrash },
            { text: "Refresh", icon: "refresh", shortcut: "F5", action: reload }
        ] : [
            { text: "New folder", icon: "folder", shortcut: "Ctrl+Shift+N", action: newFolder },
            { text: "New text document", icon: "edit", action: newFile },
            { text: "Paste", icon: "paste", shortcut: "Ctrl+V", enabled: wm.canPaste(), action: function () { wm.pasteInto(path) } },
            { text: "Import files from computer…", icon: "import", action: function () { wm.openImportDialog(path) } },
            { separator: true },
            { text: viewMode === "grid" ? "Show as list" : "Show as icons", icon: viewMode === "grid" ? "list" : "grid", action: function () { setView(viewMode === "grid" ? "list" : "grid") } },
            { text: "Open Terminal here", icon: "terminal", action: function () { wm.openApp("Terminal", { initialCwd: path }) } },
            { text: "Refresh", icon: "refresh", shortcut: "F5", action: reload }
        ]
        menu.show(item, mx, my, items)
    }

    function moveSelection(delta) {
        if (!shown.length) return
        var cur = anchorIndex < 0 ? (delta > 0 ? -1 : shown.length) : anchorIndex
        var next = Math.max(0, Math.min(shown.length - 1, cur + delta))
        clickItem(next, 0)
        if (viewMode === "grid") grid.positionViewAtIndex(next, GridView.Contain)
        else list.positionViewAtIndex(next, ListView.Contain)
    }

    Keys.onPressed: function (event) {
        var ctrl = event.modifiers & Qt.ControlModifier
        var k = event.key
        if (k === Qt.Key_Return || k === Qt.Key_Enter) openSelected()
        else if (k === Qt.Key_Backspace || (k === Qt.Key_Up && (event.modifiers & Qt.AltModifier))) up()
        else if (k === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) back()
        else if (k === Qt.Key_Right && (event.modifiers & Qt.AltModifier)) forward()
        else if (k === Qt.Key_Delete) deleteSelection()
        else if (k === Qt.Key_F2) { var s = selectedEntries(); if (s.length === 1) renameEntry(s[0]) }
        else if (k === Qt.Key_F5) reload()
        else if (k === Qt.Key_P && (event.modifiers & Qt.AltModifier)) { showDetails = !showDetails; Prefs.setValue("explorer.details", showDetails) }
        else if (ctrl && k === Qt.Key_A) selectAll()
        else if (ctrl && k === Qt.Key_C) Storage.copy(selectedPaths())
        else if (ctrl && k === Qt.Key_X) Storage.cut(selectedPaths())
        else if (ctrl && k === Qt.Key_V && !inTrash) wm.pasteInto(path)
        else if (ctrl && k === Qt.Key_F) searchField.forceActiveFocus()
        else if (ctrl && (event.modifiers & Qt.ShiftModifier) && k === Qt.Key_N) newFolder()
        else if (k === Qt.Key_Down) moveSelection(viewMode === "grid" ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1)
        else if (k === Qt.Key_Up) moveSelection(viewMode === "grid" ? -Math.max(1, Math.floor(grid.width / grid.cellWidth)) : -1)
        else if (k === Qt.Key_Right && viewMode === "grid") moveSelection(1)
        else if (k === Qt.Key_Left && viewMode === "grid") moveSelection(-1)
        else if (k === Qt.Key_Escape) selected = {}
        else return
        event.accepted = true
    }

    // ================================================================ layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(46)
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 4
            IconButton { iconName: "back"; tip: "Back (Alt+←)"; enabled: ex.historyIndex > 0; onClicked: ex.back() }
            IconButton { iconName: "forward"; tip: "Forward (Alt+→)"; enabled: ex.historyIndex < ex.history.length - 1; onClicked: ex.forward() }
            IconButton { iconName: "up"; tip: "Up (Backspace)"; enabled: ex.path !== "/"; onClicked: ex.up() }
            IconButton { iconName: "refresh"; tip: "Refresh (F5)"; onClicked: ex.reload() }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: UI.px(32)
                Layout.leftMargin: 6
                radius: UI.radiusSmall
                color: UI.field
                border.color: UI.border
                clip: true
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Repeater {
                        model: {
                            var parts = ex.path.split("/").filter(function (x) { return x !== "" })
                            var out = [{ name: "Home", path: "/" }], acc = ""
                            for (var i = 0; i < parts.length; i++) { acc += "/" + parts[i]; out.push({ name: parts[i], path: acc }) }
                            return out
                        }
                        delegate: Row {
                            Icon { name: "chevron-right"; size: UI.px(14); visible: index > 0; anchors.verticalCenter: parent.verticalCenter }
                            AbstractButton {
                                id: crumb
                                hoverEnabled: true
                                implicitHeight: UI.px(26)
                                implicitWidth: crumbText.implicitWidth + 14
                                onClicked: ex.navigate(modelData.path)
                                background: Rectangle { radius: 4; color: crumb.hovered ? UI.hover : "transparent" }
                                contentItem: Text { font.weight: UI.textWeight; id: crumbText; text: modelData.name; color: UI.text; font.pixelSize: UI.px(12.5); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }

            GTextField {
                id: searchField
                Layout.preferredWidth: UI.px(200)
                Layout.preferredHeight: UI.px(32)
                leading: "search"
                placeholderText: "Filter this folder"
                onTextChanged: ex.filter = text
                Keys.onEscapePressed: { text = ""; ex.forceActiveFocus() }
                Keys.onDownPressed: ex.forceActiveFocus()
            }
            IconButton { iconName: "import"; tip: "Import files from your computer (or drag them in)"; enabled: !ex.inTrash; onClicked: ex.wm.openImportDialog(ex.path) }
            IconButton { iconName: "details-pane"; tip: "Details pane (Alt+P)"; active: ex.showDetails; onClicked: { ex.showDetails = !ex.showDetails; Prefs.setValue("explorer.details", ex.showDetails) } }
            IconButton { iconName: "grid"; tip: "Icons"; active: ex.viewMode === "grid"; onClicked: ex.setView("grid") }
            IconButton { iconName: "list"; tip: "List"; active: ex.viewMode === "list"; onClicked: ex.setView("list") }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: UI.border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ------------------------------------------------------ sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: UI.px(186)
                visible: ex.width > 600
                color: Qt.rgba(0, 0, 0, 0.12)
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    Repeater {
                        model: [{ name: "Home", path: "/", icon: "home" }].concat(Storage.specialFolders()).concat([{ name: "Recycle Bin", path: "/Recycle Bin", icon: "trash" }])
                        delegate: AbstractButton {
                            id: side
                            width: parent.width
                            height: UI.px(32)
                            hoverEnabled: true
                            readonly property bool current: ex.path === modelData.path
                            onClicked: ex.navigate(modelData.path)
                            DropArea {
                                id: sideDrop
                                anchors.fill: parent
                                onEntered: function (drag) {
                                    var ok = UI.wm.canDropOn(drag, modelData.path)
                                    drag.accepted = ok
                                    if (ok) UI.wm.setDropTarget(modelData.name)
                                }
                                onExited: UI.wm.setDropTarget("")
                                onDropped: function (drop) { if (UI.wm.dropInto(modelData.path, drop)) drop.acceptProposedAction() }
                            }
                            background: Rectangle {
                                radius: UI.radiusSmall
                                border.width: sideDrop.containsDrag ? 2 : 0
                                border.color: UI.accent
                                color: sideDrop.containsDrag ? UI.accentSoft : side.current ? UI.accentFaint : (side.hovered ? UI.hover : "transparent")
                                Rectangle { visible: side.current; width: 3; height: 16; radius: 1.5; color: UI.accent; anchors.verticalCenter: parent.verticalCenter }
                            }
                            contentItem: Row {
                                leftPadding: 10
                                spacing: 10
                                Icon { name: modelData.icon; size: UI.px(14); anchors.verticalCenter: parent.verticalCenter }
                                Text { font.weight: UI.textWeight; text: modelData.name; color: UI.text; font.pixelSize: UI.px(12.5); anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    font.weight: UI.textWeight
                                    visible: modelData.path === "/Recycle Bin" && Storage.trashCount > 0
                                    text: Storage.trashCount
                                    color: UI.textFaint; font.pixelSize: UI.px(11)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: UI.border }
            }

            // ------------------------------------------------------ content
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {   // recycle bin banner
                    visible: ex.inTrash
                    Layout.fillWidth: true
                    Layout.preferredHeight: UI.px(44)
                    color: UI.accentFaint
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        Text { font.weight: UI.textWeight; text: "Items here can be restored to where they came from."; color: UI.textDim; font.pixelSize: UI.px(12); Layout.fillWidth: true; elide: Text.ElideRight }
                        GButton { text: "Restore"; iconName: "undo"; enabled: ex.selectedCount > 0; onClicked: ex.restoreSelection() }
                        GButton { text: "Empty"; iconName: "broom"; kind: "danger"; enabled: Storage.trashCount > 0; onClicked: ex.emptyTrash() }
                    }
                }

                Rectangle {   // list header
                    visible: ex.viewMode === "list"
                    Layout.fillWidth: true
                    Layout.preferredHeight: UI.px(30)
                    color: "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        Repeater {
                            model: [
                                { key: "name", label: "Name", w: 0.42 },
                                { key: "modified", label: ex.inTrash ? "Deleted" : "Modified", w: 0.27 },
                                { key: "kind", label: ex.inTrash ? "Original location" : "Type", w: 0.17 },
                                { key: "size", label: "Size", w: 0.14 }
                            ]
                            delegate: MouseArea {
                                width: (parent.width - 12) * modelData.w
                                height: parent.height
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ex.setSort(modelData.key)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label + (ex.sortKey === modelData.key ? (ex.sortDesc ? "  ▾" : "  ▴") : "")
                                    color: ex.sortKey === modelData.key ? UI.text : UI.textDim
                                    font.pixelSize: UI.px(11.5)
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: UI.border }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    DropArea {
                        id: paneDrop
                        anchors.fill: parent
                        onEntered: function (drag) {
                            var ok = UI.wm.canDropOn(drag, ex.path)
                            drag.accepted = ok
                            if (ok) UI.wm.setDropTarget(ex.inTrash ? "Recycle Bin" : UI.wm.folderName(ex.path))
                        }
                        onExited: UI.wm.setDropTarget("")
                        onDropped: function (drop) { if (UI.wm.dropInto(ex.path, drop)) drop.acceptProposedAction() }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: UI.radius
                        visible: paneDrop.containsDrag
                        color: UI.accentFaint
                        border.width: 2
                        border.color: UI.alpha(UI.accent, 0.7)
                    }

                    GridView {
                        id: grid
                        visible: ex.viewMode === "grid"
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        cellWidth: UI.px(108)
                        cellHeight: UI.px(116)
                        model: ex.shown
                        reuseItems: true
                        cacheBuffer: 400
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: GScrollBar {}
                        delegate: Item {
                            id: cell
                            width: grid.cellWidth
                            height: grid.cellHeight
                            readonly property bool sel: ex.selected[modelData.path] === true
                            readonly property bool isCut: ex.cutSet[modelData.path] === true
                            property string thumb: ""
                            function loadThumb() {
                                var k = modelData.kind
                                cell.thumb = (k === "image" || k === "video" || k === "audio") && modelData.ext !== "svg" ? Thumbs.request(modelData.path) : ""
                            }
                            Component.onCompleted: loadThumb()
                            GridView.onReused: loadThumb()
                            Connections { target: Thumbs; function onReady(p, url) { if (p === modelData.path && url) cell.thumb = url } }
                            DropArea {
                                id: cellDrop
                                anchors.fill: parent
                                enabled: modelData.isDir && !ex.inTrash
                                onEntered: function (drag) {
                                    var ok = UI.wm.canDropOn(drag, modelData.path)
                                    drag.accepted = ok
                                    if (ok) UI.wm.setDropTarget(modelData.name)
                                }
                                onExited: UI.wm.setDropTarget("")
                                onDropped: function (drop) { if (UI.wm.dropInto(modelData.path, drop)) drop.acceptProposedAction() }
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: UI.radius
                                color: cellDrop.containsDrag ? UI.accentSoft : cell.sel ? UI.accentSoft : (cellMouse.containsMouse ? UI.hover : "transparent")
                                border.width: cellDrop.containsDrag ? 2 : (cell.sel ? 1 : 0)
                                border.color: cellDrop.containsDrag ? UI.accent : UI.alpha(UI.accent, 0.5)
                            }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                spacing: 6
                                opacity: cell.isCut ? 0.45 : 1
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: UI.px(64); height: UI.px(56)
                                    Icon { anchors.centerIn: parent; visible: thumbImg.status !== Image.Ready; name: modelData.icon; size: UI.px(52) }
                                    Image {
                                        id: thumbImg
                                        anchors.fill: parent
                                        visible: status === Image.Ready
                                        source: cell.thumb
                                        sourceSize.width: 128
                                        sourceSize.height: 112
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                    Rectangle {   // play badge on video thumbnails
                                        visible: thumbImg.visible && modelData.kind === "video"
                                        anchors.centerIn: parent
                                        width: UI.px(22); height: width; radius: width / 2
                                        color: Qt.rgba(0, 0, 0, 0.55)
                                        Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: UI.px(12) }
                                    }
                                }
                                Text {
                                    font.weight: UI.textWeight
                                    width: grid.cellWidth - 12
                                    text: modelData.name
                                    color: UI.text
                                    font.pixelSize: UI.px(12)
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true          // the GridView must not turn a file drag into a scroll
                                property point pressPos: Qt.point(0, 0)
                                property bool dragging: false
                                property bool deferSelect: false
                                onPressed: function (mouse) {
                                    pressPos = Qt.point(mouse.x, mouse.y)
                                    dragging = false
                                    // pressing an already-selected item keeps the multi-selection so it can be dragged
                                    deferSelect = cell.sel && mouse.modifiers === Qt.NoModifier
                                    if (!deferSelect) ex.clickItem(index, mouse.modifiers)
                                }
                                onPositionChanged: function (mouse) {
                                    if (!(mouse.buttons & Qt.LeftButton) || ex.inTrash) return
                                    var p = mapToItem(null, mouse.x, mouse.y)
                                    if (!dragging) {
                                        if (Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) < 8) return
                                        dragging = true
                                        ex.startDrag(modelData, p.x, p.y)
                                    }
                                    UI.wm.moveFileDrag(p.x, p.y, mouse.modifiers)
                                }
                                onReleased: function (mouse) {
                                    if (dragging) {
                                        dragging = false
                                        var p = mapToItem(null, mouse.x, mouse.y)
                                        UI.wm.endFileDrag(p.x, p.y, mouse.modifiers)
                                    } else if (deferSelect) {
                                        ex.clickItem(index, 0)
                                    }
                                }
                                onCanceled: { if (dragging) { dragging = false; UI.wm.cancelFileDrag() } }
                                onDoubleClicked: function (mouse) { if (mouse.button === Qt.LeftButton) ex.open(modelData) }
                            }
                        }
                    }

                    ListView {
                        id: list
                        visible: ex.viewMode === "list"
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: ex.shown
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: GScrollBar {}
                        delegate: Rectangle {
                            id: row
                            width: list.width
                            height: UI.px(32)
                            radius: UI.radiusSmall
                            readonly property bool sel: ex.selected[modelData.path] === true
                            color: rowDrop.containsDrag || sel ? UI.accentSoft : (rowMouse.containsMouse ? UI.hover : "transparent")
                            border.width: rowDrop.containsDrag ? 2 : 0
                            border.color: UI.accent
                            opacity: ex.cutSet[modelData.path] === true ? 0.45 : 1
                            readonly property real usable: width - 16
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                Row {
                                    width: row.usable * 0.42
                                    rightPadding: 12
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Icon { name: modelData.icon; size: UI.px(15); anchors.verticalCenter: parent.verticalCenter }
                                    Text { font.weight: UI.textWeight; width: parent.width - 30; text: modelData.name; color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text { font.weight: UI.textWeight; width: row.usable * 0.27; rightPadding: 12; text: UI.fmtDate(ex.inTrash ? modelData.deletedAt : modelData.modified); color: UI.textDim; font.pixelSize: UI.px(12); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    font.weight: UI.textWeight
                                    width: row.usable * 0.17
                                    rightPadding: 12
                                    text: ex.inTrash ? (Storage.parentOf(modelData.originalPath || "/Documents/x") || "/")
                                                     : (modelData.isDir ? "Folder" : (modelData.ext ? modelData.ext.toUpperCase() : modelData.kind))
                                    color: UI.textDim; font.pixelSize: UI.px(12); elide: Text.ElideMiddle
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text { font.weight: UI.textWeight; width: row.usable * 0.14; elide: Text.ElideRight; text: modelData.isDir ? "" : UI.fmtSize(modelData.size); color: UI.textDim; font.pixelSize: UI.px(12); anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                property point pressPos: Qt.point(0, 0)
                                property bool dragging: false
                                property bool deferSelect: false
                                onPressed: function (mouse) {
                                    pressPos = Qt.point(mouse.x, mouse.y)
                                    dragging = false
                                    deferSelect = row.sel && mouse.modifiers === Qt.NoModifier
                                    if (!deferSelect) ex.clickItem(index, mouse.modifiers)
                                }
                                onPositionChanged: function (mouse) {
                                    if (!(mouse.buttons & Qt.LeftButton) || ex.inTrash) return
                                    var p = mapToItem(null, mouse.x, mouse.y)
                                    if (!dragging) {
                                        if (Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) < 8) return
                                        dragging = true
                                        ex.startDrag(modelData, p.x, p.y)
                                    }
                                    UI.wm.moveFileDrag(p.x, p.y, mouse.modifiers)
                                }
                                onReleased: function (mouse) {
                                    if (dragging) {
                                        dragging = false
                                        var p = mapToItem(null, mouse.x, mouse.y)
                                        UI.wm.endFileDrag(p.x, p.y, mouse.modifiers)
                                    } else if (deferSelect) {
                                        ex.clickItem(index, 0)
                                    }
                                }
                                onCanceled: { if (dragging) { dragging = false; UI.wm.cancelFileDrag() } }
                                onDoubleClicked: function (mouse) { if (mouse.button === Qt.LeftButton) ex.open(modelData) }
                            }
                            DropArea {
                                id: rowDrop
                                anchors.fill: parent
                                enabled: modelData.isDir && !ex.inTrash
                                onEntered: function (drag) {
                                    var ok = UI.wm.canDropOn(drag, modelData.path)
                                    drag.accepted = ok
                                    if (ok) UI.wm.setDropTarget(modelData.name)
                                }
                                onExited: UI.wm.setDropTarget("")
                                onDropped: function (drop) { if (UI.wm.dropInto(modelData.path, drop)) drop.acceptProposedAction() }
                            }
                        }
                    }

                    Column {
                        visible: ex.shown.length === 0
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: ex.filter ? "search" : (ex.inTrash ? "place-trash" : "place-folder"); size: 64; opacity: 0.85 }
                        Text {
                            font.weight: UI.textWeight
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ex.filter ? "Nothing matches “" + ex.filter + "”" : (ex.inTrash ? "The Recycle Bin is empty" : "This folder is empty")
                            color: UI.textDim; font.pixelSize: UI.px(13)
                        }
                        Text {
                            font.weight: UI.textWeight
                            visible: !ex.filter && !ex.inTrash
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Right-click to create a folder or file"
                            color: UI.textFaint; font.pixelSize: UI.px(11.5)
                        }
                    }

                    // Routes clicks: presses on items fall through to the delegates,
                    // presses on empty space clear the selection / open the folder menu.
                    MouseArea {
                        id: bgMouse
                        anchors.fill: parent
                        z: 10
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        function indexAtPoint(mx, my) {
                            var v = ex.viewMode === "grid" ? grid : list
                            return v.indexAt(mx - v.x + v.contentX, my - v.y + v.contentY)
                        }

                        // ---- drag on empty space: selection rectangle
                        property bool banding: false
                        property bool bandShown: false
                        property real startX: 0      // band start in *content* coordinates (survives scrolling)
                        property real startY: 0
                        property real curX: 0
                        property real curY: 0
                        property var baseSel: ({})
                        function activeView() { return ex.viewMode === "grid" ? grid : list }
                        function updateBand() {
                            var v = activeView()
                            var x1 = startX, y1 = startY
                            var x2 = curX - v.x + v.contentX, y2 = curY - v.y + v.contentY
                            var L = Math.min(x1, x2), R = Math.max(x1, x2), T = Math.min(y1, y2), B = Math.max(y1, y2)
                            var s = Object.assign({}, baseSel), items = ex.shown
                            if (v === grid) {
                                var cw = grid.cellWidth, ch = grid.cellHeight
                                var cols = Math.max(1, Math.floor(grid.width / cw))
                                for (var i = 0; i < items.length; i++) {
                                    var ix = (i % cols) * cw, iy = Math.floor(i / cols) * ch
                                    if (ix + 6 < R && ix + cw - 6 > L && iy + 4 < B && iy + ch - 4 > T) s[items[i].path] = true
                                }
                            } else {
                                var rh = UI.px(32)
                                var first = Math.max(0, Math.floor(T / rh)), last = Math.min(items.length - 1, Math.floor(B / rh))
                                for (var j = first; j <= last; j++) s[items[j].path] = true
                            }
                            ex.selected = s
                            // auto-scroll when dragging past the top/bottom edge
                            var edge = UI.px(28)
                            bandScroll.speed = curY < v.y + edge ? -Math.min(24, (v.y + edge - curY) / 2)
                                             : (curY > v.y + v.height - edge ? Math.min(24, (curY - (v.y + v.height - edge)) / 2) : 0)
                            if (bandScroll.speed !== 0) bandScroll.start(); else bandScroll.stop()
                        }
                        onPositionChanged: function (mouse) {
                            if (!banding) return
                            curX = mouse.x; curY = mouse.y
                            if (!bandShown && Math.abs(curX - (startX - activeView().contentX + activeView().x)) + Math.abs(curY - (startY - activeView().contentY + activeView().y)) > 4) bandShown = true
                            if (bandShown) updateBand()
                        }
                        onReleased: { banding = false; bandShown = false; bandScroll.stop() }
                        onCanceled: { banding = false; bandShown = false; bandScroll.stop() }
                        Timer {
                            id: bandScroll
                            interval: 16
                            repeat: true
                            property real speed: 0
                            onTriggered: {
                                var v = bgMouse.activeView()
                                v.contentY = Math.max(0, Math.min(v.contentY + speed, Math.max(0, v.contentHeight - v.height)))
                                bgMouse.updateBand()
                            }
                        }
                        Rectangle {   // the band itself (follows content as it scrolls)
                            visible: bgMouse.bandShown
                            readonly property var v: bgMouse.activeView()
                            readonly property real sx: bgMouse.startX - v.contentX + v.x
                            readonly property real sy: bgMouse.startY - v.contentY + v.y
                            x: Math.min(sx, bgMouse.curX)
                            y: Math.min(sy, bgMouse.curY)
                            width: Math.abs(bgMouse.curX - sx)
                            height: Math.abs(bgMouse.curY - sy)
                            color: UI.alpha(UI.accent, 0.16)
                            border.color: UI.alpha(UI.accent, 0.75)
                            border.width: 1
                            radius: 3
                        }
                        onPressed: function (mouse) {
                            ex.forceActiveFocus()
                            var idx = indexAtPoint(mouse.x, mouse.y)
                            if (mouse.button === Qt.RightButton) {
                                if (idx >= 0) ex.itemMenu(ex.shown[idx], bgMouse, mouse.x, mouse.y)
                                else ex.backgroundMenu(bgMouse, mouse.x, mouse.y)
                                return
                            }
                            if (idx >= 0) { mouse.accepted = false; return }
                            // empty space: start a selection rectangle (Ctrl keeps the current selection)
                            var v = activeView()
                            startX = mouse.x - v.x + v.contentX
                            startY = mouse.y - v.y + v.contentY
                            curX = mouse.x; curY = mouse.y
                            baseSel = (mouse.modifiers & Qt.ControlModifier) ? Object.assign({}, ex.selected) : ({})
                            if (!(mouse.modifiers & Qt.ControlModifier)) ex.selected = {}
                            banding = true
                            bandShown = false
                        }
                        onWheel: function (wheel) { wheel.accepted = false }
                    }
                }

                // ------------------------------------------------------ status bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: UI.px(26)
                    color: Qt.rgba(0, 0, 0, 0.12)
                    Text {
                        font.weight: UI.textWeight
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: UI.textFaint
                        font.pixelSize: UI.px(11.5)
                        text: {
                            var t = ex.shown.length + (ex.shown.length === 1 ? " item" : " items")
                            if (ex.selectedCount > 0) {
                                var size = 0
                                ex.selectedEntries().forEach(function (e) { size += e.size })
                                t += "   ·   " + ex.selectedCount + " selected" + (size > 0 ? " (" + UI.fmtSize(size) + ")" : "")
                            }
                            if (Storage.canPaste) t += "   ·   " + Storage.clipboardPaths.length + " on clipboard (" + Storage.clipboardMode + ")"
                            return t
                        }
                    }
                }
            }

            // ------------------------------------------------------ details pane
            Rectangle {
                id: details
                visible: ex.showDetails && ex.width > 760
                Layout.fillHeight: true
                Layout.preferredWidth: UI.px(270)
                color: Qt.rgba(0, 0, 0, 0.14)
                Rectangle { width: 1; height: parent.height; color: UI.border }

                readonly property var sel: ex.selectedEntries()
                readonly property var e: sel.length === 1 ? sel[0] : null
                readonly property var info: e ? Storage.quickInfo(e.path) : (sel.length === 0 ? Storage.quickInfo(ex.path) : ({}))
                readonly property string kind: info.kind || ""
                readonly property var meta: e && (kind === "video" || kind === "audio" || kind === "image") ? Thumbs.meta(e.path) : ({})
                readonly property var dims: e && kind === "image" ? Storage.imageSize(e.path) : ({ w: 0, h: 0 })
                readonly property string preview: e && (kind === "text" || kind === "code") ? Storage.textPreview(e.path, 1200) : ""
                property string thumb: ""
                onEChanged: details.thumb = details.e ? Thumbs.request(details.e.path) : ""
                Connections { target: Thumbs; function onReady(p, url) { if (details.e && p === details.e.path) { details.thumb = url; details.metaRev++ } } }
                property int metaRev: 0
                readonly property int totalSize: { var t = 0; sel.forEach(function (x) { t += x.size }); return t }

                function fmtDuration(ms) {
                    if (!(ms > 0)) return ""
                    var s = Math.round(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
                    return (h ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (x < 10 ? "0" : "") + x
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    contentHeight: dcol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: dcol
                        width: parent.width
                        spacing: 12

                        // preview area
                        Rectangle {
                            width: parent.width
                            height: width * 0.68
                            radius: UI.radius
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.color: UI.border
                            clip: true
                            Image {
                                id: dImg
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: details.thumb !== "" && status === Image.Ready
                                source: details.kind === "image" && details.e ? Storage.fileUrl(details.e.path) : details.thumb
                                sourceSize.width: 540
                                fillMode: details.kind === "audio" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Rectangle {
                                visible: dImg.visible && details.kind === "video"
                                anchors.centerIn: parent
                                width: 44; height: 44; radius: 22
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; name: "play"; size: 22 }
                            }
                            Text {
                                font.weight: UI.textWeight
                                visible: details.preview !== ""
                                anchors.fill: parent
                                anchors.margins: 10
                                // code gets syntax colors; plain text stays plain
                                readonly property string codePath: details.e && Syntax.languageFor(details.e.path) !== "" ? details.e.path : ""
                                text: codePath !== "" ? Syntax.toHtml(details.preview, codePath, 40) : details.preview
                                textFormat: codePath !== "" ? Text.RichText : Text.PlainText
                                color: UI.textDim
                                font.family: UI.monoFont
                                font.pixelSize: UI.px(10)
                                wrapMode: Text.WrapAnywhere
                                clip: true
                            }
                            Icon {
                                visible: !dImg.visible && details.preview === ""
                                anchors.centerIn: parent
                                name: details.sel.length > 1 ? "file-generic" : (details.info.icon || "place-folder")
                                size: parent.height * 0.55
                            }
                            Rectangle {
                                visible: details.sel.length > 1
                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                                width: countText.implicitWidth + 16; height: 24; radius: 12
                                color: UI.accent
                                Text { id: countText; anchors.centerIn: parent; text: details.sel.length; color: UI.accentText; font.bold: true; font.pixelSize: UI.px(12) }
                            }
                        }

                        Text {
                            width: parent.width
                            text: details.sel.length > 1 ? details.sel.length + " items selected"
                                  : (details.sel.length === 0 && ex.path === "/" ? "Home" : (details.info.name || ex.path.split("/").pop()))
                            color: UI.text
                            font.pixelSize: UI.px(15)
                            font.weight: Font.DemiBold
                            wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            elide: Text.ElideRight
                            font.weight: UI.textWeight
                            width: parent.width
                            text: details.sel.length > 1 ? "Total " + UI.fmtSize(details.totalSize) : (details.info.typeName || "")
                            color: UI.textDim
                            font.pixelSize: UI.px(12)
                        }
                        Rectangle { width: parent.width; height: 1; color: UI.border; visible: details.sel.length <= 1 }

                        Repeater {
                            model: {
                                var r = details.metaRev, i = details.info, rows = []
                                if (details.sel.length > 1 || !i.path) return rows
                                if (!i.isDir) rows.push(["Size", UI.fmtSize(i.size)])
                                if (i.isDir) rows.push(["Contains", i.items + (i.items === 1 ? " item" : " items")])
                                if (details.dims.w > 0) rows.push(["Dimensions", details.dims.w + " × " + details.dims.h])
                                else if (details.meta.width > 0) rows.push(["Resolution", details.meta.width + " × " + details.meta.height])
                                if (details.meta.duration > 0) rows.push(["Length", details.fmtDuration(details.meta.duration)])
                                if (ex.inTrash && i.originalPath) {
                                    rows.push(["Original location", Storage.parentOf(i.originalPath)])
                                    rows.push(["Deleted", UI.fmtDate(i.deletedAt)])
                                } else {
                                    rows.push(["Modified", UI.fmtDate(i.modified)])
                                    if (i.created) rows.push(["Created", UI.fmtDate(i.created)])
                                    if (i.path !== "/" && i.location) rows.push(["Location", i.location === "/" ? "Home" : i.location])
                                }
                                return rows
                            }
                            delegate: Column {
                                width: dcol.width
                                spacing: 1
                                Text { font.weight: UI.textWeight; text: modelData[0]; color: UI.textFaint; font.pixelSize: UI.px(11) }
                                Text { font.weight: UI.textWeight; width: parent.width; text: modelData[1]; color: UI.text; font.pixelSize: UI.px(12.5); wrapMode: Text.WrapAnywhere }
                            }
                        }

                        Row {
                            spacing: 6
                            visible: details.e !== null
                            GButton { text: ex.inTrash ? "Restore" : "Open"; kind: "primary"; onClicked: if (details.e) ex.inTrash ? ex.restorePaths([details.e.path]) : ex.open(details.e) }
                            GButton { visible: !ex.inTrash && details.e !== null && !details.e.isDir; text: "Open with…"; onClicked: if (details.e) ex.openWithMenu(details.e, this) }
                        }
                    }
                }
            }
        }
    }

    ArchiveView { id: archiveView; onExtractRequested: function (p) { ex.extractArchive(p) } }
    GMenu { id: menu }
    GDialog { id: dialog }
}
