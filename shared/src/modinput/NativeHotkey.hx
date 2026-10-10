package modinput;

/** Poll the game's shared key state, which BMS consumes throughout assignment. */
class NativeHotkey {
    static var keyType:hl.Bytes;
    static var pressed:hlx.runtime.ResolvedMember;
    static var down:hlx.runtime.ResolvedMember;

    public static function isPressed(binding:Dynamic):Bool {
        if (!Hotkey.isBound(binding)) return false;
        try {
            if (keyType == null) keyType = HlxRuntime.resolveType("hxd.Key");
            if (keyType == null) return false;
            if (pressed == null) pressed = HlxRuntime.resolveStaticMember(keyType, "isPressed");
            if (down == null) down = HlxRuntime.resolveStaticMember(keyType, "isDown");
            return pressed != null && down != null
                && HlxRuntime.callResolved(pressed, [Hotkey.code(binding)]) == true
                && Hotkey.matches(binding, isDown);
        } catch (_:Dynamic) return false;
    }

    static function isDown(code:Int):Bool return HlxRuntime.callResolved(down, [code]) == true;
}
