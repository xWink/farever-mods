package hlx.runtime;
class Bus {
    static final handlers:Map<String, Dynamic->Void> = [];
    public static function subscribe(topic:String, handler:Dynamic->Void):Void handlers[topic] = handler;
    public static function publish(topic:String, payload:Dynamic):Void handlers[topic](payload);
}
