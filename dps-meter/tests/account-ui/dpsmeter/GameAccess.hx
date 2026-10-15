package dpsmeter;

/** Native BaseDialog lifecycle: invoke confirm, then remove the dialog once. */
class GameAccess {
    public static final ui:Dynamic = {windows:[]};
    public static var created = 0;
    public static var removed = 0;
    public static var latest:Dynamic;
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function current(type:String, name:String):Dynamic return ui;
    public static function choose(dialog:Dynamic, index:Int):Void {
        dialog.confirm(dialog.descriptors[index].ic);
        call("ui.BaseUI", "removeWindow", ui, [dialog]);
    }
    public static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        switch (type + "." + name) {
            case "hl.types.ArrayObj.slice": return [];
            case "hl.types.ArrayObj.pushDyn": return (cast object:Array<Dynamic>).push(args[0]);
            case "hl.types.ArrayObj.getDyn": return object[args[0]];
            case "ui.BaseUI.displayDialog":
                created++;
                var descriptors:Array<Dynamic> = args[2];
                var dialog:Dynamic = {allocated:true, message:args[1], descriptors:descriptors,
                    buttons:[for (_ in descriptors) {text:""}], confirm:args[3]};
                (cast ui.windows:Array<Dynamic>).push(dialog); latest = dialog; return dialog;
            case "ui.BaseUI.removeWindow":
                if (args[0].allocated != true) throw "Dialog removed twice";
                removed++; args[0].allocated = false; (cast ui.windows:Array<Dynamic>).remove(args[0]);
            case "ui.comp.Button.setText": object.text = args[0];
            default: throw "Unexpected dialog call: " + type + "." + name;
        }
        return null;
    }
}
