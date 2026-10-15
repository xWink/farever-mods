package bettermodsettings;

import haxe.ds.ObjectMap;

private typedef SecretControl = {
    var input:Dynamic;
    var button:Dynamic;
    var graphic:Dynamic;
    var revealed:Bool;
}

/** Per-textbox display state. Never replaces the editable or persisted value. */
class NativeSecretText {
    static inline var BUTTON_SIZE = 34;
    static inline var ICON_COLOR = 0x4B2313;
    static var controls:ObjectMap<Dynamic, SecretControl> = new ObjectMap();
    static var members:Map<String, hlx.runtime.ResolvedMember> = [];

    public static function attach(parent:Dynamic, input:Dynamic, id:String):Dynamic {
        var dom = call("domkit.Properties", "createNew", null,
            ["button", parent, [""], {id: id}], true);
        var button = HlxRuntime.resolveField(dom, "obj");
        // Stay in the existing option row's flow, directly after its textbox.
        style(dom, "fill-width", false);
        style(dom, "padding", 0);
        for (key in ["width", "min-width", "max-width", "height", "min-height", "max-height"])
            style(dom, key, BUTTON_SIZE);

        var graphic = HlxRuntime.constructInstanceByName(HlxRuntime.resolveType("h2d.Graphics"), 1, [button]);
        var properties = call("h2d.Flow", "getProperties", button, [graphic]);
        call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        call("h2d.Object", "setPosition", graphic, [5.0, 5.0]);
        var filter = HlxRuntime.constructInstanceByName(HlxRuntime.resolveType("h2d.filter.Nothing"), 0, []);
        HlxRuntime.setField(filter, "smooth", true);
        HlxRuntime.setField(filter, "boundsExtend", 1.0);
        call("h2d.filter.Filter", "set_useScreenResolution", filter, [true]);
        call("h2d.filter.Filter", "set_resolutionScale", filter, [4.0]);
        call("h2d.Object", "set_filter", graphic, [filter]);

        // A newly constructed settings window can never inherit a revealed eye.
        var control:SecretControl = {input: input, button: button, graphic: graphic, revealed: false};
        controls.set(input, control);
        call("ui.UIElement", "set_onClick", button, [function():Void {
            // Ignore callbacks belonging to a discarded settings window.
            if (controls.get(input) != control) return;
            control.revealed = !control.revealed;
            refresh(control);
        }]);
        refresh(control);
        return dom;
    }

    /** Called after native splitRawText, never from an editing callback. */
    public static function display(input:Dynamic, text:String):String {
        var control = controls.get(input);
        return control == null || control.revealed
            ? text : TextSetting.mask(TextSetting.nativeValue(text));
    }

    public static function hideAll(clear:Bool = false):Void {
        for (control in controls) {
            if (!control.revealed) continue;
            control.revealed = false;
            refresh(control);
        }
        if (clear) controls = new ObjectMap();
    }

    static function refresh(control:SecretControl):Void {
        // Invalidate only derived display geometry. Do not touch text, cursorIndex,
        // selectionRange, undo/redo, or InputBox's focus/change callbacks.
        HlxRuntime.setField(control.input, "needsRebuild", true);
        HlxRuntime.setField(control.input, "textChanged", true);
        HlxRuntime.setField(control.input, "calcDone", false);
        HlxRuntime.setField(control.input, "splitLines", null);
        HlxRuntime.setField(control.input, "cursorXIndex", -1);
        call("ui.UIElement", "set_textTip", control.button, [control.revealed ? "Hide secret" : "Show secret"]);
        drawEye(control.graphic, control.revealed);
    }

    static function drawEye(graphic:Dynamic, revealed:Bool):Void {
        call("h2d.Graphics", "clear", graphic, []);
        call("h2d.Graphics", "lineStyle", graphic, [1.8, ICON_COLOR, 1.0]);
        call("h2d.Graphics", "moveTo", graphic, [2.0, 11.0]);
        // Lower eyelid, shared by the closed eye and the open-eye outline.
        for (i in 1...17) {
            var t = i / 16;
            call("h2d.Graphics", "lineTo", graphic, [2 + 20 * t, 11 + 6 * Math.sin(Math.PI * t)]);
        }
        if (revealed) {
            for (i in 1...17) {
                var t = i / 16;
                call("h2d.Graphics", "lineTo", graphic, [22 - 20 * t, 11 - 6 * Math.sin(Math.PI * t)]);
            }
            call("h2d.Graphics", "beginFill", graphic, [ICON_COLOR, 1.0]);
            call("h2d.Graphics", "drawCircle", graphic, [12.0, 11.0, 2.8, 24]);
            call("h2d.Graphics", "endFill", graphic, []);
        } else {
            // Closed eyelid with three lashes, no pupil.
            for (t in [0.2, 0.5, 0.8]) {
                var x = 2 + 20 * t;
                var y = 11 + 6 * Math.sin(Math.PI * t);
                call("h2d.Graphics", "moveTo", graphic, [x, y]);
                call("h2d.Graphics", "lineTo", graphic, [x + (t - 0.5) * 7, y + 4]);
            }
        }
    }

    static function style(dom:Dynamic, key:String, value:Dynamic):Void
        call("domkit.Properties", "initStyle", dom, [key, value]);

    static function call(typeName:String, method:String, instance:Dynamic, args:Array<Dynamic>, isStatic:Bool = false):Dynamic {
        var key = typeName + "." + method;
        if (!members.exists(key)) {
            var type = HlxRuntime.resolveType(typeName);
            var member = isStatic ? HlxRuntime.resolveStaticMember(type, method) : HlxRuntime.resolveMember(type, method);
            if (member == null) throw "Native secret field member unavailable: " + key;
            members[key] = member;
        }
        return HlxRuntime.callResolved(members[key], isStatic ? args : [instance].concat(args));
    }
}
