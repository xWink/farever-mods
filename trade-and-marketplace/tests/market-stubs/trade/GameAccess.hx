package trade;
class GameAccess {
 public static function field(o:Dynamic,k:String):Dynamic return o==null?null:Reflect.field(o,k);
 public static function text(v:Dynamic):String return v==null?"":Std.string(v);
 public static function integer(v:Dynamic):Int return v==null?0:Std.int(v);
 public static function call(type:String,name:String,o:Dynamic,?args:Array<Dynamic>):Dynamic return switch(name){case "getName":"Tester";case "getRequiredLevel":15;case "getILevel":35;default:null;};
 public static function staticCall(type:String,name:String,args:Array<Dynamic>):Dynamic return name=="getVersion"?"0.3.1.31390":{id:"Epic"};
}
