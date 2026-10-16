package minimap;

/** Native-only boundary; BigMapView and the complete marker collector/renderer run unchanged. */
class GameAccess {
    public static var globals:Map<String, Dynamic> = [];
    public static var created:Array<Dynamic> = [];
    public static var failGraphics:Bool = false;
    public static var arraysRead:Int = 0;
    public static var restored:Int = 0;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, v:Dynamic):Void Reflect.setField(o, name, v);
    public static function text(v:Dynamic, fallback:String = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float {
        if (v == null) return fallback;
        var n = Std.parseFloat(Std.string(v));
        return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(v:Dynamic, fallback:Int = 0):Int return Std.int(number(v, fallback));
    public static function family(o:Dynamic):String return text(field(o, "family"));
    public static function array(v:Dynamic, proxy:Bool = false):Array<Dynamic> {
        arraysRead++;
        if (proxy) v = field(v, "array");
        return v == null ? [] : cast v;
    }
    public static function current(type:String, name:String):Dynamic return globals[type + "." + name];
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        var parent:Dynamic = type == "h2d.Text" ? args[1] : type == "h2d.Interactive" ? args[2] : args[0];
        if (["h2d.Object", "h2d.Graphics", "h2d.Text", "h2d.Interactive"].indexOf(type) < 0) throw "Constructor " + type;
        var o:Dynamic = {nativeType: type, parent: parent, visible: true, alpha: 1., x: 0., y: 0., scale: 1., rotation: 0., removed: false};
        if (type == "h2d.Text") { o.font = args[0]; o.text = ""; }
        created.push(o);
        return o;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "HMapActivity" && name == "getKind") return args[0].id;
        if (type == "HData" && name == "checkStatus") return true;
        if (name == "isOfType") return field(args[0], "id") == args[1] || field(args[0], "inherit") == args[1];
        if (type == "HActivity" && name == "allFiltered") return globals["activities"];
        if (type == "HActivity" && name == "getPos") return args[0].position;
        if (type == "hxd.res.DefaultFont" && name == "get") return {size: 14};
        if (type == "st.event.Rift" && name == "getEvent") return null;
        if (type == "data.CodexData" && name == "isInCodex") return false;
        if (type == "HText") return field(args[0], "id");
        throw "Static " + type + "." + name;
    }
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        if (type == "h2d.Graphics") {
            if (failGraphics) throw "Graphics unavailable";
            if (["clear", "beginFill", "endFill", "lineStyle", "moveTo", "lineTo", "drawCircle", "drawRect", "drawEllipse", "drawRoundedRect"].indexOf(name) < 0) throw "Graphics " + name;
            return null;
        }
        if (type == "h2d.Object" || type == "ui.UIElement" && name == "set_visible") {
            switch name {
                case "setScale": o.scale = args[0];
                case "setPosition": o.x = args[0]; o.y = args[1];
                case "set_rotation": o.rotation = args[0];
                case "set_visible": o.visible = args[0];
                case "remove": o.parent = null; o.removed = true;
                default: throw "Object " + name;
            }
            return null;
        }
        if (type == "h2d.Text") return switch name {
            case "set_text": o.text = args[0]; null;
            case "set_textColor": o.color = args[0]; null;
            case "get_textWidth": o.text.length * 7.;
            case "get_textHeight": 14.;
            default: throw "Text " + name;
        };
        if (type == "h2d.Interactive" && name == "isOver") return true;
        if (type == "h2d.Flow" && name == "getProperties") return {};
        if (type == "h2d.FlowProperties" && name == "set_isAbsolute") return null;
        if (type == "h2d.Layers" && name == "add") { args[0].parent = o; args[0].layer = args[1]; return null; }
        if (type == "h2d.Layers" && name == "getChildLayer") return args[0].layer;
        if (type == "ui.BaseElement" && name == "get_myHero") return o.hero;
        if (type == "ui.UIElement" && name == "hideTip") { o.tipHidden = true; return null; }
        if (type == "ui.win.MapWindow") return switch name {
            case "get_tileScale": o.tileScale;
            case "refreshVisuals":
                restored++;
                for (m in (cast o.markers:Array<Dynamic>)) m.visible = m.nativeVisible;
                null;
            case "updateMapInfos":
                for (m in (cast o.markers:Array<Dynamic>)) { m.x = m.worldPos.x * o.tileScale; m.y = m.worldPos.y * o.tileScale; }
                null;
            default: throw "MapWindow " + name;
        };
        if (type == "haxe.ds.StringMap" && name == "get") return o == null ? null : (cast o:Map<String, Dynamic>).get(args[0]);
        if (type == "hrt.prefab.Object3D" && name == "getAbsPos") return o;
        if (type == "ent.Element" && name == "isHidden") return false;
        if (type == "ent.Element" && name == "getElementStateInf") return {flags: o.state};
        if (type == "st.player.Progress" && name == "hasElementCompleted") return true;
        if (type == "st.player.Progress" && name == "hasActivityCompleted") return o.completed == args[0];
        if (type == "ent.GameObject" && name == "isDead") return false;
        if (type == "ent.Foe" && name == "isEnemyWith") return true;
        if (type == "ent.Hero" && name == "isSameGroup") return args[0].party == true;
        if (type == "st.FriendList" && name == "isFriend") return false;
        if (type == "st.player.Collection" && name == "hasPet") return o.owned == args[0];
        if (name == "getName") return o.name;
        throw "Call " + type + "." + name;
    }
}
