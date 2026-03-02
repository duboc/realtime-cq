using Toybox.Application;
using Toybox.WatchUi;

class GymPulseApp extends Application.AppBase {

    var sensorCollector;
    var dataTransmitter;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        sensorCollector = new SensorCollector();
        dataTransmitter = new DataTransmitter();
        sensorCollector.start();
    }

    function onStop(state) {
        if (sensorCollector != null) {
            sensorCollector.stop();
        }
        if (dataTransmitter != null) {
            dataTransmitter.stop();
        }
    }

    function getInitialView() {
        return [new GymPulseView(), new GymPulseDelegate()];
    }
}
