package hlx.runtime;
class Bus {
    static var handlers:Map<String,Dynamic->Void>=[];
    public static function subscribe(topic:String,callback:Dynamic->Void):Void handlers[topic]=callback;
    public static function publish(topic:String,data:Dynamic):Void {if(handlers.exists(topic))handlers[topic](data);}
}
