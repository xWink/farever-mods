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
    static function preview():Dynamic return G.labels.filter(l->StringTools.startsWith(l.text,"Per unit:"))[0];
    static function showsUnit(gold:String):Bool return preview()!=null&&preview().text=="Per unit: "+gold+" gold";
    static function currencyControls():Void {
        var label:Dynamic=G.labels.filter(l->l.text=="Silver Trays")[0];
        check(label!=null&&label.x==978&&label.y==682);
        check((cast label.parent.children:Array<Dynamic>).filter(n->G.field(n,"nativeType")=="h2d.Bitmap"&&n.x==950&&n.y==684).length==1);
        check(button("+1")!=null&&button("-1")!=null&&button("+10")!=null&&button("-10")!=null);
    }
    public static function run(example:Dynamic):Void {
        check(MarketQuantity.totalPrice("12","7")==7);
        check(MarketQuantity.totalPrice("10000","200000")==200000);
        check(MarketQuantity.totalPrice("10000","1")==1);
        for(pair in [["","1"],["1",""],["0","5"],["10001","1"],["1","200001"],
            ["4294967297","1"],["1","99999999999999999999"],["1","1.5"]])
            check(MarketQuantity.totalPrice(pair[0],pair[1])==null);
        var c=new MarketController();c.tab="Sell";c.chosen=MarketExport.offer(example);c.availableQuantity=10000;
        var view=new MarketWindow(c);c.view=view;view.open();view.update();
        var priceLabel:Dynamic=G.labels.filter(l->l.text=="Total price")[0];
        check(priceLabel!=null&&priceLabel.y>button("Buyout").y+G.number(button("Buyout").height,36)&&priceLabel.y<input(676).y);
        currencyControls();
        var quantity=input(536),price=input(676),submit=button("List item for sale"),unit=preview();
        change(quantity,"12");change(price,"7");
        check(showsUnit("291.7")&&submit.enable&&!view.dirty&&unit==preview());
        submit.action();check(c.listedOrder.quantity==12&&c.listedOrder.trays==7&&!c.listedOrder.offers);
        change(quantity,"3");check(showsUnit("1,166.7")&&price.input.text=="7");
        button("+10").action();check(price.input.text=="17"&&showsUnit("2,833.3"));
        submit.action();check(c.listedOrder.quantity==3&&c.listedOrder.trays==17);
        var sent=c.sellSubmissions;
        change(price,"");check(!submit.enable&&preview().text=="Per unit: —");submit.action();check(c.sellSubmissions==sent);
        change(price,"200000");check(submit.enable&&showsUnit("33,333,333.3"));
        change(quantity,"1");check(submit.enable&&showsUnit("100,000,000"));submit.action();check(c.listedOrder.trays==200000);
        change(quantity,"10000");change(price,"1");check(showsUnit("0.1")&&submit.enable);
        button("Open to offers").action();view.update();check(preview()==null&&button("List item for sale").enable);
        button("List item for sale").action();check(c.listedOrder.quantity==10000&&c.listedOrder.offers&&c.listedOrder.trays==0);
        button("Buyout").action();view.update();check(button("List item for sale").enable&&input(676).input.text=="1"&&showsUnit("0.1"));
        view.close();

        // Editing both order types uses the same total-price controls and preview.
        for(orderType in ["sell","buy"]) {
            var row:Dynamic=haxe.Json.parse(haxe.Json.stringify(example));row.orderType=orderType;row.item.quantity=5;row.price={mode:"fixed",silverTrays:7};
            c=new MarketController();c.tab="My listings";c.rows=[row];c.selected=row;
            view=new MarketWindow(c);c.view=view;view.open();view.update();button("Edit listing").action();view.update();
            quantity=input(536);price=input(676);submit=button("Save changes");
            check(quantity.input.text=="5"&&price.input.text=="7"&&showsUnit("700"));currencyControls();
            check(G.labels.filter(l->l.text=="Total price"&&l.y==648).length==1&&button("Buyout").y==600);
            change(quantity,"10");check(price.input.text=="7"&&showsUnit("350")&&!view.dirty);
            submit.action();check(c.edited.quantity==10&&c.edited.trays==7&&!c.edited.offers);
            change(price,"");check(!submit.enable&&preview().text=="Per unit: —");var previous=c.edited;
            submit.action();check(c.edited==previous);
            change(price,"9");check(submit.enable&&showsUnit("450"));submit.action();check(c.edited.trays==9);
            change(quantity,"");check(!submit.enable&&preview().text=="Per unit: —");
            change(quantity,"3");button("Open to offers").action();view.update();check(preview()==null&&button("Save changes").enable);
            button("Save changes").action();check(c.edited.quantity==3&&c.edited.offers&&c.edited.trays==0);
            button("Buyout").action();view.update();check(input(676).input.text=="9"&&showsUnit("1,500"));
            button("Cancel").action();check(c.editingListingId=="");view.close();
        }
        Sys.println("Marketplace pricing UI checks passed: "+checks);
    }
}
