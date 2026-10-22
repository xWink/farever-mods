package trade;

import trade.GameAccess as G;
import trade.TradeTypes;
import trade.TradeUi.*;

/**
 * Read-only use of the game's exact ItemSlot frame and rarity background.
 * The original item and its inventory are never moved or exposed to DOMKit.
 * A detached one-item display stack lets the game's ItemSlot build its
 * native icon mask. The previous null-stack approach omitted that mask,
 * allowing item art to protrude over the bevel/border.
 * No inventory references or native transfer actions are ever attached.
 * Scale the full 58px native component into the desired display rectangle.
 */
class TradeNativeSlot {
    static inline var NATIVE_SIZE=58;
    public static inline var MARKET_ART_SCALE=0.82;
    static var idSequence=0;
    /** Leave the native rarity frame and clip size intact; inset only item art. */
    public static function insetMarketplaceArtwork(button:Dynamic,maskSize:Int):Void {
        if(button==null)return;
        // An inline Float constant can be boxed as Int(0) when forwarded
        // through Array<Dynamic> in compiled HashLink. Derive the displayed
        // size in whole pixels, then divide by a Float just as the native
        // slot frame does. The 52px mask contains a centered 43px button.
        var artPixels:Int=Std.int(Math.round(maskSize*MARKET_ART_SCALE));
        var nativeSize:Float=maskSize;
        var scale:Float=artPixels/nativeSize;
        var inset:Int=Std.int(Math.round((maskSize-artPixels)/2.0));
        // Keep the fraction in native transform fields; the game instance
        // holds its scale in Float fields, read via reflection across modules.
        G.set(button,"scaleX",scale);
        G.set(button,"scaleY",scale);
        position(button,inset,inset);
    }
    public static function background(parent:Dynamic,offer:TradeItem,x:Int,y:Int,sizePx:Int,
        ?actualItem:Dynamic,marketplaceArtwork=false):Bool {
        if(parent==null||offer==null)return false;
        var item=actualItem;
        if(item==null)try item=TradeTooltips.previewItem(offer) catch(_:Dynamic){}
        var inf=G.field(item,"inf");
        if(inf==null)return false;
        var slot:Dynamic=null;
        try {
            // Match the working Sell-grid ItemSlot path: constructing with
            // an item stack creates the native masked ItemButton child.
            // The item is detached, never part of any player's inventory.
            var previewStack:Dynamic={count:1,item:item};
            slot=G.field(node("item-slot",G.field(parent,"dom"),[previewStack,inf],
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
            // Keep this division typed as Float across both interpreter and
            // HashLink compilation: int-typed constant folding produced 0 for
            // 44/58 in the compiled UI test.
            var nativeSize:Float=NATIVE_SIZE;
            var scale:Float=sizePx/nativeSize;
            G.call("h2d.Object","setScale",slot,[scale]);
            var button=G.field(slot,"button");
            if(button==null)throw "Native ItemSlot did not create its masked item button";
            var mask=G.field(button,"parent");
            if(mask==null||inner==null)throw "Native ItemSlot item mask unavailable";
            // Keep the original native rarity frame visible above the inset
            // artwork. Only the inside 52x52 px of the 58px base is drawable
            // by the ItemButton; the weapon cannot spill over its border.
            absolute(inner,mask);position(mask,3,3);
            G.set(mask,"width",NATIVE_SIZE-6);G.set(mask,"height",NATIVE_SIZE-6);
            style(mask,"width",NATIVE_SIZE-6);style(mask,"height",NATIVE_SIZE-6);
            padding(button,0);size(button,NATIVE_SIZE-6,NATIVE_SIZE-6);position(button,0,0);
            if(marketplaceArtwork)insetMarketplaceArtwork(button,NATIVE_SIZE-6);
            // The marketplace/trade UI owns all interactions and the quantity
            // text. Hide the native duplicate count and all focus/hover states
            // that can apply a bright outline to the decorative slot.
            var nativeCount=G.field(button,"countTxt");
            if(nativeCount!=null)G.call("h2d.Object","set_visible",nativeCount,[false]);
            for(o in [slot,inner,button])
                G.call("h2d.Flow","set_enableInteractive",o,[false]);
            // ItemSlot and ItemButton are UIElements. innerSlot may be a plain
            // Flow on some game builds: never send it a UIElement-only method.
            for(o in [slot,button])G.call("ui.UIElement","set_padFocusable",o,[false]);
            G.call("ui.UIElement","set_selected",slot,[false]);
            return true;
        } catch(_:Dynamic) {
            if(slot!=null)try G.call("h2d.Object","remove",slot) catch(_:Dynamic){}
            return false;
        }
    }
}
