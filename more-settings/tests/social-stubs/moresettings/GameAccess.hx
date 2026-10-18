package moresettings;

class GameAccess {
    public static var me:Dynamic;
    public static var npcs:Array<Dynamic> = [];
    public static var failTeleport = false;
    public static var ui:Dynamic;
    public static var calls:Array<{type:String, name:String, object:Dynamic, args:Array<Dynamic>}> = [];
    public static var saved:Dynamic;
    public static var cancel:Dynamic;
    public static var dialog:Dynamic;
    public static var keyFrame = 100;
    public static var failChatBlur = false;
    public static var reason = "Ok";
    public static var padActive = false;
    public static var longPresses:Map<String, Dynamic> = [];
    public static var bufferedPresses:Map<String, Dynamic> = [];
    public static var defaultBindings:Array<Dynamic> = [];
    public static var onHeroCheck:Void->Void;
    public static var onInputCheck:(String, Dynamic, Dynamic)->Bool;
    public static var heldAction:String;
    public static var holdProgress = 0.0;
    public static var chatColours:Map<String, String> = [
        "Chat_Local" => "#aaaaaa", "Chat_All" => "#e6b85c",
        "Chat_Group" => "#66ccff", "Chat_Player" => "#dd88ee"
    ];
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback = ""):String return value == null ? fallback : Std.string(value);
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : value;
    public static function integer(value:Dynamic, fallback = 0):Int return Std.int(number(value, fallback));
    public static function set(object:Dynamic, name:String, value:Dynamic):Void if (object != null) Reflect.setField(object, name, value);
    public static function isA(object:Dynamic, type:String):Bool return field(object, "type") == type;
    public static function array(value:Dynamic, proxy = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
    public static function enumeration(type:String, name:String):Dynamic return name;
    public static function enumValue(type:String, name:String, args:Array<Dynamic>):Dynamic return {type:type, name:name, args:args};
    public static function current(type:String, name:String):Dynamic {
        if (type == "HElement" && name == "npcs") return npcs;
        if (type == "lib.Input") return name == "longPresses" ? longPresses : bufferedPresses;
        if (type == "ui.comp.LongInputKey") return 0.15;
        return type == "Data" ? {byId: {}} : ui;
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "HData" && name == "checkStatus") return args[0] != "disabled";
        if (type == "ui.hud.ChatBoxMessage" && name == "getChannelColor") return switch Type.enumConstructor(args[0]) {
            case "Local": "Chat_Local";
            case "All": "Chat_All";
            case "Group": "Chat_Group";
            case "Player": "Chat_Player";
            default: throw "Unexpected timestamp channel";
        };
        if (type == "HText" && name == "withColor") {
            var colour = chatColours.get(args[1]);
            if (colour == null) throw "Unknown chat colour: " + args[1];
            return '<font color="' + colour + '">' + args[0] + '</font>';
        }
        if (type == "hxd.Key" && name == "getFrame") return keyFrame;
        if (type == "gamepad.Pad" && name == "get_active") return padActive;
        if (type == "lib.Input") return switch name {
            case "getBindings": @:privateAccess SocialHooks.socialBindingRead(args[0], defaultBindings.copy());
            case "isLongPressed":
                heldAction = args[0];
                // Short-hold release buffering belongs to the passed action.
                bufferedPresses.set(heldAction, 101.0);
                switch (@:privateAccess SocialHooks.socialInput(heldAction, null, null)) {
                    case SkipWith(value): value;
                    default: throw "Alias was not routed through native checks";
                }
            case "checkInput": onInputCheck(args[0], args[1], args[2]);
            case "getLongPressProgress":
                if (args[0] != SocialInteract.ACTION) throw "Reading ordinary Interact progress";
                holdProgress;
            default: throw type + "." + name;
        };
        if (type == "HText" && name == "reason") return args[0];
        throw type + "." + name;
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type != "h2d.Text") throw type;
        var obj:Dynamic = {type:type, font:args[0], parent:args[1], scaleX:1.0, text:"", children:[], x:0.0,y:0.0};
        var parent:Dynamic = args[1]; parent.children.push(obj);
        return obj;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        calls.push({type:type,name:name,object:object,args:args});
        if (type == "hl.types.ArrayObj") {
            var a:Array<Dynamic> = cast object;
            return switch name {
                case "pop": a.pop();
                case "insert": a.insert(args[0], args[1]); null;
                case "getDyn": a[args[0]];
                case "setDyn": a[args[0]] = args[1]; null;
                default: throw name;
            };
        }
        return switch name {
            case "getAbsPos": object.matrix;
            case "rpcTeleportPosition":
                if (failTeleport) throw "Simulated teleport failure";
                null;
            case "tryInteractHero": onHeroCheck(); null;
            case "getFocusedTextInput": field(object, "textInput");
            case "isDead": field(object, "dead") == true;
            case "bindUpdate":
                var callback:Float->Void = args[0];
                object.callbacks.push(callback); callback(0); null;
            case "set_progress": object.progress = args[0]; args[0];
            case "remove" if (type == "haxe.ds.StringMap"):
                var map:Map<String, Dynamic> = object; map.remove(args[0]);
            case "get_myPlayer": me;
            case "get_baseUI": ui;
            case "getName": object.name;
            case "get_isSolo": object.players.array.length < 2;
            case "hasInvitePlayerAllowed", "invitePlayer", "requestLeave": reason;
            case "sendInviteGroup", "initStyle": null;
            case "chatError": object.errors.push(args[0]); null;
            case "focus": object.focused = true; null;
            case "unfocus" if (type == "ui.hud.ChatBox"):
                // Native TextInput.blur hides its cursor before the chat's
                // mouse-over guard can veto SceneEvents releasing focus.
                object.cursorVisible = false;
                var event:Dynamic = {cancel:field(object, "mouseOverChat") == true};
                @:privateAccess SocialHooks.chatFocusLost(field(field(object, "messageInput"), "input"), event);
                if (failChatBlur) throw "Simulated blur failure";
                if (!event.cancel) object.focused = false;
                object.inspectFocused = false;
                null;
            case "unfocus": object.focused = false; null;
            case "setChannel": object.channel = args[0]; null;
            case "get" if (type == "haxe.ds.StringMap"): {name:"Send message"};
            case "bindAction": object.boundActions.push(args[0]); null;
            case "hasClass": var classes:Array<String> = object.classes; classes.indexOf(args[0]) >= 0;
            case "get_numChildren": object.children.length;
            case "getChildAt": object.children[args[0]];
            case "get_outerWidth": object.calculatedWidth;
            case "getProperties": {};
            case "set_isAbsolute": null;
            case "setScale": object.scaleX = args[0]; null;
            case "setPosition": object.x = args[0]; object.y = args[1]; null;
            case "getBounds":
                var max:Float = field(object, "maxWidthText") == null ? 10000 : object.maxWidthText;
                var x = 0.0, y = 0.0;
                var cursor = object;
                while (cursor != null) { x += number(field(cursor,"x")); y += number(field(cursor,"y")); cursor = field(cursor,"parent"); }
                cursor = args[0];
                while (cursor != null) { x -= number(field(cursor,"x")); y -= number(field(cursor,"y")); cursor = field(cursor,"parent"); }
                var width = field(object, "calculatedWidth") == null ? Math.min(text(field(object,"text")).length * 7, max) : number(object.calculatedWidth);
                {xMin:x, xMax:x + width, yMin:y, yMax:y + number(field(object,"calculatedHeight"),16)};
            case "calcTextWidth": text(args[0]).length * 7.0;
            case "set_font": object.font = args[0]; args[0];
            case "set_text":
                if (type == "ui.comp.FmtText") object.prevUnformatted = args[0];
                object.text = args[0]; args[0];
            case "set_textColor", "set_lineBreak", "set_textTip", "set_textMultiline", "set_useEllipsis", "set_maxWidthText":
                set(object,name.substr(4),args[0]); args[0];
            case "setText": object.text = args[0]; null;
            case "rebuild": object.rebuilds++; null;
            case "displayTextInputDialog":
                saved = args[3]; cancel = args[4];
                var created:Dynamic = {input:{input:{text:args[2]}},buttons:[{},{}],closed:false};
                var confirm:Dynamic = saved;
                created.input.input.onEnter = () -> { confirm(created.input.input.text); created.closed = true; };
                dialog = created; dialog;
            default: throw type + "." + name;
        };
    }
}
