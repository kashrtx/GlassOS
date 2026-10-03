.pragma library
// GlassOS app registry. `source` is relative to qml/Main.qml.
var list = [
    { id: "AeroExplorer", name: "Files",        icon: "app-files", color: "#f5b942", source: "apps/Explorer.qml",    w: 940,  h: 580, minW: 520, minH: 340, desc: "Browse and manage your files" },
    { id: "AeroBrowser",  name: "AeroBrowser",  icon: "app-browser", color: "#4c9bff", source: "apps/Browser.qml",     w: 1120, h: 720, minW: 480, minH: 320, desc: "Browse the web", needsWeb: true },
    { id: "GlassPad",     name: "GlassPad",     icon: "app-notepad", color: "#fb923c", source: "apps/Notepad.qml",     w: 780,  h: 560, minW: 360, minH: 260, desc: "Write notes and edit text" },
    { id: "Terminal",     name: "Terminal",     icon: "app-terminal", color: "#34d399", source: "apps/Terminal.qml",    w: 780,  h: 480, minW: 380, minH: 220, desc: "GlassShell command line" },
    { id: "MediaPlayer",  name: "Media Player", icon: "app-media", color: "#f43f5e", source: "apps/MediaApp.qml",  w: 980,  h: 620, minW: 480, minH: 360, desc: "Watch videos and play music", needsMedia: true, single: true },
    { id: "Calculator",   name: "Calculator",   icon: "app-calculator", color: "#22c55e", source: "apps/Calculator.qml",  w: 380,  h: 600, minW: 320, minH: 480, desc: "Scientific calculator" },
    { id: "Weather",      name: "Weather",      icon: "app-weather", color: "#38bdf8", source: "apps/Weather.qml",     w: 820,  h: 620, minW: 420, minH: 420, desc: "Live forecast worldwide" },
    { id: "ImageViewer",  name: "Photos",       icon: "app-photos", color: "#f472b6", source: "apps/ImageViewer.qml", w: 900,  h: 620, minW: 360, minH: 280, desc: "View your pictures" },
    { id: "TaskManager",  name: "Task Manager", icon: "app-taskmanager", color: "#a78bfa", source: "apps/TaskManager.qml", w: 720,  h: 520, minW: 420, minH: 320, desc: "Windows and system resources", single: true },
    { id: "Snake",        name: "Snake",        icon: "app-snake", color: "#84cc16", source: "apps/Snake.qml",       w: 560,  h: 620, minW: 420, minH: 480, desc: "The classic, glassified" },
    { id: "Settings",     name: "Settings",     icon: "app-settings", color: "#94a3b8", source: "apps/Settings.qml",    w: 920,  h: 620, minW: 560, minH: 420, desc: "Personalize GlassOS", single: true }
]

var defaultPinned = ["AeroExplorer", "AeroBrowser", "MediaPlayer", "GlassPad", "Terminal", "Settings"]

function get(id) {
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
    return null
}

function search(q) {
    q = (q || "").toLowerCase().trim()
    if (!q) return list
    return list.filter(function (a) {
        return a.name.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0
            || a.desc.toLowerCase().indexOf(q) >= 0
    })
}

// Which app opens a file of this kind (see core/storage.py kinds)
function appForKind(kind) {
    if (kind === "folder") return "AeroExplorer"
    if (kind === "image") return "ImageViewer"
    if (kind === "pdf") return HasWebEngineHint ? "AeroBrowser" : "GlassPad"
    return "GlassPad"
}
var HasWebEngineHint = false
