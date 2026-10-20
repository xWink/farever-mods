package trade;
/** No network or UI calls: hold the delivery callback until the test resolves it. */
class GameAccess {
    public static var delivery:Bool->Void;
    public static var sent:Dynamic;
    public static var history:Array<Dynamic>=[];
    public static function field(o:Dynamic,k:String):Dynamic return o==null?null:Reflect.field(o,k);
    public static function text(v:Dynamic):String return v==null?"":Std.string(v);
    public static function enumValue(t:String,n:String,a:Array<Dynamic>):Dynamic return {name:n,args:a};
    public static function enumName(v:Dynamic):String return v==null?"":v.name;
    public static function enumArgument(v:Dynamic,i:Int):Dynamic return v.args[i];
    public static function call(t:String,n:String,o:Dynamic,?args:Array<Dynamic>):Dynamic {
        switch(n) {
            case "getName":return "Buyer";
            case "sendMessage":sent=args[1];delivery=args[2];return null;
            case "localReceiveMessage":history.push(args[0]);return null;
            default:throw "Unexpected native call "+t+"."+n;
        }
    }
}
