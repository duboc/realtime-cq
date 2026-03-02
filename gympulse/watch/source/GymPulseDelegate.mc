using Toybox.WatchUi;
using Toybox.Application;

class GymPulseDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Select/Start button: manual set boundary toggle
    function onSelect() {
        var app = Application.getApp();
        if (app.sensorCollector != null && app.sensorCollector.gymStateEngine != null) {
            app.sensorCollector.gymStateEngine.manualSetBoundary();
            WatchUi.requestUpdate();
        }
        return true;
    }

    // Back button: stop and exit
    function onBack() {
        var app = Application.getApp();
        if (app.sensorCollector != null) {
            app.sensorCollector.stop();
        }
        System.exit();
    }
}
