using Toybox.Sensor;
using Toybox.Timer;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.System;
using Toybox.UserProfile;

class SensorCollector {

    // Latest sensor readings
    var heartRate = 0;
    var accelX = 0;
    var accelY = 0;
    var accelZ = 0;
    var elapsedTime = 0;

    // HRV data
    var hrvCalculator;
    var lastRRIntervals = [];

    // Gym state engine
    var gymStateEngine;

    // User profile
    var maxHR = 190;
    var restingHR = 60;

    // Activity recording
    var session = null;

    // Transmission timer
    var transmitTimer;

    function initialize() {
        hrvCalculator = new HRVCalculator();
        gymStateEngine = new GymStateEngine();
        loadUserProfile();
    }

    function loadUserProfile() {
        var profile = UserProfile.getProfile();
        if (profile != null) {
            var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (hrZones != null && hrZones.size() > 0) {
                maxHR = hrZones[hrZones.size() - 1];
            }
            if (profile has :restingHeartRate && profile.restingHeartRate != null) {
                restingHR = profile.restingHeartRate;
            }
        }
    }

    function start() {
        // Enable standard sensors
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensorEvent));

        // High-frequency sensor listener
        var options = {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => 25
            },
            :heartBeatIntervals => {
                :enabled => true
            }
        };

        if (Sensor has :registerSensorDataListener) {
            Sensor.registerSensorDataListener(method(:onHighFreqData), options);
        }

        // Start activity recording
        if (ActivityRecording has :createSession) {
            session = ActivityRecording.createSession({
                :name => "Gym Workout",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            session.start();
        }

        // Start periodic data transmission (every 3 seconds)
        transmitTimer = new Timer.Timer();
        transmitTimer.start(method(:transmitData), 3000, true);
    }

    function stop() {
        Sensor.enableSensorEvents(null);
        if (Sensor has :unregisterSensorDataListener) {
            Sensor.unregisterSensorDataListener();
        }

        if (session != null) {
            session.stop();
            session.save();
        }

        if (transmitTimer != null) {
            transmitTimer.stop();
        }
    }

    // Standard sensor callback (~1Hz)
    function onSensorEvent(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo.heartRate != null) {
            heartRate = sensorInfo.heartRate;
        }
        if (sensorInfo has :accel && sensorInfo.accel != null) {
            accelX = sensorInfo.accel[0];
            accelY = sensorInfo.accel[1];
            accelZ = sensorInfo.accel[2];
        }

        // Update activity info
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null) {
            if (actInfo.timerTime != null) {
                elapsedTime = actInfo.timerTime;
            }
        }

        // Update gym state engine
        gymStateEngine.update(heartRate, accelX, accelY, accelZ, maxHR, restingHR);

        // Request UI update
        WatchUi.requestUpdate();
    }

    // High-frequency sensor callback
    function onHighFreqData(sensorData as Sensor.SensorData) as Void {
        // Accelerometer data
        if (sensorData has :accelerometerData && sensorData.accelerometerData != null) {
            var accelData = sensorData.accelerometerData;
            // Update latest values from high-freq samples
            if (accelData.x != null && accelData.x.size() > 0) {
                accelX = accelData.x[accelData.x.size() - 1];
                accelY = accelData.y[accelData.y.size() - 1];
                accelZ = accelData.z[accelData.z.size() - 1];
            }
        }

        // RR intervals for HRV
        if (sensorData has :heartRateData && sensorData.heartRateData != null) {
            var hrData = sensorData.heartRateData;
            if (hrData has :heartBeatIntervals && hrData.heartBeatIntervals != null) {
                lastRRIntervals = hrData.heartBeatIntervals;
                hrvCalculator.addIntervals(lastRRIntervals);
            }
        }
    }

    // Build data payload and transmit
    function transmitData() as Void {
        var app = Application.getApp();
        var payload = buildPayload();
        app.dataTransmitter.send(payload);
    }

    function buildPayload() {
        var gse = gymStateEngine;
        return {
            "ts" => System.getTimer(),
            "hr" => heartRate,
            "hrv" => hrvCalculator.getRMSSD(),
            "ax" => accelX,
            "ay" => accelY,
            "az" => accelZ,
            "et" => elapsedTime,
            "mhr" => maxHR,
            "rhr" => restingHR,
            "state" => gse.state,
            "setNumber" => gse.setNumber,
            "repCount" => gse.repCount,
            "preRestHR" => gse.preRestHR,
            "hrDrop" => gse.hrDrop
        };
    }
}
