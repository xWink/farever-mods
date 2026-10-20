package trade;

/** Only the native boundary is simulated; controller and inventory code are real. */
class GameAccess {
    public static var app:Dynamic;
    public static var skills:Dynamic;
    public static var lines:Array<Dynamic> = [];
    public static var ui:Dynamic = {get_chat: function() return {messages: {}}};
    public static function set(o:Dynamic,k:String,v:Dynamic):Void Reflect.setField(o,k,v);
    public static function field(o:Dynamic, k:String):Dynamic return o == null ? null : Reflect.field(o, k);
    public static function text(o:Dynamic, fallback = ""):String return o == null ? fallback : Std.string(o);
    public static function integer(o:Dynamic, fallback = 0):Int return o == null ? fallback : Std.int(o);
    public static function number(o:Dynamic, fallback = 0.0):Float return o == null ? fallback : o;
    public static function uid(o:Dynamic):String return text(field(o, "__uid"));
    public static function typeName(o:Dynamic):String return "st.Item";
    public static function enumName(o:Dynamic):String return text(o);
    public static function array(o:Dynamic, proxy = false):Array<Dynamic> {
        if (proxy) o = field(o, "array");
        return o == null ? [] : o;
    }
    public static function staticCall(t:String, m:String, a:Array<Dynamic>):Dynamic {
        if (t == "GameApp" && m == "get") return app;
        if (t == "HItem" && m == "getRarity") return {color: 0, name: "Common"};
        throw "Unexpected native call " + t + "." + m;
    }
    public static function current(t:String, n:String):Dynamic return t == "ui.BaseUI" ? ui : t=="Data"&&n=="skill"?skills:null;
    public static function call(t:String, m:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (t == "h2d.Text" && m == "set_textColor") { o.color = args[0]; return null; }
        var method = field(o, m);
        if (Reflect.isFunction(method)) return Reflect.callMethod(o, method, args == null ? [] : args);
        throw "Unexpected native call " + t + "." + m;
    }
    public static function isA(o:Dynamic, t:String):Bool return o == ui && t == "ui.GameUI";
    public static function create(t:String, a:Array<Dynamic>):Dynamic {
        if (t != "ui.hud.ChatBoxLine") throw "Unexpected native allocation " + t;
        var label:Dynamic = {}; lines.push(label); return {msgText: label};
    }
}
