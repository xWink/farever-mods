package dpsmeter;
class NativeUi {
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var object:Dynamic = {width:0, height:0, properties:{}}; parent.obj.content = object; return {obj:object};
    }
    public static function padding(object:Dynamic, value:Int):Void {}
    public static function style(object:Dynamic, name:String, value:Dynamic):Void {}
    public static function size(object:Dynamic, width:Int, height = -1):Void { object.width = width; if (height >= 0) object.height = height; }
    public static function absolute(parent:Dynamic, object:Dynamic):Void { object.absolute = true; }
    public static function show(object:Dynamic, visible:Bool):Void { object.visible = visible; }
    public static function position(object:Dynamic, x:Float, y:Float):Void { object.x = x; object.y = y; }
}
