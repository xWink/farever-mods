package bettermodsettings;

import hlx.runtime.Registry;

/** Optional runtime values/actions; bound secrets never pass through ModConfig. */
class NativeSettingBinding {
    static var controls:Array<{modId:String, key:String, object:Dynamic, kind:String, value:String, enabled:Null<Bool>}> = [];
    public static function clear():Void controls = [];
    public static function provider(modId:String, key:String):Dynamic return Registry.get("better-mod-settings/bindings", modId + "/" + key);
    public static function read(modId:String, key:String):String {
        var p = provider(modId, key);
        var value = p == null ? null : HlxRuntime.resolveField(p, "value");
        return value == null ? "" : TextSetting.nativeValue(value);
    }
    public static function save(modId:String, key:String, value:Dynamic):Bool {
        var p = provider(modId, key);
        var callback = p == null ? null : HlxRuntime.resolveField(p, "onChange");
        // Missing providers fail closed; never fall back to a regular config file.
        return callback != null && Reflect.callMethod(p, callback, [value]) == true;
    }
    public static function track(modId:String, key:String, object:Dynamic, kind:String):Void {
        controls.push({modId:modId, key:key, object:object, kind:kind, value:read(modId, key), enabled:null});
    }
    public static function refresh():Void {
        for (item in controls) {
            var provider = provider(item.modId, item.key);
            var value = read(item.modId, item.key);
            if (item.value != value && item.kind != "button") {
                item.value = value;
                var type = item.kind == "text" ? "h2d.TextInput" : "ui.comp.FmtText";
                HlxRuntime.callResolved(HlxRuntime.resolveMember(HlxRuntime.resolveType(type), "set_text"), [item.object, value]);
            }
            if (item.kind != "status") {
                var enabled = provider != null && HlxRuntime.resolveField(provider, "enabled") != false;
                if (item.enabled != enabled) {
                    item.enabled = enabled;
                    if (item.kind == "button") HlxRuntime.callResolved(HlxRuntime.resolveMember(HlxRuntime.resolveType("ui.UIElement"), "set_enable"), [item.object, enabled]);
                    else HlxRuntime.setField(item.object, "canEdit", enabled);
                }
            }
        }
    }
}
