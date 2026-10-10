package modinput;

/** Legacy integer keys or Farever's {code, modifier} binding (Ctrl=0, Shift=1, Alt=2). */
class Hotkey {
    public static function normalize(value:Dynamic, fallback:Int = 0):Dynamic {
        if (Std.isOfType(value, Int)) return validCode(value) ? value : fallback;
        if (value == null || !Reflect.isObject(value) || Std.isOfType(value, String)
            || Std.isOfType(value, Array)) return fallback;
        var code:Dynamic = Reflect.field(value, "code");
        var modifier:Dynamic = Reflect.field(value, "modifier");
        if (!Std.isOfType(code, Int) || !validCode(code)) return fallback;
        if (modifier == null) return code;
        if (!Std.isOfType(modifier, Int) || modifier < 0 || modifier > 2 || !supportsModifier(code)) return fallback;
        return {code: (code:Int), modifier: (modifier:Int)};
    }

    static function validCode(code:Int):Bool return code >= 0 && code < 512 && code != 27;

    public static function code(value:Dynamic):Int
        return Std.isOfType(value, Int) ? value : Reflect.field(value, "code");

    public static function modifier(value:Dynamic):Null<Int>
        return Std.isOfType(value, Int) ? null : Reflect.field(value, "modifier");

    // Integer zero remains unbound; {code:0, modifier:...} is modified left-click.
    public static function isBound(value:Dynamic):Bool
        return value != null && (!Std.isOfType(value, Int) || (cast value:Int) != 0);

    /** Same keyboard/mouse allowlist as lib.Input.supportsModifier. */
    public static function supportsModifier(code:Int):Bool {
        return (code >= 48 && code <= 57) || (code >= 96 && code <= 105)
            || (code >= 65 && code <= 90) || (code >= 112 && code <= 135)
            || code == 13 || code == 9 || (code >= 37 && code <= 40)
            || code == 0 || code == 1;
    }

    public static function modifierKey(modifier:Int):Int return switch modifier {
        case 0: 17;
        case 1: 16;
        case 2: 18;
        default: -1;
    };

    public static function isModifier(code:Int):Bool return code == 17 || code == 16 || code == 18;

    /** Farever picks the first held modifier, in Ctrl, Shift, Alt order. */
    public static function currentModifier(isDown:Int->Bool):Null<Int> {
        for (modifier in 0...3) if (isDown(modifierKey(modifier))) return modifier;
        return null;
    }

    public static function capture(code:Int, isDown:Int->Bool):Dynamic {
        var modifier = supportsModifier(code) ? currentModifier(isDown) : null;
        return modifier == null ? code : {code: code, modifier: modifier};
    }

    /** Custom actions use Farever's strict modifier matching to distinguish F2 from Ctrl+F2. */
    public static function matches(value:Dynamic, isDown:Int->Bool, strict:Bool = true):Bool {
        if (!isBound(value)) return false;
        if (!supportsModifier(code(value))) return true;
        var expected = modifier(value);
        if (expected != null && !isDown(modifierKey(expected))) return false;
        return !strict || currentModifier(isDown) == expected;
    }

    public static function label(value:Dynamic, keyName:Int->String):String {
        if (!isBound(value)) return "Not set";
        var prefix = switch modifier(value) {
            case 0: "Ctrl+";
            case 1: "Shift+";
            case 2: "Alt+";
            default: "";
        };
        return prefix + keyName(code(value));
    }
}
