package bettermodsettings;

import haxe.Json;
import modconfig.CommonSettings;

/** Refresh every visible copy of a common setting without saving it again. */
class CommonSettingControls {
    var controls:Array<{key:String, snapshot:String, update:Dynamic->Void}> = [];
    public var refreshing(default, null) = false;
    public function new() {}
    public function clear():Void controls = [];
    public function add(definition:Dynamic, value:Dynamic, update:Dynamic->Void):Void {
        if (CommonSettings.isCommon(definition))
            controls.push({key:definition.key, snapshot:Json.stringify(value), update:update});
    }
    public function refresh(values:Dynamic):Void {
        refreshing = true;
        try {
            for (control in controls) {
                var value = Reflect.field(values, control.key);
                var snapshot = Json.stringify(value);
                if (snapshot == control.snapshot) continue;
                control.update(value);
                control.snapshot = snapshot;
            }
        } catch (error:Dynamic) { refreshing = false; throw error; }
        refreshing = false;
    }
}
