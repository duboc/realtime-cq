using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

// Reps picker: 0–50 in steps of 1
class RepsPicker extends WatchUi.Picker {

    function initialize(defaultReps) {
        var factory = new NumberFactory(0, 50, 1);
        var defaults = [factory.getIndex(defaultReps)];

        var title = new WatchUi.Text({
            :text => "REPS",
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

// Delegate for reps picker
class RepsPickerDelegate extends WatchUi.PickerDelegate {

    var _editIndex;
    var _weight;

    function initialize(editIndex, weight) {
        PickerDelegate.initialize();
        _editIndex = editIndex;
        _weight = weight;
    }

    function onAccept(values) {
        var reps = values[0];
        var app = Application.getApp();
        var gse = app.sensorCollector.gymStateEngine;

        if (_editIndex >= 0) {
            // Editing an existing set
            gse.updateSetLog(_editIndex, _weight, reps);
        } else {
            // Logging a new set
            gse.logSet(_weight, reps);
        }

        // Pop back to main view (pop RepsPicker + WeightPicker)
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() {
        // Use auto-detected reps with the selected weight
        if (_editIndex == -1) {
            var app = Application.getApp();
            var gse = app.sensorCollector.gymStateEngine;
            gse.logSet(_weight, gse.repCount);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
