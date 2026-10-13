package itemutilities;

/** Names are independent of saved loadouts, including for still-empty slots. */
class PresetNames {
    public static inline var MAX_LENGTH = 15;

    /** Keep a single line and count Unicode code points, not UTF-16 halves. */
    public static function limit(value:String):String {
        if (value == null) return "";
        var out = new StringBuf(), count = 0;
        for (code in new haxe.iterators.StringIteratorUnicode(value)) {
            if (count == MAX_LENGTH) break;
            if (code < 32 || code == 127 || code == 0x2028 || code == 0x2029) code = 32;
            if (code >= 0xD800 && code <= 0xDFFF) continue;
            out.addChar(code); count++;
        }
        return out.toString();
    }

    public static function clean(value:String):String
        return StringTools.trim(limit(value == null ? "" : StringTools.trim(value)));

    public static function name(records:Array<Dynamic>, characterId:String, slot:Int):String {
        if (records != null && characterId != null && characterId != "" && PresetSlots.valid(slot))
            for (record in records) if (matches(record, characterId, slot)) {
                var value:Dynamic = Reflect.field(record, "name");
                return Std.isOfType(value, String) ? clean(value) : "";
            }
        return "";
    }

    public static function labels(records:Array<Dynamic>, characterId:String):Array<String> {
        return [for (slot in 0...PresetSlots.COUNT) {
            var value = name(records, characterId, slot);
            value == "" ? PresetSlots.label(slot) : value;
        }];
    }

    /** Copy before saving so failed writes cannot change the running labels. */
    public static function renamed(records:Array<Dynamic>, characterId:String, slot:Int, value:String):Array<Dynamic> {
        if (characterId == null || StringTools.trim(characterId) == "" || !PresetSlots.valid(slot))
            throw "A character and valid preset slot are required to rename a preset.";
        var result = records == null ? [] : records.filter(record -> !matches(record, characterId, slot));
        var name = clean(value);
        if (name != "") result.push({characterId:characterId, preset:slot, name:name});
        return result;
    }

    static function matches(record:Dynamic, characterId:String, slot:Int):Bool {
        return record != null && Reflect.isObject(record) && !Std.isOfType(record, String)
            && !Std.isOfType(record, Array) && Reflect.field(record, "characterId") == characterId
            && Reflect.field(record, "preset") == slot;
    }
}
