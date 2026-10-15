package bettermodsettings;

/** Text crossing the game/module boundary must acquire the mod's String identity. */
class TextSetting {
    public static function nativeValue(value:Dynamic):String {
        if (value == null) return "";
        #if hl
        // A native String can be read as text but JsonPrinter compares class
        // identities and otherwise serializes it as {bytes: "???", length: n}.
        // Rewrap the immutable UTF-16 buffer in this module's String class.
        // Keep the native UTF-16 length so Unicode text is preserved exactly.
        var bytes:hl.Bytes = Reflect.field(value, "bytes");
        var length:Null<Int> = Reflect.field(value, "length");
        if (bytes == null || length == null || length < 0)
            throw "Native text field did not return a string.";
        return @:privateAccess String.__alloc__(bytes, length);
        #else
        return storedValue(value);
        #end
    }

    public static function storedValue(value:Dynamic):String {
        // Old malformed records contain no recoverable text. Never show their
        // object representation or turn a number/boolean into a text setting.
        return Std.isOfType(value, String) ? cast value : "";
    }
}
