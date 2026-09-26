package minimap;

/** Native activity, Codex, item and drawing boundaries for interpreter regression tests. */
class GameAccess {
    public static var nativeCall:(String, String, Dynamic, Array<Dynamic>)->Dynamic;
    public static var statusOwner:String = "Config";
    public static var eventArguments:Int = 1;
    public static var eventStatusCalls:Int = 0;
    public static function hasStaticMethod(type:String, name:String):Bool
        return type == statusOwner && name == "checkStatus";
    public static function argumentCount(object:Dynamic, name:String):Int {
        if (object == null || name != "getEventStatus") throw "Unexpected signature lookup";
        return eventArguments;
    }
    public static var definitions:Map<String, Dynamic> = [];
    public static var completionReads:Int = 0;
    public static var items:Map<String, Dynamic> = [];
    public static var itemReads:Int = 0;
    public static var graphicsCalls:Int = 0;
    public static var created:Array<Dynamic> = [];
    public static var transformCalls:Int = 0;
    public static var codexMembershipReads:Int = 0;
    public static var codexThresholdReads:Int = 0;
    public static var codexRewardIndex:Float = 2;
    public static var dummyGroup:Null<Int> = 42;
    public static var dummyGroupReads:Int = 0;
    public static var riftEvent:Dynamic;
    public static var events:Map<String, Dynamic> = [];
    public static var elements:Map<String, Dynamic> = [];
    public static var elementList:Array<Dynamic> = [];
    public static var elementReads:Int = 0;
    public static var riftReads:Int = 0;
    public static var riftLookupUnavailable:Bool = false;
    public static var durationUnavailable:Bool = false;
    public static var randomSeeds:Array<Int> = [];
    public static var randomCounts:Array<Int> = [];
    public static var randomIndex:Int = 0;

    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "hxd.Rand") { randomSeeds.push(args[0]); return {}; }
        if (type == "h2d.Graphics" || type == "h2d.Object" || type == "h2d.Text") {
            var object:Dynamic = {nativeType: type, parent: args[type == "h2d.Text" ? 1 : 0],
                x: 0., y: 0., rotation: 0., scale: 1., visible: true};
            if (type == "h2d.Text") { object.font = args[0]; object.text = ""; }
            created.push(object);
            return object;
        }
        throw "Unexpected native constructor: " + type;
    }

    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);

    public static function set(object:Dynamic, name:String, value:Dynamic):Void
        Reflect.setField(object, name, value);

    public static function text(value:Dynamic, fallback:String = ""):String
        return value == null ? fallback : Std.string(value);

    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }

    public static function number(value:Dynamic, fallback:Float = 0):Float {
        if (value == null) return fallback;
        var n = Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : fallback;
    }

    public static function integer(value:Dynamic, fallback:Int = 0):Int {
        if (value == null) return fallback;
        var number = Std.parseFloat(Std.string(value));
        return Math.isNaN(number) ? fallback : Std.int(number);
    }

    public static function current(type:String, name:String):Dynamic {
        if (type == "_Data.Unit_group_Impl_" && name == "Dummy") {
            dummyGroupReads++;
            return dummyGroup;
        }
        if (type == "Data" && name == "item") return {byId: items};
        if (type == "Data" && name == "event") return {byId: events};
        if (type == "HElement" && name == "allElements") return elements;
        if (type == "Const" && name == "Codex") return {FoeXPRewardThresholdIndex: codexRewardIndex};
        throw "Unexpected native static field";
    }

    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (name == "checkStatus") {
            if (type != statusOwner || args.length != 1) throw "Unavailable release-status API";
            return args[0] == null || args[0] == 1;
        }
        if (type == "st.event.Rift" && name == "getEvent") {
            riftReads++;
            if (riftLookupUnavailable) throw "Unavailable Rift lookup";
            return riftEvent;
        }
        if (type == "DateTimeBuilder" && name == "build") return args[0];
        if (type == "HData" && name == "getDuration") {
            if (durationUnavailable) throw "Unavailable duration conversion";
            return field(args[0], "seconds");
        }
        if (type == "HElement" && name == "all") { elementReads++; return elementList; }
        if (type == "data.CodexData" && name == "isInCodex") {
            codexMembershipReads++;
            return field(args[0], "inCodex") == true;
        }
        if (type == "st.player.Progress" && name == "getUnitProgressThreshold") {
            codexThresholdReads++;
            return field(args[0], "thresholds");
        }
        if (type != "HActivity" || name != "isOfType") throw "Unexpected native static call";
        var inf = args[0];
        // Native HActivity.isOfType follows IDs through the inheritance chain.
        while (inf != null) {
            if (field(inf, "id") == args[1]) return true;
            var parent = field(inf, "inherit");
            if (parent == null) return false;
            inf = definitions[parent];
        }
        return false;
    }

    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (nativeCall != null) return nativeCall(type, name, object, args == null ? [] : args);
        if (type == "st.event.WorldEvents" && name == "getEventStatus") {
            eventStatusCalls++;
            if (args.length != eventArguments) throw "Incorrect native argument count";
            var element:String;
            if (eventArguments == 3) {
                if (args[0] != null || args[2] != null) throw "Element lookup must leave activity/selector empty";
                element = args[1];
            } else element = args[0];
            return {status: element == object.disabled ? "Disabled" : "Active"};
        }
        if (type == "st.GameLayer" && name == "get_time") return object._time._time;
        if (type == "st.event.WorldEvent") return switch name {
            case "get_teaseTime": object.countdown;
            case "isPending": object.state == "pending";
            case "isOngoing": object.state == "open";
            case "get_remainingTime": object.openRemaining;
            default: throw "Unexpected event call: " + name;
        };
        if (type == "hxd.Rand" && name == "random") { randomCounts.push(args[0]); return randomIndex; }
        if (type == "hrt.prefab.Object3D" && name == "getAbsPos") return object;
        if (type == "h2d.Text") return switch name {
            case "set_text": object.text = args[0]; null;
            case "set_textColor": object.color = args[0]; null;
            case "get_textWidth": object.text.length * object.font.size / 2;
            case "get_textHeight": object.font.size;
            default: throw "Unexpected text call: " + name;
        };
        if (type == "h2d.Graphics") {
            if (["beginFill", "endFill", "moveTo", "lineTo", "lineStyle", "clear", "drawCircle"].indexOf(name) < 0)
                throw "Unexpected drawing call: " + name;
            if (name == "lineStyle" && args.length != 3) throw "Native lineStyle requires three optional argument slots";
            graphicsCalls++;
            return null;
        }
        if (type == "h2d.Object") {
            switch (name) {
                case "setPosition": object.x = args[0]; object.y = args[1];
                case "set_rotation": object.rotation = args[0];
                case "setScale": object.scale = args[0];
                case "set_visible": object.visible = args[0];
                default: throw "Unexpected native transform: " + name;
            }
            transformCalls++;
            return null;
        }
        if (type == "haxe.ds.StringMap" && name == "get") {
            itemReads++;
            return object == null ? null : (cast object:haxe.ds.StringMap<Dynamic>).get(args[0]);
        }
        if (type != "st.player.Progress" || name != "hasActivityCompleted") throw "Unexpected native call";
        completionReads++;
        return object.completed == args[0];
    }
}
