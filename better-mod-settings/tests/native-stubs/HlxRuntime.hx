import hlx.runtime.ResolvedMember;

/** Minimal UI boundary for exercising production secret controls and window order. */
class HlxRuntime {
    public static var liveWorld = false;
    public static var failWindowConstruction = false;
    public static var ui:Dynamic = {target:null};
    public static var topElementReads = 0;
    public static function resolveType(name:String):String return name;
    public static function resolveStaticField(type:String, field:String):Dynamic {
        if (type == "ui.BaseUI" && field == "current") return ui;
        throw "Unexpected static field: " + type + "." + field;
    }
    public static function constructEnum(type:String, name:String, args:Array<Dynamic>):Dynamic return name;
    public static function resolveField(object:Dynamic, field:String):Dynamic return Reflect.field(object, field);
    public static function setField(object:Dynamic, field:String, value:Dynamic):Void Reflect.setField(object, field, value);
    public static function resolveMember(typeName:String, method:String):ResolvedMember return {typeName:typeName, method:method};
    public static function resolveStaticMember(typeName:String, method:String):ResolvedMember return resolveMember(typeName, method);
    public static function constructInstanceByName(typeName:String, count:Int, args:Array<Dynamic>):Dynamic {
        return switch (typeName) {
            case "ui.win.TitleWindow":
                // Native BaseElement calls virtual rebuild during construction.
                // BaseWindow skips its DOM when default flags require a world.
                var window:Dynamic = {windowFlags:1 | 65536, dom:null, allocated:false};
                bettermodsettings.NativeSettingsWindow.beforeRebuild(window);
                if (failWindowConstruction) throw "Simulated native constructor failure";
                if (liveWorld || (window.windowFlags & 65536) == 0) {
                    window.dom = {obj:window}; window.allocated = true;
                }
                window;
            case "h2d.Graphics":
                var graphic:Dynamic = {commands:[]};
                Reflect.setField(args[0], "graphic", graphic);
                graphic;
            case "h2d.filter.Nothing": {};
            default: throw "Unexpected native construction: " + typeName;
        };
    }
    public static function callResolved(member:ResolvedMember, args:Array<Dynamic>):Dynamic {
        var object:Dynamic = args[0];
        if (member.typeName == "h2d.Graphics") {
            if (member.method == "clear") Reflect.setField(object, "commands", []);
            else {
                var commands:Array<Dynamic> = Reflect.field(object, "commands");
                commands.push(member.method);
                if (member.method == "lineStyle") Reflect.setField(object, "lineColor", args[2]);
            }
            return null;
        }
        return switch (member.typeName + "." + member.method) {
            case "ui.win.BaseWindow.set_windowFlags":
                object.setFlagsOnce = true; object.windowFlags = args[1]; args[1];
            case "hl.types.ArrayObj.slice":
                var items:Array<Dynamic> = object; items.slice(args[1], args[2]);
            case "hl.types.ArrayObj.pushDyn":
                var items:Array<Dynamic> = object; items.push(args[1]); null;
            case "ui.comp.Dropdown.set_options": object.items = args[1]; args[1];
            case "ui.comp.Dropdown.initSelectedIndex": object.selectedIndex = args[1]; null;
            case "ui.comp.Dropdown.isOpen": object.open;
            case "ui.comp.Dropdown.close": object.open = false; object.closes++; null;
            case "ui.BaseUI.getTopInteractiveElement": topElementReads++; object.target;
            case "h2d.Object.contains":
                var target:Dynamic = args[1], found = false;
                while (target != null) {
                    if (target == object) { found = true; break; }
                    target = Reflect.field(target, "parent");
                }
                found;
            case "domkit.Properties.createNew":
                if (args[0] != "button") throw "Secret control must create a button";
                var dom:Dynamic = {obj:{}, styles:{}, parent:args[1]};
                var children:Array<Dynamic> = Reflect.field(args[1], "children");
                children.push(dom);
                dom;
            case "domkit.Properties.initStyle":
                Reflect.setField(Reflect.field(object, "styles"), args[1], args[2]);
                // Match the game's separate ObjectComp/FlowComp setters:
                // valign belongs to the parent; content-valign to this flow.
                var styled = Reflect.field(object, "obj");
                if (styled != null) {
                    if (args[1] == "valign") {
                        var properties = Reflect.field(styled, "flowProperties");
                        if (properties != null) Reflect.setField(properties, "verticalAlign", args[2]);
                    } else if (args[1] == "content-valign") Reflect.setField(styled, "verticalAlign", args[2]);
                }
                null;
            case "h2d.Flow.getProperties":
                if (!Reflect.hasField(args[1], "flowProperties")) Reflect.setField(args[1], "flowProperties", {});
                Reflect.field(args[1], "flowProperties");
            case "h2d.Object.getChildIndex":
                var children:Array<Dynamic> = Reflect.field(object, "children");
                children.indexOf(args[1]);
            case "h2d.Flow.addChildAt":
                var children:Array<Dynamic> = Reflect.field(object, "children");
                var index:Int = args[2];
                if (Reflect.field(object, "background") != null) index++;
                if (Reflect.field(object, "interactive") != null) index++;
                children.remove(args[1]);
                children.insert(index, args[1]);
                null;
            case "h2d.Object.setPosition":
                Reflect.setField(object, "x", args[1]);
                Reflect.setField(object, "y", args[2]);
                null;
            case "h2d.FlowProperties.set_isAbsolute", "h2d.filter.Filter.set_useScreenResolution",
                 "h2d.filter.Filter.set_resolutionScale", "h2d.Object.set_filter",
                 "h2d.Flow.set_layout", "h2d.Flow.set_reverse", "h2d.Flow.set_needReflow",
                 "h2d.Flow.set_fillWidth", "h2d.Flow.set_fillHeight", "h2d.Flow.set_multiline",
                 "h2d.Flow.set_minWidth", "h2d.Flow.set_maxWidth", "h2d.Flow.set_minHeight", "h2d.Flow.set_maxHeight",
                 "h2d.Flow.set_paddingLeft", "h2d.Flow.set_paddingRight", "h2d.Flow.set_paddingTop", "h2d.Flow.set_paddingBottom",
                 "h2d.Flow.set_verticalAlign", "h2d.Flow.set_verticalSpacing", "h2d.Flow.set_horizontalSpacing",
                 "ui.UIElement.set_onClick", "ui.UIElement.set_textTip":
                Reflect.setField(object, member.method.substr(4), args[1]);
                null;
            default: throw "Unexpected native call: " + member.typeName + "." + member.method;
        };
    }
}
