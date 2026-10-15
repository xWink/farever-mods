package hlx.runtime;
class Registry {
    static final values:Map<String, Dynamic> = [];
    public static function get(bucket:String, key:String):Dynamic return values[bucket + "/" + key];
    public static function register(bucket:String, key:String, value:Dynamic):Void values[bucket + "/" + key] = value;
    public static function unregister(bucket:String, key:String):Void { values.remove(bucket + "/" + key); }
}
