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
            var title:Dynamic=G.labels.filter(l->l.text==prefix+"Order item")[0];
            check(title!=null&&title.textColor==0x5B4334);
            var role:Dynamic=G.labels.filter(l->l.text==owner.toUpperCase())[0];
            var player:Dynamic=G.labels.filter(l->l.parent==role.parent.parent&&l.text==row.seller.characterName)[0];
            check(role!=null&&player!=null&&player.x>role.parent.x+role.parent.width);
            check(role.parent.y+role.parent.height<=24);
            if(tab=="Browse")check(G.buttons.filter(b->b.text=="Whisper "+owner.toLowerCase()).length==1);
            else {
                G.buttons.filter(b->b.text=="Edit listing")[0].action();view.update();
                check(G.labels.filter(l->l.text=="Quantity to "+order).length==1);
                var helper=order=="buy"?"Sellers":"Buyers";
                check(G.labels.filter(l->l.text==helper+" can contact you to agree on a price.").length==1);
                G.buttons.filter(b->b.text=="Cancel")[0].action();view.update();
            }
        }
        // The original prefix and long item name still fit before the level column.
        c.tab="Browse";row.orderType="buy";row.item.name=[for(_ in 0...30)"Long item name"].join(" ");
        view.dirty=true;view.update();@:privateAccess view.advanceDetails(view.drawer.started+1);
        var longTitle:Dynamic=G.labels.filter(l->StringTools.startsWith(l.text,"B> Long item"))[0];
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
