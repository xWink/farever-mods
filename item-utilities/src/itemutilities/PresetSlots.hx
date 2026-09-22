package itemutilities;

/** Shared limits and persistent key names for all four preset categories. */
class PresetSlots {
    public static inline var COUNT = 5;
    public static inline var SELECTOR_WIDTH = 136;
    public static inline var SET_WIDTH = 58;
    public static inline var GAP = 8;
    public static inline var CONTROLS_WIDTH = SELECTOR_WIDTH + GAP + SET_WIDTH;

    public static inline function valid(slot:Int):Bool return slot >= 0 && slot < COUNT;
    public static inline function label(slot:Int):String return "Preset " + (slot + 1);

    /** Old configs retain their first three bindings; new slots start unbound. */
    public static function hotkeys(config:Dynamic, prefix:String):Array<Int> {
        return [for (slot in 0...COUNT) {
            var value:Dynamic = Reflect.field(config, prefix + (slot + 1) + "Hotkey");
            Std.isOfType(value, Int) && value > 0 ? cast(value, Int) : 0;
        }];
    }

    public static function saveHotkeys(config:Dynamic, prefix:String, keys:Array<Int>):Void {
        for (slot in 0...COUNT)
            Reflect.setField(config, prefix + (slot + 1) + "Hotkey", slot < keys.length ? keys[slot] : 0);
    }
}
