package moresettings;

/** No game reflection is expected in the pipeline return regression. */
class GameAccess {
    public static function field(object:Dynamic, name:String):Dynamic return null;
    public static function call(type:String, name:String, object:Dynamic):Dynamic return null;
}
