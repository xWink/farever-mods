package hlx.runtime;
class Registry {
    public static function get(bucket:String,key:String):Dynamic return null;
    public static function register(bucket:String,key:String,value:Dynamic):Void {}
    public static function unregister(bucket:String,key:String):Void {}
}
