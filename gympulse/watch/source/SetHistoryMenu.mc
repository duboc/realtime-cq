using Toybox.WatchUi;
using Toybox.Application;

// Menu to review and edit previous sets during rest
class SetHistoryMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Set History" });

        var app = Application.getApp();
        var gse = app.sensorCollector.gymStateEngine;
        var log = gse.getSetLog();

        // Add items in reverse order (most recent first)
        for (var i = log.size() - 1; i >= 0; i--) {
            var entry = log[i];
            var label = "#" + entry["setNumber"] + ": " + entry["weight"] + "kg x " + entry["reps"];
            addItem(new WatchUi.MenuItem(label, null, i, {}));
        }
    }
}

// Delegate for set history menu
class SetHistoryDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var editIndex = item.getId();
        var app = Application.getApp();
        var gse = app.sensorCollector.gymStateEngine;
        var entry = gse.getSetLog()[editIndex];

        WatchUi.pushView(
            new WeightPicker(entry["weight"]),
            new WeightPickerDelegate(editIndex),
            WatchUi.SLIDE_UP
        );
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
