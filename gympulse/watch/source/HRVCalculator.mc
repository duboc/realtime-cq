using Toybox.Math;

class HRVCalculator {

    // Rolling window of RR intervals (last 60 seconds worth)
    var rrWindow = [];
    var maxWindowSize = 120;  // ~120 beats in 60s at 120bpm

    function initialize() {
    }

    function addIntervals(intervals) {
        for (var i = 0; i < intervals.size(); i++) {
            rrWindow.add(intervals[i]);
        }
        // Trim to window size
        while (rrWindow.size() > maxWindowSize) {
            rrWindow = rrWindow.slice(1, null);
        }
    }

    // RMSSD — Root Mean Square of Successive Differences
    // Primary short-term HRV metric, reflects parasympathetic activity
    // Dropping RMSSD during exercise = increasing fatigue
    function getRMSSD() {
        if (rrWindow.size() < 4) {
            return 0.0;
        }

        var sumSquaredDiff = 0.0;
        var count = 0;

        for (var i = 1; i < rrWindow.size(); i++) {
            var diff = rrWindow[i] - rrWindow[i - 1];
            // Filter out artifacts (>20% change likely artifact)
            var prev = rrWindow[i - 1];
            var absDiff = diff < 0 ? -diff : diff;
            if (prev > 0 && absDiff.toFloat() / prev < 0.20) {
                sumSquaredDiff += diff * diff;
                count++;
            }
        }

        if (count == 0) {
            return 0.0;
        }

        return Math.sqrt(sumSquaredDiff / count);
    }

    // SDNN — Standard deviation of NN intervals
    // Overall HRV variability
    function getSDNN() {
        if (rrWindow.size() < 4) {
            return 0.0;
        }

        var sum = 0.0;
        for (var i = 0; i < rrWindow.size(); i++) {
            sum += rrWindow[i];
        }
        var mean = sum / rrWindow.size();

        var sumSqDev = 0.0;
        for (var i = 0; i < rrWindow.size(); i++) {
            var dev = rrWindow[i] - mean;
            sumSqDev += dev * dev;
        }

        return Math.sqrt(sumSqDev / rrWindow.size());
    }

    // HR derived from RR intervals
    function getLatestHRIndex() {
        if (rrWindow.size() < 2) {
            return 0;
        }
        // Average of last 5 RR intervals
        var count = 5;
        if (rrWindow.size() < count) {
            count = rrWindow.size();
        }
        var sum = 0.0;
        for (var i = rrWindow.size() - count; i < rrWindow.size(); i++) {
            sum += rrWindow[i];
        }
        var avgRR = sum / count;
        if (avgRR > 0) {
            return (60000.0 / avgRR).toNumber();  // Convert ms to bpm
        }
        return 0;
    }
}
