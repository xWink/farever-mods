package trade;
class GameAccess {
 public static var app:Dynamic;
 public static function field(o:Dynamic,k:String):Dynamic return o == null ? null : Reflect.field(o,k);
 public static function text(o:Dynamic,fallback=""):String return o == null ? fallback : Std.string(o);
 public static function integer(o:Dynamic,fallback=0):Int return o == null ? fallback : Std.int(o);
 public static function uid(o:Dynamic):String return text(field(o,"uid"));
 public static function array(o:Dynamic,unused=false):Array<Dynamic> return o == null ? [] : o;
 public static function staticCall(t:String,m:String,a:Array<Dynamic>):Dynamic { if(t=="GameApp" && m=="get") return app; throw "Unexpected native call"; }
 public static function current(t:String,n:String):Dynamic return null;
 public static function call(t:String,m:String,o:Dynamic,?args:Array<Dynamic>):Dynamic { if(m=="getName") return "Tester"; throw "Unexpected native call "+t+"."+m; }
 public static function isA(o:Dynamic,t:String):Bool return false;
 public static function create(t:String,a:Array<Dynamic>):Dynamic throw "Unexpected native allocation";
}
