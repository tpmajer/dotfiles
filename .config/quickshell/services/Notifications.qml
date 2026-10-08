pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// The notification daemon (org.freedesktop.Notifications): which
// notifications are on screen as toasts and for how long, which wait in the
// notification center, and do not disturb. A notification whose toast timed
// out is not closed: it waits in the center until it is dismissed. A low
// one is closed: it is of use only as it comes.
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

    // No more than Theme.notificationsKept are kept: each has its card, and
    // every one of them is looked at as any other comes or goes, so a sender
    // gone wild would bring the bar and the lock down with it. Past that the
    // oldest are closed as if their time were up: those in the center first,
    // then the toasts, the critical ones last. Not from the change itself,
    // which closing them would change again.
    readonly property int trackedCount: tracked.values.length
    onTrackedCountChanged: if (trackedCount > Theme.notificationsKept)
        Qt.callLater(trim)
    function trim() {
        const over = tracked.values.length - Theme.notificationsKept;
        if (over <= 0)
            return;
        const critical = n => urgency(n) === NotificationUrgency.Critical;
        const oldest = [...missed].reverse().concat(toasts.filter(n => !critical(n)), toasts.filter(critical));
        for (const n of oldest.slice(0, over))
            n.expire();
    }

    // Senders whose notifications are low whatever they say, by desktop
    // entry: ghostty sends all of its own as normal.
    readonly property var lowSenders: ["com.mitchellh.ghostty"]

    // How urgent a notification is taken to be.
    function urgency(notification) {
        return lowSenders.includes(notification.desktopEntry) ? NotificationUrgency.Low : notification.urgency;
    }

    // The most urgent of those waiting in the center; low with none.
    readonly property int missedUrgency: missed.reduce((u, n) => Math.max(u, urgency(n)), NotificationUrgency.Low)

    // An urgency's color: the line on a notification's card.
    function urgencyColor(urgency) {
        return urgency === NotificationUrgency.Critical ? Theme.red : urgency === NotificationUrgency.Low ? Theme.subtext0 : Theme.green;
    }

    // A notification's body, as its card is to show it: of the markup only
    // bold, italic, underline, links and line breaks are let through. The
    // rest is shown as it was written, since the text format of the card
    // would load any image the body names, from the network too, and drop
    // what it takes for a tag it does not know, such as "<no subject>".
    function markup(body) {
        const allowed = /^<\/?[biu]>$|^<br\s*\/?>$|^<a(\s+href\s*=\s*("[^"]*"|'[^']*'))?\s*>$|^<\/a>$/i;
        return body.replace(/<[^<>]*>|[<>]/g, tag => allowed.test(tag) ? tag : tag.replace(/</g, "&lt;").replace(/>/g, "&gt;"));
    }

    // Do not disturb: a notification gets no toast and goes straight to the
    // center, unless it is critical.
    readonly property bool dnd: state.dnd
    // The same while a screen is recorded or shared, so that no toast gets
    // into the recording; those on screen then go to the center, but for
    // the critical ones. niri could keep the toasts out of a screencast by
    // itself, but blacks out their whole window, as high as the screen.
    // Only a cast that lasts: a screenshot is one too, of a moment.
    readonly property bool quiet: dnd || casting
    property bool casting: false
    readonly property bool castingNow: Niri.castingOutput
    onCastingNowChanged: if (!castingNow)
        casting = false
    Timer {
        interval: 1000
        running: root.castingNow
        onTriggered: root.casting = true
    }
    onCastingChanged: {
        if (!casting)
            return;
        for (const n of toasts.filter(n => urgency(n) !== NotificationUrgency.Critical))
            timedOut(n);
    }

    // How long a toast stays, in ms, by urgency; 0 keeps it until it is
    // dismissed. The timeout the sender asked for is ignored.
    function timeout(notification) {
        switch (urgency(notification)) {
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

    // The icon a notification names, as such or as its image; "" if it
    // names none, or a picture there.
    function iconName(notification) {
        const prefix = "image://icon/";
        return notification.appIcon || (notification.image.startsWith(prefix) ? notification.image.slice(prefix.length) : "");
    }

    function isBatteryIcon(name) {
        return name === "battery" || name.startsWith("battery-");
    }

    // The icon a notification came with, kept while its sender replaces it
    // with a battery: blueman does so to one of a device just connected,
    // once the device tells its charge. "" if that is not known.
    function icon(notification) {
        return entries[notification.id]?.icon ?? "";
    }

    // Only ever a toast, closed when its time is up: a low one, or one its
    // sender marked transient.
    function isTransient(notification) {
        return notification.transient || urgency(notification) === NotificationUrgency.Low;
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
            toast: false,
            icon: icon(notification)
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
    // that swaps it for the window are in ~/.nixos (background-apps.nix).
    readonly property var windowless: ({
            "thunderbird": {
                unit: "thunderbird-headless.service",
                command: ["thunderbird"]
            }
        })
    // The notifications activated, while their senders' units are asked
    // about, one at a time: a second click does not wait for the first.
    property var pending: []

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
        pending = pending.concat([notification]);
        checkNext();
    }

    function checkNext() {
        // Not those closed in the meantime.
        pending = pending.filter(n => tracked.values.includes(n));
        if (unitCheck.running || pending.length === 0)
            return;
        unitCheck.command = ["systemctl", "--user", "is-active", "--quiet", windowless[pending[0].desktopEntry].unit];
        unitCheck.running = true;
    }

    Process {
        id: unitCheck
        onExited: exitCode => {
            const notification = root.pending[0];
            root.pending = root.pending.slice(1);
            // Not one closed in the meantime.
            if (notification && root.tracked.values.includes(notification)) {
                if (exitCode !== 0) {
                    const appId = notification.desktopEntry;
                    root.activateDefault(notification);
                    Niri.focusApp(appId);
                } else {
                    // Through niri, as from the launcher: a child of this
                    // service would go with it when it restarts.
                    Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(root.windowless[notification.desktopEntry].command));
                    notification.dismiss();
                }
            }
            root.checkNext();
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
        const toast = !quiet || urgency(notification) === NotificationUrgency.Critical;
        if (!toast && isTransient(notification))
            return false;
        const name = iconName(notification);
        const before = icon(notification);
        store(notification, {
            time: Date.now(),
            toast: toast,
            icon: isBatteryIcon(name) && before !== "" ? before : name
        });
        const file = sounds[notification.desktopEntry];
        // One at a time: a burst of notifications sounds once.
        if (toast && file && !sound.running) {
            sound.command = ["pw-play", file];
            sound.running = true;
        }
        return true;
    }

    // Senders whose toasts come with a sound, by desktop entry: the file.
    // One that gets no toast, as under do not disturb, is silent. pop.ogg
    // is Signal's own, kept out of git: silent where it was not copied.
    readonly property string pop: Quickshell.shellDir + "/sounds/pop.ogg"
    readonly property var sounds: ({
            "thunderbird": pop,
            "signal": pop
        })

    Process {
        id: sound
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

    // Notification id -> { time: when it came, in ms; toast: it is on screen;
    // icon: the one it came with }. The server tells none of them.
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
            // One carried over a reload of the configuration comes here
            // again: it is as it was. One not tracked is closed.
            if (!n.lastGeneration && !root.arrived(n))
                return;
            n.tracked = true;
        }
    }

    // A sender replacing its notification changes it in place, without the
    // server's signal: only what it shows changes, or how urgent it is. All
    // that changed with one replacement makes it come once, a moment later.
    // One replaced by the very same is not told from one left alone.
    Instantiator {
        model: server.trackedNotifications

        Connections {
            id: replacement
            required property var modelData
            target: modelData
            property Timer changed: Timer {
                interval: 0
                onTriggered: {
                    // Closed in the meantime.
                    if (!root.tracked.values.includes(replacement.modelData))
                        return;
                    if (!root.arrived(replacement.modelData))
                        replacement.modelData.expire();
                }
            }
            function onSummaryChanged() {
                changed.start();
            }
            function onBodyChanged() {
                changed.start();
            }
            function onUrgencyChanged() {
                changed.start();
            }
        }
    }
}
