import moresettings.BuffStackOutlines as Outlines;
import moresettings.GameAccess as G;
import moresettings.SettingsData;

class BuffStackOutlinesTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw '$why: expected $b, got $a';
    }
    static function main():Void {
        eq(SettingsData.defaults().buffStackNumberOutline, true, "stack outline defaults on");
        var original = {native:true};
        var text:Dynamic = {filter:original, text:"12", visible:true, textColor:0xFFFFFF};
        var display:Dynamic = {stacks:text, timer:{filter:null}, bmp:{filter:null}};
        Outlines.configure(true); Outlines.attach(display);
        var group = text.filter;
        eq(group.filters.length, 2, "preserves native styling then outlines");
        eq(group.filters[0], original, "native filter is first");
        eq(group.filters[1].color, 0, "outline is black");
        eq(group.filters[1].size, 1.0, "outline remains thin");
        eq(text.text, "12", "stack count is untouched");
        eq(text.textColor, 0xFFFFFF, "number stays white");
        eq(display.timer.filter, null, "native buff timer is untouched");
        eq(display.bmp.filter, null, "buff art is untouched");
        Outlines.afterFilter(text);
        eq(text.filter, group, "own filter never gets repeatedly wrapped");
        var css = {updatedStyle:true};
        G.call("h2d.Object", "set_filter", text, [css]);
        eq(text.filter.filters[0], css, "later CSS changes are preserved and reoutlined");
        eq(text.filter.filters.length, 2, "style refresh does not accumulate outline groups");
        Outlines.configure(false);
        eq(text.filter, css, "toggle off immediately restores latest native filter");
        G.call("h2d.Object", "set_filter", text, [null]);
        eq(text.filter, null, "disabled mode allows native styling");
        Outlines.configure(true);
        eq(text.filter.nativeType, "h2d.filter.Outline", "toggle on works on existing buff widgets");
        var old = text;
        display.stacks = {filter:null, text:"3"};
        Outlines.attach(display);
        eq(old.filter, null, "widget rebuild restores and releases old stack text");
        eq(display.stacks.filter.nativeType, "h2d.filter.Outline", "widget rebuild styles new stack text");
        Outlines.forget(display);
        eq(display.stacks.filter, null, "removing buff releases its outline");
        Outlines.configure(true);
        eq(display.stacks.filter, null, "removed buff is not retained by settings changes");
        Outlines.attach(display); Outlines.clear();
        eq(display.stacks.filter, null, "game disposal restores native filters");
        var config = SettingsData.defaults();
        eq(config.skillProcAlertPosition, "Right", "position defaults to existing right side");
        eq(config.skillProcAlertSize, 100, "size defaults to existing scale");
        config.skillProcAlertSize = 999; config.skillProcAlertPosition = "invalid";
        SettingsData.normalize(config);
        eq(config.skillProcAlertSize, 200, "size is bounded");
        eq(config.skillProcAlertPosition, "Right", "invalid position restores right default");
        trace('Buff stack outlines and settings: $checks checks passed');
    }
}
