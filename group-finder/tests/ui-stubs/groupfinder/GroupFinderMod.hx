package groupfinder;
class GroupFinderMod {
    public static var enabledValue=true;
    public static function enabled():Bool return enabledValue;
    public static function examples():Bool return true;
    public static function position():{x:Null<Float>,y:Null<Float>} return {x:null,y:null};
    public static function moved(x:Float,y:Float):Void {}
    public static function report(error:String):Void throw error;
}
