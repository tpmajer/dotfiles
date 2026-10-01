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
            n.tracked = true;
        }
    }
}
