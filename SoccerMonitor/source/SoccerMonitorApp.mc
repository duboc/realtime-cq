using Toybox.Application;
using Toybox.WatchUi;

class SoccerMonitorApp extends Application.AppBase {

    var sensorCollector;
    var dataTransmitter;
    var fatigueEngine;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        sensorCollector = new SensorCollector();
        dataTransmitter = new DataTransmitter();
        fatigueEngine = new FatigueEngine();

        sensorCollector.start();
    }

    function onStop(state) {
        sensorCollector.stop();
        dataTransmitter.stop();
    }

    function getInitialView() {
        var view = new SoccerMonitorView();
        var delegate = new SoccerMonitorDelegate();
        return [view, delegate];
    }
}
