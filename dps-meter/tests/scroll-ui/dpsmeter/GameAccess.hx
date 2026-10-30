package dpsmeter;
class GameAccess {
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function number(value:Dynamic, fallback = 0.0):Float return value == null ? fallback : value;
    public static function enumeration(type:String, name:String):Dynamic return name;
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        switch(type + "." + name) {
            case "h2d.Flow.get_innerHeight": return object.innerHeight;
            case "h2d.Flow.getProperties": return args[0].properties;
            case "h2d.FlowProperties.set_isAbsolute": object.isAbsolute = args[0];
            case "h2d.Flow.set_verticalAlign", "h2d.Flow.set_horizontalAlign":
            case "h2d.Flow.set_needReflow": object.needReflow = args[0];
            case "h2d.Flow.set_scrollPosY":
                var value:Float = args[0], height:Float = object.content.height, viewport:Float = object.innerHeight;
                object.scrollPosY = Math.max(0, Math.min(value, Math.max(0, height - viewport)));
            default: throw "Unexpected scroll UI call " + type + "." + name;
        }
        return null;
    }
}
