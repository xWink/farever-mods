import bettermodsettings.TextSetting;
import haxe.Json;

#if hl
/** Same UTF-16 storage as the game's String, with a different class identity. */
private class ForeignString {
    var bytes:hl.Bytes;
    var length:Int;
    public function new(value:String) {
        bytes = @:privateAccess value.bytes;
        length = value.length;
    }
}
#end

class TextSettingTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        for (value in ["", "ff0003", "000003", "true", "123", "  #Fa003B \t",
            'quote " and slash \\', "café 日本語 🎨"]) {
            eq(TextSetting.storedValue(value), value, "Stored text stays literal");
            #if hl
            var source:Dynamic = new ForeignString(value);
            #else
            var source:Dynamic = value;
            #end
            var local = TextSetting.nativeValue(source);
            eq(local, value, "Native text keeps every character");
            eq(local.length, value.length, "Text length survives conversion");
            var saved = Json.stringify({colour: local, unrelated: 42});
            var loaded:Dynamic = Json.parse(saved);
            eq(Std.isOfType(loaded.colour, String), true, "JSON contains a string, not runtime internals");
            eq(loaded.colour, value, "Save and reload preserve raw text");
            eq(TextSetting.storedValue(loaded.colour), value, "Reopening the field shows the original text");
            eq(loaded.unrelated, 42, "Other settings remain intact");
        }
        eq(TextSetting.nativeValue(null), "", "Missing native text is empty");
        for (broken in ([null, 123, true, [], {bytes: "???", length: 6}]:Array<Dynamic>))
            eq(TextSetting.storedValue(broken), "", "Malformed stored values never appear as object text");
        #if hl
        var old:Dynamic = Json.parse(Json.stringify(new ForeignString("ff0003")));
        eq(old.bytes, "???", "Reproduces the original native buffer serialization failure");
        eq(old.length, 6, "Reproduces the customer's damaged record");
        eq(TextSetting.storedValue(old), "", "Damaged records reopen as editable empty fields");
        #end
        Sys.println('Text settings: $checks checks passed.');
    }
}
