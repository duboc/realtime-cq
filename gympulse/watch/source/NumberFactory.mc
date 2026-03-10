using Toybox.WatchUi;
using Toybox.Graphics;

// Factory that generates number values for Picker views.
// Produces a scrollable column of numbers from min to max with a given step.

class NumberFactory extends WatchUi.PickerFactory {

    var _min;
    var _max;
    var _step;
    var _count;
    var _font;

    function initialize(min, max, step) {
        PickerFactory.initialize();
        _min = min;
        _max = max;
        _step = step;
        _count = ((max - min) / step).toNumber() + 1;
        _font = Graphics.FONT_NUMBER_HOT;
    }

    function getIndex(value) {
        return ((value - _min) / _step).toNumber();
    }

    function getDrawable(index, selected) {
        var value = _min + index * _step;
        return new WatchUi.Text({
            :text => value.toString(),
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
            :font => _font,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index) {
        return _min + index * _step;
    }

    function getSize() {
        return _count;
    }
}
