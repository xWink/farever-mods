package dpsmeter;
class NativeUi {
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var object:Dynamic = {width:0, height:0, properties:{}}; parent.obj.content = object; return {obj:object};
    }
    public static function padding(object:Dynamic, value:Int):Void {}
    public static function style(object:Dynamic, name:String, value:Dynamic):Void {}
    public static function size(object:Dynamic, width:Int, height:Int):Void { object.width = width; object.height = height; }
}
