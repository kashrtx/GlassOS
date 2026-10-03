// Frosted-glass panel. Samples the blurred wallpaper rendered by Python at the
// panel's scene position, so it looks like real background blur at ~zero cost.
// Bind sceneX/sceneY to the panel's position in window (scene) coordinates.
import QtQuick
import QtQuick.Effects
import "../ui"

Item {
    id: surf
    property real radius: UI.radius
    property real sceneX: 0
    property real sceneY: 0
    property color tint: UI.surface
    property color borderColor: UI.border
    property bool showBorder: true

    // Frosted glass needs the GPU mask effect for rounded corners; the software
    // renderer (--software) gets the solid surface instead.
    readonly property bool frosted: UI.glass && UI.blurUrl !== "" && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool rounded: radius > 0.5

    Rectangle {   // solid fallback (and the base while the blur image loads)
        anchors.fill: parent
        radius: surf.radius
        color: surf.frosted ? UI.rim : UI.surfaceOpaque
    }

    // the frosted layer: wallpaper blur sampled at our scene position + tint
    Item {
        id: frost
        anchors.fill: parent
        clip: !surf.rounded          // square surfaces just clip; rounded ones are masked below
        visible: surf.frosted && !surf.rounded
        layer.enabled: surf.frosted && surf.rounded
        Image {
            x: -surf.sceneX
            y: -surf.sceneY
            width: UI.sceneWidth
            height: UI.sceneHeight
            source: surf.frosted ? UI.blurUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
        Rectangle { anchors.fill: parent; color: surf.tint }
    }
    Rectangle {   // rounded mask shape
        id: shape
        anchors.fill: parent
        radius: surf.radius
        visible: false
        layer.enabled: surf.frosted && surf.rounded
    }
    MultiEffect {   // glass clipped exactly to the rounded outline: no dark rim, no square corners
        anchors.fill: parent
        visible: surf.frosted && surf.rounded
        source: frost
        maskEnabled: true
        maskSource: shape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: surf.radius
        color: "transparent"
        border.width: surf.showBorder ? 1 : 0
        border.color: surf.borderColor
    }
}
