pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The current weather in Warsaw from Open-Meteo (no key), every half an hour.
// Unknown when it has not been fetched for three hours: offline, it is not
// shown rather than shown stale. The half hours are by the wall clock, checked
// every minute: a Timer's own does not run during a suspend.
Singleton {
    id: root

    readonly property real latitude: 52.23
    readonly property real longitude: 21.01

    property real temperature: NaN
    property int code: -1
    property bool day: true
    property real fetchedAt: 0
    readonly property bool known: !isNaN(temperature) && clock.date.getTime() - fetchedAt < 3 * 3600 * 1000

    readonly property string temperatureText: known ? Math.round(temperature) + "°" : ""
    property real attemptedAt: 0

    // After a suspend, say: the lock refreshes it before it shows.
    function refreshIfStale() {
        if (!fetch.running && Date.now() - fetchedAt >= 30 * 60 * 1000)
            fetch.running = true;
    }

    // WMO weather codes, as Open-Meteo gives them.
    readonly property string icon: {
        const c = code;
        let glyph;
        if (c === 0)
            glyph = day ? 0xf0599 : 0xf0594;            // clear
        else if (c <= 2)
            glyph = day ? 0xf0595 : 0xf0f31;            // partly cloudy
        else if (c === 3)
            glyph = 0xf0590;                            // overcast
        else if (c === 45 || c === 48)
            glyph = 0xf0591;                            // fog
        else if (c === 65 || c === 82)
            glyph = 0xf0596;                            // heavy rain
        else if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
            glyph = 0xf0597;                            // drizzle, rain
        else if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            glyph = 0xf0598;                            // snow
        else if (c >= 95)
            glyph = 0xf0593;                            // thunderstorm
        else
            glyph = 0xf0590;
        return Theme.glyph(glyph);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: fetch
        onStarted: root.attemptedAt = Date.now()
        command: ["curl", "-sf", "--max-time", "15", `https://api.open-meteo.com/v1/forecast?latitude=${root.latitude}&longitude=${root.longitude}&current=temperature_2m,weather_code,is_day`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const current = JSON.parse(text).current;
                    root.temperature = current.temperature_2m;
                    root.code = current.weather_code;
                    root.day = current.is_day === 1;
                    root.fetchedAt = Date.now();
                } catch (e) {
                    // Offline or a bad answer: tried again sooner, see below.
                }
            }
        }
    }

    // Every half an hour since the last answer, every two minutes since the
    // last try while there is none.
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (!fetch.running && now - root.fetchedAt >= 30 * 60 * 1000 && now - root.attemptedAt >= 2 * 60 * 1000)
                fetch.running = true;
        }
    }
}
