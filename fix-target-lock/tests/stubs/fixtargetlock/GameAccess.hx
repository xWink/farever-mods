package fixtargetlock;

class GameAccess {
    public static var data:Dynamic;
    public static var inputActive = true;
    public static var releasedInput:String;
    public static var releaseReads = 0;
    public static var failRelease = false;
    public static var heldInputs:Map<String, Bool> = ["Skill1" => true, "Skill2" => true];
    public static var bindingsAvailable = true;
    public static var usePad = false;
    public static var unlocks = 0;
    public static var failUnlock = false;
    static var sampledInput:String;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void Reflect.setField(o, name, value);
    public static function current(type:String, name:String):Dynamic return field(data, name);
    public static function setCurrent(type:String, name:String, value:Dynamic):Void set(data, name, value);
    public static function number(v:Dynamic, fallback:Float):Float {
        var n = Std.parseFloat(Std.string(v));
        return Math.isFinite(n) ? n : fallback;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type != "client.PlayerController" || name != "leaveLock") throw "Unexpected native call";
        if (failUnlock) throw "Unlock failure";
        if (object.unit == null) throw "Cannot call native leaveLock without a hero";
        unlocks++;
        object.unit.lockedTarget = null;
        object.inLock = false;
        return null;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "hxd.Key" || type == "gamepad.Pad") {
            if (name != "isDown") throw "Unexpected physical input call";
            return heldInputs[sampledInput] == true && sampledInput != releasedInput;
        }
        if (type != "lib.Input") throw "Unexpected input call";
        releaseReads++;
        if (failRelease) throw "Input failure";
        if (data._noCheckMode != true) throw "Aiming mode was not bypassed";
        if (name == "isReleased") return inputActive && bindingsAvailable && args[0] == releasedInput;
        if (name != "checkInput") throw "Unexpected input method";
        if (!bindingsAvailable) return false; // Native UI/cinematic/binding gate skips the readers.
        sampledInput = args[0];
        if (usePad) {
            var readPad:Dynamic->Bool = args[2];
            return readPad({button:1});
        }
        var readKey:Int->Bool = args[1];
        return readKey(49);
    }
}
