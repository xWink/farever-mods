package moresettings;

/** Test adapter: plain objects stand in for native HL objects and arrays. */
class GameAccess {
    public static var data:Dynamic;
    public static var inputArrayCalls:Int = 0;
    public static var blitCalls:Int = 0;
    public static var blitElements:Int = 0;
    public static var removedElements:Int = 0;
    public static var terrainLookups:Int = 0;
    public static var terrainBindings:Int = 0;
    public static var beforeTerrainLookup:Void->Void;
    public static var failTerrainBinding:Bool = false;
    public static var inputActive:Bool = true;
    public static var releasedInput:String;
    public static var failRelease:Bool = false;
    public static var releaseReads:Int = 0;
    public static var removedTips:Int = 0;
    public static function setCurrent(type:String, name:String, value:Dynamic):Void
        set(data, name, value);
    public static function bind(type:String, name:String):Array<Dynamic>->Dynamic {
        return args -> {
            if (type == "world.terrain.TerrainData" && name == "getChunk") {
                terrainLookups++;
                if (beforeTerrainLookup != null) beforeTerrainLookup();
                var data = args[0];
                var x = Math.floor(args[1] / data.chunkWidth);
                var y = Math.floor(args[2] / data.chunkWidth);
                var chunks:Map<Int, Dynamic> = data.chunks;
                return chunks.get((x + 16384) | ((y + 16384) << 16));
            }
            if (type == "haxe.ds.IntMap" && name == "get") {
                var map:Map<Int, Dynamic> = args[0]; return map.get(args[1]);
            }
            if (type == "client.Renderer" && name == "setTerrainGlobals") {
                if (failTerrainBinding) throw "native terrain binding failed";
                terrainBindings++;
                args[0].boundTerrain = args[0].terrain;
                return null;
            }
            if (type == "h3d.mat.Texture" && name == "set_lastFrame") {
                if (args[0].lastFrame != -1) args[0].lastFrame = args[1];
                return args[0].lastFrame;
            }
            throw "Unexpected bound native call: " + type + "." + name;
        };
    }
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "h2d.Interactive" && args.length != 4)
            throw "Native Interactive requires width, height, parent and shape";
        return {type: type, args: args, parent: args.length > 0 ? args[0] : null};
    }
    public static function set(o:Dynamic, name:String, value:Dynamic):Void if (o != null) Reflect.setField(o, name, value);
    public static function text(v:Dynamic, fallback:String = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float {
        var n = Std.parseFloat(text(v)); return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(v:Dynamic, fallback:Int = 0):Int return Std.int(number(v, fallback));
    public static function array(v:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) v = field(v, "array");
        if (field(v, "items") != null) return (cast v.items:Array<Dynamic>).copy();
        return v == null ? [] : cast v;
    }
    public static function isA(o:Dynamic, name:String):Bool {
        if (o == null) return false;
        var types:Array<String> = field(o, "types"); return types != null && types.indexOf(name) >= 0;
    }
    public static function callInstance(o:Dynamic, name:String):Dynamic return call("", name, o);
    public static function current(type:String, name:String):Dynamic
        return field(data, name);
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic return switch name {
        case "get_myPlayer": field(data, "player");
        case "set_visible": set(o, "visible", args[0]); args[0];
        case "setTip":
            if (args.length != 4) throw "Native BaseUI.setTip requires content, anchor, position and spacing";
            var tip = {content: args[0], anchor: args[1], parent: field(o, "root")};
            set(o, "currentTip", tip); tip;
        case "removeTip":
            if (args.length != 1) throw "Native BaseUI.removeTip requires its optional tip argument";
            var tip = field(o, "currentTip");
            if (tip != null) { set(tip, "parent", null); set(o, "currentTip", null); removedTips++; }
            null;
        case "isOwner": field(o, "isOwner") == true;
        case "get_group": field(o, "group");
        case "getPlayerInfo":
            var found:Dynamic = null;
            for (entry in array(field(o, "players"), true))
                if (entry.player == args[0]) { found = entry; break; }
            found;
        case "hasAllPlayersReady":
            var entries = array(field(o, "players"), true);
            var ready = true;
            // Native lobby readiness deliberately skips its owner at index 0.
            for (i in 1...entries.length) if (entries[i].ready != true) ready = false;
            ready;
        case "set_enable": set(o, "enable", args[0]); args[0];
        case "setText":
            set(o, "text", args[0]);
            // Button.setText rebuilds via UIElement.init, clearing checkEnable.
            set(o, "checkEnable", null); null;
        case "bindUpdate":
            var callbacks:Array<Float->Void> = field(o, "callbacks");
            var callback:Float->Void = args[0];
            callbacks.push(callback); callback(0); null;
        case "set_text": set(o, "text", args[0]); args[0];
        case "getDyn": inputArrayCalls++; o.items[args[0]];
        case "setDyn": inputArrayCalls++; o.items[args[0]] = args[1]; null;
        case "blit":
            var count:Int = args[3];
            var source:Array<Dynamic> = args[1].items;
            var copy = source.slice(args[2], args[2] + count);
            for (i in 0...count) o.items[args[0] + i] = copy[i];
            blitCalls++; blitElements += count; null;
        case "resize":
            var items:Array<Dynamic> = o.items;
            items.resize(args[0]); o.length = items.length; null;
        case "remove":
            if (type == "h2d.Object") { o.parent = null; removedElements++; null; }
            else {
                var items:Array<Dynamic> = o.items;
                var removed = items.remove(args[0]); o.length = items.length; removed;
            }
        case "hasClass": (cast o.classes:Array<String>).indexOf(args[0]) >= 0;
        case "getFocusedTextInput": field(o, "textInput");
        case "get": field(o, args[0]);
        case "getSourceSkill": field(o, "sourceSkill") == null ? o : field(o, "sourceSkill");
        case "getSourceObject": field(o, "instigator") != null ? field(o, "instigator") : field(o, "owner");
        case "resolveProxy": field(o, "proxy") == null ? o : field(o, "proxy");
        case "isEnemy": field(args[0], "enemy") == true;
        case "isActive": field(o, "playing") == true;
        case "stop": set(o, "playing", false); set(o, "stops", integer(field(o, "stops")) + 1); null;
        default: throw "Unexpected native call: " + type + "." + name;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic return switch name {
        case "fromItem":
            if (type != "ui.Tooltip" || args.length != 2 || args[0] != field(args[1], "inf"))
                throw "Native Tooltip.fromItem requires the definition followed by the item";
            {definition: args[0], item: args[1]};
        case "isReleased":
            if (field(data, "_noCheckMode") != true) throw "Ground aim input mode was not bypassed";
            releaseReads++;
            if (failRelease) throw "Native input failed";
            inputActive && releasedInput == args[0];
        default: throw "Unexpected native static call: " + type + "." + name;
    };
}
