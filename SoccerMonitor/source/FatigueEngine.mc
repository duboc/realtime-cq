using Toybox.Math;

class FatigueEngine {

    // Fatigue score: 0 (fresh) to 100 (exhausted)
    var fatigueScore = 0.0;

    // Rolling metrics
    var hrHistory = [];            // Last 90 readings (~90 seconds)
    var speedHistory = [];         // Speed over time
    var hrvHistory = [];           // RMSSD over time
    var sprintCount = 0;          // Number of sprints detected
    var highIntensitySeconds = 0;  // Time above 85% max HR

    // Thresholds (will be personalized from user profile)
    var maxHR = 190;
    var restingHR = 60;
    var sprintThreshold = 5.5;    // m/s (~20 km/h) = sprint for soccer

    // Baseline values (set from first 5 minutes)
    var baselineHR = 0.0;
    var baselineHRV = 0.0;
    var baselineSpeed = 0.0;
    var isBaselineSet = false;
    var baselineSamples = 0;
    var baselineHRSum = 0.0;
    var baselineHRVSum = 0.0;
    var baselineSpeedSum = 0.0;

    function initialize() {
    }

    function update(collector) {
        var hr = collector.heartRate;
        var spd = collector.speed > collector.gpsSpeed ? collector.speed : collector.gpsSpeed;
        var rmssd = collector.hrvCalculator.getRMSSD();

        // Build history buffers (keep last 90 seconds)
        hrHistory.add(hr);
        speedHistory.add(spd);
        hrvHistory.add(rmssd);
        if (hrHistory.size() > 90) { hrHistory = hrHistory.slice(1, null); }
        if (speedHistory.size() > 90) { speedHistory = speedHistory.slice(1, null); }
        if (hrvHistory.size() > 90) { hrvHistory = hrvHistory.slice(1, null); }

        // Update max HR from user profile
        maxHR = collector.maxHR;
        restingHR = collector.restingHR;

        // Establish baseline (first 5 minutes of match)
        if (!isBaselineSet && baselineSamples < 300) {
            baselineHRSum += hr;
            baselineHRVSum += rmssd;
            baselineSpeedSum += spd;
            baselineSamples++;
            if (baselineSamples >= 300) {
                baselineHR = baselineHRSum / baselineSamples;
                baselineHRV = baselineHRVSum / baselineSamples;
                baselineSpeed = baselineSpeedSum / baselineSamples;
                isBaselineSet = true;
            }
        }

        // Track high-intensity time
        var hrPercent = getHRPercent(hr);
        if (hrPercent > 85.0) {
            highIntensitySeconds++;
        }

        // Detect sprints
        if (spd > sprintThreshold) {
            sprintCount++;
        }

        // Calculate composite fatigue score
        fatigueScore = calculateFatigue(hr, spd, rmssd);
    }

    function getHRPercent(hr) {
        if (maxHR <= restingHR) { return 0.0; }
        // Using HR Reserve (Karvonen method)
        return ((hr - restingHR).toFloat() / (maxHR - restingHR)) * 100.0;
    }

    function calculateFatigue(hr, speed, rmssd) {
        var score = 0.0;

        // === Factor 1: HR Zone Stress (0-30 points) ===
        // Higher HR% = more fatigue accumulation
        var hrPct = getHRPercent(hr);
        if (hrPct > 90) {
            score += 30.0;
        } else if (hrPct > 85) {
            score += 25.0;
        } else if (hrPct > 80) {
            score += 18.0;
        } else if (hrPct > 70) {
            score += 10.0;
        } else {
            score += hrPct * 0.1;
        }

        // === Factor 2: Cardiac Drift (0-25 points) ===
        // If HR is rising while speed is constant or dropping = fatigue
        if (isBaselineSet && hrHistory.size() > 30) {
            var recentHR = avgLast(hrHistory, 30);
            var drift = ((recentHR - baselineHR) / baselineHR) * 100.0;
            if (drift > 0) {
                score += (drift * 2.5).toFloat();  // 10% drift = 25 points
                if (score > 55) { score = 55.0; }  // Cap factor 1+2
            }
        }

        // === Factor 3: HRV Decline (0-20 points) ===
        // Dropping RMSSD = parasympathetic withdrawal = fatigue
        if (isBaselineSet && baselineHRV > 0 && rmssd > 0) {
            var hrvDecline = ((baselineHRV - rmssd) / baselineHRV) * 100.0;
            if (hrvDecline > 0) {
                score += (hrvDecline * 0.4).toFloat();  // 50% decline = 20 points
            }
        }

        // === Factor 4: Speed Decay (0-15 points) ===
        // Dropping average speed over time
        if (isBaselineSet && baselineSpeed > 0 && speedHistory.size() > 30) {
            var recentSpeed = avgLast(speedHistory, 30);
            var speedDecay = ((baselineSpeed - recentSpeed) / baselineSpeed) * 100.0;
            if (speedDecay > 0) {
                score += (speedDecay * 0.3).toFloat();
            }
        }

        // === Factor 5: Cumulative High-Intensity Load (0-10 points) ===
        // More time spent above 85% HR = more fatigue
        var hiMinutes = highIntensitySeconds / 60.0;
        score += (hiMinutes * 0.5).toFloat();  // 20 minutes @ high intensity = 10 pts

        // Clamp 0-100
        if (score < 0) { score = 0.0; }
        if (score > 100) { score = 100.0; }

        return score;
    }

    function avgLast(buffer, n) {
        if (buffer.size() == 0) { return 0.0; }
        var count = n;
        if (buffer.size() < count) { count = buffer.size(); }
        var sum = 0.0;
        for (var i = buffer.size() - count; i < buffer.size(); i++) {
            sum += buffer[i];
        }
        return sum / count;
    }

    function getFatigueScore() {
        return fatigueScore.toNumber();
    }

    function getFatigueZone() {
        if (fatigueScore < 30) { return "FRESH"; }
        if (fatigueScore < 55) { return "MODERATE"; }
        if (fatigueScore < 75) { return "TIRED"; }
        if (fatigueScore < 90) { return "EXHAUSTED"; }
        return "CRITICAL";
    }

    function getEstimatedMinutesLeft() {
        // Simple linear projection based on fatigue rate
        if (fatigueScore < 10 || hrHistory.size() < 60) {
            return 90;  // Can't estimate yet
        }
        // Rate of fatigue accumulation per minute
        var minutesElapsed = hrHistory.size() / 60.0;
        if (minutesElapsed < 1) { return 90; }
        var fatigueRate = fatigueScore / minutesElapsed;
        if (fatigueRate <= 0) { return 90; }
        var remaining = (100.0 - fatigueScore) / fatigueRate;
        if (remaining > 90) { return 90; }
        return remaining.toNumber();
    }
}
