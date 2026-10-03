import QtQuick
import Quickshell
import Quickshell.Services.Pam

// The lock's fingerprint reader: a second conversation with PAM, next to the
// password's, in which pam_fprintd waits for a finger and nothing else. It
// gives up after half a minute without one, and is started again at once, the
// icon staying; after three wrong ones, and is started again half a minute
// later, so its limit holds; without asking for one (no reader, or fprintd
// lost it in a suspend), and is tried again every few seconds.
Scope {
    id: root

    // The session is locked and not being unlocked: set by watch().
    property bool watching: false
    // The icon: "" not watched, "waiting" for a finger, "bad" for a moment
    // after one it did not recognise, "ok" after one it did, which stays
    // through the fade out.
    property string mark: ""
    // Whether the reader asked for a finger in this conversation: it does not
    // when there is no reader.
    property bool prompted: false

    // A finger is recognised.
    signal recognised
    // A line for under the field, and that line being over.
    signal said(string text)
    signal unsaid(string text)

    // The reader is watched for as long as the session is locked.
    function watch(on) {
        watching = on;
        retry.stop();
        if (on) {
            if (!pam.active) {
                prompted = false;
                pam.start();
            }
        } else if (pam.active) {
            pam.abort();
        }
    }

    // The session is being unlocked. The icon stays as it is, for the fade out.
    function stop() {
        watch(false);
    }

    // After a suspend. The conversation that slept through it is lost: fprintd
    // is stopped on resume (NixOS, resumeCommands) and PAM takes seconds to say
    // so, then the retry waits its turn. Dropped here, and a new one started
    // once the old fprintd has had the moment it needs to go, the reader waits
    // for a finger a second after the wake, not five. No icon until it does.
    function woke() {
        if (!watching)
            return;
        if (pam.active)
            pam.abort();
        bad.stop();
        mark = "";
        retry.interval = 300;
        retry.restart();
    }

    PamContext {
        id: pam

        // GDM's service, borrowed: it has pam_fprintd, hyprlock's has not.
        config: "gdm-fingerprint"

        // Its prompt for a finger, then an error for each one not recognised.
        onPamMessage: {
            if (!root.watching)
                return;
            root.prompted = true;
            if (messageIsError) {
                root.said("fingerprint not recognised");
                root.mark = "bad";
                bad.restart();
            } else if (root.mark !== "bad") {
                root.mark = "waiting";
            }
        }
        onCompleted: result => {
            if (!root.watching)
                return;
            if (result === PamResult.Success) {
                bad.stop();
                root.mark = "ok";
                root.recognised();
                return;
            }
            root.again(result === PamResult.MaxTries);
        }
        onError: error => {
            if (root.watching)
                root.again(false);
        }
    }

    function again(tooMany) {
        if (tooMany) {
            bad.stop();
            mark = "";
            said("too many fingerprint attempts");
            retry.interval = 30000;
        } else if (prompted) {
            // Timed out: the icon stays, the reader is back in a moment.
            retry.interval = 1000;
        } else {
            mark = "";
            retry.interval = 3000;
        }
        retry.restart();
    }

    // How long the mark of a finger not recognised stays, and its line.
    Timer {
        id: bad
        interval: 1500
        onTriggered: {
            root.mark = pam.active ? "waiting" : "";
            root.unsaid("fingerprint not recognised");
        }
    }

    Timer {
        id: retry
        onTriggered: {
            root.unsaid("too many fingerprint attempts");
            root.watch(root.watching);
        }
    }
}
