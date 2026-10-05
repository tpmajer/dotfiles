import QtQuick
import Quickshell
import qs

// A sound wave in the bar: a row of bars, each as high as its level. The
// levels are the spectrum of what plays, or, simulated, a pattern that
// only tells that something plays. Paused, the bars are low and gray.
Item {
    id: wave

    property var levels: []          // 0 to 1, one a bar
    property color color: Theme.text
    property bool simulated: false
    property bool playing: false

    readonly property int count: levels.length
    // 2.5 px is 4 whole device pixels at scale 1.6.
    readonly property real barWidth: 2.5
    readonly property real gap: 2.5
    readonly property real maxHeight: 20
    readonly property real minHeight: 2.5

    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    // Where the wave is in its window, to draw the bars on whole device
    // pixels, and so with hard edges.
    readonly property point origin: {
        // Referenced so the binding re-evaluates when the wave moves:
        // every item from the wave up to the window.
        for (let item = wave; item; item = item.parent)
            void (item.x + item.y);
        return wave.mapToItem(null, 0, 0);
    }

    // The simulated pattern: two slow sines a bar, out of step.
    property int phase: 0
    function simulatedLevel(index) {
        return 0.2 + 0.8 * Math.abs(Math.sin(phase * 0.45 + index * 1.3) * Math.sin(phase * 0.17 + index * 0.7));
    }

    function level(index) {
        if (!playing)
            return 0;
        if (simulated)
            return simulatedLevel(index);
        return Math.max(0, Math.min(1, levels[index] ?? 0));
    }

    implicitWidth: count * barWidth + (count - 1) * gap
    implicitHeight: maxHeight

    // In steps, 8 a second: the bar is not redrawn any more often.
    Timer {
        interval: 125
        repeat: true
        running: wave.simulated && wave.playing && wave.visible
        onTriggered: wave.phase++
    }

    Repeater {
        model: wave.count

        Rectangle {
            required property int index
            // In the window's coordinates. An Item has a left and a bottom
            // of its own, its anchor lines.
            readonly property real windowLeft: wave.origin.x + index * (wave.barWidth + wave.gap)
            readonly property real windowBottom: wave.origin.y + wave.height
            readonly property real tall: Math.max(wave.minHeight, Theme.snap(wave.minHeight + (wave.maxHeight - wave.minHeight) * wave.level(index), wave.dpr))

            x: Theme.snap(windowLeft, wave.dpr) - wave.origin.x
            y: Theme.snap(windowBottom - tall, wave.dpr) - wave.origin.y
            width: wave.barWidth
            height: tall
            radius: width / 2
            color: wave.playing ? wave.color : Theme.subtext0
        }
    }
}
