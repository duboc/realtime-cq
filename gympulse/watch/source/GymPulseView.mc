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

        // Connection status indicator (top-right)
        if (app.dataTransmitter != null && app.dataTransmitter.connected) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillCircle(w - 20, 20, 6);

        var hr = 0;
        if (app.sensorCollector != null) {
            hr = app.sensorCollector.heartRate;
        }

        // Heart rate (always centered)
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2, h / 2 - 20,
            Graphics.FONT_NUMBER_HOT,
            hr > 0 ? hr.toString() : "--",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (app.sensorCollector != null && app.sensorCollector.gymStateEngine != null) {
            var gse = app.sensorCollector.gymStateEngine;
            var dt = app.dataTransmitter;

            if (gse.state.equals("ACTIVE_SET")) {
                // === ACTIVE SET VIEW ===
                // Top: SET N (orange) + last weight context
                dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, 25, Graphics.FONT_SMALL,
                    "SET " + gse.setNumber,
                    Graphics.TEXT_JUSTIFY_CENTER);

                // Show last weight context if available
                if (gse.lastWeight > 0) {
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w / 2, 48, Graphics.FONT_XTINY,
                        gse.lastWeight + "kg",
                        Graphics.TEXT_JUSTIFY_CENTER);
                }

                // Bottom: rep count + set timer
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 55, Graphics.FONT_MEDIUM,
                    gse.repCount + " reps",
                    Graphics.TEXT_JUSTIFY_CENTER);

                var setSec = gse.setDuration / 1000;
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 30, Graphics.FONT_TINY,
                    setSec.toNumber() + "s",
                    Graphics.TEXT_JUSTIFY_CENTER);

            } else if (gse.state.equals("RESTING")) {
                // === RESTING VIEW ===
                // Top: recovery status from cloud
                var recStatus = "REST";
                var recColor = Graphics.COLOR_GREEN;
                if (dt != null && dt.cloudRecovery > 0) {
                    if (dt.cloudRecovery >= 85) {
                        recStatus = "GO!";
                        recColor = Graphics.COLOR_GREEN;
                    } else if (dt.cloudRecovery >= 60) {
                        recStatus = "ALMOST";
                        recColor = Graphics.COLOR_ORANGE;
                    } else {
                        recStatus = "WAIT";
                        recColor = Graphics.COLOR_RED;
                    }
                }
                dc.setColor(recColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, 25, Graphics.FONT_SMALL,
                    recStatus, Graphics.TEXT_JUSTIFY_CENTER);

                // Bottom: rest timer + recovery %
                var restSec = gse.restDuration / 1000;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 55, Graphics.FONT_MEDIUM,
                    restSec.toNumber() + "s rest",
                    Graphics.TEXT_JUSTIFY_CENTER);

                if (dt != null && dt.cloudRecovery > 0) {
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w / 2, h - 30, Graphics.FONT_TINY,
                        "Rec " + dt.cloudRecovery.toNumber() + "%",
                        Graphics.TEXT_JUSTIFY_CENTER);
                }

                // Show last set summary from setLog
                var log = gse.getSetLog();
                if (log.size() > 0) {
                    var lastEntry = log[log.size() - 1];
                    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w / 2, 48, Graphics.FONT_XTINY,
                        lastEntry["weight"] + "kg x " + lastEntry["reps"] + " reps",
                        Graphics.TEXT_JUSTIFY_CENTER);
                }

            } else {
                // === IDLE / CARDIO VIEW ===
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h / 2 + 30, Graphics.FONT_SMALL,
                    "BPM", Graphics.TEXT_JUSTIFY_CENTER);

                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h - 40, Graphics.FONT_TINY,
                    gse.state, Graphics.TEXT_JUSTIFY_CENTER);

                if (dt != null && dt.cloudFatigue > 0) {
                    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w / 2, h - 22, Graphics.FONT_TINY,
                        "Fat " + dt.cloudFatigue.toNumber() + "%",
                        Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }
    }
}
