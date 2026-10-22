package marketplace;

import trade.GameAccess as G;
import trade.TradeUi.*;

/** Decoration only: native Flow still owns scrolling, dragging and thumb sizing. */
class MarketScrollbar {
    final track:Dynamic;
    final cursor:Dynamic;
    final trackPaint:Dynamic;
    final cursorPaint:Dynamic;
    var trackWidth=-1.0;
    var trackHeight=-1.0;
    var cursorWidth=-1.0;
    var cursorHeight=-1.0;
    var reportedLayout=false;

    public function new(viewport:Dynamic) {
        track=G.field(viewport,"scrollBar");cursor=G.field(viewport,"scrollBarCursor");
        if(track==null||cursor==null)throw "Native Sell scrollbar was not created by Flow";
        trade.TradeDiagnostics.log("Marketplace Sell scrollbar setup: track="+G.typeName(track)+", cursor="+G.typeName(cursor));
        trackPaint=paintLayer(track);
        trade.TradeDiagnostics.log("Marketplace Sell scrollbar setup: track paint attached");
        cursorPaint=paintLayer(cursor);
        trade.TradeDiagnostics.log("Marketplace Sell scrollbar setup: cursor paint attached");
        // Heaps creates both scrollBar and scrollBarCursor as h2d.Flow objects.
        // Calling ui.UIElement.set_onOver/set_onOut on a plain Flow through
        // HashLink reflection is an invalid receiver call and can crash rendering.
        // Keep the native Flow input handlers; decoration is visual only.
    }
    static function paintLayer(parent:Dynamic):Dynamic {
        // A background colour/style must not create a DynamicBackground inside
        // the scrollbar. Clear native fills and draw a plain absolute Graphics.
        style(parent,"background",null);
        G.call("h2d.Flow","set_backgroundTile",parent,[null]);
        var paint=G.create("h2d.Graphics",[null]);
        // Flow's override maintains its parallel child/layout arrays. Calling
        // Object.addChildAt here corrupts the layout when the cursor is reflowed.
        G.call("h2d.Flow","addChildAt",parent,[paint,0]);
        absolute(parent,paint);
        return paint;
    }
    public function update():Void {
        // Read last completed layout without getBounds/getProperties or a
        // reflow callback. Paint only changed geometry, never resize Flow here.
        for(part in [track,cursor]) {
            var bg=G.field(part,"background");
            if(bg!=null&&G.field(bg,"visible")!=false)show(bg,false);
        }
        var w=G.number(G.field(track,"calculatedWidth")),h=G.number(G.field(track,"calculatedHeight"));
        if(w!=trackWidth||h!=trackHeight) {
            draw(trackPaint,w,h,0xB69B7F);trackWidth=w;trackHeight=h;
        }
        w=G.number(G.field(cursor,"calculatedWidth"));h=G.number(G.field(cursor,"calculatedHeight"));
        if(w!=cursorWidth||h!=cursorHeight) {
            draw(cursorPaint,w,h,0x806B5B);cursorWidth=w;cursorHeight=h;
        }
        if(!reportedLayout) {
            reportedLayout=true;
            trade.TradeDiagnostics.log("Marketplace Sell scrollbar first layout: track="+trackWidth+"x"+trackHeight
                +", cursor="+cursorWidth+"x"+cursorHeight);
        }
    }
    static function draw(paint:Dynamic,w:Float,h:Float,color:Int):Void {
        G.call("h2d.Graphics","clear",paint);
        if(w>0&&h>0)trade.TradeFrame.rounded(paint,0,0,w,h,Math.min(w,h)/2,color);
    }
}
