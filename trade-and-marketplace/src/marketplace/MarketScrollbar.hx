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
    var hovered=false;
    var paintedHover=false;

    public function new(viewport:Dynamic) {
        track=G.field(viewport,"scrollBar");cursor=G.field(viewport,"scrollBarCursor");
        trackPaint=paintLayer(track);cursorPaint=paintLayer(cursor);
        G.call("ui.UIElement","set_onOver",cursor,[function():Void {hovered=true;}]);
        G.call("ui.UIElement","set_onOut",cursor,[function():Void {hovered=false;}]);
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
        if(w!=cursorWidth||h!=cursorHeight||hovered!=paintedHover) {
            draw(cursorPaint,w,h,hovered?0x5B4334:0x806B5B);cursorWidth=w;cursorHeight=h;paintedHover=hovered;
        }
    }
    static function draw(paint:Dynamic,w:Float,h:Float,color:Int):Void {
        G.call("h2d.Graphics","clear",paint);
        if(w>0&&h>0)trade.TradeFrame.rounded(paint,0,0,w,h,Math.min(w,h)/2,color);
    }
}
