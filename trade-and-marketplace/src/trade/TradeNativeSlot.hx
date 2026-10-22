package trade;

import trade.GameAccess as G;
import trade.TradeTypes;
import trade.TradeUi.*;

/**
 * Read-only use of the game's exact ItemSlot frame and rarity background.
 * The original item and its inventory are never moved or exposed to DOMKit.
 * Passing no stack builds a native rarity frame without its clickable item
 * button, quantity label, transfer or inventory controls. Artwork and actions
 * are owned by the marketplace/trade UI above this decorative frame.
 */
class TradeNativeSlot {
    public static function background(parent:Dynamic,offer:TradeItem,x:Int,y:Int,sizePx:Int,?actualItem:Dynamic):Bool {
        if(parent==null||offer==null)return false;
        var item=actualItem;
        if(item==null)try item=TradeTooltips.previewItem(offer) catch(_:Dynamic){}
        var inf=G.field(item,"inf");
        if(inf==null)return false;
        var slot:Dynamic=null;
        try {
            slot=G.field(node("item-slot",G.field(parent,"dom"),[null,inf],"tradeNativeRarityFrame"),"obj");
            if(slot==null)return false;
            absolute(parent,slot);padding(slot,0);size(slot,sizePx,sizePx);position(slot,x,y);
            var inner=G.field(slot,"innerSlot");
            if(inner!=null){
                absolute(slot,inner);padding(inner,0);size(inner,sizePx,sizePx);position(inner,0,0);
            }
            // This is a decorative frame. Leave all trade drag/click/tooltip
            // handling with the already-tested marketplace row or trade slot.
            G.call("h2d.Flow","set_enableInteractive",slot,[false]);
            G.call("ui.UIElement","set_padFocusable",slot,[false]);
            return true;
        } catch(_:Dynamic) {
            if(slot!=null)try G.call("h2d.Object","remove",slot) catch(_:Dynamic){}
            return false;
        }
    }
}
