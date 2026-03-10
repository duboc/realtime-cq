using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

// Weight picker: 0–300 kg in steps of 5
class WeightPicker extends WatchUi.Picker {

    function initialize(defaultWeight) {
        var factory = new NumberFactory(0, 300, 5);
        var defaults = [factory.getIndex(defaultWeight)];

        var title = new WatchUi.Text({
            :text => "WEIGHT (kg)",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_SMALL,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => defaults
        });
    }
}

// Delegate for weight picker
class WeightPickerDelegate extends WatchUi.PickerDelegate {

    var _editIndex;  // -1 = new set, >=0 = editing existing set

    function initialize(editIndex) {
        PickerDelegate.initialize();
        _editIndex = editIndex;
    }

    function onAccept(values) {
        var weight = values[0];
        var app = Application.getApp();
        var gse = app.sensorCollector.gymStateEngine;

        // Default reps to auto-detected repCount
        var defaultReps = gse.repCount;
        if (_editIndex >= 0 && _editIndex < gse.setLog.size()) {
            defaultReps = gse.setLog[_editIndex]["reps"];
        }

        // Push reps picker, passing the selected weight
        WatchUi.pushView(
            new RepsPicker(defaultReps),
            new RepsPickerDelegate(_editIndex, weight),
            WatchUi.SLIDE_UP
        );
        return true;
    }

    function onCancel() {
        // Skip input — use defaults
        if (_editIndex == -1) {
            var app = Application.getApp();
            var gse = app.sensorCollector.gymStateEngine;
            gse.logSet(gse.lastWeight, gse.repCount);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
