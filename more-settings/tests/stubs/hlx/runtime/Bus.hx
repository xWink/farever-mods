package hlx.runtime;

/** Eval stand-in. The real bus is native and cannot be compiled for tests. */
class Bus {
    public static function publish(topic:String, payload:Dynamic):Void {}
    public static function subscribe(topic:String, handler:Dynamic->Void):Void {}
}
