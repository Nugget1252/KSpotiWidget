import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import Qt5Compat.GraphicalEffects

Text {
    id: textElement
    Layout.fillWidth: true
    Layout.preferredHeight: parent.height
    Layout.rightMargin: 15
    Layout.leftMargin: 15
    wrapMode: Text.NoWrap
    horizontalAlignment: centeredLyrics ? Text.AlignHCenter : Text.AlignRight
    Layout.alignment: centeredLyrics ? Qt.AlignHCenter | Qt.AlignVCenter : Qt.AlignLeft
    textFormat: Text.RichText

    text: "Lyrics"
    color: plasmoid.configuration.useCustomLyricsColor ? plasmoid.configuration.lyricsTextColor : Kirigami.Theme.textColor
    font.pixelSize: plasmoid.configuration.lyricsFontSize
    font.family: plasmoid.configuration.lyricsFontFamily
    lineHeightMode: Text.FixedHeight
    lineHeight: font.pixelSize + font.pixelSize * 0.2

    property var lyrics: null
    property var spotify: null
    property var transitionDuration: 1000
    property var lineCount: 0
    property var renderedLineIndex: -1
    property var renderedHighlighted: false
    property bool centeredLyrics: false

    property bool animateY: true

    function darkenColor(hexColor, factor) {
        let hex = hexColor.replace("#", "");
        if (hex.length === 3) {
            hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
        }
        let r = Math.round(parseInt(hex.substring(0, 2), 16) * factor);
        let g = Math.round(parseInt(hex.substring(2, 4), 16) * factor);
        let b = Math.round(parseInt(hex.substring(4, 6), 16) * factor);
        r = Math.min(255, Math.max(0, r));
        g = Math.min(255, Math.max(0, g));
        b = Math.min(255, Math.max(0, b));
        return "#" + r.toString(16).padStart(2, "0") + g.toString(16).padStart(2, "0") + b.toString(16).padStart(2, "0");
    }

    Connections {
        target: plasmoid.configuration
        function onUseCustomLyricsColorChanged() { updateText() }
        function onLyricsTextColorChanged() { updateText() }
        function onHighlightCurrentLineChanged() { updateText() }
    }

    // FIX: Force immediate UI re-render whenever lyrics dataset changes
    onLyricsChanged: {
        renderedLineIndex = -1;
        updateText();
        updateTargetPosition(false);
    }

    Timer {
        interval: 250
        running: spotify.ready && spotify.playing && lyrics !== null
        repeat: true
        onTriggered: {
            updateTargetPosition()
        }
    }

    Behavior on y {
        enabled: textElement.animateY
        NumberAnimation {
            duration: textElement.transitionDuration
            easing.type: Easing.OutQuart
        }
    }

    function updateText() {
        let builder = "";
        let lines = 0;
        let currentLineIndex = getCurrentLineIndex();
        let highlight = plasmoid.configuration.highlightCurrentLine;
        let useCustomColor = plasmoid.configuration.useCustomLyricsColor;
        let unhighlightedColor = useCustomColor
        ? darkenColor(plasmoid.configuration.lyricsTextColor, 0.45)
        : "gray";

        if (lyrics !== null && lyrics) {
            lyrics.forEach((line, i) => {
                let lineText = line.text || "";
                if (i === currentLineIndex || !highlight) {
                    builder += lineText;
                } else {
                    builder += `<span style="color:${unhighlightedColor}">${lineText}</span>`;
                }

                if (i < lyrics.length - 1) {
                    builder += "<br/>";
                }
                lines++;
            });
        }

        lineCount = lines;
        textElement.text = builder;
        renderedLineIndex = currentLineIndex;
        renderedHighlighted = highlight;
    }

    function updateTargetPosition(animated = true) {
        if (canUpdateText()) {
            updateText();
        }

        if (textElement.parent !== null && lineCount > 0) {
            textElement.animateY = animated;
            y = calculateTargetY();
        } else {
            textElement.animateY = false;
            y = textElement.parent.height / 2 - textElement.lineHeight / 2;
        }
    }

    function canUpdateText() {
        let highlight = plasmoid.configuration.highlightCurrentLine;
        if (renderedHighlighted !== highlight) {
            return true;
        }

        let currentLineIndex = getCurrentLineIndex();
        if (renderedLineIndex === currentLineIndex) {
            return false;
        }

        return highlight;
    }

    function getCurrentLineIndex(offset = 0) {
        if (lyrics === null || lyrics.length === 0) {
            return -1;
        }

        let position = spotify.getDaemonPosition() / 1_000_000 + offset;
        let target = -1;
        for (let i = 0; i < lyrics.length; i++) {
            if (lyrics[i].time <= position) {
                target = i;
            } else {
                break;
            }
        }
        return target;
    }

    function calculateTargetY() {
        let currentLineIndex = getCurrentLineIndex(transitionDuration / 1000 / 2);
        if (!(currentLineIndex >= 0 && lineCount > 0)) {
            return textElement.parent.height / 2 - textElement.lineHeight / 2;
        }

        if (plasmoid.configuration.alternativeLineHeightCalculation) {
            let offsetY = 0;
            let lineHeight = (textElement.contentHeight - 3) / textElement.lineCount;
            if (lyrics !== null && currentLineIndex >= 0) {
                offsetY = lineHeight * (currentLineIndex + 1);
            }
            return textElement.parent.height / 2 - offsetY + lineHeight / 2 - 3;
        }

        let lineHeight = textElement.lineHeight;
        let visibleLines = Math.floor(textElement.height / lineHeight);
        let targetLineInView = Math.floor(visibleLines / 2);

        let targetLineIndex = currentLineIndex - targetLineInView;
        return -targetLineIndex * lineHeight;
    }
}