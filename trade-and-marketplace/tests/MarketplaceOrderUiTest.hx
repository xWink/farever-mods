import marketplace.MarketController;
import marketplace.MarketWindow;
import trade.GameAccess as G;
class MarketplaceOrderUiTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace order UI assertion "+checks;}
    public static function run(example:Dynamic):Void {
        var row:Dynamic=haxe.Json.parse(haxe.Json.stringify(example));
        row.item.quantity=1;row.item.name="Order item";row.price={mode:"offers"};
        var c=new MarketController();c.rows=[row];c.selected=row;
        var view=new MarketWindow(c);c.view=view;view.open();
        for(tab in ["Browse","My listings"])for(order in ["sell","buy"]) {
            c.tab=tab;row.orderType=order;view.dirty=true;view.update();
            var prefix=order=="buy"?"B> ":"S> ",owner=order=="buy"?"Buyer":"Seller";
            var marker:Dynamic=G.labels.filter(l->l.text==prefix)[0];
            var title:Dynamic=G.labels.filter(l->l.text=="Order item"&&l.parent==marker.parent)[0];
            check(marker!=null&&title!=null&&marker.textColor!=title.textColor);
            check(title.x>=marker.x+G.number(G.call("h2d.Text","calcTextWidth",marker,[prefix])));
            check(G.labels.filter(l->StringTools.startsWith(l.text,owner+": ")).length==1);
            if(tab=="Browse")check(G.buttons.filter(b->b.text=="Whisper "+owner.toLowerCase()).length==1);
            else {
                G.buttons.filter(b->b.text=="Edit listing")[0].action();view.update();
                check(G.labels.filter(l->l.text=="Quantity to "+order).length==1);
                var helper=order=="buy"?"Sellers":"Buyers";
                check(G.labels.filter(l->l.text==helper+" can contact you to agree on a price.").length==1);
                G.buttons.filter(b->b.text=="Cancel")[0].action();view.update();
            }
        }
        // The colored prefix occupies measured space without pushing a long name into the level column.
        c.tab="Browse";row.orderType="buy";row.item.name=[for(_ in 0...30)"Long item name"].join(" ");
        view.dirty=true;view.update();@:privateAccess view.advanceDetails(view.drawer.started+1);
        var prefixLabel:Dynamic=G.labels.filter(l->l.text=="B> ")[0];
        var longTitle:Dynamic=G.labels.filter(l->l.parent==prefixLabel.parent&&StringTools.startsWith(l.text,"Long item"))[0];
        check(StringTools.endsWith(longTitle.text,"…"));
        check(longTitle.x+G.number(G.call("h2d.Text","calcTextWidth",longTitle,[longTitle.text]))<=392);
        row.item.name="Order item";
        c.tab="Browse";row.orderType="buy";row.item.category="Weapon";row.item.native.level=0;
        Reflect.deleteField(row.item,"requiredLevel");view.dirty=true;view.update();
        check(G.labels.filter(l->l.text=="Any").length==1&&G.labels.filter(l->l.text=="Any level").length==1);
        row.orderType="sell";view.dirty=true;view.update();
        check(G.labels.filter(l->l.text=="Any"||l.text=="Any level").length==0);
        view.close();Sys.println("Marketplace order UI checks passed: "+checks);
    }
}
