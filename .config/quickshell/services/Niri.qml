pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Workspaces and focused window, kept in sync with `niri msg --json event-stream`.
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    readonly property var focusedWindow: {
        for (const id in windows)
            if (windows[id].is_focused)
                return windows[id];
        return null;
    }

    // The screencasts, by stream id.
    property var casts: ({})
    // A whole output is being recorded or shared, layer surfaces with it,
    // as a window alone is not. Not a cast that is paused.
    readonly property bool castingOutput: Object.values(casts).some(c => c.is_active && c.target.Output !== undefined)

    readonly property string focusedOutput: {
        const ws = workspaces.find(w => w.is_focused);
        return ws ? ws.output : "";
    }

    function workspacesOn(output) {
        return workspaces.filter(ws => ws.output === output).sort((a, b) => a.idx - b.idx);
    }

    // Focus by id over the IPC socket. `niri msg action focus-monitor`
    // would also warp the pointer to the middle of the screen.
    function focusWorkspace(ws) {
        send({Action: {FocusWorkspace: {reference: {Id: ws.id}}}});
    }

    // Focuses the window of an application, the one focused last if it has
    // several, on whatever workspace it is. False if it has none.
    function focusApp(appId) {
        const stamp = w => w.focus_timestamp ? w.focus_timestamp.secs + w.focus_timestamp.nanos / 1e9 : 0;
        // By the id as it is; failing that whatever its case, and with a
        // Flatpak's domain before it (org.mozilla.firefox for firefox).
        const id = String(appId).toLowerCase();
        const all = Object.values(windows);
        const exact = all.filter(w => w.app_id === appId);
        const own = (exact.length > 0 ? exact : all.filter(w => {
            const other = String(w.app_id ?? "").toLowerCase();
            return id !== "" && (other === id || other.endsWith("." + id));
        })).sort((a, b) => stamp(b) - stamp(a));
        if (own.length === 0)
            return false;
        send({Action: {FocusWindow: {id: own[0].id}}});
        return true;
    }

    // niri answers one request per connection, so each request gets its own socket.
    function send(request) {
        ipcSocket.createObject(root, {request: JSON.stringify(request) + "\n"});
    }

    Component {
        id: ipcSocket

        Socket {
            required property string request
            path: Quickshell.env("NIRI_SOCKET")
            connected: true
            onConnectedChanged: {
                if (connected) {
                    write(request);
                    flush();
                } else {
                    destroy();
                }
            }
            parser: SplitParser {
                onRead: line => {
                    if (!line.startsWith('{"Ok"'))
                        console.warn("niri IPC:", line);
                }
            }
        }
    }

    function updateWorkspaces(fn) {
        workspaces = workspaces.map(ws => {
            const copy = Object.assign({}, ws);
            fn(copy);
            return copy;
        });
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const {id, focused} = ev.WorkspaceActivated;
            const target = workspaces.find(ws => ws.id === id);
            if (!target)
                return;
            updateWorkspaces(ws => {
                if (ws.output === target.output)
                    ws.is_active = ws.id === id;
                if (focused)
                    ws.is_focused = ws.id === id;
            });
        } else if (ev.WorkspaceUrgencyChanged) {
            const {id, urgent} = ev.WorkspaceUrgencyChanged;
            updateWorkspaces(ws => {
                if (ws.id === id)
                    ws.is_urgent = urgent;
            });
        } else if (ev.WorkspaceActiveWindowChanged) {
            const {workspace_id, active_window_id} = ev.WorkspaceActiveWindowChanged;
            updateWorkspaces(ws => {
                if (ws.id === workspace_id)
                    ws.active_window_id = active_window_id;
            });
        } else if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows)
                map[w.id] = w;
            windows = map;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const map = Object.assign({}, windows);
            if (w.is_focused)
                for (const id in map)
                    map[id] = Object.assign({}, map[id], {is_focused: false});
            map[w.id] = w;
            windows = map;
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[ev.WindowClosed.id];
            windows = map;
        } else if (ev.CastsChanged) {
            const map = {};
            for (const c of ev.CastsChanged.casts)
                map[c.stream_id] = c;
            casts = map;
        } else if (ev.CastStartedOrChanged) {
            const c = ev.CastStartedOrChanged.cast;
            const map = Object.assign({}, casts);
            map[c.stream_id] = c;
            casts = map;
        } else if (ev.CastStopped) {
            const map = Object.assign({}, casts);
            delete map[ev.CastStopped.stream_id];
            casts = map;
        } else if (ev.WindowFocusTimestampChanged) {
            // Comes apart from the focus itself, a moment later.
            const {id, focus_timestamp} = ev.WindowFocusTimestampChanged;
            if (!(id in windows))
                return;
            const map = Object.assign({}, windows);
            map[id] = Object.assign({}, map[id], {focus_timestamp: focus_timestamp});
            windows = map;
        } else if (ev.WindowFocusChanged) {
            const focusedId = ev.WindowFocusChanged.id;
            const map = {};
            for (const id in windows)
                map[id] = Object.assign({}, windows[id], {is_focused: windows[id].id === focusedId});
            windows = map;
        }
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("niri event-stream:", e, line);
                }
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}
