pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The current weather in Lublin from Open-Meteo (no key), every half an hour,
// with what the popup lists: how it feels, the wind, the day's sun, when it
// is to rain, and the week from today.
// Unknown when it has not been fetched for three hours: offline, it is not
// shown rather than shown stale. The half hours are by the wall clock, checked
// every minute: a Timer's own does not run during a suspend.
Singleton {
    id: root

    // Where, and what the popup calls it.
    readonly property string place: "Lublin"
    readonly property real latitude: 51.25
    readonly property real longitude: 22.57

    property real temperature: NaN
    property int code: -1
    property bool day: true
    property real fetchedAt: 0
    readonly property bool known: !isNaN(temperature) && clock.date.getTime() - fetchedAt < 3 * 3600 * 1000

    readonly property string temperatureText: known ? Math.round(temperature) + "°" : ""

    property real apparent: NaN
    property int humidity: 0
    property real windSpeed: 0       // km/h
    property int windDirection: 0    // degrees, where it blows from
    // Today's.
    property real sunrise: 0         // ms
    property real sunset: 0
    // The hours from today's first on: [{ time: its start, in ms; chance: of
    // precipitation, in %; code: the weather's }].
    property var hours: []
    // Today and the six days after it: [{ time: its start, in ms; code:
    // the weather's; low, high; chance: of precipitation, in % }].
    property var days: []

    // The first hour of the next twelve, the current one included, in which
    // it is more likely to rain or snow than not; null if there is none.
    readonly property var wetHour: {
        const now = clock.date.getTime();
        return hours.find(h => h.time + 3600 * 1000 > now && h.time < now + 12 * 3600 * 1000 && h.chance >= 50) ?? null;
    }

    function isSnow(c) {
        return (c >= 71 && c <= 77) || c === 85 || c === 86;
    }

    // The popup's rows: a label, a value and the value's color.
    readonly property var details: {
        if (!known)
            return [];
        const row = (label, value, color) => ({
                    label: label,
                    value: value,
                    color: color ?? Theme.text
                });
        const hm = ms => Qt.formatTime(new Date(ms), "HH:mm");
        const compass = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(windDirection / 45) % 8];
        const wet = wetHour;
        const rows = [];
        if (wet)
            rows.push(row(isSnow(wet.code) ? "Snow" : "Rain", (wet.time <= clock.date.getTime() ? "now" : hm(wet.time)) + ", " + wet.chance + "%", Theme.sky));
        else if (hours.length > 0)
            rows.push(row("Rain", "none for 12 h"));
        rows.push(row("Feels like", Math.round(apparent) + "°"));
        rows.push(row("Wind", Math.round(windSpeed) + " km/h " + compass));
        rows.push(row("Humidity", humidity + "%"));
        if (sunrise > 0 && sunset > 0)
            rows.push(row("Daylight", hm(sunrise) + " – " + hm(sunset)));
        return rows;
    }
    property real attemptedAt: 0

    // After a suspend, say: the lock refreshes it before it shows.
    function refreshIfStale() {
        if (!fetch.running && Date.now() - fetchedAt >= 30 * 60 * 1000)
            fetch.running = true;
    }

    readonly property string description: {
        const c = code;
        if (c === 0)
            return "Clear";
        if (c <= 2)
            return "Partly cloudy";
        if (c === 3)
            return "Overcast";
        if (c === 45 || c === 48)
            return "Fog";
        if (c >= 51 && c <= 57)
            return "Drizzle";
        if (c === 65 || c === 82)
            return "Heavy rain";
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82))
            return "Rain";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return "Snow";
        if (c >= 95)
            return "Thunderstorm";
        return "";
    }

    readonly property string icon: glyphFor(code, day)

    // WMO weather codes, as Open-Meteo gives them.
    function glyphFor(c, day) {
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
        command: ["curl", "-sf", "--max-time", "15", `https://api.open-meteo.com/v1/forecast?latitude=${root.latitude}&longitude=${root.longitude}&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code,is_day&hourly=precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&timeformat=unixtime&forecast_days=7`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text);
                    const current = answer.current;
                    const hourly = answer.hourly;
                    const daily = answer.daily;
                    root.temperature = current.temperature_2m;
                    root.code = current.weather_code;
                    root.day = current.is_day === 1;
                    root.apparent = current.apparent_temperature;
                    root.humidity = current.relative_humidity_2m;
                    root.windSpeed = current.wind_speed_10m;
                    root.windDirection = current.wind_direction_10m;
                    // The first day is today, by the place's own time.
                    root.sunrise = daily.sunrise[0] * 1000;
                    root.sunset = daily.sunset[0] * 1000;
                    root.hours = hourly.time.map((t, i) => ({
                                time: t * 1000,
                                chance: hourly.precipitation_probability[i] ?? 0,
                                code: hourly.weather_code[i]
                            }));
                    root.days = daily.time.map((t, i) => ({
                                time: t * 1000,
                                code: daily.weather_code[i],
                                low: daily.temperature_2m_min[i],
                                high: daily.temperature_2m_max[i],
                                chance: daily.precipitation_probability_max[i] ?? 0
                            }));
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
