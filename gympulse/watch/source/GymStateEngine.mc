using Toybox.Math;
using Toybox.System;

// Gym workout state detection via accelerometer variance + HR patterns
// States: IDLE, ACTIVE_SET, RESTING, CARDIO

class GymStateEngine {

    // Current state
    var state = "IDLE";
    var prevState = "IDLE";

    // Set tracking
    var setNumber = 0;
    var repCount = 0;
    var preRestHR = 0.0;
    var hrDrop = 0.0;
    var sessionMaxHR = 0.0;
    var avgHR = 0.0;

    // Set log — array of dicts: {setNumber, weight, reps, peakHR, durationSec}
    var setLog = [];
    var lastWeight = 0;           // Persists across sets as next picker default
    var pendingSetLog = false;    // True when set ends, cleared after picker completes

    // Timing (ms via System.getTimer())
    var setStartTime = 0;
    var restStartTime = 0;
    var setDuration = 0;          // Current/last set duration in ms
    var restDuration = 0;         // Current rest duration in ms
    var avgRepDuration = 0.0;     // Average ms per rep in current set
    var setPeakHR = 0;            // Peak HR in current set

    // Exposed metrics
    var lastVariance = 0.0;       // Latest accel variance for form analysis

    // Internal tracking
    var hrSum = 0.0;
    var hrCount = 0;
    var accelVarianceHistory = [];
    var hrHistory = [];
    var stateTimer = 0;           // How long in current state (seconds)
    var lastAccelMagnitude = 0.0;

    // Rep detection
    var repPhase = "down";        // "down" or "up"
    var lastMagFiltered = 980.0;  // Filtered accel magnitude (~1g in milli-g)
    var repThresholdHigh = 1100.0;
    var repThresholdLow = 900.0;

    // Thresholds
    var accelVarianceSetThreshold = 50000.0;
    var accelVarianceRestThreshold = 5000.0;
    var hrElevatedThreshold = 0.55;
    var cardioSteadyThreshold = 0.60;
    var cardioMinDuration = 60;

    function initialize() {
    }

    function update(hr, accelX, accelY, accelZ, maxHR, restingHR) {
        // Track HR
        if (hr > 0) {
            hrHistory.add(hr);
            if (hrHistory.size() > 30) {
                hrHistory = hrHistory.slice(1, null);
            }
            hrSum += hr;
            hrCount++;
            avgHR = hrSum / hrCount;
            if (hr > sessionMaxHR) {
                sessionMaxHR = hr;
            }
        }

        // Compute accelerometer magnitude and variance
        var mag = Math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
        lastAccelMagnitude = mag;

        accelVarianceHistory.add(mag);
        if (accelVarianceHistory.size() > 10) {
            accelVarianceHistory = accelVarianceHistory.slice(1, null);
        }
        var variance = computeVariance(accelVarianceHistory);
        lastVariance = variance;

        // Detect reps during active set
        if (state.equals("ACTIVE_SET")) {
            detectRep(mag);
            // Track peak HR and timing during set
            if (hr > setPeakHR) {
                setPeakHR = hr;
            }
            setDuration = System.getTimer() - setStartTime;
            if (repCount > 0) {
                avgRepDuration = setDuration.toFloat() / repCount;
            }
        }

        // Track rest duration
        if (state.equals("RESTING")) {
            restDuration = System.getTimer() - restStartTime;
        }

        // Save previous state before transitions
        prevState = state;

        // State machine transitions
        stateTimer += 3;
        var hrPct = getHRPct(hr, maxHR, restingHR);

        if (state.equals("IDLE")) {
            if (variance > accelVarianceSetThreshold && hrPct > 0.3) {
                transitionToSet();
            } else if (hrPct > cardioSteadyThreshold && stateTimer > 30) {
                state = "CARDIO";
                stateTimer = 0;
            }
        } else if (state.equals("ACTIVE_SET")) {
            if (variance < accelVarianceRestThreshold && stateTimer > 6) {
                // Set complete — transition to rest
                preRestHR = hr;
                setDuration = System.getTimer() - setStartTime;
                state = "RESTING";
                stateTimer = 0;
                restStartTime = System.getTimer();
                restDuration = 0;
                pendingSetLog = true;
            }
        } else if (state.equals("RESTING")) {
            if (variance > accelVarianceSetThreshold) {
                hrDrop = preRestHR - hr;
                transitionToSet();
            } else if (hrPct < 0.35 && stateTimer > 120) {
                state = "IDLE";
                stateTimer = 0;
            } else if (hrPct > cardioSteadyThreshold && variance > accelVarianceRestThreshold * 2 && stateTimer > 30) {
                state = "CARDIO";
                stateTimer = 0;
            }
        } else if (state.equals("CARDIO")) {
            if (variance > accelVarianceSetThreshold) {
                transitionToSet();
            } else if (hrPct < 0.4 && stateTimer > 30) {
                state = "RESTING";
                stateTimer = 0;
                restStartTime = System.getTimer();
                restDuration = 0;
            }
        }

        // Track HR drop during rest
        if (state.equals("RESTING") && preRestHR > 0) {
            hrDrop = preRestHR - hr;
        }

        return state;
    }

    function transitionToSet() {
        setNumber++;
        repCount = 0;
        repPhase = "down";
        lastMagFiltered = 980.0;
        state = "ACTIVE_SET";
        stateTimer = 0;
        setStartTime = System.getTimer();
        setPeakHR = 0;
        setDuration = 0;
        avgRepDuration = 0.0;
    }

    function detectRep(mag) {
        lastMagFiltered = lastMagFiltered * 0.7 + mag * 0.3;

        if (repPhase.equals("down") && lastMagFiltered > repThresholdHigh) {
            repPhase = "up";
        } else if (repPhase.equals("up") && lastMagFiltered < repThresholdLow) {
            repPhase = "down";
            repCount++;
        }
    }

    // Manual set boundary (triggered by watch button press)
    function manualSetBoundary() {
        if (state.equals("ACTIVE_SET")) {
            preRestHR = hrHistory.size() > 0 ? hrHistory[hrHistory.size() - 1] : 0;
            setDuration = System.getTimer() - setStartTime;
            state = "RESTING";
            stateTimer = 0;
            restStartTime = System.getTimer();
            restDuration = 0;
            pendingSetLog = true;
        } else {
            transitionToSet();
        }
    }

    function getHRPct(hr, maxHR, restingHR) {
        if (maxHR <= restingHR || hr <= 0) {
            return 0.0;
        }
        return (hr.toFloat() - restingHR) / (maxHR - restingHR);
    }

    function computeVariance(buffer) {
        if (buffer.size() < 2) {
            return 0.0;
        }
        var sum = 0.0;
        for (var i = 0; i < buffer.size(); i++) {
            sum += buffer[i];
        }
        var mean = sum / buffer.size();
        var sumSqDev = 0.0;
        for (var i = 0; i < buffer.size(); i++) {
            var dev = buffer[i] - mean;
            sumSqDev += dev * dev;
        }
        return sumSqDev / buffer.size();
    }

    function getAccelMagnitude() {
        return lastAccelMagnitude;
    }

    // Log a completed set with user-confirmed weight and reps
    function logSet(weight, reps) {
        var entry = {
            "setNumber" => setNumber,
            "weight" => weight,
            "reps" => reps,
            "peakHR" => setPeakHR,
            "durationSec" => setDuration / 1000
        };
        setLog.add(entry);
        lastWeight = weight;
        pendingSetLog = false;
    }

    // Edit an existing set log entry
    function updateSetLog(index, weight, reps) {
        if (index >= 0 && index < setLog.size()) {
            setLog[index]["weight"] = weight;
            setLog[index]["reps"] = reps;
            lastWeight = weight;
        }
    }

    // Return the set log array
    function getSetLog() {
        return setLog;
    }
}
