pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The weather in Lublin: the forecast from Open-Meteo (no key), every half an
// hour, and the air as IMGW's station measures it, every ten minutes, with
// what the popup lists: how it feels, the wind, the day's sun, when it is to
// rain, and the week from today.
// The forecast's "now" is a model's, and can be degrees off: it stands in
// only when the station has not answered or its measurement is old.
// Unknown when it has not been fetched for three hours: offline, it is not
// shown rather than shown stale. The half hours are by the wall clock, checked
// every minute: a Timer's own does not run during a suspend.
Singleton {
    id: root

    // Where, and what the popup calls it.
    readonly property string place: "Lublin"
    readonly property real latitude: 51.25
    readonly property real longitude: 22.57
    // IMGW's Lublin-Radawiec.
    readonly property string station: "351220495"

    // The air now, as the forecast's model has it and as the station measured
    // it: { time: of the measurement, in ms; temperature, apparent; humidity,
    // in %; windSpeed, in km/h; windDirection, in degrees, where it blows
    // from }, null when there is none.
    property var modelled: null
    property var measured: null
    readonly property var air: measured && clock.date.getTime() - measured.time < 2 * 3600 * 1000 ? measured : modelled

    readonly property real temperature: air ? air.temperature : NaN
    property int code: -1
    property bool day: true
    property real fetchedAt: 0
    readonly property bool known: !isNaN(temperature) && clock.date.getTime() - fetchedAt < 3 * 3600 * 1000

    readonly property string temperatureText: known ? Math.round(temperature) + "°" : ""

    readonly property real apparent: air ? air.apparent : NaN
    readonly property int humidity: air ? Math.round(air.humidity) : 0
    readonly property real windSpeed: air ? air.windSpeed : 0
    readonly property int windDirection: air ? air.windDirection : 0
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
    property real observedAt: 0

    // After a suspend, say: the lock refreshes it before it shows.
    function refreshIfStale() {
        const now = Date.now();
        if (!fetch.running && now - fetchedAt >= 30 * 60 * 1000)
            fetch.running = true;
        if (!observe.running && now - observedAt >= 10 * 60 * 1000)
            observe.running = true;
    }

    // How it feels in the shade, by Steadman's formula: the temperature in
    // °C, the humidity in %, the wind in km/h.
    function feelsLike(temperature, humidity, wind) {
        const vapour = humidity / 100 * 6.105 * Math.exp(17.27 * temperature / (237.7 + temperature));
        return temperature + 0.33 * vapour - 0.7 * wind / 3.6 - 4;
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
                    root.modelled = {
                        time: current.time * 1000,
                        temperature: current.temperature_2m,
                        apparent: current.apparent_temperature,
                        humidity: current.relative_humidity_2m,
                        windSpeed: current.wind_speed_10m,
                        windDirection: current.wind_direction_10m
                    };
                    root.code = current.weather_code;
                    root.day = current.is_day === 1;
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

    // The station's last measurements, each with its own time, in UTC; its
    // wind is in m/s.
    Process {
        id: observe
        onStarted: root.observedAt = Date.now()
        command: ["curl", "-sf", "--max-time", "15", `https://danepubliczne.imgw.pl/api/data/meteo/id/${root.station}`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text)[0];
                    const temperature = parseFloat(answer.temperatura_powietrza);
                    const humidity = parseFloat(answer.wilgotnosc_wzgledna);
                    const windSpeed = parseFloat(answer.wiatr_srednia_predkosc) * 3.6;
                    const windDirection = parseFloat(answer.wiatr_kierunek);
                    const time = new Date(answer.temperatura_powietrza_data.replace(" ", "T") + "Z").getTime();
                    if ([temperature, humidity, windSpeed, windDirection, time].some(isNaN))
                        return;
                    root.measured = {
                        time: time,
                        temperature: temperature,
                        apparent: root.feelsLike(temperature, humidity, windSpeed),
                        humidity: humidity,
                        windSpeed: windSpeed,
                        windDirection: windDirection
                    };
                } catch (e) {
                    // Offline or a bad answer: the last one stands while it
                    // is fresh, then the model's.
                }
            }
        }
    }

    // The forecast every half an hour since the last answer, every two
    // minutes since the last try while there is none; the station every ten
    // minutes.
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (!fetch.running && now - root.fetchedAt >= 30 * 60 * 1000 && now - root.attemptedAt >= 2 * 60 * 1000)
                fetch.running = true;
            if (!observe.running && now - root.observedAt >= 10 * 60 * 1000)
                observe.running = true;
        }
    }
}
