package hlx.runtime;
class Bus {
    public static function subscribe(topic:String,callback:Dynamic->Void):Void {}
    public static function publish(topic:String,data:Dynamic):Void {}
}
