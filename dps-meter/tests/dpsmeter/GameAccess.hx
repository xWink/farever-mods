package dpsmeter;

/** Interpreter-only native bridge. Unexpected native calls fail the test;
    production builds do not include this classpath. */
class GameAccess {
    public static var globals:Map<String, Dynamic> = [];
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback:String = ""):String return value == null ? fallback : Std.string(value);
    public static function uid(value:Dynamic):String return text(field(value, "__uid"));
    public static function integer(value:Dynamic, fallback:Int = 0):Int return value == null ? fallback : Std.int(value);
    public static function number(value:Dynamic, fallback:Float = 0):Float {
        var number = value == null ? Math.NaN : Std.parseFloat(Std.string(value));
        return Math.isFinite(number) ? number : fallback;
    }
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function current(type:String, name:String):Dynamic return globals[type + "." + name];
    public static function enumeration(type:String, name:String):Dynamic return current(type, name);
    public static function create(type:String, args:Array<Dynamic>):Dynamic return switch (type) {
        case "h3d.mat.Texture":
            // Match Farever's DX12 boundary: BGRA is valid for CPU Pixels but
            // is rejected when allocating a GPU texture (getTextureFormat).
            if (args[3] != "RGBA") throw "Unsupported texture format " + args[3];
            {width: args[0], height: args[1], flags: args[2], format: args[3]};
        default: throw "Unexpected native constructor: " + type;
    };
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic return switch (type + "." + name) {
        case "haxe.ds.StringMap.get": (cast object:Map<String, Dynamic>).get(args[0]);
        case "haxe.ds.StringMap.keys": (cast object:Map<String, Dynamic>).keys();
        case "haxe.ds._StringMap.StringMapKeysIterator.hasNext": object.hasNext();
        case "haxe.ds._StringMap.StringMapKeysIterator.next": object.next();
        case "st.Player.getActivityContext": field(object, "context");
        case "ent.GameObject.isDead": field(object, "dead") == true || field(object, "removed") == true;
        // The shipped client retains this server-only method as a throwing stub.
        case "ent.Unit.isAtDeathDoor": throw "!isServer";
        case "ent.Unit.get_health": field(object, "health");
        case "ent.Unit.get_maxHealth": field(object, "maxHealth");
        case "ent.Unit.getName": field(object, "name");
        case "st.skill.DamageResult.get_source": field(object, "source");
        case "st.skill.DamageResult.get_isPhysical": field(object, "physical") == true;
        case "st.skill.DamageResult.get_isMagic": field(object, "magical") == true;
        case "h2d.Object.getScene": field(object, "scene");
        case "h2d.Object.drawTo":
            var draw:Dynamic->Void = globals["drawSnapshot"];
            if (draw == null) throw "Missing snapshot draw expectation";
            draw(args[0]);
            null;
        case "h3d.mat.Texture.capturePixels":
            if (object.format != "RGBA") throw "Unsupported texture format " + object.format;
            globals["capturedPixels"];
        case "hxd.Pixels.convert":
            if (globals["failPixelConversion"] == true) throw "Simulated conversion failure";
            if (object.format != "RGBA" || args[0] != "BGRA") throw "Unexpected pixel conversion";
            var bytes:haxe.io.Bytes = object.bytes;
            for (i in 0...Std.int(bytes.length / 4)) {
                var red = bytes.get(i * 4); bytes.set(i * 4, bytes.get(i * 4 + 2)); bytes.set(i * 4 + 2, red);
            }
            object.format = "BGRA";
            null;
        case "hxd.Pixels.dispose": object.disposed = true; null;
        default: throw "Unexpected native metadata call: " + type + "." + name;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic return switch (type + "." + name) {
        case "Config.getVersion": "0.3.0.test";
        case "HActivity.all": [];
        case "data.CodexData.isInCodex": field(args[0], "inCodex") == true;
        case "st.player.Progress.getUnitProgressThreshold": field(args[0], "thresholds");
        case "HText.unit": field(args[0], "name");
        case "HActivity.getInf": (cast globals["activities"]:Map<String, Dynamic>).get(args[0]);
        case "HActivity.isOfType": (cast field(args[0], "types"):Array<String>).indexOf(args[1]) >= 0;
        case "HSkill.getSkillRef": (cast globals["skillRefs"]:Map<String, Dynamic>).get(args[0]);
        case "ui.BaseUI.getTile": args[0];
        // In particular HText.skill is intentionally unavailable: readable
        // names must not depend on constructing a native SkillSpec.
        default: throw "Unexpected native metadata call: " + type + "." + name;
    };
}
