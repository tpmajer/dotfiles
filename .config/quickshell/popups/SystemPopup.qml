import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

// The system's release and architecture, and below them the kernel and the
// generation it runs, and the nixpkgs it was built from. Read anew as the
// popup opens.
Column {
    id: popup

    readonly property string release: field("PRETTY_NAME")
    // "26.11.20261014.55bfb4d": the release, the date and the revision.
    readonly property var build: field("BUILD_ID").split(".")
    readonly property var rows: {
        const list = [];
        if (Machine.kernel !== "")
            list.push({label: "Kernel", value: Machine.kernel});
        if (Machine.generation > 0)
            list.push({label: "Generation", value: Machine.generation + (Machine.generationAt > 0 ? " (" + Qt.formatDate(new Date(Machine.generationAt), "yyyy-MM-dd") + ")" : "")});
        if (/^\d{8}$/.test(build[2] ?? ""))
            list.push({label: "nixpkgs", value: build[2].replace(/(\d{4})(\d{2})(\d{2})/, "$1-$2-$3") + (build[3] ? " (" + build[3] + ")" : "")});
        return list;
    }
    readonly property real wide: Math.max(title.implicitWidth, details.implicitWidth)

    spacing: Theme.popupSectionGap
    onVisibleChanged: if (visible) {
        osRelease.reload();
        arch.reload();
        Machine.refresh();
    }

    // A value of /etc/os-release, without its quotes.
    function field(name) {
        const line = osRelease.text().split("\n").find(l => l.startsWith(name + "="));
        return line ? line.slice(name.length + 1).replace(/^"|"$/g, "") : "";
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
