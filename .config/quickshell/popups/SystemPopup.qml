import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

// The system's release and architecture, and below them the kernel and the
// generation it runs. Read anew as the popup opens.
Column {
    id: popup

    readonly property string release: {
        const line = osRelease.text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
        return line ? line.slice(12).replace(/^"|"$/g, "") : "";
    }
    readonly property var rows: {
        const list = [];
        if (Machine.kernel !== "")
            list.push({label: "Kernel", value: Machine.kernel});
        if (Machine.generation > 0)
            list.push({label: "Generation", value: String(Machine.generation)});
        return list;
    }
    readonly property real wide: Math.max(title.implicitWidth, details.implicitWidth)

    spacing: Theme.popupSectionGap
    onVisibleChanged: if (visible) {
        osRelease.reload();
        arch.reload();
        Machine.refresh();
    }

    PopupText {
        id: title
        text: [popup.release, arch.text().trim()].filter(s => s !== "").join(" ")
    }
    PopupDetails {
        id: details
        visible: popup.rows.length > 0
        width: popup.wide
        rows: popup.rows
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
