package bettermodsettings;

private typedef SecretControl = {input:Dynamic, button:Dynamic, graphic:Dynamic, revealed:Bool};

/** Mask only the native layout result, preserving the textbox's editable value. */
class NativeSecretText {
    static var controls = new haxe.ds.ObjectMap<Dynamic, SecretControl>();
    static var members:Map<String, hlx.runtime.ResolvedMember> = [];
    public static function attach(parent:Dynamic, input:Dynamic, id:String):Dynamic {
        var dom = call("domkit.Properties", "createNew", null, ["button", parent, [""], {id:id}], true);
        var button = Reflect.field(dom, "obj");
        style(dom, "fill-width", false);
        for (key in ["width", "min-width", "max-width", "height", "min-height", "max-height"]) style(dom, key, 34);
        style(dom, "padding", 0);
        var graphic = HlxRuntime.constructInstanceByName(HlxRuntime.resolveType("h2d.Graphics"), 1, [button]);
        var props = call("h2d.Flow", "getProperties", button, [graphic]);
        call("h2d.FlowProperties", "set_isAbsolute", props, [true]);
        Reflect.setField(graphic, "x", 5.0); Reflect.setField(graphic, "y", 5.0);
        var filter = HlxRuntime.constructInstanceByName(HlxRuntime.resolveType("h2d.filter.Nothing"), 0, []);
        Reflect.setField(filter, "smooth", true); Reflect.setField(filter, "boundsExtend", 1.0);
        call("h2d.filter.Filter", "set_useScreenResolution", filter, [true]);
        call("h2d.filter.Filter", "set_resolutionScale", filter, [4.0]);
        call("h2d.Object", "set_filter", graphic, [filter]);
        var control:SecretControl = {input:input, button:button, graphic:graphic, revealed:false};
        controls.set(input, control);
        call("ui.UIElement", "set_onClick", button, [() -> { control.revealed = !control.revealed; refresh(control); }]);
        refresh(control); return dom;
    }
    public static function masked(input:Dynamic, text:Dynamic):Null<String> {
        var control = controls.get(input);
        return control == null || control.revealed ? null : TextSetting.mask(TextSetting.nativeValue(text));
    }
    public static function hideAll(clear:Bool = false):Void {
        for (control in controls) if (control.revealed) { control.revealed = false; refresh(control); }
        if (clear) controls = new haxe.ds.ObjectMap();
    }
    static function refresh(control:SecretControl):Void {
        Reflect.setField(control.input, "needsRebuild", true); Reflect.setField(control.input, "textChanged", true);
        Reflect.setField(control.input, "calcDone", false); Reflect.setField(control.input, "splitLines", null);
        Reflect.setField(control.input, "cursorXIndex", -1);
        call("ui.UIElement", "set_textTip", control.button, [control.revealed ? "Hide secret" : "Show secret"]);
        var g = control.graphic;
        call("h2d.Graphics", "clear", g, []);
        call("h2d.Graphics", "lineStyle", g, [1.8, 4924179, 1.0]);
        call("h2d.Graphics", "moveTo", g, [2.0, 11.0]);
        for (i in 1...17) {
            var t = i / 16;
            call("h2d.Graphics", "lineTo", g, [2 + 20 * t, 11 + 6 * Math.sin(Math.PI * t)]);
        }
        if (control.revealed) {
            for (i in 1...17) {
                var t = i / 16;
                call("h2d.Graphics", "lineTo", g, [22 - 20 * t, 11 - 6 * Math.sin(Math.PI * t)]);
            }
            call("h2d.Graphics", "beginFill", g, [4924179, 1.0]);
            call("h2d.Graphics", "drawCircle", g, [12.0, 11.0, 2.8, 24]);
            call("h2d.Graphics", "endFill", g, []);
        } else for (t in [0.2, 0.5, 0.8]) {
            var x = 2 + 20 * t, y = 11 + 6 * Math.sin(Math.PI * t);
            call("h2d.Graphics", "moveTo", g, [x, y]);
            call("h2d.Graphics", "lineTo", g, [x + (t - 0.5) * 7, y + 4]);
        }
    }
    static function style(dom:Dynamic, key:String, value:Dynamic):Void { call("domkit.Properties", "initStyle", dom, [key, value]); }
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
