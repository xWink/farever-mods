import marketplace.MarketController;
import marketplace.MarketWindow;
import marketplace.MarketDrawer;
import trade.GameAccess as G;
import trade.TradeFrame;
class MarketplaceDrawerTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace drawer assertion "+checks;}
    static function node(prefix:String):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),prefix))[0];
    static function rows():Array<Dynamic> return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketRow"));
    static function finish(view:MarketWindow):Void {
        @:privateAccess view.advanceDetails(view.drawer.started+0.24);
        TradeFrame.latest.layout();
    }
    public static function run(example:Dynamic):Void {
        var tween=new MarketDrawer();tween.set(true,0);tween.update(0.12);
        check(tween.value>0&&tween.value<1);var mid=tween.value;
        tween.set(false,0.12);check(tween.value==mid);tween.update(0.24);check(tween.value<mid&&tween.value>0);
        tween.set(true,0.24);tween.update(0.48);check(tween.value==1);tween.update(100);check(tween.value==1);
        var c=new MarketController(),other=haxe.Json.parse(haxe.Json.stringify(example));other.id="second";
        c.rows=[example,other];c.total=2;
        var view=new MarketWindow(c);c.view=view;
        for(tab in ["Browse","My listings"]) {
            c.tab=tab;c.selected=null;view.open();view.update();
            check(node("marketDetailsDrawer")==null&&G.labels.filter(l->l.text=="ITEM DETAILS").length==0);
            check(node("marketListingViewport").width==1060&&rows()[0].width==1048);
            check(node("marketSortrequired-level").x==788&&node("marketSortprice").x==880);
            rows()[0].action();view.update();
            var panel=node("marketDetailsDrawer"),table=node("marketListingViewport"),originalRows=rows();
            check(c.selected==example&&panel!=null&&panel.x>0&&panel.x<=368);
            var clip:Dynamic=panel.parent;
            check(clip.component=="element"&&clip.overflow=="Hidden"&&clip.parent==TradeFrame.latest.container&&clip.width==1104&&clip.height==888);
            check(clip.x==0&&clip.y==0);
            // The clipping parent must participate in native DOM style inheritance.
            check(G.field(G.field(clip,"dom"),"obj")==clip&&G.field(G.field(panel,"dom"),"obj")==panel&&G.field(clip.parent,"dom")!=null);
            @:privateAccess view.advanceDetails(view.drawer.started+0.12);
            check(panel.parent==clip&&clip.x==0&&clip.y==0&&panel.x+1088>clip.width);
            check(table.width>692&&table.width<1060&&panel.x>0&&panel.x<368);
            check(rows()[0]==originalRows[0]&&!view.dirty&&c.refreshes==0);
            finish(view);check(table.width==692&&panel.x==0&&rows()[0].width==680);
            var detail=node("marketDetailViewport"),back:Dynamic=null;
            for(child in (cast panel.children:Array<Dynamic>))if(child.shapes!=null)
                for(shape in (cast child.shapes:Array<Dynamic>))if(shape.color==0x4A423C&&shape.alpha==1)back=shape;
            check(back!=null&&back.x-736==18&&1088-back.x-back.width==18);
            check(detail.x==back.x+8&&detail.x+detail.width==back.x+back.width-8);
            if(tab=="Browse") {
                var action=G.buttons.filter(b->b.text=="Whisper seller"||b.text=="Your listing")[0];
                check(action.y-(back.y+back.height)==806-(action.y+36));
            }
            check(table.overflow=="Hidden");
            rows()[1].action();view.update();
            table=node("marketListingViewport");
            check(c.selected==other&&node("marketDetailsDrawer").x==0&&table.overflow=="Hidden");
            rows()[1].action();view.update();check(c.selected==null&&node("marketDetailsDrawer")!=null);
            var closing=node("marketDetailsDrawer"),closingMask=closing.parent;
            finish(view);check(node("marketDetailsDrawer")==null&&G.removed.indexOf(closing)>=0);
            check(G.removed.indexOf(closingMask)>=0);
            check(node("marketListingViewport").width==1060&&rows()[0].width==1048&&c.refreshes==0);
            view.close();
        }
        c.tab="Sell";c.chosen=marketplace.MarketExport.offer(example);view.open();view.update();
        check(node("marketDetailsDrawer")==null&&G.labels.filter(l->l.text=="ITEM DETAILS").length==1);
        var panel=node("marketDetailViewport"),dark:Dynamic=null;
        for(child in (cast TradeFrame.latest.container.children:Array<Dynamic>))if(child.shapes!=null)
            for(shape in (cast child.shapes:Array<Dynamic>))if(shape.color==0x4A423C&&shape.alpha==1)dark=shape;
        check(dark.x==754&&dark.width==316&&panel.x==762);
        view.close();check(TradeFrame.active==0);
        Sys.println("Marketplace drawer checks passed: "+checks);
    }
}
