package marketplace;

import trade.GameAccess as G;
import trade.TradeUi.*;

/**
 * Paints a rounded scrollbar ABOVE the Sell grid without changing the native
 * scrollbar or cursor at all. Heaps/UIElement owns the backgrounds, event
 * handlers, scroll calculations and Flow child/property arrays.
 */
class MarketScrollbar {
    final viewport:Dynamic;
    final track:Dynamic;
    final cursor:Dynamic;
    final trackPaint:Dynamic;
    final cursorPaint:Dynamic;
    var trackWidth=-1.0;
    var trackHeight=-1.0;
    var cursorWidth=-1.0;
    var cursorHeight=-1.0;
    var frames=0;
    var reportedReady=false;

    public function new(root:Dynamic, viewport:Dynamic) {
        this.viewport=viewport;
        track=G.field(viewport,"scrollBar");
        cursor=G.field(viewport,"scrollBarCursor");
        if(track==null||cursor==null)throw "Native Sell scrollbar was not created by Flow";
        // Graphics are siblings of the viewport. NEVER clear a native background,
        // hide/reparent its children or install a reflow/hover callback on it.
        trackPaint=G.create("h2d.Graphics",[root]);
        absolute(root,trackPaint);
        cursorPaint=G.create("h2d.Graphics",[root]);
        absolute(root,cursorPaint);
        trade.TradeDiagnostics.log("Marketplace Sell scrollbar initialized (native untouched): track="
            +G.typeName(track)+", cursor="+G.typeName(cursor));
    }

    public function owns(child:Dynamic):Bool return child==trackPaint||child==cursorPaint;

    public function update():Void {
        frames++;
        var w=G.number(G.field(track,"calculatedWidth"));
        var h=G.number(G.field(track,"calculatedHeight"));
        var cw=G.number(G.field(cursor,"calculatedWidth"));
        var ch=G.number(G.field(cursor,"calculatedHeight"));
        var visible=G.field(track,"visible")!=false;
        var ready=visible&&w>0&&h>0&&cw>0&&ch>0;
        // The initial 0x0 values are normal before Heaps' first scene reflow.
        // Log the first MEASURED geometry, or a bounded diagnostic if absent.
        if(ready&&!reportedReady) {
            reportedReady=true;
            trade.TradeDiagnostics.log("Marketplace Sell scrollbar measured after "+frames
                +" updates: track="+w+"x"+h+", cursor="+cw+"x"+ch);
        } else if(!ready&&frames==60) {
            trade.TradeDiagnostics.log("Marketplace Sell scrollbar still awaiting native layout after 60 updates:"
                +" visible="+visible+", track="+w+"x"+h+", cursor="+cw+"x"+ch
                +", viewport="+G.number(G.field(viewport,"calculatedWidth"))+"x"
                +G.number(G.field(viewport,"calculatedHeight")));
        }
        show(trackPaint,ready);
        show(cursorPaint,ready);
        if(!ready)return;

        var x=G.number(G.field(viewport,"x"))+G.number(G.field(track,"x"));
        var y=G.number(G.field(viewport,"y"))+G.number(G.field(track,"y"));
        position(trackPaint,x,y);
        position(cursorPaint,x+G.number(G.field(cursor,"x")),y+G.number(G.field(cursor,"y")));

        if(w!=trackWidth||h!=trackHeight) {
            G.call("h2d.Graphics","clear",trackPaint);
            // Hide the native rectangular corners with the surrounding Sell
            // panel colour, then draw a rounded track over them.
            trade.TradeFrame.rounded(trackPaint,0,0,w,h,0,0xEFE3D1);
            trade.TradeFrame.rounded(trackPaint,0,0,w,h,Math.min(w,h)/2,0xB69B7F);
            trackWidth=w;trackHeight=h;
        }
        if(cw!=cursorWidth||ch!=cursorHeight) {
            G.call("h2d.Graphics","clear",cursorPaint);
            trade.TradeFrame.rounded(cursorPaint,0,0,cw,ch,0,0xB69B7F);
            trade.TradeFrame.rounded(cursorPaint,0,0,cw,ch,Math.min(cw,ch)/2,0x806B5B);
            cursorWidth=cw;cursorHeight=ch;
        }
    }
}
