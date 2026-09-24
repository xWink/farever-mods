package fixtargetlock;

class TargetLockGame {
    public static var refresh:Dynamic->Void;
    public static function field(object:Dynamic, name:String):Dynamic {
        return object == null ? null : Reflect.field(object, name);
    }
    public static function set(object:Dynamic, name:String, value:Dynamic):Void {
        Reflect.setField(object, name, value);
    }
    public static function isHero(object:Dynamic):Bool {
        return object != null && Reflect.field(object, "hero") == true;
    }
    public static function refreshPick(controller:Dynamic):Void refresh(controller);
}
