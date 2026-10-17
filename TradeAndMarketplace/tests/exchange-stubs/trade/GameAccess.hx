package trade;
class GameAccess {
    public static function field(o:Dynamic,k:String):Dynamic return o == null ? null : Reflect.field(o,k);
    public static function integer(o:Dynamic,fallback = 0):Int return o == null ? fallback : Std.int(o);
    public static function number(o:Dynamic,fallback = 0.0):Float return o == null ? fallback : o;
    public static function uid(o:Dynamic):String return o == null ? "" : Std.string(o.__uid);
    public static function call(type:String,name:String,o:Dynamic,?args:Array<Dynamic>):Dynamic {
        if (o == null || !Reflect.isFunction(Reflect.field(o,name))) throw "Unexpected native call "+type+"."+name;
        return Reflect.callMethod(o,Reflect.field(o,name),args == null ? [] : args);
    }
}
