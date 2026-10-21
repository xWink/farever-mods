package marketplace;
typedef MarketEvent=Dynamic;
class MarketWorker {
    public static var current:MarketWorker;
    public var sent:Array<Dynamic>=[];
    public var incoming:Array<Dynamic>=[];
    public var generation=0;
    public function new() current=this;
    public function session(account:String,key:String,server=""):Int return ++generation;
    public function cancelPrefetch():Void {}
    public function send(job:Dynamic):Void sent.push(job);
    public function receive():Dynamic return incoming.shift();
}
