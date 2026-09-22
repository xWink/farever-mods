package modupdatealerts;

private enum WindowFlag {
    AutoDisplays; BlockInputs; AllowKeyboardInput; BlockSkills;
    IgnoreAutoClose; CloseOnWorldClick; CloseOnModalClick; BgShade;
    GcOnOpen; AutoRegisterLayer; FreeCursor; HideHud; NoHud; Debug;
    PreventCloseOther; LockClosing; NeedLayer;
}

/** Lifecycle test double; rendering is exercised by the real HL build/in-game. */
class GameAccess {
    public static var currentUi:Dynamic;
    public static var icons:Dynamic;
    public static function field(object:Dynamic,name:String):Dynamic
        return object==null ? null : Reflect.field(object,name);
    public static function set(object:Dynamic,name:String,value:Dynamic):Void
        if(object!=null) Reflect.setField(object,name,value);
    public static function number(value:Dynamic,fallback:Float=0):Float
        return value==null ? fallback : value;
    public static function integer(value:Dynamic,fallback:Int=0):Int
        return Std.int(number(value,fallback));
    public static function current(type:String,name:String):Dynamic
        return type=="Data" ? icons : currentUi;
    public static function call(type:String,name:String,object:Dynamic,?args:Array<Dynamic>):Dynamic {
        switch(type+"."+name) {
            case "ui.BaseUI.removeWindow":
                var windows:Array<Dynamic>=object.windows;
                var window=args[0];windows.remove(window);
                window.parent=null;window.removed=true;
            case "h2d.Object.remove":
                object.parent=null;object.removed=true;
            case "h2d.Object.set_visible": object.visible=args[0];
            case "ui.comp.FmtText.set_text": object.text=args[0];
            case "ui.comp.CheckBox.set_selected": object.selected=args[0];
            case "ui.win.BaseWindow.set_windowFlags": object.windowFlags=args[0];
            case "ui.win.BaseWindow.rebuild":
                // Match the game's early return when NeedLayer has no gameplay
                // layer. The default TitleWindow cannot build at the main menu.
                if((object.windowFlags & (1 << Type.enumIndex(NeedLayer)))==0 || object.myLayer!=null) {
                    object.dom={contentRoot:{}};
                    object.header={};
                }
            default: throw "Unexpected lifecycle call: "+type+"."+name;
        }
        return null;
    }
    public static function staticCall(type:String,name:String,args:Array<Dynamic>):Dynamic
        throw "Rendering is not available in lifecycle tests";
    public static function create(type:String,args:Array<Dynamic>):Dynamic
        throw "Rendering is not available in lifecycle tests";
    public static function enumeration(type:String,name:String):Dynamic {
        if(type=="ui.win.WindowFlags") return Type.createEnum(WindowFlag,name);
        throw "Rendering is not available in lifecycle tests";
    }
}
