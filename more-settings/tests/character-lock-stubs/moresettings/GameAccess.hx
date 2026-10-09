package moresettings;

/** Small native scene model: callback ownership, button state and child lifetime. */
class GameAccess {
    public static function field(o:Dynamic, n:String):Dynamic return o == null ? null : Reflect.field(o,n);
    public static function set(o:Dynamic, n:String, v:Dynamic):Void if (o != null) Reflect.setField(o,n,v);
    public static function text(v:Dynamic, fallback = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float return v == null ? fallback : v;
    public static function integer(v:Dynamic, fallback = 0):Int return Std.int(number(v,fallback));
    public static function array(v:Dynamic):Array<Dynamic> return v == null ? [] : cast v;
    public static function enumeration(t:String,n:String):Dynamic return n;
    public static function node(?parent:Dynamic):Dynamic {
        var o:Dynamic = {parent:parent, children:[], props:{}, callbacks:[], visible:true, enable:true,
            x:0., y:0., calculatedWidth:400., calculatedHeight:40., color:{}};
        o.dom = {obj:o, styles:{}};
        if (parent != null) { var children:Array<Dynamic> = parent.children; children.push(o); }
        return o;
    }
    public static function create(t:String, args:Array<Dynamic>):Dynamic
        return node(t == "h2d.filter.Nothing" ? null : args[0]);
    public static function staticCall(t:String, n:String, args:Array<Dynamic>):Dynamic {
        if (t == "domkit.Properties" && n == "createNew") return node(field(args[1],"obj")).dom;
        throw t+"."+n;
    }
    public static function call(t:String, n:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        if (t == "ui.UIElement" && n == "set_enable") {
            switch (@:privateAccess CharacterLockHooks.enableButton(o,args[0])) {
                case SkipWith(result): return result;
                default:
            }
        }
        if (t == "h2d.Graphics") return null;
        switch n {
            case "getProperties": return field(args[0],"props");
            case "initStyle": set(field(o,"styles"),args[0],args[1]); return null;
            case "setPosition": set(o,"x",args[0]); set(o,"y",args[1]); return null;
            case "setScale": set(o,"scaleX",args[0]); set(o,"scaleY",args[0]); return null;
            case "setColor": set(o,"value",args[0]); return null;
            case "bindUpdate": var a:Array<Dynamic> = o.callbacks; a.push(args[0]); return null;
            case "get_baseUI": return null;
            case "get_numChildren": var a:Array<Dynamic> = o.children; return a.length;
            case "getChildAt": var a:Array<Dynamic> = o.children; return a[args[0]];
            case "remove":
                var parent = field(o,"parent");
                if (parent != null) { var a:Array<Dynamic> = parent.children; a.remove(o); }
                o.parent = null; return null;
            default:
        }
        if (StringTools.startsWith(n,"set_")) { set(o,n.substr(4),args[0]); return args[0]; }
        throw t+"."+n;
    }
}
