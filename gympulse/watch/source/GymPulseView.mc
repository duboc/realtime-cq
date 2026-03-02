using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

class GymPulseView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        var app = Application.getApp();
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Connection status indicator
        if (app.dataTransmitter != null && app.dataTransmitter.connected) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillCircle(w - 20, 20, 6);

        // Heart rate value (large, center)
        var hr = 0;
        if (app.sensorCollector != null) {
            hr = app.sensorCollector.heartRate;
        }

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2 - 20,
            Graphics.FONT_NUMBER_HOT,
            hr > 0 ? hr.toString() : "--",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // BPM label
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2,
            h / 2 + 30,
            Graphics.FONT_SMALL,
            "BPM",
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // State indicator at bottom
        if (app.sensorCollector != null && app.sensorCollector.gymStateEngine != null) {
            var gse = app.sensorCollector.gymStateEngine;
            var stateText = gse.state;

            if (stateText.equals("ACTIVE_SET")) {
                dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                stateText = "SET " + gse.setNumber + " · " + gse.repCount + " reps";
            } else if (stateText.equals("RESTING")) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            } else if (stateText.equals("CARDIO")) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            }

            dc.drawText(
                w / 2,
                h - 40,
                Graphics.FONT_TINY,
                stateText,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }
}
