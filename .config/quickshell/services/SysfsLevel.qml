import QtQuick
import Quickshell
import Quickshell.Io

// A level in sysfs, as a percent of its most: `brightness` of
// `max_brightness`, in the directory named. Read at the start, and anew when
// told to.
Scope {
    id: root

    required property string sysfs
    property bool printErrors: true

    property int percent: 0
    property bool ready: false

    // A change is not told of while this is set.
    property bool quiet: false
    // The level changed after startup.
    signal changed

    function reload() {
        valueFile.reload();
    }

    function update() {
        const max = Number(maxFile.text().trim());
        if (!(max > 0))
            return;
        const now = Math.round(Number(valueFile.text().trim()) * 100 / max);
        const differs = now !== percent;
        percent = now;
        if (ready && differs && !quiet)
            changed();
        ready = true;
    }

    FileView { id: maxFile; path: root.sysfs + "max_brightness"; blockLoading: true; printErrors: root.printErrors }
    // reload() only starts the read; the new value is there in onLoaded.
    FileView { id: valueFile; path: root.sysfs + "brightness"; printErrors: root.printErrors; onLoaded: root.update() }
}
