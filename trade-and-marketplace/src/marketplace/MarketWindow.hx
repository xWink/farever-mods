package marketplace;
import trade.GameAccess as G;
import trade.TradeUi.*;
import trade.TradeFrame.*;
import trade.TradeTypes;
import trade.TradeInventory;
import trade.TradeTooltips;
import fareverly.Protocol;
class MarketWindow {
    final c:MarketController;
    var frame:trade.TradeFrame;
    var controls:Array<Dynamic>=[];
    var sequence=0;
    var shown=false;
    var px:Null<Float>;
    var py:Null<Float>;
    var quantity="1";
    var trays="1";
    var offers=false;
    public var dirty=true;
    public function new(controller:MarketController)c=controller;
    public function open():Void {shown=true;dirty=true;}
    public function close():Void {
        shown=false;closeDropdowns();
        if(frame!=null){px=frame.x;py=frame.y;frame.dispose();frame=null;}
    }
    public function closeFromBack(window:Dynamic):Bool {if(frame==null||frame.window!=window)return false;close();return true;}
    public function update():Void {
        if(!shown)return;
        if(frame!=null&&!frame.intact()){close();return;}
        if(frame==null){
            var ui=G.current("ui.BaseUI","current");if(ui==null)return;
            frame=new trade.TradeFrame(ui,"Trade and Marketplace",1060,840,close);frame.x=px;frame.y=py;
            frame.onMoved=(x,y)->{px=x;py=y;};dirty=true;
        }
        if(dirty){dirty=false;render();}
        frame.layout();
    }
    function closeDropdowns():Void {for(control in controls)try G.call("ui.comp.Dropdown","close",control,[null])catch(_:Dynamic){} controls=[];}
    function render():Void {
        closeDropdowns();for(child in children(frame.container))G.call("h2d.Object","remove",child);
        var root=frame.container;
        for(i in 0...3){var title=["Browse","Sell an item","My listings"][i];button(title,14+i*190,12,180,()->c.chooseTab(title),c.tab==title?"unaccept":"");}
        button(c.signingIn?"Cancel sign-in":c.ready?"Connected to Steam":"Sign in with Steam",780,12,246,()->{if(c.signingIn)c.cancelSignIn();else if(!c.ready)c.signIn();},c.ready?"accept":"");
        textAt(root,"Server: "+(c.server==""?"Unavailable":c.server)+"  |  Listings last 3 days  |  10 active listings per account",18,58,1000);
        if(c.tab=="Browse")filters();
        else textAt(root,c.tab=="Sell an item"?"Choose an unlocked, tradable item from your backpack. Items remain in your inventory until traded.":"Edit the price, mark sold, or remove an active listing. Changing the price does not extend its expiry.",18,98,995);
        var bg=graphic(root);rounded(bg,12,252,640,446,7,0xE8DAC7);rounded(bg,664,252,366,446,7,0xE8DAC7);
        textAt(root,c.tab=="Sell an item"?"Backpack":"Item",26,226,380,true);textAt(root,c.tab=="Sell an item"?"Quantity":"Total price / Seller",422,226,220,true);
        if(c.tab=="Sell an item"){
            var start=(c.page-1)*12;
            for(i in 0...12)if(start+i<c.inventory.length){var item=c.inventory[start+i];row(item,260+i*36,item.count+" available",()->{c.chosen=item;quantity=Std.string(item.count);dirty=true;},c.chosen==item);}
            sellPanel();
        }else{
            for(i in 0...c.rows.length){var listing=c.rows[i],item:TradeItem=null;try item=MarketExport.offer(listing)catch(_:Dynamic){}
                if(item!=null)row(item,260+i*36,(listing.price.mode=="offers"?"Open to offers":listing.price.silverTrays+" trays")+" · "+listing.seller.characterName,
                    ()->{c.selected=listing;offers=listing.price.mode=="offers";trays=Std.string(offers?1:listing.price.silverTrays);dirty=true;},c.selected==listing);}
            listingPanel();
        }
        if(c.total==0)textAt(root,c.busy?"Loading...":c.tab=="Sell an item"?"No tradable items in your backpack.":"No matching listings.",30,285,585);
        button("Previous",14,710,126,()->{if(!c.busy&&c.page>1){c.page--;c.refresh();}},"");textAt(root,"Page "+c.page+(c.tab=="Sell an item"?" of "+c.pages:"")+"  ·  "+c.total+(c.tab=="Sell an item"?" items":" shown"),156,720,310);
        button("Next",460,710,96,()->{if(!c.busy&&c.page<c.pages){c.page++;c.refresh();}},"");button(c.busy?"Loading...":"Refresh",566,710,110,c.refresh,"");
        var status=textAt(root,c.message,18,754,1000);ink(status,0x5B4334);
    }
    function button(label:String,x:Int,y:Int,width:Int,action:Void->Void,kind:String):Dynamic {var obj=frame.button(label,x,y,width,action,kind);if(c.busy)G.call("ui.UIElement","set_enable",obj,[false]);return obj;}
    function input(value:String,x:Int,y:Int,width:Int,changed:String->Void):Dynamic {
        var root=frame.container,box=G.field(node("input-box",G.field(root,"dom"),[],"marketInput"+(sequence++)),"obj");
        absolute(root,box);size(box,width,32);position(box,x,y);var input=G.field(box,"input");G.call("h2d.TextInput","set_text",input,[value]);style(input,"width",width-18);style(input,"color",0xF5F0E8);
        G.set(box,"onChange",()->changed(G.text(G.field(input,"text"))));return box;
    }
    function dropdown(label:String,values:Array<String>,labels:Array<String>,selected:String,x:Int,y:Int,width:Int,changed:String->Void):Void {
        var root=frame.container;textAt(root,label,x,y-20,width);
        var control=G.field(node("dropdown",G.field(root,"dom"),[false,false,"options-dropdown-list"],"marketSelect"+(sequence++)),"obj");absolute(root,control);size(control,width,32);position(control,x,y);
        var options=G.call("hl.types.ArrayObj","slice",G.field(control,"items"),[0,0]);for(i in 0...values.length)G.call("hl.types.ArrayObj","pushDyn",options,[{name:labels[i],value:i,icon:null,group:null}]);
        G.call("ui.comp.Dropdown","set_options",control,[options]);G.call("ui.comp.Dropdown","initSelectedIndex",control,[Std.int(Math.max(0,values.indexOf(selected)))]);
        G.set(control,"onSelectOption",(_:Dynamic)->{var i=G.integer(G.field(control,"selectedIndex"),-1);if(i>=0&&i<values.length)changed(values[i]);});controls.push(control);
    }
    function filter(key:String,value:String):Void {
        if(c.busy)return;c.filters[key]=value;c.page=1;if(key=="category"){c.filters["subcategory"]="";if(value!="Equipment"&&value!="")c.filters["classes"]="";}c.refresh();dirty=true;
    }
    function filters():Void {
        var f=c.filters;textAt(frame.container,"Find an item",18,88,250);input(f["search"],18,108,270,s->f["search"]=s.substr(0,100));button("Search",298,108,92,()->filter("search",f["search"]),"");
        var cats=["","Components","Equipment","Consumables","Collections","Containers","Miscellaneous"];
        dropdown("Category",cats,["All items"].concat(cats.slice(1)),f["category"],404,108,204,s->filter("category",s));
        var subs=[""].concat(subcategories(f["category"]));dropdown("Subcategory",subs,["All subcategories"].concat(subs.slice(1)),f["subcategory"],622,108,220,s->filter("subcategory",s));
        var rarities=["","Common","Uncommon","Rare","Epic","Legendary"];dropdown("Rarity",rarities,["All rarities"].concat(rarities.slice(1)),f["rarity"],856,108,170,s->filter("rarity",s));
        dropdown("Pricing",["","fixed","offers"],["All pricing","Fixed price","Open to offers"],f["pricing"],18,169,170,s->filter("pricing",s));
        dropdown("Sort",["price-asc","price-desc"],["Lowest price","Highest price"],f["sort"],202,169,170,s->filter("sort",s));
        button(f["online"]=="true"?"Online sellers":"All sellers",386,169,144,()->filter("online",f["online"]=="true"?"false":"true"),f["online"]=="true"?"unaccept":"");
        for(i in 0...4){var name=["Warrior","Rogue","Mage","Priest"][i],selected=f["classes"].split(",").indexOf(name)>=0;
            button(name,544+i*123,169,113,()->{var classes=f["classes"].split(",").filter(s->s!="");if(classes.indexOf(name)>=0)classes.remove(name);else classes.push(name);filter("classes",classes.join(","));},selected?"unaccept":"");}
    }
    function row(item:TradeItem,y:Int,right:String,action:Void->Void,selected:Bool):Void {
        var root=frame.container,row=G.field(node("element",G.field(root,"dom"),[],"marketRow"+(sequence++)),"obj");absolute(root,row);size(row,624,34);position(row,20,y);
        var bg=graphic(row);rounded(bg,0,0,624,34,4,selected?0xD6BF94:0xE2D1B7);var definition=TradeInventory.definition(item.kind);
        if(definition!=null){var icon=G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[definition]),row]);absolute(row,icon);position(icon,6,1);G.call("h2d.Bitmap","set_width",icon,[32.0]);G.call("h2d.Bitmap","set_height",icon,[32.0]);}
        textAt(row,item.name+(item.count>1?" ×"+item.count:""),44,8,340,true);textAt(row,right,395,8,224);G.call("ui.UIElement","set_onClick",row,[()->{if(!c.busy)action();}]);
        G.call("ui.UIElement","set_getTip",row,[()->item.preview==null?null:TradeTooltips.create(item,c.tab=="Sell an item"?c.inv:null)]);G.set(row,"showTipOnOver",true);style(row,"show-tip-on-over",true);
    }
    function selectedItem(item:TradeItem):Void {textAt(frame.container,item.name,680,266,330,true);textAt(frame.container,item.detail.split("\n").slice(0,5).map(line->line.length>45?line.substr(0,42)+"...":line).join("\n"),680,302,330);}
    function priceFields(y:Int):Void {
        button(offers?"Open to offers":"Fixed total price",680,y,330,()->{offers=!offers;dirty=true;},offers?"unaccept":"");
        if(!offers){textAt(frame.container,"Silver Trays (total for the listing)",680,y+48,330);input(trays,680,y+70,330,s->trays=s.substr(0,6));}
    }
    function sellPanel():Void {
        if(c.chosen==null){textAt(frame.container,"Select an item to list it for sale.",680,280,330);return;}selectedItem(c.chosen);textAt(frame.container,"Quantity",680,440,330);input(quantity,680,464,330,s->quantity=s.substr(0,5));priceFields(510);button("List item for sale",680,640,330,()->c.list(int(quantity),int(trays),offers),"accept");
    }
    function listingPanel():Void {
        if(c.selected==null){textAt(frame.container,"Select a listing. Hover its item for the full native tooltip.",680,280,330);return;}
        var row=c.selected;try selectedItem(MarketExport.offer(row))catch(_:Dynamic){}var online=row.seller.onlineUntil!=null&&Protocol.expiry(row.seller.onlineUntil)>Date.now().getTime()/1000;
        textAt(frame.container,row.seller.characterName+" · "+(online?"Online":"Offline")+"\nExpires: "+G.text(row.expiresAt).substr(0,16).split("T").join(" ")+" UTC",680,444,330);
        if(c.tab=="My listings"){
            priceFields(500);button("Save price",680,612,330,()->c.changePrice(int(trays),offers),"accept");button("Mark sold",680,654,160,()->c.remove(true),"");button("Remove",850,654,160,()->c.remove(false),"cancel");
        }else{
            textAt(frame.container,row.price.mode=="offers"?"Open to offers":Std.string(row.price.silverTrays)+" Silver Trays total\n"+Std.string(row.price.silverTrays*500)+" gold",680,514,330,true);
            textAt(frame.container,"Contact the seller to arrange a trade. Meet in the same party and area to exchange items.",680,564,330);button("Whisper seller",680,640,330,c.contact,"accept");
        }
    }
    static function int(text:String):Int {if(!~/^[0-9]+$/.match(text))return 0;var n=Std.parseInt(text);return n==null?0:n;}
    static function subcategories(category:String):Array<String> return switch(category){
        case "Components":["Crafting materials","Upgrade materials","Finishing materials"];
        case "Equipment":["Weapons","Armour","Accessories"];
        case "Consumables":["Food","Potions","Elixirs","Scrolls","Enchantments","Demon enchantments","Skill point books","Other consumables"];
        case "Collections":["Recipes","Infusion patterns","Mounts","Gliders","Emotes","Other collectibles"];
        case "Containers":["Containers","Bags","Packages"];
        case "Miscellaneous":["Currency","Soulstones","Other"];
        default:[];
    };
}
