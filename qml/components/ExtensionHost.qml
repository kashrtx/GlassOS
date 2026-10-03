// Drives Qt WebEngine's extension manager from QML.
// Why QML: PySide6 6.10 can't convert QWebEngineExtensionInfo to Python, and
// receiving one there crashes the process. QML talks to Qt directly.
// Loaded only when Chrome extensions (experimental) are switched on.
import QtQuick
import "../ui"

Item {
    id: host
    property var mgr: null
    property var items: []
    property string problem: ""
    property var disabled: UI.arr(Prefs.value("browser.extensions.disabled", [])).filter(function (x) { return typeof x === "string" })
    readonly property var builtin: ["mhjfbmdgcfjbbpaeojofohoefgiehjai", "nkeimhogjdpnpccoofpliimaahmaaome"]   // Chromium PDF, Hangouts
    signal notify(string title, string body)

    Component.onCompleted: Qt.callLater(init)

    function init() {
        Extensions.markActive()   // crash guard: if we die from here on, extensions get switched off
        try { mgr = BrowserProfile ? BrowserProfile.extensionManager : null } catch (e) { mgr = null }
        if (!mgr) { problem = "This Qt build has no extension manager (needs Qt WebEngine 6.10+)."; return }
        refresh()
        startupEnable.start()
    }
    function raw() {
        if (!mgr) return []
        try { var l = mgr.extensions; return l ? l : [] } catch (e) { problem = "Couldn't list extensions: " + e; return [] }
    }
    function describe(e) {
        return { id: String(e.id), name: String(e.name || "Extension"), description: String(e.description || ""),
                 popup: e.actionPopupUrl ? e.actionPopupUrl.toString() : "", enabled: e.isEnabled === true,
                 loaded: e.isLoaded === true, installed: e.isInstalled === true, error: String(e.error || "") }
    }
    function refresh() {
        var out = [], list = raw()
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || typeof e.id !== "string") { problem = "This Qt build can't show extension details to QML."; continue }
            if (builtin.indexOf(e.id) >= 0) continue
            out.push(describe(e))
        }
        items = out
    }
    function find(id) {
        var l = raw()
        for (var i = 0; i < l.length; i++) if (l[i] && l[i].id === id) return l[i]
        return null
    }
    function enableIfWanted(e) {
        // Qt loads every extension disabled; switch on everything the user hasn't turned off
        if (!e || typeof e.id !== "string" || builtin.indexOf(e.id) >= 0 || e.isLoaded !== true || e.isEnabled === true) return
        if (disabled.indexOf(e.id) >= 0) return
        try { mgr.setExtensionEnabled(e, true) } catch (x) { console.warn("enable extension:", x) }
    }
    function setEnabled(id, on) {
        var e = find(id)
        if (!e) return
        var d = disabled.filter(function (x) { return x !== id })
        if (!on) d.push(id)
        disabled = d
        Prefs.setValue("browser.extensions.disabled", d)
        try { mgr.setExtensionEnabled(e, on) } catch (x) { console.warn("toggle extension:", x) }
        refreshTimer.restart()
    }
    function remove(id) {
        var e = find(id)
        if (!e) return
        try { if (e.isInstalled === true) mgr.uninstallExtension(e); else mgr.unloadExtension(e) } catch (x) { console.warn("remove extension:", x) }
        refreshTimer.restart()
    }
    function install(path) {
        if (!mgr) { notify("Extensions unavailable", problem); return }
        try { mgr.installExtension(path) } catch (x) { notify("Couldn't install the extension", String(x)) }
    }

    Timer { id: refreshTimer; interval: 150; onTriggered: host.refresh() }
    Timer {   // extensions installed earlier are auto-loaded (disabled) once the profile is up
        id: startupEnable
        interval: 2500
        onTriggered: { var l = host.raw(); for (var i = 0; i < l.length; i++) host.enableIfWanted(l[i]); host.refresh() }
    }
    Connections {
        target: host.mgr
        ignoreUnknownSignals: true
        function onLoadFinished(ext) {
            host.enableIfWanted(ext)
            if (ext && ext.error) host.notify("Extension problem", ext.name + ": " + ext.error)
            refreshTimer.restart()
        }
        function onInstallFinished(ext) {
            host.enableIfWanted(ext)
            if (ext && ext.error) host.notify("Couldn't install the extension", ext.error)
            else if (ext) host.notify("Extension installed", ext.name)
            refreshTimer.restart()
        }
        function onUnloadFinished(ext) { refreshTimer.restart() }
        function onUninstallFinished(ext) { refreshTimer.restart() }
    }
    Connections {
        target: Extensions
        function onInstallReady(path, name) { host.install(path) }
    }
}
