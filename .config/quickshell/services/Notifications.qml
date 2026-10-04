pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (org.freedesktop.Notifications): which
// notifications are on screen as toasts and for how long, which wait in the
// notification center, and do not disturb. A notification whose toast timed
// out is not closed: it waits in the center until it is dismissed.
Singleton {
    id: root

    // Every notification not closed yet, oldest first.
    readonly property var tracked: server.trackedNotifications
    // Those on screen as toasts, oldest first.
    readonly property var toasts: tracked.values.filter(n => root.isToast(n))
    // Those waiting in the center, newest first.
    readonly property var missed: tracked.values.filter(n => !root.isToast(n)).sort((a, b) => root.time(b) - root.time(a))
    readonly property int missedCount: missed.length
    // Those in the center and the toasts that are to go there: what there is
    // to see once the lock is gone, the toasts not being shown over it. A
    // critical one stays a toast, and so would not be among the missed.
    readonly property int waitingCount: tracked.values.filter(n => !root.isToast(n) || !root.isTransient(n)).length

    // Do not disturb: a notification gets no toast and goes straight to the
    // center, unless it is critical.
    readonly property bool dnd: state.dnd

    // A new notification in one of these categories replaces the previous one.
    readonly property var replacedCategories: ["mpd"]
    // A notification in one of these is closed when its toast times out,
    // as is one its sender marked transient.
    readonly property var transientCategories: ["mpd"]

    // How long a toast stays, in ms, by urgency; 0 keeps it until it is
    // dismissed. The timeout the sender asked for is ignored.
    function timeout(notification) {
        if (notification.hints.category === "mpd")
            return 2000;
        switch (notification.urgency) {
        case NotificationUrgency.Low:
            return 8000;
        case NotificationUrgency.Critical:
            return 0;
        default:
            return 12000;
        }
    }

    function isToast(notification) {
        return entries[notification.id]?.toast === true;
    }

    // When a notification came, in ms; 0 if that is not known.
    function time(notification) {
        return entries[notification.id]?.time ?? 0;
    }

    // The same, as on its card: "14:05".
    function arrival(notification) {
        const ms = time(notification);
        return ms ? Qt.formatTime(new Date(ms), "HH:mm") : "";
    }

    // Only ever a toast: there is nothing of it to keep in the center.
    function isTransient(notification) {
        return notification.transient || transientCategories.includes(notification.hints.category);
    }

    // A toast's time is up.
    function timedOut(notification) {
        if (isTransient(notification))
            notification.expire();
        else
            hide(notification);
    }

    // Off the screen, into the center.
    function hide(notification) {
        store(notification, {
            time: time(notification),
            toast: false
        });
    }

    // The toasts leave the screen as if their time were up.
    function hideAll() {
        for (const n of [...toasts])
            timedOut(n);
    }

    // Senders that may be running without a window, by desktop entry: the
    // unit that runs them so, and what brings their window up. Their default
    // action has no window to show then. Thunderbird's unit and the wrapper
    // that swaps it for the window are in ~/.nixos (user-services.nix).
    readonly property var windowless: ({
            "thunderbird": {
                unit: "thunderbird-headless.service",
                command: ["thunderbird"]
            }
        })
    // The notification activated, while its sender's unit is asked about.
    property var pending: null

    // A click on a card: the default action, and the notification is closed.
    // For a sender that may be running without a window the click leads to
    // its window as well: brought up if there is none, focused if there is
    // one, since the sender cannot take the focus by itself.
    function activate(notification) {
        const app = windowless[notification.desktopEntry];
        if (!app) {
            activateDefault(notification);
            return;
        }
        pending = notification;
        unitCheck.command = ["systemctl", "--user", "is-active", "--quiet", app.unit];
        unitCheck.running = true;
    }

    Process {
        id: unitCheck
        onExited: exitCode => {
            const notification = root.pending;
            root.pending = null;
            // Closed in the meantime.
            if (!notification || !root.tracked.values.includes(notification))
                return;
            if (exitCode !== 0) {
                const appId = notification.desktopEntry;
                root.activateDefault(notification);
                Niri.focusApp(appId);
                return;
            }
            // Through niri, as from the launcher: a child of this service
            // would go with it when it restarts.
            Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(root.windowless[notification.desktopEntry].command));
            notification.dismiss();
        }
    }

    // The default action, if there is one, and the notification is closed.
    function activateDefault(notification) {
        const action = notification.actions.find(a => a.identifier === "default");
        if (action) {
            action.invoke();
            // Invoking an action closes a notification that is not resident.
            if (!notification.resident)
                return;
        }
        notification.dismiss();
    }

    // Closes what waits in the center; the toasts stay.
    function clear() {
        for (const n of [...missed])
            n.dismiss();
    }

    function toggleDnd() {
        state.dnd = !state.dnd;
    }

    // Just come, or just replaced by its sender: a toast with the time it is
    // now, or straight to the center under do not disturb. False for one
    // that is to be neither: a transient one under do not disturb.
    function arrived(notification) {
        const toast = !state.dnd || notification.urgency === NotificationUrgency.Critical;
        if (!toast && isTransient(notification))
            return false;
        store(notification, {
            time: Date.now(),
            toast: toast
        });
        return true;
    }

    // Writes a notification's entry, and drops those of the closed ones.
    function store(notification, entry) {
        const kept = {};
        for (const n of tracked.values) {
            if (n.id in entries)
                kept[n.id] = entries[n.id];
        }
        kept[notification.id] = entry;
        state.entries = JSON.stringify(kept);
    }

    // Notification id -> { time: when it came, in ms; toast: it is on screen }.
    // The server tells neither.
    readonly property var entries: JSON.parse(state.entries)

    // Survives a reload of the configuration, as the notifications do. As
    // JSON: an object does not make it to the reloaded configuration.
    PersistentProperties {
        id: state
        reloadableId: "notifications"
        property string entries: "{}"
        property bool dnd: false
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        inlineReplySupported: true
        keepOnReload: true

        onNotification: n => {
            const category = n.hints.category;
            if (root.replacedCategories.includes(category)) {
                for (const old of [...server.trackedNotifications.values]) {
                    if (old !== n && old.hints.category === category)
                        old.dismiss();
                }
            }
            // One carried over a reload of the configuration comes here
            // again: it is as it was. One not tracked is closed.
            if (!n.lastGeneration && !root.arrived(n))
                return;
            n.tracked = true;
        }
    }

    // A sender replacing its notification changes it in place, without the
    // server's signal: only what it shows changes.
    Instantiator {
        model: server.trackedNotifications

        Connections {
            required property var modelData
            target: modelData
            function onSummaryChanged() {
                if (!root.arrived(modelData))
                    modelData.expire();
            }
            function onBodyChanged() {
                if (!root.arrived(modelData))
                    modelData.expire();
            }
        }
    }
}
