// GlassOS design system + shared state. Main.qml binds the live values
// (accent, text scale, effects, clock format, window manager) into it.
pragma Singleton
import QtQuick

QtObject {
    id: ui

    // ----- live values (bound by Main.qml) -----
    property var wm: null                 // the window manager (Main.qml root)
    property color accent: "#4cc2ff"
    property real textScale: 1.0
    property bool animations: true
    property bool glass: true
    property bool use24h: false
    property bool bold: true              // "Bold text" accessibility option
    property string tempUnit: "C"         // bound to Prefs.weatherUnit in Main.qml
    // Celsius in, display string out ("10°C" / "50°F"); the only place that converts
    function temp(c, withUnit) {
        if (c === undefined || c === null || isNaN(c)) return "–"
        return Math.round(tempUnit === "F" ? c * 9 / 5 + 32 : c) + "°" + (withUnit === false ? "" : tempUnit)
    }
    readonly property int textWeight: bold ? Font.DemiBold : Font.Normal
    property string monoFont: "monospace"
    property string blurUrl: ""           // frosted wallpaper rendered by Python
    property real sceneWidth: 1920
    property real sceneHeight: 1080

    // ----- clock (one timer for the whole shell) -----
    // Nothing in the shell shows seconds, so `now` only changes when the minute
    // does: every time-dependent binding re-evaluates once a minute, not once a second.
    property date now: new Date()
    property Timer clockTimer: Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            if (d.getMinutes() !== ui.now.getMinutes() || d.getHours() !== ui.now.getHours()
                    || d.getDate() !== ui.now.getDate()) ui.now = d
        }
    }

    // ----- palette -----
    readonly property color text: "#f2f5fa"
    readonly property color textDim: "#aab4c5"
    readonly property color textFaint: "#6e7a8e"
    readonly property color surface: Qt.rgba(0.075, 0.09, 0.13, 0.62)       // tint over frosted glass
    readonly property color surfaceOpaque: Qt.rgba(0.075, 0.09, 0.13, 0.94) // when glass is off
    readonly property color rim: Qt.rgba(0.06, 0.07, 0.10, 0.92)
    readonly property color card: Qt.rgba(1, 1, 1, 0.045)
    readonly property color cardStrong: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.075)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.13)
    readonly property color border: Qt.rgba(1, 1, 1, 0.09)
    readonly property color borderStrong: Qt.rgba(1, 1, 1, 0.17)
    readonly property color field: Qt.rgba(0, 0, 0, 0.28)
    readonly property color danger: "#f87171"
    readonly property color success: "#4ade80"
    readonly property color warning: "#fbbf24"
    readonly property color accentText: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.62 ? "#0b1020" : "#ffffff"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color accentFaint: Qt.rgba(accent.r, accent.g, accent.b, 0.12)

    // ----- metrics -----
    readonly property int radius: 10
    readonly property int radiusSmall: 6
    readonly property int radiusLarge: 14
    readonly property int taskbarHeight: 52

    // ----- window snapping -----
    // Every snap zone as [x, y, w, h] fractions of the work area. Windows, the
    // Snap Layouts picker and Snap Assist all use this one table.
    readonly property var zones: ({
        "max": [0, 0, 1, 1], "left": [0, 0, 0.5, 1], "right": [0.5, 0, 0.5, 1],
        "top": [0, 0, 1, 0.5], "bottom": [0, 0.5, 1, 0.5],
        "tl": [0, 0, 0.5, 0.5], "tr": [0.5, 0, 0.5, 0.5], "bl": [0, 0.5, 0.5, 0.5], "br": [0.5, 0.5, 0.5, 0.5],
        "l3": [0, 0, 1 / 3, 1], "c3": [1 / 3, 0, 1 / 3, 1], "r3": [2 / 3, 0, 1 / 3, 1],
        "l23": [0, 0, 2 / 3, 1], "r13": [2 / 3, 0, 1 / 3, 1]
    })
    readonly property var snapLayouts: [
        ["left", "right"], ["tl", "tr", "bl", "br"], ["top", "bottom"], ["l3", "c3", "r3"], ["l23", "r13"]
    ]
    function zoneFrac(zone) { return zones[zone] || null }
    function layoutFor(zone) {
        for (var i = 0; i < snapLayouts.length; i++) if (snapLayouts[i].indexOf(zone) >= 0) return snapLayouts[i]
        return null
    }

    // ----- helpers -----
    // Settings written by older versions (or edited by hand) may hold the wrong type;
    // these keep a malformed value from breaking an app.
    // NB: PySide turns a Python list of strings into QStringList, which QML exposes as a
    // *sequence* object: array-like, but Array.isArray() is false. Copy those into real arrays.
    function isList(v) { return Array.isArray(v) || (v !== null && v !== undefined && typeof v === "object" && typeof v.length === "number" && typeof v !== "string") }
    function arr(v) {
        if (Array.isArray(v)) return v
        if (!isList(v)) return []
        var out = []
        for (var i = 0; i < v.length; i++) out.push(v[i])
        return out
    }
    function obj(v) { return (v !== null && typeof v === "object" && !isList(v)) ? v : ({}) }
    function px(n) { return Math.round(n * textScale) }
    function dur(ms) { return animations ? ms : 0 }
    function alpha(c, a) { var k = Qt.lighter(c, 1.0); return Qt.rgba(k.r, k.g, k.b, a) }

    function timeText(d) { return Qt.formatTime(d, use24h ? "HH:mm" : "h:mm AP") }
    function dateText(d) { return Qt.formatDate(d, "ddd, MMM d") }

    function fmtSize(bytes) {
        if (bytes === undefined || bytes === null) return ""
        if (bytes < 1024) return bytes + " B"
        var units = ["KB", "MB", "GB", "TB"], v = bytes / 1024, i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
        return (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i]
    }

    function fmtDate(ms) {
        if (!ms) return ""
        var d = new Date(ms), today = new Date()
        if (d.toDateString() === today.toDateString()) return "Today " + timeText(d)
        return Qt.formatDate(d, "MMM d, yyyy") + " " + timeText(d)
    }

    function greeting() {
        var h = now.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
}
