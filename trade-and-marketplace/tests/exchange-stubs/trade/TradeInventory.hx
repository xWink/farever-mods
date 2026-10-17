package trade;
class TradeInventory {
    public var inventory:Dynamic;
    public var hero:Dynamic = {__uid:"hero"};
    public var player:Dynamic = {};
    public var stack:Dynamic;
    public var ground:Array<Dynamic> = [];
    public var counts:Map<String,Int> = [];
    public var requests = 0;
    public var dropAllowed = true;
    public var reply:Bool->Void;
    public function new() {
        inventory = {requestDropIndex:function(index:Int,manual:Bool,count:Int,callback:Bool->Void) { requests++; reply = callback; }};
    }
    public function totals():Map<String,Int> return counts.copy();
    public function find(uid:String):Dynamic return stack;
    public function drops():Array<Dynamic> return ground;
    public function canDrop(s:Dynamic,count:Int):Bool return dropAllowed && s != null && s.count >= count;
    public static function fingerprint(i:Dynamic):String return i.fingerprint;
    public static function distance(a:Dynamic,b:Dynamic):Float return a.distance == null ? 0 : a.distance;
}
