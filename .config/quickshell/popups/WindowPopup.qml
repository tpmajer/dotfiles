import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// The focused window: its whole title, which the bar cuts short when it does
// not fit, and below it the application's name.
Column {
    id: popup

    readonly property var win: Niri.focusedWindow
    // Desktop entries load asynchronously; the length makes this re-evaluate once they do.
    readonly property var entry: win && DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(win.app_id) : null
    // Wraps past this.
    readonly property int maxWidth: 480

    spacing: Theme.popupRowGap

    PopupText {
        width: Math.min(implicitWidth, popup.maxWidth)
        text: popup.win?.title || ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    PopupText {
        visible: text !== ""
        width: Math.min(implicitWidth, popup.maxWidth)
        text: popup.entry?.name || popup.win?.app_id || ""
        textFormat: Text.PlainText
        color: Theme.subtext0
        elide: Text.ElideRight
    }
}
