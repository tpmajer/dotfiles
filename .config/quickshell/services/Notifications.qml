pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The notification daemon (org.freedesktop.Notifications): what is on screen
// and how long each notification stays.
Singleton {
    id: root

    // Oldest first.
    readonly property var list: server.trackedNotifications

    // A new notification in one of these categories replaces the previous one.
    readonly property var replacedCategories: ["mpd"]

    // How long a notification stays, in ms, by urgency; 0 keeps it until it is
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

    // When a notification came, as on its card: "14:05". The server does not
    // tell, so it is noted here as each one arrives.
    function arrival(notification) {
        const time = arrivals[notification.id];
        return time ? Qt.formatTime(new Date(time), "HH:mm") : "";
    }

    // Notification id -> when it came, in ms.
    readonly property var arrivals: JSON.parse(state.arrivals)

    // Survives a reload of the configuration, as the notifications do. As
    // JSON: an object does not make it to the reloaded configuration.
    PersistentProperties {
        id: state
        reloadableId: "notifications"
        property string arrivals: "{}"
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: n => {
            const category = n.hints.category;
            if (root.replacedCategories.includes(category)) {
                for (const old of [...server.trackedNotifications.values]) {
                    if (old !== n && old.hints.category === category)
                        old.dismiss();
                }
            }
            // Those of the notifications still there, and this one's.
            const arrivals = {};
            for (const old of server.trackedNotifications.values) {
                if (old.id in root.arrivals)
                    arrivals[old.id] = root.arrivals[old.id];
            }
            arrivals[n.id] = Date.now();
            state.arrivals = JSON.stringify(arrivals);
            n.tracked = true;
        }
    }
}
