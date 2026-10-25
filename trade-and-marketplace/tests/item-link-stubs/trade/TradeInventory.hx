package trade;
import trade.TradeTypes;
class TradeInventory {
    public function new() {}
    public function find(uid:String):Dynamic return null;
    public static function fingerprint(item:Dynamic):String return "";
    public static function definition(kind:String):Dynamic return GameAccess.definitions.get("item:"+kind);
    public static function describe(item:Dynamic,count:Int):TradeItem {
        var offer=ItemLinkTest.fixture();offer.kind=item.kind;offer.count=count;
        offer.name="Épée du test";offer.color=0xAABBCC;
        if(item.preview!=null)offer.preview=item.preview;
        return offer;
    }
}
