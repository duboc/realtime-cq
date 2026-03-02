using Toybox.Math;

// Gym workout state detection via accelerometer variance + HR patterns
// States: IDLE, ACTIVE_SET, RESTING, CARDIO

class GymStateEngine {

    // Current state
    var state = "IDLE";

    // Set tracking
    var setNumber = 0;
    var repCount = 0;
    var preRestHR = 0.0;
    var hrDrop = 0.0;
    var sessionMaxHR = 0.0;
    var avgHR = 0.0;

    // Internal tracking
    var hrSum = 0.0;
    var hrCount = 0;
    var accelVarianceHistory = [];
    var hrHistory = [];
    var stateTimer = 0;          // How long in current state (seconds)
    var lastAccelMagnitude = 0.0;

    // Rep detection
    var repPhase = "down";       // "down" or "up"
    var lastMagFiltered = 980.0; // Filtered accel magnitude (~1g in milli-g)
    var repThresholdHigh = 1100.0;
    var repThresholdLow = 900.0;

    // Thresholds
    var accelVarianceSetThreshold = 50000.0;   // High variance = lifting
    var accelVarianceRestThreshold = 5000.0;   // Low variance = resting
    var hrElevatedThreshold = 0.55;            // 55% HRR for elevated HR
    var cardioSteadyThreshold = 0.60;          // 60% HRR for cardio
    var cardioMinDuration = 60;                // 60s steady elevated = cardio

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

        // Compute variance of recent magnitudes
        accelVarianceHistory.add(mag);
        if (accelVarianceHistory.size() > 10) {
            accelVarianceHistory = accelVarianceHistory.slice(1, null);
        }
        var variance = computeVariance(accelVarianceHistory);

        // Detect reps during active set
        if (state.equals("ACTIVE_SET")) {
            detectRep(mag);
        }

        // State machine transitions
        stateTimer += 3;  // ~3 seconds per update
        var hrPct = getHRPct(hr, maxHR, restingHR);
        if (state.equals("IDLE")) {
            if (variance > accelVarianceSetThreshold && hrPct > 0.3) {
                // Movement detected with some HR elevation -> set started
                transitionToSet();
            } else if (hrPct > cardioSteadyThreshold && stateTimer > 30) {
                // Elevated HR without set-like movement -> cardio
                state = "CARDIO";
                stateTimer = 0;
            }
        } else if (state.equals("ACTIVE_SET")) {
            if (variance < accelVarianceRestThreshold && stateTimer > 6) {
                // Movement stopped, set likely done
                preRestHR = hr;
                state = "RESTING";
                stateTimer = 0;
            }
        } else if (state.equals("RESTING")) {
            if (variance > accelVarianceSetThreshold) {
                // New set starting
                hrDrop = preRestHR - hr;
                transitionToSet();
            } else if (hrPct < 0.35 && stateTimer > 120) {
                // Fully recovered, rested too long -> idle
                state = "IDLE";
                stateTimer = 0;
            } else if (hrPct > cardioSteadyThreshold && variance > accelVarianceRestThreshold * 2 && stateTimer > 30) {
                // Moderate movement with elevated HR -> cardio
                state = "CARDIO";
                stateTimer = 0;
            }
        } else if (state.equals("CARDIO")) {
            if (variance > accelVarianceSetThreshold) {
                // Set-like movement during cardio
                transitionToSet();
            } else if (hrPct < 0.4 && stateTimer > 30) {
                // HR dropped, cardio ended
                state = "RESTING";
                stateTimer = 0;
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
    }

    function detectRep(mag) {
        // Simple rep detection using acceleration magnitude crossings
        // Low-pass filter the magnitude
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
            // End current set
            preRestHR = hrHistory.size() > 0 ? hrHistory[hrHistory.size() - 1] : 0;
            state = "RESTING";
            stateTimer = 0;
        } else {
            // Start new set
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
}
