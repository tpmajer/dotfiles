import QtQuick
import qs

Text {
    color: Theme.text
    linkColor: Theme.blue
    // As written: text from outside (titles, names) must not be read as
    // markup, which would also fetch the images it names. Styled where set.
    textFormat: Text.PlainText
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
}
