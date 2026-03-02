using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

class SoccerMonitorView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var app = Application.getApp();
        var collector = app.sensorCollector;
        var fatigue = app.fatigueEngine;

        if (collector == null || fatigue == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_MEDIUM,
                "Starting...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        // --- Fatigue Zone Color Bar (top) ---
        var fatigueScore = fatigue.getFatigueScore();
        var zoneColor = getZoneColor(fatigueScore);
        dc.setColor(zoneColor, zoneColor);
        dc.fillRectangle(0, 0, dc.getWidth(), 30);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 2, Graphics.FONT_XTINY,
            fatigue.getFatigueZone() + " " + fatigueScore + "%",
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- Heart Rate (large, center) ---
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 45, Graphics.FONT_NUMBER_HOT,
            collector.heartRate.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 5, Graphics.FONT_XTINY, "BPM",
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- Speed (km/h) ---
        var speedKmh = (collector.speed * 3.6);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 50, cy + 20, Graphics.FONT_SMALL,
            speedKmh.format("%.1f"),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 50, cy + 42, Graphics.FONT_XTINY, "km/h",
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- Distance (km) ---
        var distKm = collector.distance / 1000.0;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 50, cy + 20, Graphics.FONT_SMALL,
            distKm.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 50, cy + 42, Graphics.FONT_XTINY, "km",
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- Time Remaining Estimate (bottom) ---
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var minsLeft = fatigue.getEstimatedMinutesLeft();
        dc.drawText(cx, cy + 60, Graphics.FONT_SMALL,
            "~" + minsLeft + " min left",
            Graphics.TEXT_JUSTIFY_CENTER);

        // --- HRV indicator (small, bottom) ---
        var rmssd = collector.hrvCalculator.getRMSSD();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 82, Graphics.FONT_XTINY,
            "HRV:" + rmssd.format("%.0f") + "ms",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function getZoneColor(fatigue) {
        if (fatigue < 30) { return 0x00AA00; }      // Green — fresh
        if (fatigue < 55) { return 0xAAAA00; }       // Yellow — moderate
        if (fatigue < 75) { return 0xFF8800; }       // Orange — tired
        if (fatigue < 90) { return 0xFF0000; }       // Red — exhausted
        return 0xFF00FF;                              // Magenta — critical
    }
}
