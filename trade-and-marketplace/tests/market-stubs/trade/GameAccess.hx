package trade;
class GameAccess {
 public static function uid(o:Dynamic):String return text(field(o,"uid"),"item");
 public static function array(o:Dynamic,proxy=false):Array<Dynamic> return o==null?[]:cast o;
 public static function field(o:Dynamic,k:String):Dynamic return o==null?null:Reflect.field(o,k);
 public static function text(v:Dynamic,f=""):String return v==null?f:Std.string(v);
 public static function current(type:String,name:String):Dynamic return null;
 public static function integer(v:Dynamic,f=0):Int return v==null?f:Std.int(v);
 public static function enumName(v:Dynamic):String return text(v);
 public static function call(type:String,name:String,o:Dynamic,?args:Array<Dynamic>):Dynamic return switch(name){case "getName":"Tester";case "getRequiredLevel":15;case "getILevel":35;case "getStack":o.content[args[0]];case "checkRequestDropIndex":field(o.content[args[0]].item,"bound")==true?"NotAllowed_":"Ok";default:null;};
 public static function staticCall(type:String,name:String,args:Array<Dynamic>):Dynamic return name=="getVersion"?"0.3.1.31390":{id:field(args[0],"rarity")==null||field(args[0],"rarity")==""?"Epic":field(args[0],"rarity")};
}
