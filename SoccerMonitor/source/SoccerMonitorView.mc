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
        var transmitter = app.dataTransmitter;

        if (collector == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_MEDIUM,
                "Starting...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        // --- Connection status (top) ---
        var isConnected = (transmitter != null && transmitter.connected);
        if (isConnected) {
            dc.setColor(0x00CC00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 48, 32, 6);
            dc.drawText(cx + 4, 22, Graphics.FONT_SMALL,
                "Connected", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 38, 32, 6);
            dc.drawText(cx + 8, 22, Graphics.FONT_SMALL,
                "No Link", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- Heart Rate (large, centered) ---
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 30, Graphics.FONT_NUMBER_HOT,
            collector.heartRate.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Graphics.FONT_MEDIUM, "BPM",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
