package marketplace;

import trade.GameAccess as G;
import trade.TradeUi.*;

/**
 * Rounded native-colour skin for a native scrolling viewport.
 *
 * The older, visible scrollbar used h2d.Graphics too, but inserted drawings
 * into native scrollBar/scrollBarCursor Flow children and changed their reflow
 * callbacks. That can corrupt their layout arrays or crash the renderer.
 *
 * This is a plain non-interactive sibling of the viewport. The game still
 * owns the real scrollbar, wheel, track clicks, dragging and thumb geometry.
 */
class MarketScrollbar {
    public final paint:Dynamic;
    var viewport:Dynamic;
    var content:Dynamic;
    var lastX=-1.0;
    var lastY=-1.0;
    var lastWidth=-1.0;
    var lastHeight=-1.0;
    var lastThumbHeight=-1.0;
    var lastThumbY=-1.0;

    public function new(root:Dynamic) {
        paint=trade.TradeFrame.graphic(root);
        G.call("h2d.Object","set_visible",paint,[false]);
    }

    public function attachedTo(root:Dynamic):Bool return G.field(paint,"parent")==root;
    public function owns(child:Dynamic):Bool return child==paint;

    public function bind(viewport:Dynamic,content:Dynamic):Void {
        this.viewport=viewport;
        this.content=content;
        // The skin survives refreshes, but the list card and viewport are new
        // siblings. Put it above them again so their backgrounds cannot hide it.
        // Object.addChild dispatches through Flow.addChildAt, preserving its
        // layout properties; leave the native scrollbar's children untouched.
        var root=G.field(viewport,"parent");
        if(root!=null){G.call("h2d.Object","addChild",root,[paint]);absolute(root,paint);}
        // A rebuilt Flow can report a different thumb size at the same scroll
        // position. Invalidate the skin, not the game's scrollbar.
        lastHeight=-1;
    }

    public function update():Void {
        if(viewport==null||content==null){G.call("h2d.Object","set_visible",paint,[false]);return;}
        var bar=G.field(viewport,"scrollBar"),cursor=G.field(viewport,"scrollBarCursor");
        if(bar==null||cursor==null){G.call("h2d.Object","set_visible",paint,[false]);return;}
        // Public Flow getters measure actual sizes. The private calculatedHeight
        // field returns null via HLX reflection, which led to misleading 0x0 logs.
        var height=G.number(G.call("h2d.Flow","get_outerHeight",viewport,[]));
        var contentHeight=G.number(G.call("h2d.Flow","get_outerHeight",content,[]));
        if(height<=0||contentHeight<=height||G.field(bar,"visible")==false) {
            G.call("h2d.Object","set_visible",paint,[false]);
            return;
        }

        var width=G.number(G.call("h2d.Flow","get_outerWidth",bar,[]),10);
        if(width<=0)width=10;
        var x=G.number(G.field(viewport,"x"))+G.number(G.field(bar,"x"));
        var y=G.number(G.field(viewport,"y"))+G.number(G.field(bar,"y"));
        var thumbHeight=G.number(G.call("h2d.Flow","get_outerHeight",cursor,[]));
        if(thumbHeight<=0||thumbHeight>height)
            thumbHeight=Math.max(1,Math.floor(height*height/contentHeight));
        var scroll=G.number(G.field(viewport,"scrollPosY"));
        var travel=Math.max(0,height-thumbHeight);
        var thumbY=Math.round(travel*Math.max(0,Math.min(1,scroll/(contentHeight-height))));

        G.call("h2d.Object","set_visible",paint,[true]);
        if(x!=lastX||y!=lastY)position(paint,x,y);
        if(x!=lastX||y!=lastY||width!=lastWidth||height!=lastHeight
            ||thumbHeight!=lastThumbHeight||thumbY!=lastThumbY) {
            G.call("h2d.Graphics","clear",paint);
            // Opaque backing masks any invisible/rectangular native background,
            // while keeping the same paper colour as the Sell inventory card.
            trade.TradeFrame.rounded(paint,0,0,width,height,0,0xEFE3D1);
            trade.TradeFrame.rounded(paint,0,0,width,height,width/2,0xB69B7F,0.60);
            trade.TradeFrame.rounded(paint,0,thumbY,width,thumbHeight,width/2,0x806B5B);
            lastX=x;lastY=y;lastWidth=width;lastHeight=height;
            lastThumbHeight=thumbHeight;lastThumbY=thumbY;
        }
    }
}
