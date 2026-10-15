package fareverly;
import haxe.io.Bytes;

/** Windows CSPRNG and atomic owner-only credential persistence. */
class NativeAccount {
    public static function random():Bytes {
        #if hl
        var bytes = Bytes.alloc(32);
        check(randomNative(bytes, bytes.length));
        return bytes;
        #else
        throw "Secure Steam sign-in requires the Windows desktop plugin.";
        #end
    }
    public static function write(path:String, contents:String):Void {
        #if hl
        var p = Bytes.ofString(path), value = Bytes.ofString(contents);
        try { check(writeNative(p, p.length, value, value.length)); }
        catch (error:Dynamic) { value.fill(0, value.length, 0); throw error; }
        value.fill(0, value.length, 0);
        #else
        throw "Secure credential storage requires the Windows desktop plugin.";
        #end
    }
    #if hl
    static function check(code:Int):Void {
        if (code == -1) throw "Install the complete DPS Meter update, including its desktop plugin, to sign in.";
        if (code != 0) throw "Could not securely create or save Fareverly credentials (Windows error " + code + ").";
    }
    @:hlNative("?dps_meter_desktop", "secure_random")
    static function randomNative(bytes:hl.Bytes, length:Int):Int return -1;
    @:hlNative("?dps_meter_desktop", "write_credential")
    static function writeNative(path:hl.Bytes, length:Int, bytes:hl.Bytes, size:Int):Int return -1;
    #end
}
