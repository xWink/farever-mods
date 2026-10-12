package moresettings;

/** Native rendering boundary for filter composition, alpha, and resource-lifetime tests. */
class GameAccess {
    public static var textures:Array<Dynamic> = [];
    public static var skillRefs:Map<String, Dynamic> = [];
    public static var data:Dynamic;
    public static var tileLoads:Int = 0;
    public static var bitmapCreates:Int = 0;
    /** DOMKit inline styles win over stylesheet rules during delayed refresh. */
    public static function refreshStyles(dom:Dynamic, rules:Dynamic):Void {
        for (name in Reflect.fields(rules)) {
            if (!Reflect.hasField(dom.styles, name))
                call("h2d.Object", "set_" + name, dom.obj, [field(rules, name)]);
        }
        for (name in Reflect.fields(dom.styles)) {
            var setter = name == "src" ? "tile" : name;
            call("h2d.Object", "set_" + setter, dom.obj, [field(dom.styles, name)]);
        }
    }
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function text(value:Dynamic, fallback:String = ""):String return value == null ? fallback : Std.string(value);
    public static function current(type:String, name:String):Dynamic return field(data, name);
    public static function callInstance(o:Dynamic, name:String):Dynamic {
        if (name == "getSourceSkill") return field(o, "sourceSkill") == null ? o : field(o, "sourceSkill");
        throw "Unexpected instance call: " + name;
    }
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : cast value;
    public static function integer(value:Dynamic, fallback:Int = 0):Int return Std.int(number(value, fallback));
    public static function set(o:Dynamic, name:String, value:Dynamic):Void Reflect.setField(o, name, value);
    public static function isA(o:Dynamic, type:String):Bool
        return o != null && field(o, "nativeType") == type;
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic>
        return value == null ? [] : cast value;
    public static function enumeration(type:String, name:String):Dynamic return type + "." + name;
    public static function create(type:String, args:Array<Dynamic>):Dynamic return switch type {
        case "h3d.MatrixImpl": {};
        case "h3d.pass.ColorMatrixShader": {maskMatA__: {}, maskMatB__: {}, maskChannel__: {}};
        case "h2d.filter.Shader": {kind: "gradient", shader: args[0], pass: {shader: args[0]}};
        case "h2d.filter.Outline": {kind: "outline", color: 0, alpha: 1.0};
        case "h2d.filter.Group": {kind: "group", filters: new Array<Dynamic>()};
        default: throw "Unexpected native constructor: " + type;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "domkit.Properties" && name == "createNew") {
            if (args[0] != "bitmap") throw "Unexpected DOM component";
            bitmapCreates++;
            // UnitEffectDisplay redirects contentRoot to its centered child.
            var parent:Dynamic = args[1].contentRoot.obj;
            var icon:Dynamic = {nativeType:"h2d.Bitmap", parent:parent, visible:true, tile:null};
            var dom:Dynamic = {obj:icon, styles:{}, id:args[3].id};
            icon.dom = dom;
            (cast parent.children:Array<Dynamic>).push(icon);
            return dom;
        }
        if (type == "HSkill" && name == "getSkillRef") return skillRefs[args[0]];
        if (type == "ui.BaseUI" && name == "getTile") { tileLoads++; return field(args[0], "tile"); }
        if (type == "hxd.Pixels" && name == "alloc") return {width: args[0], height: args[1], colors: new Array<Int>(), disposed: false};
        if (type == "h3d.mat.Texture" && name == "fromPixels") {
            var texture:Dynamic = {pixels: args[0], disposed: false, uploads: 1};
            textures.push(texture); return texture;
        }
        throw "Unexpected static call: " + type + "." + name;
    }
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Flow" && name == "addChildAt") {
            var child:Dynamic = args[0];
            if (child.parent != null) (cast child.parent.children:Array<Dynamic>).remove(child);
            (cast o.children:Array<Dynamic>).insert(args[1], child);
            child.parent = o;
            o.needReflow = true;
            return null;
        }
        if (type == "haxe.ds.StringMap" && name == "get") return (cast o:Map<String, Dynamic>)[args[0]];
        if (type == "h2d.Tile" && name == "clone") return Reflect.copy(o);
        if (type == "h2d.Tile" && name == "scaleToSize") { o.width = args[0]; o.height = args[1]; return null; }
        if (type == "st.skill.DamageResult") switch name {
            case "get_amount": return o.amount;
            case "getDynamicScalingFactor": return o.scale;
            case "get_critical": return o.critical;
        }
        if (type == "hl.types.ArrayObj" && name == "getDyn") return o[args[0]];
        if (type == "h2d.Object" && name == "get_numChildren") return o.children.length;
        if (type == "h2d.Object" && name == "getChildAt") return o.children[args[0]];
        if (type == "domkit.Properties" && name == "hasClass") return (cast o.classes:Array<String>).indexOf(args[0]) >= 0;
        if (type == "h2d.Text" && name == "updateSize") return null;
        if (type == "st.skill.DamageResult" && name == "get_isMagic") return o.magic;
        if (type == "h3d.pass.ColorMatrixShader" && StringTools.startsWith(name, "set_")) {
            set(o, name.substr(4) + "__", args[0]); return args[0];
        }
        if (type == "domkit.Properties" && name == "initStyle") {
            set(o.styles, args[0], args[1]); return null;
        }
        if (type == "h3d.MatrixImpl" && name == "zero") {
            for (row in 1...5) for (col in 1...5) set(o, '_$row$col', 0.0);
            return null;
        }
        if (type == "h2d.filter.Group" && name == "add") {
            (cast o.filters:Array<Dynamic>).push(args[0]); return null;
        }
        if (type == "hxd.Pixels" && name == "setPixel") {
            (cast o.colors:Array<Int>)[args[1]] = args[2]; return null;
        }
        if (name == "dispose") { o.disposed = true; return null; }
        if (type == "h3d.mat.Texture") switch name {
            case "isDisposed": return o.disposed;
            case "preventAutoDispose": o.pinned = true; return null;
            case "uploadPixels":
                if (args[0].disposed) throw "Used released ramp pixels";
                o.uploads++; return null;
        }
        if (StringTools.startsWith(name, "set_")) { set(o, name.substr(4), args[0]); return args[0]; }
        throw "Unexpected native call: " + type + "." + name;
    }
}
