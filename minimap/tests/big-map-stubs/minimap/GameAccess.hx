package minimap;

/** Native-only boundary; BigMapView and the complete marker collector/renderer run unchanged. */
class GameAccess {
    public static var globals:Map<String, Dynamic> = ["h3d.mat.TextureFlags.Target" => "Target", "hxd.PixelFormat.RGBA" => "RGBA", "h2d.BlendMode.AlphaAdd" => "AlphaAdd",
        "h3d.mat.TextureFlags.MipMapped" => "MipMapped", "h3d.mat.MipMap.Linear" => "Linear"];
    public static var bakes:Int = 0;
    public static var positionWrites:Int = 0;
    public static var visibilityWrites:Int = 0;
    public static var failBake:Bool = false;
    public static var created:Array<Dynamic> = [];
    public static var failGraphics:Bool = false;
    public static var arraysRead:Int = 0;
    public static var restored:Int = 0;
    public static var activityNameReads:Int = 0;
    public static var failActivityLookup:Bool = false;
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
        if (type == "h3d.mat.Texture") {
            if (args.length != 4 || args[3] != "RGBA" || (cast args[2]:Array<Dynamic>).indexOf("Target") < 0) throw "Invalid texture arguments";
            var texture:Dynamic = {nativeType:type, width:args[0], height:args[1], flags:(cast args[2]:Array<Dynamic>).copy(), disposed:false};
            created.push(texture); return texture;
        }
        if (type == "h2d.filter.Nothing" || type == "h2d.filter.Outline") { var filter:Dynamic = {nativeType: type}; created.push(filter); return filter; }
        var parent:Dynamic = type == "h2d.Mask" ? args[2] : type == "h2d.Text" || type == "h2d.Bitmap" ? args[1] : type == "h2d.Interactive" ? args[2] : args[0];
        if (["h2d.Object", "h2d.Graphics", "h2d.Text", "h2d.Bitmap", "h2d.Interactive", "h2d.Mask"].indexOf(type) < 0) throw "Constructor " + type;
        var o:Dynamic = {nativeType: type, parent: parent, visible: true, alpha: 1., x: 0., y: 0., scale: 1., rotation: 0., removed: false};
        if (type == "h2d.Text") { o.font = args[0]; o.text = ""; }
        if (type == "h2d.Bitmap") { o.tile = args[0]; o.color = {argb:0xffffffff}; }
        created.push(o);
        return o;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "domkit.Properties" && name == "createNew") {
            var component:String = args[0];
            var parent = field(args[1], "obj");
            var obj:Dynamic = {nativeType:component, parent:parent, visible:true, removed:false, x:0., y:0., scale:1.};
            var dom:Dynamic = {obj:obj, id:args[3].id}; obj.dom = dom;
            if (component == "button") obj.background = {shader:{}, color:{argb:0}, dom:{}, fill:0};
            if (component == "text") { obj.text = args[2][0]; obj.font = {size:14}; obj.styleClass = field(args[3], "class"); }
            created.push(obj); return dom;
        }
        if (type == "h2d.Tile" && name == "fromTexture") {
            if (args.length != 1) throw "Tile argument count";
            return {texture:args[0], width:args[0].width, height:args[0].height};
        }
        if (type == "HMapActivity" && name == "getKind") return args[0].id;
        if (type == "HData" && name == "checkStatus") return true;
        if (name == "isOfType") return field(args[0], "id") == args[1] || field(args[0], "inherit") == args[1];
        if (type == "HActivity" && name == "allFiltered") return globals["activities"];
        if (type == "HActivity" && name == "getInf") {
            activityNameReads++;
            if (failActivityLookup) throw "Activity definitions unavailable";
            return globals["activity:" + args[0]];
        }
        if (type == "HActivity" && name == "getPos") return args[0].position;
        if (type == "hxd.res.DefaultFont" && name == "get") return {size: 14};
        if (type == "ui.BaseUI" && name == "getTile") return field(args[0], "tile");
        if (type == "st.event.Rift" && name == "getEvent") return null;
        if (type == "data.CodexData" && name == "isInCodex") return false;
        if (type == "HText") return field(args[0], "label") == null ? field(args[0], "id") : field(args[0], "label");
        throw "Static " + type + "." + name;
    }
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        if (type == "hl.types.ArrayObj") return switch name {
            case "slice": (cast o:Array<Dynamic>).slice(args[0], args[1]);
            case "pushDyn": (cast o:Array<Dynamic>).push(args[0]);
            default: throw "Array " + name;
        };
        if (type == "h3d.mat.Texture") return switch name {
            case "clear":
                if (args.length != 3) throw "Invalid texture clear arguments";
                // Match the game's RGB + separate alpha API: null means opaque.
                o.clearColor = args[0];
                o.clearAlpha = args[1] == null ? 1. : number(args[1]);
                o.clearArgb = integer(args[0]) | (Std.int(Math.max(0, Math.min(1, o.clearAlpha)) * 255) << 24);
                null;
            case "checkMipMapGen":
                // The method and enums exist even on unsupported renderers.
                throw "Mipmaps auto generation is not supported on this platform";
            case "set_mipMap": o.mipMap = args[0]; null;
            case "preventAutoDispose": o.retained = true; null;
            case "dispose": o.disposed = true; null;
            default: throw "Texture " + name;
        };
        if (type == "h2d.Tile") return switch name {
            case "scaleToSize": o.width = args[0]; o.height = args[1]; null;
            case "setCenterRatio": o.dx = -o.width * args[0]; o.dy = -o.height * args[1]; null;
            default: throw "Tile " + name;
        };
        if (type == "h2d.Graphics") {
            if (failGraphics) throw "Graphics unavailable";
            if (["clear", "beginFill", "endFill", "lineStyle", "moveTo", "lineTo", "drawCircle", "drawRect", "drawEllipse", "drawRoundedRect"].indexOf(name) < 0) throw "Graphics " + name;
            return null;
        }
        if (type == "h2d.Object" || type == "ui.UIElement" && name == "set_visible") {
            switch name {
                case "drawTo":
                    if (args.length != 1 || args[0].clearColor != 0) throw "Invalid bake";
                    if (failBake) throw "Texture bake failed";
                    bakes++; args[0].baked = true;
                    args[0].bakedBackground = args[0].clearArgb;
                case "addChild": args[0].parent = o;
                case "set_filter": o.filter = args[0];
                case "setScale": o.scale = args[0];
                case "setPosition": positionWrites++; o.x = args[0]; o.y = args[1];
                case "set_rotation": o.rotation = args[0];
                case "set_visible": visibilityWrites++; o.visible = args[0];
                case "remove": o.parent = null; o.removed = true;
                case "onRemove": o.removed = true;
                default: throw "Object " + name;
            }
            return null;
        }
        if (type == "shiro.ui.DynamicBackground" && name == "set_background") { o.fill = args[0]; return null; }
        if (type == "h3d.Vector4Impl" && name == "setColor") { o.argb = args[0]; return null; }
        if (type == "domkit.Properties") return null;
        if (type == "ui.UIElement" || type == "ui.comp.CheckBox") {
            if (StringTools.startsWith(name, "set_")) { Reflect.setField(o, name.substr(4), args[0]); return null; }
        }
        if (type == "h2d.Flow" && StringTools.startsWith(name, "set_")) { Reflect.setField(o, name.substr(4), args[0]); return null; }
        if (type == "h2d.filter.Outline") { Reflect.setField(o, name.substr(4), args[0]); return null; }
        if (type == "h2d.filter.Filter") return switch name {
            case "set_useScreenResolution": o.useScreenResolution = args[0]; null;
            case "set_resolutionScale": o.resolutionScale = args[0]; null;
            default: throw "Filter " + name;
        };
        if (type == "h2d.Text") return switch name {
            case "set_font": o.font = args[0]; null;
            case "set_text": o.text = args[0]; null;
            case "set_textColor": o.color = args[0]; null;
            case "get_textWidth": o.text.length * 7.;
            case "get_textHeight": 14.;
            default: throw "Text " + name;
        };
        if (type == "h2d.Bitmap" && name == "set_tile") { o.tile = args[0]; return null; }
        if (type == "h2d.Interactive" && name == "isOver") return true;
        if (type == "h2d.Flow" && name == "getProperties") return {};
        if (type == "h2d.FlowProperties" && name == "set_isAbsolute") return null;
        if (type == "h2d.Layers" && name == "add") { args[0].parent = o; args[0].layer = args[1]; return null; }
        if (type == "h2d.Layers" && name == "getChildLayer") return args[0].layer;
        if (type == "ui.BaseElement" && name == "get_myHero") return o.hero;
        if (type == "ui.UIElement" && name == "hideTip") { o.tipHidden = true; return null; }
        if (type == "ui.win.map.MapMarker" && name == "get_showOffscreen") return field(o, "showOffscreen") == true;
        if (type == "ui.win.MapWindow") return switch name {
            case "get_tileScale": o.tileScale;
            case "refreshVisuals":
                restored++;
                for (m in (cast o.markers:Array<Dynamic>)) m.visible = m.nativeVisible;
                null;
            case "updateMapInfos":
                for (m in (cast o.markers:Array<Dynamic>)) { m.x = field(m, "showOffscreen") == true ? -999. : m.worldPos.x * o.tileScale; m.y = m.worldPos.y * o.tileScale; }
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
