import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property bool cfg_showLyricsDefault
    property bool cfg_highlightCurrentLineDefault
    property int cfg_lyricsFontSizeDefault
    property bool cfg_alternativeLineHeightCalculationDefault
    property string cfg_lyricsFontFamilyDefault

    property bool cfg_showAlbumCoverDefault
    property bool cfg_fetchAlbumCoverHttpsDefault
    property int cfg_maxTitleArtistLengthDefault
    property bool cfg_showTitleDefault
    property int cfg_titleFontSizeDefault
    property string cfg_titleFontFamilyDefault
    property bool cfg_showArtistDefault
    property int cfg_artistFontSizeDefault
    property string cfg_artistFontFamilyDefault

    property alias cfg_transparentBackground: transparentBackground.checked

    property alias cfg_showLyrics: showLyrics.checked
    property alias cfg_autoDetectLanguage: autoDetectLanguage.checked
    property alias cfg_highlightCurrentLine: highlightCurrentLine.checked
    property alias cfg_lyricsFontSize: lyricsFontSize.value
    property alias cfg_alternativeLineHeightCalculation: alternativeLineHeightCalculation.checked
    property alias cfg_lyricsFontFamily: lyricsFontFamily.currentText

    property bool cfg_useCustomLyricsColorDefault
    property alias cfg_useCustomLyricsColor: useCustomLyricsColor.checked
    property string cfg_lyricsTextColor: plasmoid.configuration.lyricsTextColor

    // Translation Button Color Settings
    property bool cfg_useCustomTransColorDefault
    property alias cfg_useCustomTransColor: useCustomTransColor.checked
    property string cfg_transTextColor: plasmoid.configuration.transTextColor

    property alias cfg_showAlbumCover: showAlbumCover.checked
    property alias cfg_fetchAlbumCoverHttps: fetchAlbumCoverHttps.checked
    property alias cfg_maxTitleArtistLength: maxTitleArtistLength.value
    property alias cfg_showTitle: showTitle.checked
    property alias cfg_titleFontSize: titleFontSize.value
    property alias cfg_titleFontFamily: titleFontFamily.currentText
    property bool cfg_useCustomTitleColorDefault
    property alias cfg_useCustomTitleColor: useCustomTitleColor.checked
    property string cfg_titleTextColor: plasmoid.configuration.titleTextColor
    property alias cfg_showArtist: showArtist.checked
    property alias cfg_artistFontSize: artistFontSize.value
    property alias cfg_artistFontFamily: artistFontFamily.currentText
    property bool cfg_useCustomArtistColorDefault
    property alias cfg_useCustomArtistColor: useCustomArtistColor.checked
    property string cfg_artistTextColor: plasmoid.configuration.artistTextColor

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            text: "Appearance"
            level: 3
            Layout.alignment: Qt.AlignLeft
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        CheckBox {
            id: transparentBackground
            text: "Transparent background"
            ToolTip.text: "Use transparent background when plasmoid is on desktop (not in panel)"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        Rectangle {
            Layout.fillWidth: true
            height: 15
            color: "transparent"
        }

        Kirigami.Heading {
            text: "Lyrics & Translation"
            level: 3
            Layout.alignment: Qt.AlignLeft
        }

        CheckBox {
            id: showLyrics
            text: "Show lyrics"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        CheckBox {
            id: autoDetectLanguage
            text: "Auto-detect language (Romaji for Japanese / Translit for Russian)"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showLyrics.checked
        }

        CheckBox {
            id: highlightCurrentLine
            text: "Highlight current line"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showLyrics.checked
        }

        CheckBox {
            id: alternativeLineHeightCalculation
            text: "Use alternative scroll offset calculation"
            Layout.alignment: Qt.AlignLeft
            enabled: showLyrics.checked
            Layout.leftMargin: 20
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: 20
            enabled: showLyrics.checked

            Label { text: "Lyrics Font:" }

            ComboBox {
                id: lyricsFontFamily
                model: Qt.fontFamilies()
                editable: true
                Component.onCompleted: {
                    const index = model.indexOf(plasmoid.configuration.lyricsFontFamily)
                    currentIndex = index >= 0 ? index : 0
                }
            }

            SpinBox {
                id: lyricsFontSize
                from: 8; to: 72; stepSize: 1
            }
        }

        CheckBox {
            id: useCustomLyricsColor
            text: "Use custom lyrics text color"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showLyrics.checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: 40
            enabled: showLyrics.checked && useCustomLyricsColor.checked

            Label { text: "Lyrics Color:" }

            Rectangle {
                width: 40; height: 24; radius: 4
                color: cfg_lyricsTextColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: lyricsColorDialog.open()
                }
            }
            Label { text: cfg_lyricsTextColor; opacity: 0.7 }
        }

        ColorDialog {
            id: lyricsColorDialog
            title: "Choose lyrics text color"
            selectedColor: cfg_lyricsTextColor
            onAccepted: cfg_lyricsTextColor = selectedColor.toString()
        }

        // Custom Translation Button Color Settings
        CheckBox {
            id: useCustomTransColor
            text: "Use custom translation button text color"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showLyrics.checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: 40
            enabled: showLyrics.checked && useCustomTransColor.checked

            Label { text: "Button Color:" }

            Rectangle {
                width: 40; height: 24; radius: 4
                color: cfg_transTextColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: transColorDialog.open()
                }
            }
            Label { text: cfg_transTextColor; opacity: 0.7 }
        }

        ColorDialog {
            id: transColorDialog
            title: "Choose translation button text color"
            selectedColor: cfg_transTextColor
            onAccepted: cfg_transTextColor = selectedColor.toString()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 15
            color: "transparent"
        }

        Kirigami.Heading {
            text: "Track Information"
            level: 3
            Layout.alignment: Qt.AlignLeft
        }

        CheckBox {
            id: showAlbumCover
            text: "Show album cover"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            CheckBox {
                id: fetchAlbumCoverHttps
                text: "Fetch album cover over HTTPS"
                enabled: showAlbumCover.checked
                Layout.leftMargin: 20
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Label { text: "Max title/artist length:" }

            SpinBox {
                id: maxTitleArtistLength
                from: 10; to: 200; stepSize: 1
                enabled: showAlbumCover.checked
            }
        }

        CheckBox {
            id: showTitle
            text: "Show title"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
            checked: plasmoid.configuration.showTitle
            onCheckedChanged: plasmoid.configuration.showTitle = checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing

            Label { text: "Title Font:" }

            ComboBox {
                id: titleFontFamily
                model: Qt.fontFamilies()
                editable: true
                Component.onCompleted: {
                    const index = model.indexOf(plasmoid.configuration.titleFontFamily)
                    currentIndex = index >= 0 ? index : 0
                }
            }

            SpinBox {
                id: titleFontSize
                from: 8; to: 72; stepSize: 1
            }
        }

        CheckBox {
            id: useCustomTitleColor
            text: "Use custom title text color"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showTitle.checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: 40
            enabled: showTitle.checked && useCustomTitleColor.checked

            Label { text: "Title Color:" }

            Rectangle {
                width: 40; height: 24; radius: 4
                color: cfg_titleTextColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: titleColorDialog.open()
                }
            }
            Label { text: cfg_titleTextColor; opacity: 0.7 }
        }

        ColorDialog {
            id: titleColorDialog
            title: "Choose title text color"
            selectedColor: cfg_titleTextColor
            onAccepted: cfg_titleTextColor = selectedColor.toString()
        }

        CheckBox {
            id: showArtist
            text: "Show artist"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: Kirigami.Units.largeSpacing
            checked: plasmoid.configuration.showArtist
            onCheckedChanged: plasmoid.configuration.showArtist = checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing

            Label { text: "Artist Font:" }

            ComboBox {
                id: artistFontFamily
                model: Qt.fontFamilies()
                editable: true
                Component.onCompleted: {
                    const index = model.indexOf(plasmoid.configuration.artistFontFamily)
                    currentIndex = index >= 0 ? index : 0
                }
            }

            SpinBox {
                id: artistFontSize
                from: 8; to: 72; stepSize: 1
            }
        }

        CheckBox {
            id: useCustomArtistColor
            text: "Use custom artist text color"
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 20
            enabled: showArtist.checked
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Kirigami.Units.smallSpacing
            Layout.leftMargin: 40
            enabled: showArtist.checked && useCustomArtistColor.checked

            Label { text: "Artist Color:" }

            Rectangle {
                width: 40; height: 24; radius: 4
                color: cfg_artistTextColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: artistColorDialog.open()
                }
            }
            Label { text: cfg_artistTextColor; opacity: 0.7 }
        }

        ColorDialog {
            id: artistColorDialog
            title: "Choose artist text color"
            selectedColor: cfg_artistTextColor
            onAccepted: cfg_artistTextColor = selectedColor.toString()
        }
    }
}