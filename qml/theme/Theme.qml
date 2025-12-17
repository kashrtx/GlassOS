// GlassOS Theme Singleton
// Provides theme values to all QML components

pragma Singleton
import QtQuick

QtObject {
    id: theme
    
    // Glass effect settings
    readonly property int blurRadius: 40
    readonly property real blurOpacity: 0.75
    readonly property color glassTint: "#1a1a2e"
    readonly property real glassTintOpacity: 0.6
    
    // Accent colors
    readonly property color accentColor: "#00b4d8"
    readonly property color accentGlow: "#48cae4"
    readonly property color highlightColor: "#90e0ef"
    
    // Window colors
    readonly property color windowBorderColor: "#4cc9f0"
    readonly property real windowBorderOpacity: 0.8
    readonly property color windowShadowColor: "#000000"
    readonly property real windowShadowOpacity: 0.5
    
    // Text colors
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#b0b0b0"
    readonly property color textDisabled: "#666666"
    
    // Taskbar settings
    readonly property int taskbarHeight: 48
    readonly property int taskbarBlur: 50
    readonly property color taskbarTint: "#0a0a15"
    readonly property real taskbarOpacity: 0.85
    
    // Animation settings
    readonly property int animationDuration: 250
    readonly property bool enableAnimations: true
    readonly property bool enableBlur: true
    
    // Spacing and sizing
    readonly property int spacing: 8
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12
    readonly property int radiusXLarge: 16
    
    // Font sizes
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeMedium: 13
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeXLarge: 20
    readonly property int fontSizeHeading: 24
    
    // Shadows
    readonly property real shadowOpacity: 0.3
    readonly property int shadowRadius: 20
    readonly property int shadowOffset: 4
}
