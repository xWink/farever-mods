import marketplace.MarketController;
import marketplace.MarketWindow;
import trade.GameAccess as G;
import trade.TradeFrame;
@:access(marketplace.MarketWindow)
class MarketplaceScrollTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace scroll assertion "+checks;}
    static function node(prefix:String):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),prefix))[0];
    static function rows():Array<Dynamic> return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketRow"));
    static function reflow(view:MarketWindow):Dynamic {
        var viewport=node("marketListingViewport");
        viewport.onAfterReflow();view.update();return viewport;
    }
    public static function run(example:Dynamic):Void {
        for(tab in ["Browse","My listings"]) {
            var c=new MarketController();c.tab=tab;
            c.rows=[for(i in 0...200){var row=haxe.Json.parse(haxe.Json.stringify(example));row.id="row-"+i;row;}];
            c.total=c.rows.length;
            var view=new MarketWindow(c);c.view=view;view.open();view.update();var viewport=reflow(view);
            check(viewport.component=="flow"&&viewport.layout=="Vertical"&&viewport.overflow=="Scroll");
            check(viewport.contentHeight==200*68&&viewport.scrollBar.visible);
            check(rows().length<=12&&rows()[0].y==0&&c.moreRequests==0);
            check(G.buttons.filter(b->b.text=="Previous"||b.text=="Next").length==0);
            viewport.scrollPosY=6800;view.update();
            check(rows()[0].y==98*68&&rows().length<=14);
            var target=rows().filter(r->r.y==100*68)[0];target.action();view.update();viewport=reflow(view);
            check(c.selected==c.rows[100]&&viewport.scrollPosY==6800);
            check(rows().filter(r->r.y==100*68).length==1);
            @:privateAccess view.advanceDetails(view.drawer.started+0.24);TradeFrame.latest.layout();
            check(G.number(rows()[0].x)+G.number(rows()[0].width)<G.number(viewport.scrollBar.x));
            for(i in 0...25){viewport.scrollPosY=i*136;view.update();}
            check(view.rowLayouts.length<=14&&view.rowPresence.length<=14&&view.tableLayouts.length<=20);
            viewport.scrollPosY=6800;view.update();
            var original=c.rows[100];
            c.rows=c.rows.concat([for(i in 0...24)example]);c.total=c.rows.length;view.dirty=true;view.update();viewport=reflow(view);
            check(viewport.scrollPosY==6800&&c.selected==original&&viewport.contentHeight==224*68);
            c.toggleFilters();view.update();viewport=reflow(view);
            check(viewport.scrollPosY==6800&&c.rows.length==224);
            view.close();view.open();view.update();viewport=reflow(view);
            check(viewport.scrollPosY==6800&&c.selected==original);
            viewport.scrollPosY=224*68-viewport.height;view.update();
            check(rows()[rows().length-1].y==223*68);
            if(tab=="Browse") {
                check(c.moreRequests==1&&c.moreLoading&&!c.busy);
                view.update();reflow(view);check(c.moreRequests==1);
                c.moreLoading=false;c.moreFailed=true;view.dirty=true;view.update();reflow(view);
                check(c.moreRequests==1&&c.rows.length==224);
                var retry=G.buttons.filter(b->b.text=="Retry")[0];check(retry!=null);retry.action();
                check(c.moreRequests==2&&c.moreLoading&&!c.moreFailed);
            } else check(c.moreRequests==0);
            // A new query owns a different state object and starts at the top.
            c.scroll={offset:0.0};c.moreLoading=true;c.rows=[example];c.total=1;view.dirty=true;view.update();viewport=reflow(view);
            check(viewport.scrollPosY==0&&rows()[0].y==0);
            view.close();
        }
        check(TradeFrame.active==0);
        Sys.println("Marketplace scroll checks passed: "+checks);
    }
}
