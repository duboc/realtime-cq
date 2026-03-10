using Toybox.WatchUi;
using Toybox.Application;
using Toybox.System;

class GymPulseDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Select/Start button: manual set boundary toggle
    function onSelect() {
        var app = Application.getApp();
        if (app.sensorCollector != null && app.sensorCollector.gymStateEngine != null) {
            var gse = app.sensorCollector.gymStateEngine;
            var wasPrevState = gse.state;
            gse.manualSetBoundary();

            // If we just ended a set (was ACTIVE_SET, now RESTING), trigger weight picker
            if (wasPrevState.equals("ACTIVE_SET") && gse.state.equals("RESTING")) {
                pushWeightPicker(gse);
            }

            WatchUi.requestUpdate();
        }
        return true;
    }

    // Back button: context-dependent
    function onBack() {
        var app = Application.getApp();
        if (app.sensorCollector != null && app.sensorCollector.gymStateEngine != null) {
            var gse = app.sensorCollector.gymStateEngine;

            if (gse.state.equals("RESTING") && gse.setLog.size() > 0) {
                // During rest with logged sets: open set history menu
                WatchUi.pushView(
                    new SetHistoryMenu(),
                    new SetHistoryDelegate(),
                    WatchUi.SLIDE_UP
                );
                return true;
            }
        }

        // IDLE or no sets: stop and exit
        if (app.sensorCollector != null) {
            app.sensorCollector.stop();
        }
        System.exit();
        return true;
    }

    // Push weight picker for a new set
    function pushWeightPicker(gse) {
        WatchUi.pushView(
            new WeightPicker(gse.lastWeight),
            new WeightPickerDelegate(-1),
            WatchUi.SLIDE_UP
        );
    }
}
