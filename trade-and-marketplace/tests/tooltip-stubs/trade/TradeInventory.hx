package trade;

class TradeInventory {
    public var actual:Dynamic;
    public function new(actual:Dynamic) this.actual = actual;
    public static function definition(kind:String):Dynamic return GameAccess.definitions.get("item:"+kind);
    public static function fingerprint(item:Dynamic):String return item.fingerprint;
    public function find(uid:String):Dynamic return actual == null ? null : {item:actual};
}
