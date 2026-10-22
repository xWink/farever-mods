package trade;

import trade.GameAccess as G;
import trade.TradeTypes;
import trade.TradeUi.*;

/**
 * Read-only use of the game's exact ItemSlot frame and rarity background.
 * The original item and its inventory are never moved or exposed to DOMKit.
 * Passing no stack builds the game's native rarity frame AND artwork without
 * a clickable inventory button, item count, transfer, or drag controls.
 * Never draw a second icon over it. Its natural size is 58px: apply one
 * proportional scene-graph scale to keep both art and frame inside the
 * requested 44px / 60px / 80px bounds rather than fighting native CSS sizes.
 */
class TradeNativeSlot {
    static inline var NATIVE_SIZE=58;
    static var idSequence=0;
    public static function background(parent:Dynamic,offer:TradeItem,x:Int,y:Int,sizePx:Int,?actualItem:Dynamic):Bool {
        if(parent==null||offer==null)return false;
        var item=actualItem;
        if(item==null)try item=TradeTooltips.previewItem(offer) catch(_:Dynamic){}
        var inf=G.field(item,"inf");
        if(inf==null)return false;
        var slot:Dynamic=null;
        try {
            slot=G.field(node("item-slot",G.field(parent,"dom"),[null,inf],
                "tradeNativeRarityFrame"+(++idSequence)),"obj");
            if(slot==null)return false;
            absolute(parent,slot);padding(slot,0);
            // ItemSlot's native art and bevel have a natural 58px footprint.
            // Set the full frame to that size, then scale it *as a unit*.
            // Forcing the CSS box to 44px left the game's inner 58px icon
            // overhanging the row and overlapping the item-name label.
            size(slot,NATIVE_SIZE,NATIVE_SIZE);
            var inner=G.field(slot,"innerSlot");
            if(inner!=null) {
                absolute(slot,inner);padding(inner,0);
                size(inner,NATIVE_SIZE,NATIVE_SIZE);position(inner,0,0);
            }
            position(slot,x,y);
            G.call("h2d.Object","setScale",slot,[sizePx/(NATIVE_SIZE*1.0)]);
            // This is a decorative frame. Leave all trade drag/click/tooltip
            // handling with the already-tested marketplace row or trade slot.
            G.call("h2d.Flow","set_enableInteractive",slot,[false]);
            G.call("ui.UIElement","set_padFocusable",slot,[false]);
            var button=G.field(slot,"button");
            if(button!=null) {
                // Defensive: some native skins can instantiate an item button
                // even for null stacks. Don't let it swallow row clicks.
                G.call("h2d.Flow","set_enableInteractive",button,[false]);
                G.call("ui.UIElement","set_padFocusable",button,[false]);
            }
            return true;
        } catch(_:Dynamic) {
            if(slot!=null)try G.call("h2d.Object","remove",slot) catch(_:Dynamic){}
            return false;
        }
    }
}
