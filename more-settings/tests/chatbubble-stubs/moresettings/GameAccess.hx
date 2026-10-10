package moresettings;

class GameAccess {
    public static var ui:Dynamic;
    public static var bubbles:Array<Dynamic> = [];
    public static var fail = false;
    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function number(value:Dynamic):Float return value == null ? 0.0 : value;
    public static function isA(object:Dynamic, type:String):Bool return field(object, "type") == type;
    public static function current(type:String, name:String):Dynamic
        return type == "Const" ? {WidgetHeightOffset: 0.25} : ui;
    public static function enumValue(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "ui.EWidgetFollowType" || name != "EFollow" || args[1] != null) throw "Wrong native follow type";
        return {object: args[0]};
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "ui.Widget") {
            if (args[1] != ui || args[2] != null) throw "Widget must use the current native UI container";
            var widget:Dynamic = {followType: args[0], parent: ui, removed: false};
            widget.container = {parent: widget};
            ui.widgets.push(widget);
            return widget;
        }
        if (type == "ui.hud.ChatBubble") {
            if (fail) throw "Native chat bubble failed";
            var bubble:Dynamic = {unit: args[0], parent: args[1]};
            bubbles.push(bubble);
            return bubble;
        }
        throw 'Unexpected constructor: $type';
    }
    public static function call(type:String, name:String, object:Dynamic):Dynamic {
        if (type != "h2d.Object" || name != "remove") throw 'Unexpected call: $type.$name';
        object.parent.widgets.remove(object);
        object.parent = null;
        object.removed = true;
        return null;
    }
}
