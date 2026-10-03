import QtQuick
import QtQuick.Controls
import "../ui"
import "../components"

FocusScope {
    id: game
    property var hostWindow: null
    readonly property int cols: 22
    readonly property int rows: 22
    property var snake: []
    property var dir: ({ x: 1, y: 0 })
    property var queued: []          // buffered turns so quick key combos aren't lost
    property var food: ({ x: 5, y: 5 })
    property int score: 0
    property int best: Prefs.value("snake.best", 0)
    property string phase: "ready"   // ready | playing | paused | over
    readonly property real cell: Math.floor(Math.min(board.width, board.height) / cols)

    Component.onCompleted: { reset(); game.forceActiveFocus() }
    onVisibleChanged: if (!visible && phase === "playing") phase = "paused"
    // pause when the window loses focus
    readonly property bool windowActive: hostWindow ? hostWindow.active : true
    onWindowActiveChanged: if (!windowActive && phase === "playing") phase = "paused"

    function reset() {
        var cx = Math.floor(cols / 2), cy = Math.floor(rows / 2)
        snake = [{ x: cx, y: cy }, { x: cx - 1, y: cy }, { x: cx - 2, y: cy }]
        dir = { x: 1, y: 0 }
        queued = []
        score = 0
        placeFood()
        canvas.requestPaint()
    }
    function placeFood() {
        var free = []
        for (var x = 0; x < cols; x++) for (var y = 0; y < rows; y++) {
            var hit = false
            for (var i = 0; i < snake.length; i++) if (snake[i].x === x && snake[i].y === y) { hit = true; break }
            if (!hit) free.push({ x: x, y: y })
        }
        food = free.length ? free[Math.floor(Math.random() * free.length)] : { x: -1, y: -1 }
    }
    function turn(dx, dy) {
        if (phase === "ready" || phase === "over") { if (phase === "over") reset(); phase = "playing" }
        else if (phase === "paused") phase = "playing"
        var last = queued.length ? queued[queued.length - 1] : dir
        if (last.x === -dx && last.y === -dy) return     // no instant reversal
        if (last.x === dx && last.y === dy) return
        if (queued.length < 3) queued = queued.concat([{ x: dx, y: dy }])
    }
    function tick() {
        if (queued.length) { dir = queued[0]; queued = queued.slice(1) }
        var head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y }
        var dead = head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows
        for (var i = 0; i < snake.length - 1 && !dead; i++) if (snake[i].x === head.x && snake[i].y === head.y) dead = true
        if (dead) {
            phase = "over"
            if (score > best) { best = score; Prefs.setValue("snake.best", best) }
            canvas.requestPaint()
            return
        }
        var s = [head].concat(snake)
        if (head.x === food.x && head.y === food.y) { score += 10; placeFood(); pop.restart() }
        else s.pop()
        snake = s
        canvas.requestPaint()
    }

    Keys.onPressed: function (event) {
        var k = event.key
        if (k === Qt.Key_Up || k === Qt.Key_W) turn(0, -1)
        else if (k === Qt.Key_Down || k === Qt.Key_S) turn(0, 1)
        else if (k === Qt.Key_Left || k === Qt.Key_A) turn(-1, 0)
        else if (k === Qt.Key_Right || k === Qt.Key_D) turn(1, 0)
        else if (k === Qt.Key_Space || k === Qt.Key_P) { if (phase === "playing") phase = "paused"; else if (phase === "paused") phase = "playing" }
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) { reset(); phase = "playing" }
        else return
        event.accepted = true
    }

    Timer {
        interval: Math.max(55, 140 - game.score / 10 * 4)
        repeat: true
        running: game.phase === "playing"
        onTriggered: game.tick()
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.04, 0.03, 0.55) }

    Row {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        spacing: 28
        Column {
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: game.score; color: "#a3e635"; font.pixelSize: UI.px(26); font.bold: true; scale: pop.running ? 1.25 : 1; Behavior on scale { NumberAnimation { duration: 120 } } }
            Text { font.weight: UI.textWeight; anchors.horizontalCenter: parent.horizontalCenter; text: "SCORE"; color: UI.textFaint; font.pixelSize: UI.px(10); font.letterSpacing: 1.5 }
        }
        Column {
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: game.best; color: UI.warning; font.pixelSize: UI.px(26); font.bold: true }
            Text { font.weight: UI.textWeight; anchors.horizontalCenter: parent.horizontalCenter; text: "BEST"; color: UI.textFaint; font.pixelSize: UI.px(10); font.letterSpacing: 1.5 }
        }
    }
    Timer { id: pop; interval: 150 }

    Item {
        id: board
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14

        Rectangle {
            id: field
            anchors.centerIn: parent
            width: game.cell * game.cols
            height: game.cell * game.rows
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: Qt.rgba(0.6, 1, 0.4, 0.25)

            Canvas {
                id: canvas
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"), c = game.cell
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "rgba(255,255,255,0.025)"
                    for (var gx = 0; gx < game.cols; gx++) for (var gy = 0; gy < game.rows; gy++)
                        if ((gx + gy) % 2 === 0) ctx.fillRect(gx * c, gy * c, c, c)
                    // food
                    if (game.food.x >= 0) {
                        ctx.fillStyle = "#f43f5e"
                        ctx.beginPath()
                        ctx.arc(game.food.x * c + c / 2, game.food.y * c + c / 2, c * 0.36, 0, Math.PI * 2)
                        ctx.fill()
                        ctx.fillStyle = "rgba(255,255,255,0.6)"
                        ctx.beginPath()
                        ctx.arc(game.food.x * c + c * 0.38, game.food.y * c + c * 0.38, c * 0.09, 0, Math.PI * 2)
                        ctx.fill()
                    }
                    // snake: gradient from head to tail
                    var n = game.snake.length
                    for (var i = n - 1; i >= 0; i--) {
                        var p = game.snake[i], t = n > 1 ? i / (n - 1) : 0
                        ctx.fillStyle = Qt.rgba(0.64 - 0.3 * t, 0.9 - 0.25 * t, 0.21 + 0.1 * t, 1)
                        var pad = i === 0 ? 1 : 2
                        ctx.fillRect(p.x * c + pad, p.y * c + pad, c - pad * 2, c - pad * 2)
                    }
                    if (n > 0) {   // eyes
                        var h = game.snake[0], ex = game.dir.x, ey = game.dir.y
                        ctx.fillStyle = "#0b1a05"
                        var cx = h.x * c + c / 2 + ex * c * 0.18, cy = h.y * c + c / 2 + ey * c * 0.18
                        ctx.beginPath(); ctx.arc(cx - ey * c * 0.2, cy - ex * c * 0.2, c * 0.09, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.arc(cx + ey * c * 0.2, cy + ex * c * 0.2, c * 0.09, 0, Math.PI * 2); ctx.fill()
                    }
                }
            }

            Rectangle {
                visible: game.phase !== "playing"
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.55)
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: game.phase === "over" ? "Game over" : (game.phase === "paused" ? "Paused" : "Snake")
                        color: "white"; font.pixelSize: UI.px(28); font.bold: true
                    }
                    Text {
                        font.weight: UI.textWeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: game.phase === "over"
                        text: game.score >= game.best && game.score > 0 ? "New best: " + game.score + "!" : "Score: " + game.score
                        color: UI.warning; font.pixelSize: UI.px(15)
                    }
                    Text {
                        font.weight: UI.textWeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: game.phase === "paused" ? "Press Space or an arrow key to continue" : "Arrow keys / WASD to play  ·  Space pauses"
                        color: UI.textDim; font.pixelSize: UI.px(12.5)
                    }
                    GButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: game.phase === "paused" ? "Resume" : (game.phase === "over" ? "Play again" : "Start")
                        kind: "primary"
                        onClicked: { if (game.phase === "over") game.reset(); game.phase = "playing"; game.forceActiveFocus() }
                    }
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; onClicked: game.forceActiveFocus() }
}
