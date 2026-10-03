// A site icon on a light chip, so dark favicons (GitHub, X, Apple...) stay visible on glass.
import QtQuick

Rectangle {
    id: chip
    property url source
    property real size: 16
    readonly property bool ready: img.status === Image.Ready
    width: size + 4
    height: size + 4
    radius: 4
    color: Qt.rgba(1, 1, 1, 0.92)
    Image {
        id: img
        anchors.centerIn: parent
        width: chip.size
        height: chip.size
        source: chip.source
        sourceSize: Qt.size(chip.size * 2, chip.size * 2)
        asynchronous: true
        smooth: true
    }
}
