import marketplace.MarketController;
import marketplace.MarketWindow;
import marketplace.MarketExport;
import marketplace.MarketQuantity;
import trade.GameAccess as G;

class MarketplacePricingUiTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace pricing UI assertion "+checks;}
    static function button(text:String):Dynamic return G.buttons.filter(b->b.text==text)[0];
    static function input(y:Int):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput")&&n.x==754&&n.y==y)[0];
    static function change(box:Dynamic,text:String):Void {box.input.text=text;box.onChange();}
    static function total():Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketOrderTotal"))[0];
    static function showsTotal(trays:String,gold:String):Bool {
        var box=total(),content=box.children.filter(n->StringTools.startsWith(Std.string(n.id),"marketMoney"))[0].children.filter(n->StringTools.startsWith(Std.string(n.id),"marketMoneyContent"))[0];
        return box.visible&&G.labels.filter(l->l.parent==content&&l.text==trays).length==1
            &&G.labels.filter(l->l.parent==content&&l.text==gold).length==1;
    }
    public static function run(example:Dynamic):Void {
        check(MarketQuantity.totalPrice("12","7")==84);
        check(MarketQuantity.totalPrice("10000","20")==200000);
        for(pair in [["10000","21"],["2","200000"],["","1"],["1",""],["0","5"],
            ["10001","1"],["4294967297","1"],["1","99999999999999999999"],["1","1.5"]])
            check(MarketQuantity.totalPrice(pair[0],pair[1])==null);
        var c=new MarketController();c.tab="Sell";c.chosen=MarketExport.offer(example);c.availableQuantity=10000;
        var view=new MarketWindow(c);c.view=view;view.open();view.update();
        var priceLabel:Dynamic=G.labels.filter(l->l.text=="Per unit price")[0];
        check(priceLabel!=null&&priceLabel.y>button("Buyout").y+G.number(button("Buyout").height,36)&&priceLabel.y<input(676).y);
        var quantity=input(536),price=input(676),submit=button("List item for sale");
        change(quantity,"12");change(price,"7");
        check(showsTotal("84","42,000")&&submit.enable&&!view.dirty);
        submit.action();check(c.listedOrder.quantity==12&&c.listedOrder.trays==84&&!c.listedOrder.offers);
        change(quantity,"3");check(showsTotal("21","10,500"));
        button("+10").action();check(price.input.text=="17"&&showsTotal("51","25,500"));
        submit.action();check(c.listedOrder.quantity==3&&c.listedOrder.trays==51);
        var sent=c.sellSubmissions;
        change(price,"");check(!submit.enable&&!total().visible);submit.action();check(c.sellSubmissions==sent);
        change(price,"200000");check(!submit.enable&&!total().visible);
        check(G.labels.filter(l->l.text=="Total limit: 200,000 Silver Trays"&&l.visible).length==1);
        submit.action();check(c.sellSubmissions==sent);
        change(quantity,"1");check(submit.enable&&showsTotal("200,000","100,000,000"));
        submit.action();check(c.listedOrder.trays==200000);
        change(quantity,"10000");button("Open to offers").action();view.update();
        check(total()==null&&button("List item for sale").enable);
        button("List item for sale").action();check(c.listedOrder.quantity==10000&&c.listedOrder.offers&&c.listedOrder.trays==0);
        button("Buyout").action();view.update();check(!button("List item for sale").enable);
        change(input(676),"20");check(showsTotal("200,000","100,000,000"));
        view.close();Sys.println("Marketplace pricing UI checks passed: "+checks);
    }
}
