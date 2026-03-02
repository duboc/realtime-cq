using Toybox.Sensor;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.System;
using Toybox.UserProfile;

class SensorCollector {

    // Latest sensor readings
    var heartRate = 0;
    var speed = 0.0;
    var cadence = 0;
    var altitude = 0.0;
    var accelX = 0;
    var accelY = 0;
    var accelZ = 0;
    var latitude = 0.0;
    var longitude = 0.0;
    var gpsSpeed = 0.0;
    var distance = 0.0;
    var calories = 0;
    var elapsedTime = 0;

    // HRV data
    var hrvCalculator;
    var lastRRIntervals = [];

    // High-frequency data buffers
    var accelBuffer = [];
    var gyroBuffer = [];

    // User profile
    var maxHR = 190;        // Will be updated from profile
    var restingHR = 60;

    // Activity recording
    var session = null;

    // Transmission timer
    var transmitTimer;

    function initialize() {
        hrvCalculator = new HRVCalculator();
        loadUserProfile();
    }

    function loadUserProfile() {
        var profile = UserProfile.getProfile();
        if (profile != null) {
            // Get HR zones for personalized thresholds
            var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (hrZones != null && hrZones.size() > 0) {
                maxHR = hrZones[hrZones.size() - 1];
            }
            // Resting HR
            if (profile has :restingHeartRate && profile.restingHeartRate != null) {
                restingHR = profile.restingHeartRate;
            }
        }
    }

    function start() {
        // Enable standard sensors
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensorEvent));

        // Register high-frequency sensor listener
        // This gives us accelerometer, gyro, magnetometer, and RR intervals
        var options = {
            :period => 1,  // Callback period in seconds
            :accelerometer => {
                :enabled => true,
                :sampleRate => 25  // 25 Hz accelerometer
            },
            :heartBeatIntervals => {
                :enabled => true   // RR intervals for HRV
            }
        };

        // Only add gyroscope if supported
        if (Sensor has :registerSensorDataListener) {
            try {
                options[:gyroscope] = {
                    :enabled => true,
                    :sampleRate => 25
                };
            } catch (e) {
                // Gyroscope not available on this device
            }
            Sensor.registerSensorDataListener(method(:onHighFreqData), options);
        }

        // Enable GPS
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));

        // Start activity recording (saves to FIT file)
        if (ActivityRecording has :createSession) {
            session = ActivityRecording.createSession({
                :name => "Soccer Match",
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
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);

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
        if (sensorInfo.speed != null) {
            speed = sensorInfo.speed;
        }
        if (sensorInfo.cadence != null) {
            cadence = sensorInfo.cadence;
        }
        if (sensorInfo.altitude != null) {
            altitude = sensorInfo.altitude;
        }
        if (sensorInfo has :accel && sensorInfo.accel != null) {
            accelX = sensorInfo.accel[0];
            accelY = sensorInfo.accel[1];
            accelZ = sensorInfo.accel[2];
        }

        // Update activity info
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null) {
            if (actInfo.elapsedDistance != null) {
                distance = actInfo.elapsedDistance;
            }
            if (actInfo.calories != null) {
                calories = actInfo.calories;
            }
            if (actInfo.timerTime != null) {
                elapsedTime = actInfo.timerTime;
            }
        }

        // Update fatigue engine
        var app = Application.getApp();
        app.fatigueEngine.update(self);

        // Request UI update
        WatchUi.requestUpdate();
    }

    // High-frequency sensor callback
    function onHighFreqData(sensorData as Sensor.SensorData) as Void {
        // Accelerometer data (arrays of samples)
        if (sensorData has :accelerometerData && sensorData.accelerometerData != null) {
            var accelData = sensorData.accelerometerData;
            // Store latest batch for sprint/impact detection
            accelBuffer = {
                :x => accelData.x,
                :y => accelData.y,
                :z => accelData.z
            };
        }

        // Heart beat intervals (RR intervals) — KEY for HRV
        if (sensorData has :heartRateData && sensorData.heartRateData != null) {
            var hrData = sensorData.heartRateData;
            if (hrData has :heartBeatIntervals && hrData.heartBeatIntervals != null) {
                lastRRIntervals = hrData.heartBeatIntervals;
                hrvCalculator.addIntervals(lastRRIntervals);
            }
        }

        // Gyroscope data
        if (sensorData has :gyroscopeData && sensorData.gyroscopeData != null) {
            gyroBuffer = {
                :x => sensorData.gyroscopeData.x,
                :y => sensorData.gyroscopeData.y,
                :z => sensorData.gyroscopeData.z
            };
        }
    }

    // GPS position callback
    function onPosition(info as Position.Info) as Void {
        if (info.position != null) {
            var coords = info.position.toDegrees();
            latitude = coords[0];
            longitude = coords[1];
        }
        if (info.speed != null) {
            gpsSpeed = info.speed;
        }
    }

    // Build data payload and transmit
    function transmitData() as Void {
        var app = Application.getApp();
        var payload = buildPayload();
        app.dataTransmitter.send(payload);
    }

    function buildPayload() {
        var app = Application.getApp();
        return {
            "ts" => System.getTimer(),                    // Timestamp
            "hr" => heartRate,                            // Heart rate (bpm)
            "spd" => speed,                               // Speed (m/s)
            "gspd" => gpsSpeed,                           // GPS speed (m/s)
            "cad" => cadence,                             // Cadence (spm)
            "alt" => altitude,                            // Altitude (m)
            "lat" => latitude,                            // Latitude
            "lon" => longitude,                           // Longitude
            "dist" => distance,                           // Distance (m)
            "cal" => calories,                            // Calories (kcal)
            "et" => elapsedTime,                          // Elapsed time (ms)
            "ax" => accelX,                               // Accel X
            "ay" => accelY,                               // Accel Y
            "az" => accelZ,                               // Accel Z
            "hrv" => hrvCalculator.getRMSSD(),            // Current RMSSD
            "hri" => hrvCalculator.getLatestHRIndex(),    // HR index
            "mhr" => maxHR,                               // User max HR
            "rhr" => restingHR,                           // User resting HR
            "fat" => app.fatigueEngine.getFatigueScore()  // On-watch fatigue %
        };
    }
}
