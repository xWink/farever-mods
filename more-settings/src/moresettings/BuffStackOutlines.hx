package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;

private typedef StackLabel = {
    var display:Dynamic;
    var text:Dynamic;
    var original:Dynamic;
    var outlined:Dynamic;
    var outline:Dynamic;
}

/** Decorates only native StatusDisplay stack labels, preserving CSS filters. */
class BuffStackOutlines {
    static var enabled = true;
    static var changing = false;
    static var labels:ObjectMap<Dynamic, StackLabel> = new ObjectMap();
    static var displays:ObjectMap<Dynamic, StackLabel> = new ObjectMap();
    static var reported = false;

    public static function configure(value:Bool):Void {
        enabled = value;
        for (label in labels) apply(label);
    }

    public static function attach(display:Dynamic):Void {
        forget(display);
        var text = G.field(display, "stacks");
        if (text == null) return;
        var label:StackLabel = {display:display, text:text, original:G.field(text, "filter"),
            outlined:null, outline:null};
        labels.set(text, label);
        displays.set(display, label);
        apply(label);
    }

    // CSS may assign its filter after init or on a status-class change. Keep
    // that native filter, then apply our outline once; never wrap our own group.
    public static function afterFilter(text:Dynamic):Void {
        if (changing) return;
        var label = labels.get(text);
        if (label == null) return;
        var current = G.field(text, "filter");
        if (current == label.outlined && current != null) return;
        label.original = current;
        label.outlined = null;
        apply(label);
    }

    public static function makeOutline(size:Float = 1.0):Dynamic {
        var filter = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", filter, [size]);
        G.call("h2d.filter.Outline", "set_quality", filter, [0.5]);
        G.call("h2d.filter.Outline", "set_color", filter, [0x000000]);
        return filter;
    }

    static function apply(label:StackLabel):Void {
        if (enabled && label.outlined == null) {
            if (label.outline == null) label.outline = makeOutline();
            label.outlined = label.outline;
            if (label.original != null) {
                label.outlined = G.create("h2d.filter.Group", [null]);
                G.call("h2d.filter.Group", "add", label.outlined, [label.original]);
                G.call("h2d.filter.Group", "add", label.outlined, [label.outline]);
            }
        }
        var desired = enabled ? label.outlined : label.original;
        if (G.field(label.text, "filter") == desired) return;
        changing = true;
        try G.call("h2d.Object", "set_filter", label.text, [desired]) catch (error:Dynamic) {
            changing = false;
            throw error;
        }
        changing = false;
    }

    public static function forget(display:Dynamic):Void {
        var label = displays.get(display);
        if (label == null) return;
        displays.remove(display);
        labels.remove(label.text);
        if (label.outlined != null && G.field(label.text, "filter") == label.outlined)
            G.call("h2d.Object", "set_filter", label.text, [label.original]);
    }

    public static function clear():Void {
        for (label in labels) if (G.field(label.text, "filter") == label.outlined) {
            changing = true;
            try G.call("h2d.Object", "set_filter", label.text, [label.original]) catch (_:Dynamic) {}
            changing = false;
        }
        labels = new ObjectMap();
        displays = new ObjectMap();
    }

    public static function report(error:Dynamic):Void {
        if (!reported) trace("[More Settings] Buff stack outlines: " + Std.string(error));
        reported = true;
    }
}
