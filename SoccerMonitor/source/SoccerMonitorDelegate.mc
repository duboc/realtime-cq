using Toybox.WatchUi;

class SoccerMonitorDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Start/Lap button — mark half-time or substitution events
    function onSelect() {
        // Could mark half-time, sub, or reset baseline
        return true;
    }

    // Back button — stop and save
    function onBack() {
        var app = Application.getApp();
        app.sensorCollector.stop();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
