import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

PlasmoidItem {
    id: widget

    Plasmoid.status: PlasmaCore.Types.HiddenStatus
    Plasmoid.backgroundHints: plasmoid.configuration.transparentBackground
    ? PlasmaCore.Types.NoBackground
    : PlasmaCore.Types.DefaultBackground

    Layout.preferredWidth: row.implicitWidth + 30
    Layout.preferredHeight: row.implicitHeight + 10

    readonly property int volumeStep: 2
    property string translationMode: "kanji"
    property string currentDetectedScript: "latin"

    property var rawSpotifyLyrics: null
    property string currentTrackId: ""
    property string longestLyricLine: ""

    readonly property bool lyricsActive: plasmoid.configuration.showLyrics && spotify && spotify.ready && lyricsRenderer.lyrics && lyricsRenderer.lyrics.length > 0

    // Background Process Auto-Launcher
    Plasma5Support.DataSource {
        id: serverLauncher
        engine: "executable"
        connectedSources: []
    }

    Component.onCompleted: {
        checkAndStartServer();
    }

    function getScriptAbsolutePath() {
        let mainUrl = Qt.resolvedUrl("main.qml").toString();
        let absPath = mainUrl.replace("file://", "").replace("ui/main.qml", "scripts/romaji_server.py");
        return absPath;
    }

    function launchServerProcess() {
        let absPath = getScriptAbsolutePath();
        let cmd = "sh -c 'nohup python3 \"" + absPath + "\" >/dev/null 2>&1 || nohup python \"" + absPath + "\" >/dev/null 2>&1 &'";
        serverLauncher.connectSource(cmd);
    }

    function checkAndStartServer() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "http://127.0.0.1:28481/position");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status !== 200) {
                    launchServerProcess();
                }
            }
        };
        xhr.send();
    }

    Text {
        id: textMeasurer
        visible: false
        text: widget.longestLyricLine
        font.pixelSize: 16
        font.weight: Font.Bold
    }

    LyricsLrcLib { id: lyricsLrcLib }
    Spotify { id: spotify }

    Connections {
        target: spotify

        onReadyChanged: {
            Plasmoid.status = spotify.ready ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
        }

        onPositionChanged: {
            if (spotify.ready) {
                updateProgressIndicator()
            }
        }

        onArtworkUrlChanged: updateArtwork()
        onTrackChanged: Qt.callLater(updateLyrics)
        onArtistChanged: Qt.callLater(updateLyrics)
        onAlbumChanged: Qt.callLater(updateLyrics)
    }

    Timer {
        id: timer
        interval: 1000
        running: spotify && spotify.playing
        repeat: true
        onTriggered: updateProgressIndicator()
    }

    MouseArea {
        z: 0
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: spotify && spotify.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true

        onClicked: (mouse) => {
            switch (mouse.button) {
                case Qt.MiddleButton:
                    spotify.togglePlayback()
                    break
                case Qt.LeftButton:
                    if (spotify.canRaise) {
                        spotify.raise()
                    }
                    break
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                spotify.changeVolume(volumeStep / 100, true)
            } else {
                spotify.changeVolume(-volumeStep / 100, true)
            }
        }
    }

    // =========================================================
    // WIDGET MAIN ROW LAYOUT
    // =========================================================
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12
        clip: false

        Item {
            id: lyricsLayoutWrapper
            Layout.preferredWidth: widget.lyricsActive ? Math.min(550, Math.max(280, textMeasurer.contentWidth + 60)) : 0
            Layout.preferredHeight: 64
            Layout.rightMargin: widget.lyricsActive ? 8 : 0
            clip: true
            opacity: widget.lyricsActive ? 1 : 0

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            LyricsRenderer {
                id: lyricsRenderer
                width: parent.width
                height: parent.height
                lyrics: null
                spotify: spotify
                centeredLyrics: !plasmoid.configuration.showAlbumCover
                && !plasmoid.configuration.showTitle
                && !plasmoid.configuration.showArtist
            }
        }

        /* Album cover */
        Image {
            id: artwork

            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.fillWidth: false
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            property string fallbackSource: Qt.resolvedUrl("../assets/icon.svg")

            source: fallbackSource
            visible: plasmoid.configuration.showAlbumCover

            onStatusChanged: {
                if (status === Image.Error) {
                    source = fallbackSource
                }
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Item {
                    width: artwork.width
                    height: artwork.height
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                    }
                }
            }

            MouseArea {
                z: 10
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: dropdownPopup.toggle()
            }

            Rectangle {
                id: progress
                visible: spotify && spotify.ready

                x: 2
                height: 3
                width: artwork.width - 4
                anchors.bottom: parent.bottom
                color: "#282828"

                Rectangle {
                    id: progressIndicator
                    anchors.bottom: parent.bottom
                    height: 2
                    width: 0
                    color: "#1db954"
                }
            }
        }

        /* Song Info Block */
        Item {
            id: songInfoContainer
            Layout.preferredWidth: column.implicitWidth
            Layout.preferredHeight: column.implicitHeight
            Layout.fillWidth: false
            visible: plasmoid.configuration.showTitle || plasmoid.configuration.showArtist

            ColumnLayout {
                id: column
                anchors.fill: parent
                spacing: 1

                Text {
                    id: title
                    wrapMode: Text.NoWrap
                    lineHeightMode: Text.FixedHeight
                    Layout.fillWidth: true
                    Layout.rightMargin: 10

                    color: plasmoid.configuration.useCustomTitleColor ? plasmoid.configuration.titleTextColor : Kirigami.Theme.textColor
                    font.pixelSize: plasmoid.configuration.titleFontSize
                    font.family: plasmoid.configuration.titleFontFamily
                    font.weight: Font.Bold
                    text: spotify && spotify.ready ? truncateText(spotify.track, plasmoid.configuration.maxTitleArtistLength) : "Spotify"

                    Layout.preferredHeight: title.font.pixelSize + 4
                    visible: plasmoid.configuration.showTitle
                }

                Text {
                    id: artist
                    wrapMode: Text.NoWrap
                    lineHeightMode: Text.FixedHeight
                    Layout.fillWidth: true
                    Layout.rightMargin: 10

                    color: plasmoid.configuration.useCustomArtistColor ? plasmoid.configuration.artistTextColor : Kirigami.Theme.textColor
                    font.pixelSize: plasmoid.configuration.artistFontSize
                    font.family: plasmoid.configuration.artistFontFamily
                    text: spotify && spotify.ready ? truncateText(spotify.artist, plasmoid.configuration.maxTitleArtistLength) : "No song playing"

                    Layout.preferredHeight: artist.font.pixelSize + 4
                    visible: plasmoid.configuration.showArtist
                }

                /* Mode Toggle Button */
                Rectangle {
                    id: transToggleContainer
                    implicitWidth: transToggle.implicitWidth + 12
                    implicitHeight: transToggle.implicitHeight + 6
                    color: "transparent"
                    Layout.topMargin: 2
                    visible: plasmoid.configuration.showArtist

                    Text {
                        id: transToggle
                        anchors.centerIn: parent
                        text: {
                            if (widget.translationMode === "romaji") return "[ Romaji ]";
                            if (widget.translationMode === "translit") return "[ Translit ]";
                            if (widget.translationMode === "english") return "[ English ]";
                            return "[ Original ]";
                        }
                        color: plasmoid.configuration.useCustomTransColor ? plasmoid.configuration.transTextColor : "#1db954"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cycleTranslationMode()
                    }
                }
            }
        }
    }

    // =========================================================
    // PLASMA TRANSLUCENT DROPDOWN POPUP
    // =========================================================
    PlasmaComponents3.Popup {
        id: dropdownPopup
        x: row.x + artwork.x - (width / 2) + (artwork.width / 2)
        y: row.y + artwork.y + artwork.height + 10
        width: 280
        height: 370
        padding: 16
        modal: false
        focus: true
        closePolicy: PlasmaComponents3.Popup.CloseOnPressOutside | PlasmaComponents3.Popup.CloseOnEscape

        function toggle() {
            if (visible) close(); else open();
        }

        onOpened: {
            if (spotify && spotify.ready) {
                seekSlider.value = spotify.getDaemonPosition() / 1000000;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Image {
                Layout.preferredWidth: 180
                Layout.preferredHeight: 180
                Layout.alignment: Qt.AlignHCenter
                fillMode: Image.PreserveAspectCrop
                source: (artwork.source && artwork.source.toString().length > 0) ? artwork.source : artwork.fallbackSource
                asynchronous: true

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: 180; height: 180
                        Rectangle { anchors.fill: parent; radius: 10 }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Label {
                    text: spotify.ready ? spotify.track : "Not Playing"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents3.Label {
                    text: spotify.ready ? spotify.artist : ""
                    font.pixelSize: 11
                    opacity: 0.7
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    from: 0
                    to: spotify.ready && spotify.length > 0 ? spotify.length / 1000000 : 1

                    onPressedChanged: {
                        if (!pressed && spotify.ready) {
                            spotify.setPosition(value)
                        }
                    }
                }

                Binding {
                    target: seekSlider
                    property: "value"
                    value: spotify.ready ? spotify.getDaemonPosition() / 1000000 : 0
                    when: spotify.ready && !seekSlider.pressed && dropdownPopup.visible
                }

                Timer {
                    interval: 250
                    running: dropdownPopup.visible && spotify.ready && spotify.playing
                    repeat: true
                    onTriggered: {
                        if (!seekSlider.pressed) {
                            seekSlider.value = spotify.getDaemonPosition() / 1000000;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents3.Label {
                        text: formatTime(spotify.ready ? (seekSlider.pressed ? seekSlider.value * 1000 : spotify.getDaemonPosition() / 1000) : 0)
                        font.pixelSize: 9
                        opacity: 0.7
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents3.Label {
                        text: formatTime(spotify.ready ? spotify.length / 1000 : 0)
                        font.pixelSize: 9
                        opacity: 0.7
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                PlasmaComponents3.ToolButton {
                    icon.name: "media-playlist-shuffle"
                    checkable: true
                    checked: spotify.shuffle
                    onClicked: spotify.toggleShuffle()
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-backward"
                    enabled: spotify.canGoPrevious
                    onClicked: spotify.previous()
                }

                PlasmaComponents3.Button {
                    icon.name: spotify.playing ? "media-playback-pause" : "media-playback-start"
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    onClicked: spotify.togglePlayback()
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "media-skip-forward"
                    enabled: spotify.canGoNext
                    onClicked: spotify.next()
                }

                PlasmaComponents3.ToolButton {
                    icon.name: spotify.loopStatus === "Track" ? "media-playlist-repeat-song" : "media-playlist-repeat"
                    checkable: true
                    checked: spotify.loopStatus !== "None"
                    onClicked: spotify.cycleLoopStatus()
                }
            }
        }
    }

    function formatTime(ms) {
        let totalSecs = Math.floor(ms / 1000);
        let mins = Math.floor(totalSecs / 60);
        let secs = totalSecs % 60;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function detectScript(trackName, artistName, lyricsArray) {
        if (!lyricsArray || lyricsArray.length === 0) {
            let sampleName = (trackName || "") + " " + (artistName || "");
            if (/[\u0400-\u04FF]/.test(sampleName)) return "cyrillic";
            if (/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/.test(sampleName)) return "japanese";
            return "latin";
        }

        let sample = "";
        for (let i = 0; i < lyricsArray.length; i++) {
            sample += " " + (lyricsArray[i].text || "");
        }

        if (/[\u0400-\u04FF]/.test(sample)) {
            return "cyrillic";
        }
        if (/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/.test(sample)) {
            return "japanese";
        }
        return "latin";
    }

    function updateProgressIndicator() {
        if (spotify.ready) {
            progressIndicator.width = Math.min(1, (spotify.getDaemonPosition() / spotify.length)) * progress.width
        }
    }

    function calculateLongestTrackLine(lyricsArray) {
        if (!lyricsArray || lyricsArray.length === 0) {
            widget.longestLyricLine = "";
            return;
        }
        let longestStr = "";
        for (let i = 0; i < lyricsArray.length; i++) {
            let currentLineText = lyricsArray[i].text || "";
            if (currentLineText.length > longestStr.length) {
                longestStr = currentLineText;
            }
        }
        widget.longestLyricLine = longestStr;
    }

    function truncateText(text, maxLen) {
        return text && text.length > maxLen
        ? text.slice(0, maxLen - 3) + "..."
        : text;
    }

    function updateArtwork() {
        if (spotify.ready) {
            let url = spotify.artworkUrl;
            if (url && typeof url === "string" && url.length > 0) {
                if (url.startsWith("https://") && !plasmoid.configuration.fetchAlbumCoverHttps) {
                    url = url.replace("https://", "http://");
                }
                artwork.source = url;
            } else {
                artwork.source = artwork.fallbackSource;
            }
        } else {
            artwork.source = artwork.fallbackSource;
        }
    }

    function cycleTranslationMode() {
        if (widget.currentDetectedScript === "cyrillic") {
            if (widget.translationMode === "translit") widget.translationMode = "english";
            else if (widget.translationMode === "english") widget.translationMode = "kanji";
            else widget.translationMode = "translit";
        } else if (widget.currentDetectedScript === "japanese") {
            if (widget.translationMode === "romaji") widget.translationMode = "english";
            else if (widget.translationMode === "english") widget.translationMode = "kanji";
            else widget.translationMode = "romaji";
        } else {
            if (widget.translationMode === "english") widget.translationMode = "kanji";
            else widget.translationMode = "english";
        }
        updateLyrics();
    }

    /* Smart Lyric Router */
    function updateLyrics() {
        if (!spotify || !spotify.ready) return;

        let requestedTrack = spotify.track;
        let requestedArtist = spotify.artist;
        let requestedAlbum = spotify.album;
        let trackId = requestedTrack + "|||" + requestedArtist;

        if (currentTrackId !== trackId) {
            currentTrackId = trackId;
            rawSpotifyLyrics = null;
            lyricsRenderer.lyrics = null;

            lyricsLrcLib.fetchLyrics(requestedTrack, requestedArtist, requestedAlbum)
            .then(lyrics => {
                if (currentTrackId === trackId) {
                    rawSpotifyLyrics = lyrics;
                    let detectedScript = detectScript(requestedTrack, requestedArtist, lyrics);
                    widget.currentDetectedScript = detectedScript;

                    if (plasmoid.configuration.autoDetectLanguage) {
                        if (detectedScript === "cyrillic") {
                            if (widget.translationMode === "romaji") widget.translationMode = "translit";
                        } else if (detectedScript === "japanese") {
                            if (widget.translationMode === "translit") widget.translationMode = "romaji";
                        } else {
                            widget.translationMode = "kanji";
                        }
                    }

                    processAndDisplay(lyrics, requestedTrack, requestedArtist);
                }
            });
        }
        else {
            processAndDisplay(rawSpotifyLyrics, requestedTrack, requestedArtist);
        }
    }

    function processAndDisplay(lyrics, requestedTrack, requestedArtist) {
        let trackId = requestedTrack + "|||" + requestedArtist;

        if (lyrics && lyrics.length > 0) {
            if (widget.translationMode === "kanji") {
                lyricsRenderer.lyrics = lyrics;
                calculateLongestTrackLine(lyrics);
            } else {
                lyricsRenderer.lyrics = [{"text": "Translating...", "time": 0}];
                calculateLongestTrackLine(lyricsRenderer.lyrics);
                translateViaPython(lyrics, requestedTrack, requestedArtist, function(translatedLyrics, detectedScript) {
                    if (currentTrackId === trackId) {
                        widget.currentDetectedScript = detectedScript;
                        lyricsRenderer.lyrics = translatedLyrics;
                        calculateLongestTrackLine(translatedLyrics);
                    }
                });
            }
        }
        else {
            widget.translationMode = "kanji";
            lyricsRenderer.lyrics = [{"text": "No lyrics found.", "time": 0}];
            calculateLongestTrackLine(lyricsRenderer.lyrics);
        }
    }

    function translateViaPython(lyricsArray, trackName, artistName, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:28481/convert");
        xhr.setRequestHeader("Content-Type", "application/json;charset=UTF-8");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    callback(response.lyrics, response.script || widget.currentDetectedScript);
                } else {
                    console.warn("Python server offline, launching server process...");
                    launchServerProcess();
                    callback(lyricsArray, widget.currentDetectedScript);
                }
            }
        };

        xhr.send(JSON.stringify({
            lyrics: lyricsArray,
            mode: widget.translationMode,
            track: trackName,
            artist: artistName
        }));
    }
}
