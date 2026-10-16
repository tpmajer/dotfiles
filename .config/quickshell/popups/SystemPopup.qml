import QtQuick
import Quickshell
import Quickshell.Io
import qs.widgets

// The system's release and architecture, read anew as the popup opens.
PopupText {
    id: popup

    readonly property string release: {
        const line = osRelease.text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
        return line ? line.slice(12).replace(/^"|"$/g, "") : "";
    }

    text: [release, arch.text().trim()].filter(s => s !== "").join(" ")
    onVisibleChanged: if (visible) {
        osRelease.reload();
        arch.reload();
    }

    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
    }
    FileView {
        id: arch
        path: "/proc/sys/kernel/arch"
        blockLoading: true
    }
}
