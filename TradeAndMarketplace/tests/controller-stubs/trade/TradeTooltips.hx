package trade;
import trade.TradeTypes;
class TradeTooltips {
    public static var builds = 0;
    public static function previewItem(offer:TradeItem):Dynamic {
        builds++;
        return {kind:offer.kind,maxStack:()->99,canStack:(other:Dynamic)->other.kind == offer.kind};
    }
}
