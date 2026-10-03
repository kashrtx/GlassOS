// Keyboard shortcut cheat sheet (F1).
import QtQuick
import QtQuick.Controls
import "../ui"

Popup {
    id: help
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(UI.px(760), parent ? parent.width - 40 : 760)
    height: Math.min(UI.px(560), parent ? parent.height - 60 : 560)
    padding: 22
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(140) } }
    background: Rectangle { radius: UI.radiusLarge; color: "#151a26"; border.color: UI.borderStrong }

    readonly property var groups: [
        { title: "Desktop", keys: [["Ctrl+Space", "Start & search"], ["Alt+Tab", "Switch windows"], ["Ctrl+Alt+D", "Show desktop"],
                                   ["Ctrl+Alt+L", "Lock"], ["Ctrl+Alt+V", "Clipboard history"], ["Print / Ctrl+Alt+S", "Screenshot"],
                                   ["Alt+Print", "Screenshot of the active window"], ["F11", "Full screen"], ["Ctrl+Q", "Shut down"], ["F1", "This help"]] },
        { title: "Windows & workspaces", keys: [["Ctrl+Alt+← / →", "Snap left / right"], ["Ctrl+Alt+↑ / ↓", "Maximize, or snap to a quarter"],
                                   ["Hover maximize", "Snap layouts (halves, quarters, thirds)"], ["Ctrl+Alt+W", "Close window"],
                                   ["Ctrl+Alt+1…4", "Go to workspace"], ["Ctrl+Alt+Shift+1…4", "Move window to workspace"],
                                   ["Ctrl+Alt+PgUp / PgDn", "Previous / next workspace"]] },
        { title: "Apps", keys: [["Ctrl+Alt+T", "Terminal"], ["Ctrl+Alt+E", "Files"], ["Ctrl+T / Ctrl+W", "Browser tab: new / close"],
                                ["Ctrl+Shift+T", "Reopen closed tab"], ["F12", "Developer tools"], ["Space / ← →", "Media: play-pause / seek"],
                                ["Ctrl+S / Ctrl+F", "GlassPad: save / find"]] },
        { title: "Files", keys: [["Ctrl+C / X / V", "Copy, cut, paste (works with your computer too)"], ["Drag", "Move (hold Ctrl to copy)"],
                                 ["Del", "Recycle Bin"], ["F2", "Rename"], ["Ctrl+Shift+N", "New folder"], ["Backspace", "Up a folder"]] }
    ]

    contentItem: Flickable {
        contentHeight: cols.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: cols
            width: parent.width
            spacing: 16
            Row {
                spacing: 10
                Icon { name: "keyboard"; size: UI.px(22); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Keyboard shortcuts"; color: UI.text; font.pixelSize: UI.px(18); font.weight: Font.DemiBold }
            }
            Grid {
                columns: help.width > 640 ? 2 : 1
                columnSpacing: 26
                rowSpacing: 18
                width: parent.width
                Repeater {
                    model: help.groups
                    Column {
                        width: (cols.width - (help.width > 640 ? 26 : 0)) / (help.width > 640 ? 2 : 1)
                        spacing: 6
                        SectionTitle { text: modelData.title }
                        Repeater {
                            model: modelData.keys
                            Row {
                                width: parent.width
                                Text { font.weight: UI.textWeight; width: parent.width * 0.45; text: modelData[0]; color: UI.accent; font.pixelSize: UI.px(12); font.family: UI.monoFont; elide: Text.ElideRight }
                                Text { font.weight: UI.textWeight; width: parent.width * 0.55; text: modelData[1]; color: UI.textDim; font.pixelSize: UI.px(12); wrapMode: Text.Wrap }
                            }
                        }
                    }
                }
            }
        }
    }
}
