// GlassOS Media Player: video and music via Qt Multimedia (FFmpeg backend).
// Music gets a live spectrum equalizer (core/media.py analyzes the decoded audio).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "../ui"
import "../components"

FocusScope {
    id: mp
    property var hostWindow: null
    property string filePath: ""
    property var queue: []              // list of virtual paths
    property int index: -1
    property bool shuffle: Prefs.value("media.shuffle", false) === true
    property string repeatMode: Prefs.value("media.repeat", "off")   // off | all | one
    property bool libraryOpen: true
    property string libraryTab: "audio"
    property var library: []
    property bool immersive: false
    property bool controlsShown: true
    property string errorText: ""
    property var synth: []
    readonly property var wm: UI.wm
    readonly property bool isActive: hostWindow ? hostWindow.active : true
    readonly property bool hasMedia: index >= 0 && index < queue.length
    readonly property string current: hasMedia ? queue[index] : ""
    readonly property bool videoMode: hasMedia && player.hasVideo
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property string trackTitle: {
        var t = player.metaData.stringValue(MediaMetaData.Title)
        return t ? t : (current ? current.split("/").pop().replace(/\.[^.]+$/, "") : "")
    }
    readonly property string trackArtist: {
        var a = player.metaData.stringValue(MediaMetaData.ContributingArtist) || player.metaData.stringValue(MediaMetaData.AlbumArtist)
        var al = player.metaData.stringValue(MediaMetaData.AlbumTitle)
        return [a, al].filter(function (x) { return x }).join("  ·  ")
    }
    readonly property var levels: Visualizer.realSpectrum ? Visualizer.levels : synth

    // (each playlist's items is a string list -> a Qt sequence in QML, so normalize with UI.arr)
    property var playlists: UI.arr(Prefs.value("media.playlists", []))
        .filter(function (p) { return p && typeof p.name === "string" && UI.isList(p.items) })
        .map(function (p) { return { name: p.name, items: UI.arr(p.items) } })

    Component.onCompleted: {
        Visualizer.attach(player)
        reloadLibrary()
        // bring back the queue from last time (without auto-playing)
        var saved = UI.arr(Prefs.value("media.queue", [])).filter(function (p) { return typeof p === "string" && Storage.exists(p) })
        if (saved.length) {
            queue = saved
            index = Math.max(0, Math.min(saved.length - 1, Number(Prefs.value("media.index", 0)) || 0))
            player.source = Storage.fileUrl(queue[index])
        }
        if (filePath) openFile(filePath)
        mp.forceActiveFocus()
    }
    function saveQueue() { Prefs.setValue("media.queue", queue.slice(0, 500)); Prefs.setValue("media.index", index) }
    Component.onDestruction: Visualizer.setEnabled(false)
    onVideoModeChanged: updateVisualizer()
    onPlayingChanged: updateVisualizer()
    onVisibleChanged: updateVisualizer()
    function updateVisualizer() { Visualizer.setEnabled(mp.visible && mp.hasMedia && !mp.videoMode && mp.playing) }

    function handleArgs(props) { if (props.filePath) openFile(props.filePath) }
    function acceptDrop(paths, urls) {
        var media = paths.filter(function (p) { var k = Storage.kindOf(p); return k === "audio" || k === "video" })
        if (media.length) { openFile(media[0]); if (media.length > 1) queue = media }
        else if (urls.length) wm.importInto(urls, "/Music")
    }

    function reloadLibrary() { library = Storage.mediaFiles(libraryTab) }
    onLibraryTabChanged: if (libraryTab === "audio" || libraryTab === "video") reloadLibrary()

    // ------------------------------------------------------------ playback
    // VLC-style: opening something adds it to the queue and plays it; nothing is thrown away
    function openFile(path) {
        var kind = Storage.kindOf(path)
        if (kind === "playlist") { loadM3u(path); return }
        if (kind !== "audio" && kind !== "video") { wm.notify("Can't play this file", path.split("/").pop(), "warning-color"); return }
        enqueue(path, true)
        wm.rememberRecent(path)
    }
    function enqueue(path, playNow) {
        var i = queue.indexOf(path)
        if (i < 0) { queue = queue.concat([path]); i = queue.length - 1 }
        if (playNow) playAt(i); else saveQueue()
        if (!playNow) wm.notify("Added to queue", path.split("/").pop(), "queue-add")
    }
    function playNext(path) {
        var q = queue.filter(function (p) { return p !== path })
        var at = Math.min(q.length, Math.max(0, q.indexOf(current) + 1))
        q.splice(at, 0, path)
        var cur = current
        queue = q
        index = q.indexOf(cur)
        saveQueue()
    }
    function playList(list, i) { queue = list.slice(); playAt(i) }
    function removeAt(i) {
        if (i < 0 || i >= queue.length) return
        var wasCurrent = i === index
        var q = queue.slice(); q.splice(i, 1)
        queue = q
        if (i < index) index--
        if (wasCurrent) { if (q.length) playAt(Math.min(i, q.length - 1)); else { player.stop(); player.source = ""; index = -1 } }
        saveQueue()
    }
    function moveItem(i, d) {
        var j = i + d
        if (i < 0 || j < 0 || i >= queue.length || j >= queue.length) return
        var q = queue.slice(), t = q[i]; q[i] = q[j]; q[j] = t
        if (index === i) index = j; else if (index === j) index = i
        queue = q
        saveQueue()
    }
    function clearQueue() { player.stop(); player.source = ""; queue = []; index = -1; saveQueue() }

    // ---------------- playlists (saved in settings; exportable as .m3u)
    function savePlaylists(list) { playlists = list; Prefs.setValue("media.playlists", list) }
    function saveQueueAs() {
        if (!queue.length) return
        dialog.ask({ title: "Save queue as playlist", input: true, text: "Playlist " + (playlists.length + 1),
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Save", value: "ok", kind: "primary" }] },
                   function (v, name) {
                       name = (name || "").trim()
                       if (v !== "ok" || !name) return
                       var list = playlists.filter(function (p) { return p.name !== name })
                       list.push({ name: name, items: queue.slice() })
                       savePlaylists(list)
                       wm.notify("Playlist saved", name + " · " + queue.length + " items", "playlist")
                   })
    }
    function addToPlaylist(name, path) {
        savePlaylists(playlists.map(function (p) {
            return p.name === name && p.items.indexOf(path) < 0 ? { name: p.name, items: p.items.concat([path]) } : p
        }))
        wm.notify("Added to " + name, path.split("/").pop(), "playlist")
    }
    function deletePlaylist(name) { savePlaylists(playlists.filter(function (p) { return p.name !== name })) }
    function playPlaylist(p) {
        var items = p.items.filter(function (x) { return Storage.exists(x) })
        if (!items.length) { wm.notify("Playlist is empty", p.name + ": its files were moved or deleted.", "warning-color"); return }
        playList(items, 0)
    }
    function exportPlaylist(p) {
        var dest = Storage.join("/Music", p.name.replace(/[\\/:*?"<>|]/g, "_") + ".m3u")
        var lines = ["#EXTM3U"].concat(p.items.map(function (x) { return x }))
        if (Storage.writeText(dest, lines.join("\n") + "\n")) wm.notify("Playlist exported", dest + " (opens in VLC too)", "export", function () { wm.openApp("AeroExplorer", { initialPath: "/Music" }) })
    }
    function loadM3u(path) {
        var r = Storage.readText(path)
        if (!r.ok) { wm.notify("Can't open playlist", r.error, "warning-color"); return }
        var base = Storage.parentOf(path)
        var items = r.text.split(/\r?\n/).map(function (l) { return l.trim() }).filter(function (l) { return l && l.charAt(0) !== "#" })
            .map(function (l) { return l.charAt(0) === "/" ? l : Storage.join(base, l) })
            .filter(function (l) { var k = Storage.kindOf(l); return (k === "audio" || k === "video") && Storage.exists(l) })
        if (!items.length) { wm.notify("Playlist is empty", "None of its files are in GlassOS.", "warning-color"); return }
        playList(items, 0)
        wm.notify("Playing playlist", path.split("/").pop() + " · " + items.length + " items", "playlist")
    }

    function rowMenu(path, item, mx, my) {
        var items = [
            { text: "Play now", icon: "play", action: function () { mp.enqueue(path, true) } },
            { text: "Play next", icon: "queue-add", action: function () { mp.playNext(path) } },
            { text: "Add to queue", icon: "playlist", action: function () { mp.enqueue(path, false) } }
        ]
        if (playlists.length) items.push({ separator: true })
        playlists.slice(0, 8).forEach(function (p) {
            items.push({ text: "Add to “" + p.name + "”", icon: "plus", action: function () { mp.addToPlaylist(p.name, path) } })
        })
        items.push({ separator: true })
        items.push({ text: "Show in Files", icon: "folder", action: function () { wm.openApp("AeroExplorer", { initialPath: Storage.parentOf(path) }) } })
        menu.show(item, mx, my, items)
    }
    function playAt(i) {
        if (i < 0 || i >= queue.length) return
        errorText = ""
        index = i
        player.source = Storage.fileUrl(queue[i])
        player.play()
        saveQueue()
        if (hostWindow) hostWindow.title = trackTitle + " — Media Player"
    }
    function toggle() {
        if (!hasMedia) return
        if (playing) player.pause(); else player.play()
    }
    function next(auto) {
        if (!queue.length) return
        if (shuffle && queue.length > 1) {
            var r = index
            while (r === index) r = Math.floor(Math.random() * queue.length)
            playAt(r)
        } else if (index + 1 < queue.length) playAt(index + 1)
        else if (repeatMode === "all") playAt(0)
        else if (auto) { player.stop(); player.setPosition(0) }
    }
    function prev() {
        if (player.position > 3000 || index <= 0) player.setPosition(0)
        else playAt(index - 1)
    }
    function seekBy(ms) { if (player.seekable) player.setPosition(Math.max(0, Math.min(player.duration, player.position + ms))) }
    function setVolume(v) { Prefs.setVolume(v); if (Prefs.muted) Prefs.setMuted(false) }
    function cycleRepeat() {
        repeatMode = repeatMode === "off" ? "all" : (repeatMode === "all" ? "one" : "off")
        Prefs.setValue("media.repeat", repeatMode)
    }
    // true fullscreen through the window manager: taskbar hidden, Esc exits
    function setImmersive(on) {
        on = on && videoMode
        if (on === immersive) return
        immersive = on
        if (on) wm.enterFullscreen(hostWindow, function () { mp.setImmersive(false) })
        else wm.exitFullscreen(hostWindow)
        showControls()
    }
    Connections {
        target: mp.wm
        function onFullscreenWindowChanged() { if (mp.immersive && mp.wm.fullscreenWindow !== mp.hostWindow) mp.immersive = false }
    }
    function showControls() { controlsShown = true; hideTimer.restart() }
    function fmt(ms) {
        if (!(ms > 0)) return "0:00"
        var s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60
        return (h ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            // perceptual curve: the slider feels linear to the ear
            volume: Math.pow(Prefs.volume / 100, 2)
            muted: Prefs.muted
        }
        videoOutput: videoOut
        loops: mp.repeatMode === "one" ? MediaPlayer.Infinite : 1
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && mp.repeatMode !== "one") mp.next(true)
        onErrorOccurred: function (error, errorString) { mp.errorText = errorString || "This file can't be played." }
        onMetaDataChanged: if (mp.hostWindow && mp.hasMedia) mp.hostWindow.title = mp.trackTitle + " — Media Player"
    }

    Timer { id: hideTimer; interval: 2600; onTriggered: if (mp.videoMode && mp.playing) mp.controlsShown = false }

    // synthetic spectrum when the Qt build can't tap decoded audio
    Timer {
        interval: 45
        repeat: true
        running: !Visualizer.realSpectrum && mp.playing && !mp.videoMode && mp.visible
        property real t: 0
        onTriggered: {
            t += 0.045
            var out = []
            for (var i = 0; i < Visualizer.bandCount; i++) {
                var x = i / Visualizer.bandCount
                var v = 0.55 * Math.exp(-x * 2.2) * (0.6 + 0.4 * Math.sin(t * 7.1 + i * 0.35))
                      + 0.25 * Math.abs(Math.sin(t * 3.3 + i * 0.9)) * (1 - x * 0.5) + 0.08 * Math.random()
                var prev = mp.synth.length > i ? mp.synth[i] : 0
                out.push(v > prev ? v : prev * 0.8 + v * 0.2)
            }
            mp.synth = out
        }
    }

    Keys.onPressed: function (event) {
        var k = event.key
        if (k === Qt.Key_Space || k === Qt.Key_K) toggle()
        else if (k === Qt.Key_Right) seekBy(5000)
        else if (k === Qt.Key_Left) seekBy(-5000)
        else if (k === Qt.Key_L) seekBy(10000)
        else if (k === Qt.Key_J) seekBy(-10000)
        else if (k === Qt.Key_Up) setVolume(Prefs.volume + 5)
        else if (k === Qt.Key_Down) setVolume(Prefs.volume - 5)
        else if (k === Qt.Key_M) Prefs.setMuted(!Prefs.muted)
        else if (k === Qt.Key_F) setImmersive(!immersive)
        else if (k === Qt.Key_Escape && immersive) setImmersive(false)
        else if (k === Qt.Key_N) next(false)
        else if (k === Qt.Key_P) prev()
        else return
        event.accepted = true
        showControls()
    }

    Rectangle { anchors.fill: parent; color: mp.videoMode ? "black" : Qt.rgba(0.02, 0.03, 0.06, 0.55) }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ======================================================== stage
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            VideoOutput {
                id: videoOut
                anchors.fill: parent
                visible: mp.videoMode
                fillMode: VideoOutput.PreserveAspectFit
            }

            // ---------------------------------------------- music visual
            Item {
                id: musicView
                anchors.fill: parent
                anchors.bottomMargin: controls.height
                visible: mp.hasMedia && !mp.videoMode

                Rectangle {   // ambient glow that breathes with the bass
                    anchors.centerIn: disc
                    width: disc.width * (1.6 + Visualizer.bass * 0.6)
                    height: width
                    radius: width / 2
                    color: UI.alpha(UI.accent, 0.10 + Visualizer.bass * 0.12)
                }
                Rectangle {
                    id: disc
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.12
                    width: Math.min(parent.width * 0.32, parent.height * 0.36)
                    height: width
                    radius: width / 2
                    scale: 1 + Visualizer.bass * 0.06
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.25) }
                        GradientStop { position: 1; color: Qt.darker(UI.accent, 1.9) }
                    }
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.25)
                    Repeater {   // vinyl grooves
                        model: 4
                        Rectangle {
                            anchors.centerIn: parent
                            width: disc.width * (0.86 - index * 0.13)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                        }
                    }
                    Icon { anchors.centerIn: parent; name: "music"; size: disc.width * 0.3; opacity: 0.9 }
                    RotationAnimation on rotation {
                        running: mp.playing && UI.animations && musicView.visible
                        from: 0; to: 360; duration: 18000; loops: Animation.Infinite
                    }
                }
                Column {
                    anchors.top: disc.bottom
                    anchors.topMargin: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 60
                    spacing: 4
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: mp.trackTitle; color: "white"; font.pixelSize: UI.px(22); font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: mp.trackArtist; visible: text !== ""; color: UI.textDim; font.pixelSize: UI.px(13); elide: Text.ElideRight }
                }

                // equalizer bars + reflection
                Item {
                    id: eq
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24
                    height: Math.min(parent.height * 0.26, 170)
                    readonly property int n: Visualizer.bandCount
                    readonly property real barW: width / n
                    Repeater {
                        model: eq.n
                        Item {
                            x: index * eq.barW
                            width: eq.barW
                            height: eq.height
                            readonly property real level: mp.levels.length > index ? mp.levels[index] : 0
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.verticalCenter
                                anchors.bottomMargin: -parent.height * 0.25
                                width: Math.max(2, eq.barW * 0.62)
                                height: Math.max(3, parent.level * parent.height * 0.75)
                                radius: width / 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.5) }
                                    GradientStop { position: 1; color: UI.accent }
                                }
                            }
                            Rectangle {   // reflection
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.verticalCenter
                                anchors.topMargin: parent.height * 0.25 + 3
                                width: Math.max(2, eq.barW * 0.62)
                                height: Math.max(1, parent.level * parent.height * 0.22)
                                radius: width / 2
                                color: UI.alpha(UI.accent, 0.22)
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- empty state / library hero
            Column {
                visible: !mp.hasMedia
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -20
                spacing: 14
                width: Math.min(parent.width - 60, 420)
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "app-media"; size: 88 }
                Text { elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Media Player"; color: UI.text; font.pixelSize: UI.px(22); font.weight: Font.DemiBold }
                Text {
                    font.weight: UI.textWeight
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: "Plays video and music: MP4, MKV, WebM, MOV, AVI, MP3, FLAC, OGG, WAV, M4A and more. Pick something from your library, open a file, or drop one here."
                    color: UI.textDim; font.pixelSize: UI.px(13)
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    GButton { text: "Open file…"; iconName: "folder-open"; kind: "primary"
                              onClicked: picker.openFile({ title: "Open media", folder: "/Music", kinds: ["audio", "video"] }, function (p) { mp.openFile(p) }) }
                    GButton { text: "Import"; iconName: "import"; onClicked: mp.wm.openImportDialog(mp.libraryTab === "video" ? "/Videos" : "/Music") }
                }
            }

            Rectangle {   // playback error
                visible: mp.errorText !== ""
                anchors.centerIn: parent
                width: Math.min(parent.width - 60, errRow.implicitWidth + 40)
                height: errRow.implicitHeight + 28
                radius: UI.radius
                color: Qt.rgba(0.1, 0.05, 0.06, 0.92)
                border.color: UI.alpha(UI.danger, 0.6)
                Row {
                    id: errRow
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { name: "error-color"; size: 22; anchors.verticalCenter: parent.verticalCenter }
                    Text { font.weight: UI.textWeight; text: mp.errorText; color: UI.text; font.pixelSize: UI.px(13); wrapMode: Text.Wrap; width: Math.min(implicitWidth, stage.width - 140); anchors.verticalCenter: parent.verticalCenter }
                }
            }

            MouseArea {   // video: click = play/pause, double-click = immersive, move = show controls
                anchors.fill: parent
                anchors.bottomMargin: controls.height
                enabled: mp.videoMode
                hoverEnabled: true
                cursorShape: mp.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
                onPositionChanged: mp.showControls()
                onClicked: { mp.toggle(); mp.forceActiveFocus() }
                onDoubleClicked: mp.setImmersive(!mp.immersive)
            }

            // ---------------------------------------------- transport controls
            Item {
                id: controls
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: UI.px(96)
                visible: mp.hasMedia
                opacity: !mp.videoMode || mp.controlsShown || !mp.playing ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: UI.dur(220) } }
                HoverHandler { onHoveredChanged: if (hovered) mp.showControls() }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, mp.videoMode ? 0.6 : 0.25) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, mp.videoMode ? 0.8 : 0.35) }
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 8
                    spacing: 0
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: mp.fmt(seek.pressed ? seek.value : player.position); color: UI.textDim; font.pixelSize: UI.px(11.5); Layout.preferredWidth: UI.px(48) }
                        GSlider {
                            id: seek
                            Layout.fillWidth: true
                            from: 0
                            to: Math.max(1, player.duration)
                            enabled: player.seekable
                            onMoved: player.setPosition(value)
                            // follow playback, except while the user is dragging the handle
                            Binding on value { value: player.position; when: !seek.pressed; restoreMode: Binding.RestoreNone }
                        }
                        Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: mp.fmt(player.duration); color: UI.textDim; font.pixelSize: UI.px(11.5); Layout.preferredWidth: UI.px(48); horizontalAlignment: Text.AlignRight }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        IconButton { iconName: "shuffle"; tip: "Shuffle (S)"; active: mp.shuffle; onClicked: { mp.shuffle = !mp.shuffle; Prefs.setValue("media.shuffle", mp.shuffle) } }
                        IconButton { iconName: "prev"; tip: "Previous (P)"; onClicked: mp.prev() }
                        AbstractButton {
                            id: playBtn
                            implicitWidth: UI.px(46); implicitHeight: UI.px(46)
                            hoverEnabled: true
                            onClicked: mp.toggle()
                            background: Rectangle {
                                radius: width / 2
                                color: playBtn.down ? Qt.darker(UI.accent, 1.2) : (playBtn.hovered ? Qt.lighter(UI.accent, 1.12) : UI.accent)
                            }
                            contentItem: Item { Icon { anchors.centerIn: parent; name: mp.playing ? "pause" : "play"; size: UI.px(22) } }
                            GTip { text: (mp.playing ? "Pause" : "Play") + " (Space)"; visible: playBtn.hovered }
                        }
                        IconButton { iconName: "next"; tip: "Next (N)"; onClicked: mp.next(false) }
                        IconButton {
                            iconName: mp.repeatMode === "one" ? "repeat-one" : "repeat"
                            tip: "Repeat: " + mp.repeatMode
                            active: mp.repeatMode !== "off"
                            onClicked: mp.cycleRepeat()
                        }
                        Item { Layout.fillWidth: true }
                        GButton {
                            text: player.playbackRate + "×"
                            kind: "flat"
                            onClicked: {
                                var rates = [0.5, 0.75, 1, 1.25, 1.5, 2], i = rates.indexOf(player.playbackRate)
                                player.playbackRate = rates[(i + 1) % rates.length]
                            }
                            GTip { text: "Playback speed"; visible: parent.hovered }
                        }
                        IconButton {
                            iconName: Prefs.muted || Prefs.volume === 0 ? "mute" : (Prefs.volume < 50 ? "volume-low" : "volume")
                            tip: "Mute (M)"
                            onClicked: Prefs.setMuted(!Prefs.muted)
                        }
                        GSlider {
                            Layout.preferredWidth: UI.px(110)
                            from: 0; to: 100; stepSize: 1
                            value: Prefs.volume
                            onMoved: mp.setVolume(value)
                        }
                        IconButton { iconName: "playlist"; tip: "Library"; active: mp.libraryOpen; onClicked: mp.libraryOpen = !mp.libraryOpen }
                        IconButton { visible: mp.videoMode; iconName: mp.immersive ? "exit-fullscreen" : "fullscreen"; tip: "Full screen (F)"; onClicked: mp.setImmersive(!mp.immersive) }
                    }
                }
            }
        }

        // ======================================================== library panel
        Rectangle {
            visible: mp.libraryOpen && !mp.immersive
            Layout.fillHeight: true
            Layout.preferredWidth: UI.px(310)
            color: Qt.rgba(0, 0, 0, 0.3)
            Rectangle { width: 1; height: parent.height; color: UI.border }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: [{ id: "queue", label: "Queue" }, { id: "audio", label: "Music" }, { id: "video", label: "Videos" }, { id: "playlists", label: "Playlists" }]
                        GButton {
                            text: modelData.label + (modelData.id === "queue" && mp.queue.length ? " " + mp.queue.length : "")
                            kind: mp.libraryTab === modelData.id ? "primary" : "flat"
                            onClicked: mp.libraryTab = modelData.id
                        }
                    }
                }
                RowLayout {   // actions for the current tab
                    Layout.fillWidth: true
                    spacing: 4
                    GButton {
                        visible: mp.libraryTab === "audio" || mp.libraryTab === "video"
                        text: "Play all"; iconName: "play"; enabled: mp.library.length > 0
                        onClicked: mp.playList(mp.library.map(function (e) { return e.path }), 0)
                    }
                    GButton { visible: mp.libraryTab === "queue"; text: "Save as playlist"; iconName: "save"; enabled: mp.queue.length > 0; onClicked: mp.saveQueueAs() }
                    GButton { visible: mp.libraryTab === "queue"; text: "Clear"; kind: "flat"; enabled: mp.queue.length > 0; onClicked: mp.clearQueue() }
                    GButton { visible: mp.libraryTab === "playlists"; text: "New from queue"; iconName: "plus"; enabled: mp.queue.length > 0; onClicked: mp.saveQueueAs() }
                    Item { Layout.fillWidth: true }
                    IconButton { visible: mp.libraryTab === "audio" || mp.libraryTab === "video"; iconName: "refresh"; tip: "Rescan"; onClicked: mp.reloadLibrary() }
                }

                // ---------------------------------------------- playlists
                ListView {
                    id: plList
                    visible: mp.libraryTab === "playlists"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: mp.libraryTab === "playlists" ? mp.playlists : []
                    ScrollBar.vertical: GScrollBar {}
                    delegate: Rectangle {
                        width: plList.width
                        height: UI.px(50)
                        radius: UI.radiusSmall
                        color: plMouse.containsMouse ? UI.hover : "transparent"
                        MouseArea { id: plMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mp.playPlaylist(modelData) }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 4
                            spacing: 10
                            Icon { name: "playlist"; size: UI.px(22) }
                            Column {
                                Layout.fillWidth: true
                                Text { font.weight: UI.textWeight; width: parent.width; text: modelData.name; color: UI.text; font.pixelSize: UI.px(12.5); elide: Text.ElideRight }
                                Text { font.weight: UI.textWeight; text: modelData.items.length + " items"; color: UI.textFaint; font.pixelSize: UI.px(10.5) }
                            }
                            IconButton { iconName: "export"; size: 26; glyphSize: 11; tip: "Export as .m3u"; onClicked: mp.exportPlaylist(modelData) }
                            IconButton { iconName: "trash"; size: 26; glyphSize: 11; tip: "Delete playlist"; onClicked: mp.deletePlaylist(modelData.name) }
                        }
                    }
                    Text {
                        font.weight: UI.textWeight
                        visible: plList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 30
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: "No playlists yet.\nQueue some songs, then “New from queue”. .m3u files open here too."
                        color: UI.textFaint; font.pixelSize: UI.px(12)
                    }
                }

                // ---------------------------------------------- queue / music / videos
                ListView {
                    id: libList
                    visible: mp.libraryTab !== "playlists"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: mp.libraryTab === "queue" ? mp.queue : (mp.libraryTab === "playlists" ? [] : mp.library)
                    ScrollBar.vertical: GScrollBar {}
                    delegate: Rectangle {
                        id: row
                        width: libList.width
                        height: UI.px(52)
                        radius: UI.radiusSmall
                        readonly property string path: typeof modelData === "string" ? modelData : modelData.path
                        readonly property bool isCurrent: path === mp.current
                        readonly property bool inQueue: mp.libraryTab === "queue"
                        property string thumb: ""
                        function loadThumb() { thumb = Thumbs.request(path) }
                        Component.onCompleted: loadThumb()
                        onPathChanged: loadThumb()
                        Connections { target: Thumbs; function onReady(p, url) { if (p === row.path) row.thumb = url } }
                        color: isCurrent ? UI.accentSoft : (rowMouse.containsMouse ? UI.hover : "transparent")
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) { mp.rowMenu(row.path, rowMouse, mouse.x, mouse.y); return }
                                if (row.inQueue) mp.playAt(index)
                                else mp.enqueue(row.path, true)
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 4
                            spacing: 10
                            Item {
                                Layout.preferredWidth: UI.px(60)
                                Layout.preferredHeight: UI.px(40)
                                Rectangle { anchors.fill: parent; radius: 4; color: Qt.rgba(0, 0, 0, 0.35); visible: row.thumb !== "" }
                                Image {
                                    anchors.fill: parent
                                    visible: row.thumb !== ""
                                    source: row.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 120
                                }
                                Icon { anchors.centerIn: parent; visible: row.thumb === ""; name: Storage.iconFor(row.path); size: UI.px(30) }
                                Icon { anchors.centerIn: parent; visible: row.isCurrent && mp.playing; name: "volume"; size: UI.px(18) }
                            }
                            Column {
                                Layout.fillWidth: true
                                Text {
                                    font.weight: UI.textWeight
                                    width: parent.width
                                    text: row.path.split("/").pop().replace(/\.[^.]+$/, "")
                                    color: row.isCurrent ? UI.accent : UI.text
                                    font.pixelSize: UI.px(12.5)
                                    elide: Text.ElideRight
                                }
                                Text { font.weight: UI.textWeight; width: parent.width; text: Storage.parentOf(row.path); color: UI.textFaint; font.pixelSize: UI.px(10.5); elide: Text.ElideMiddle }
                            }
                            Row {
                                visible: row.inQueue && rowMouse.containsMouse
                                IconButton { iconName: "chevron-up"; size: 24; glyphSize: 10; tip: "Move up"; onClicked: mp.moveItem(index, -1) }
                                IconButton { iconName: "chevron-down"; size: 24; glyphSize: 10; tip: "Move down"; onClicked: mp.moveItem(index, 1) }
                                IconButton { iconName: "close"; size: 24; glyphSize: 10; tip: "Remove from queue"; onClicked: mp.removeAt(index) }
                            }
                        }
                    }
                    Text {
                        font.weight: UI.textWeight
                        visible: libList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 30
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: mp.libraryTab === "queue" ? "The queue is empty.\nPick something from Music or Videos." : "No " + (mp.libraryTab === "audio" ? "music" : "videos") + " found.\nImport some or drop files into " + (mp.libraryTab === "audio" ? "Music" : "Videos") + "."
                        color: UI.textFaint
                        font.pixelSize: UI.px(12)
                    }
                }
            }
        }
    }

    FilePicker { id: picker }
    GMenu { id: menu }
    GDialog { id: dialog }
}
