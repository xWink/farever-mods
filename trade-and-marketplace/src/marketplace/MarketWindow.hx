package marketplace;

import trade.GameAccess as G;
import trade.TradeUi.*;
import trade.TradeFrame.*;
import trade.TradeTypes;
import trade.TradeInventory;
import trade.TradeTooltips;
import fareverly.Protocol;

/** Native controls with explicit inner bounds; dropdown lists live above the window. */
class MarketWindow {
    static inline var INK = 0x5B4334;
    static inline var MUTED = 0x806B5B;
    static inline var PAPER = 0xEFE3D1;
    static inline var EDGE = 0xB69B7F;
    final c:MarketController;
    var frame:trade.TradeFrame;
    var controls:Array<Dynamic> = [];
    var sequence = 0;
    var shown = false;
    var px:Null<Float>;
    var py:Null<Float>;
    var quantity = "1";
    var trays = "1";
    var offers = false;
    var contentY = 284;
    var stage = "initialization";
    var recovery = false;
    var partialRow:Dynamic;
    var reported:Map<String,Bool> = [];
    public var dirty = true;

    public function new(controller:MarketController) c = controller;
    public function open():Void { shown = true; recovery = false; dirty = true; }
    public function close():Void {
        shown = false; closeDropdowns();
        if (frame != null) {
            var old=frame;frame=null;px=old.x;py=old.y;
            old.dispose();
        }
    }
    public function recover(error:Dynamic):Void {
        report(stage,error);
        if(recovery) {try close()catch(_:Dynamic){}return;}
        recovery=true;dirty=true;
    }
    function report(where:String,error:Dynamic):Void {
        var detail=Std.string(error),key=where+":"+detail;
        if(reported.exists(key))return;
        reported[key]=true;
        trade.TradeDiagnostics.log("Marketplace "+where+": "+detail+"\n"+haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
    }
    public function closeFromBack(window:Dynamic):Bool {
        if (frame == null || frame.window != window) return false;
        for (control in controls) if (G.call("ui.comp.Dropdown", "isOpen", control) == true) {
            closeDropdowns(false); return true;
        }
        close(); return true;
    }
    public function update():Void {
        if (!shown) return;
        stage="window state";
        if (frame != null && !frame.intact()) { close(); return; }
        if (frame == null) {
            stage="create window";
            var ui = G.current("ui.BaseUI", "current"); if (ui == null) return;
            frame = new trade.TradeFrame(ui, "Trade and Marketplace", 1120, 860, close);
            frame.x = px; frame.y = py; frame.onMoved = (x,y) -> { px = x; py = y; }; dirty = true;
        }
        if (dirty) { dirty = false; render(); }
        stage="window layout";frame.layout();
        stage="dropdown input";dismissOutsideDropdowns();
    }
    function closeDropdowns(clear = true):Void {
        for (control in controls) try G.call("ui.comp.Dropdown", "close", control, [null]) catch (_:Dynamic) {}
        if (clear) controls = [];
    }
    function dismissOutsideDropdowns():Void {
        var open = [for (control in controls) if (G.call("ui.comp.Dropdown", "isOpen", control) == true) control];
        if (open.length == 0) return;
        var pressed = false;
        for (button in 0...3) if (G.staticCall("hxd.Key", "isPressed", [button]) == true) pressed = true;
        if (!pressed) return;
        var target = G.call("ui.BaseUI", "getTopInteractiveElement", frame.ui, [null]);
        for (control in open) if (!inside(control,target) && !inside(G.field(control,"listWindow"),target))
            G.call("ui.comp.Dropdown", "close", control, [null]);
    }
    static function inside(parent:Dynamic, child:Dynamic):Bool return parent != null && child != null
        && (parent == child || G.call("h2d.Object", "contains", parent, [child]) == true);

    function render():Void {
        stage="clear old controls";
        closeDropdowns();
        for (child in children(frame.container)) G.call("h2d.Object", "remove", child);
        var root = frame.container;
        if(recovery) {
            stage="recovery screen";
            labelAt(root,"The marketplace could not display this page.",28,38,1000,true);
            labelAt(root,"Any listing already submitted is kept. You can reload the page or switch tabs below.",28,78,1000);
            button("Browse",28,130,190,()->{recovery=false;c.chooseTab("Browse");},"");
            button("Sell an item",234,130,190,()->{recovery=false;c.chooseTab("Sell an item");},"");
            button("My listings",440,130,190,()->{recovery=false;c.chooseTab("My listings");},"");
            labelAt(root,"The underlying error was recorded in the HLX log.",28,196,1000,false,MUTED);
            return;
        }
        stage="navigation and filters";
        for (i in 0...3) {
            var title = ["Browse", "Sell an item", "My listings"][i];
            button(title,16+i*182,12,174,()->c.chooseTab(title),c.tab == title ? "unaccept" : "");
        }
        if (c.ready) badge(root,"Steam connected",906,19,182,0xD5DFC6,0x426138);
        else button(c.signingIn ? "Cancel sign-in" : "Sign in with Steam",866,12,222,
            ()->{if(c.signingIn)c.cancelSignIn();else c.signIn();}, "");
        var heading = switch(c.tab) {case "Browse": "Find your next upgrade"; case "Sell an item": "List an item from your backpack"; default: "Manage your listings";};
        var headingText=labelAt(root,heading,20,65,740,true);
        largeLabel(headingText);
        labelAt(root,switch(c.tab) {
            case "Browse": "Browse items for sale, inspect their details, and contact the seller.";
            case "Sell an item": "Choose an unlocked, tradable item. It stays in your backpack until you trade it.";
            default: "Up to 10 active listings. Listings expire after 3 days; editing a price does not renew them.";
        },20,92,800,false,MUTED);
        labelAt(root,serverLabel(c.server),886,80,202,true);
        contentY = c.tab == "Browse" ? 284 : 142;
        if (c.tab == "Browse") filters();
        card(root,16,contentY,704,734-contentY);
        card(root,736,contentY,352,734-contentY);
        labelAt(root,c.tab == "Sell an item" ? "YOUR BACKPACK" : "ITEM",32,contentY+16,420,true);
        labelAt(root,c.tab == "Sell an item" ? "AVAILABLE" : "TOTAL PRICE",530,contentY+16,170,true);
        labelAt(root,"ITEM DETAILS",754,contentY+16,300,true);
        line(root,30,contentY+42,676); line(root,750,contentY+42,324);
        var rowHeight = c.tab == "Browse" ? 48 : 66;
        if (c.tab == "Sell an item") {
            var start = (c.page-1)*MarketController.PAGE_SIZE;
            for (i in 0...MarketController.PAGE_SIZE) if (start+i < c.inventory.length) {
                var item = c.inventory[start+i];
                row(item,contentY+48+i*rowHeight,rowHeight,Std.string(item.count),"In backpack","",false,
                    ()->{c.chosen=item;quantity=Std.string(item.count);dirty=true;},c.chosen==item);
            }
            sellPanel();
        } else {
            for (i in 0...c.rows.length) savedRow(c.rows[i],contentY+48+i*rowHeight,rowHeight,i);
            stage="selected listing";
            listingPanel();
        }
        stage="footer";
        if (c.total == 0) emptyList();
        button("Previous",16,748,118,()->{c.page--;c.refresh();},"",c.page>1);
        labelAt(root,"Page "+c.page+(c.tab=="Sell an item"?" of "+c.pages:""),152,758,172,true);
        button("Next",342,748,104,()->{c.page++;c.refresh();},"",c.page<c.pages);
        button(c.busy?"Loading...":"Refresh",458,748,118,c.refresh,"");
        labelAt(root,c.tab=="Sell an item"?MarketText.count(c.total,"tradable item"):MarketText.count(c.rows.length,"listing")+" on this page",594,758,326,false,MUTED);
        if(c.tab=="Browse")button("Clear filters",940,748,148,resetFilters,"");
        var message = c.message;
        if (message == "No matching listings." || message == "Listings updated." || message == "Connected to Fareverly.") message = "";
        if (message != "") labelAt(root,message,20,786,1064,false,INK,true);
    }
    function savedRow(listing:Dynamic,y:Int,height:Int,index:Int):Void {
        stage="listing "+(index+1)+" data";
        var select=()->{
            c.selected=listing;offers=G.text(G.field(G.field(listing,"price"),"mode"))=="offers";
            trays=offers?"1":G.text(G.field(G.field(listing,"price"),"silverTrays"));dirty=true;
        };
        try {
            var item=MarketExport.offer(listing);
            var price:Dynamic=G.field(listing,"price"),seller:Dynamic=G.field(listing,"seller");
            var priceText=MarketText.price(price);
            row(item,y,height,priceText,G.text(G.field(seller,"characterName")),G.text(G.field(G.field(listing,"item"),"rarity")),isOnline(listing),select,c.selected==listing);
        } catch(error:Dynamic) {
            report(stage,error);
            if(partialRow!=null) {try G.call("h2d.Object","remove",partialRow)catch(_:Dynamic){}partialRow=null;}
            // Keep the listing selectable/removable even if its icon or tooltip cannot be drawn.
            var name=G.text(G.field(G.field(listing,"item"),"name"),"Listing");
            button(name.substr(0,55)+" — details unavailable",28,y,680,select,"");
        }
    }

    function button(label:String,x:Int,y:Int,width:Int,action:Void->Void,kind:String,enabled=true):Dynamic {
        var obj = frame.button(label,x,y,width,()->{if(!c.busy&&enabled)action();},kind);
        G.call("ui.UIElement", "set_enable", obj, [enabled&&!c.busy]); return obj;
    }
    function input(value:String,x:Int,y:Int,width:Int,changed:String->Void,hint=""):Dynamic {
        var root = frame.container, box = G.field(node("input-box",G.field(root,"dom"),[],"marketInput"+(sequence++)),"obj");
        absolute(root,box); padding(box,0); size(box,width,34); position(box,x,y);
        var input = G.field(box,"input");
        G.call("h2d.TextInput","set_text",input,[value]); style(input,"width",width-20); style(input,"color",0xF5F0E8);
        G.call("ui.comp.InputBox","set_hintText",box,[hint]); style(G.field(box,"inputHint"),"color",0xE0D8CD);
        G.set(box,"onChange",()->changed(G.text(G.field(input,"text")))); return box;
    }
    function dropdown(label:String,values:Array<String>,labels:Array<String>,selected:String,x:Int,y:Int,width:Int,changed:String->Void):Void {
        var root = frame.container;
        labelAt(root,label,x,y-20,width,false,MUTED);
        var control = G.field(node("dropdown",G.field(root,"dom"),[false,false,"options-dropdown-list"],"marketSelect"+(sequence++)),"obj");
        absolute(root,control); padding(control,0); size(control,width,34); position(control,x,y);
        // The nested select retains a large native minimum width unless sized too.
        var select = G.field(control,"select"); padding(select,0); size(select,width,34);
        var options = G.call("hl.types.ArrayObj","slice",G.field(control,"items"),[0,0]);
        for (i in 0...values.length) G.call("hl.types.ArrayObj","pushDyn",options,[{name:escape(labels[i]),value:i,icon:null,group:null}]);
        G.call("ui.comp.Dropdown","set_options",control,[options]);
        G.call("ui.comp.Dropdown","initSelectedIndex",control,[Std.int(Math.max(0,values.indexOf(selected)))]);
        var caption = G.field(control,"selectText");
        absolute(G.field(caption,"parent"),caption);position(caption,10,8);
        G.call("ui.comp.FmtText","set_maxWidthText",caption,[width-44]);
        G.call("ui.comp.FmtText","set_useEllipsis",caption,[true]); textColor(caption,INK);
        var popupRoot = G.field(frame.ui,"root");
        G.set(control,"getListLayout",()->popupRoot);
        G.call("ui.UIElement","set_onClick",select,[()->{
            if(c.busy)return;
            for (other in controls) if(other!=control) G.call("ui.comp.Dropdown","close",other,[null]);
            G.call("ui.comp.Dropdown","toggle",control,[null]);
            var popup=G.field(control,"listWindow");
            if(popup!=null&&G.field(popup,"parent")==popupRoot)absolute(popupRoot,popup);
            for(item in G.array(G.field(control,"items"))) for(child in children(item))
                if(G.field(child,"font")!=null)textColor(child,INK);
        }]);
        G.set(control,"onSelectOption",(_:Dynamic)->{
            var i=G.integer(G.field(control,"selectedIndex"),-1);
            if(i>=0&&i<values.length)changed(values[i]);
        });
        G.call("ui.comp.Dropdown","set_enable",control,[!c.busy]); controls.push(control);
    }
    function filter(key:String,value:String):Void {
        if(c.busy)return; c.filters[key]=value; c.page=1;
        if(key=="category") {c.filters["subcategory"]="";if(value!="Equipment"&&value!="")c.filters["classes"]="";}
        c.refresh(); dirty=true;
    }
    function resetFilters():Void {
        if(c.busy)return;
        for(key in c.filters.keys())c.filters[key]=key=="sort"?"price-asc":key=="online"?"false":"";
        c.page=1;c.refresh();dirty=true;
    }
    function filters():Void {
        var f=c.filters, root=frame.container;
        card(root,16,122,1072,146,0xDCCAB5);
        labelAt(root,"Search items",28,134,232,false,MUTED);
        input(f["search"],28,154,232,s->f["search"]=s.substr(0,100),"Item name...");
        button("Search",268,154,92,()->filter("search",f["search"]),"");
        var cats=["","Components","Equipment","Consumables","Collections","Containers","Miscellaneous"];
        dropdown("Category",cats,["All items"].concat(cats.slice(1)),f["category"],376,154,220,s->filter("category",s));
        var subs=[""].concat(subcategories(f["category"]));
        dropdown("Subcategory",subs,["All subcategories"].concat(subs.slice(1)),f["subcategory"],612,154,264,s->filter("subcategory",s));
        var rarities=["","Common","Uncommon","Rare","Epic","Legendary"];
        dropdown("Rarity",rarities,["Any rarity"].concat(rarities.slice(1)),f["rarity"],892,154,184,s->filter("rarity",s));
        dropdown("Pricing",["","fixed","offers"],["Any price","Fixed price","Open to offers"],f["pricing"],28,222,190,s->filter("pricing",s));
        dropdown("Sort by",["price-asc","price-desc"],["Lowest price","Highest price"],f["sort"],234,222,190,s->filter("sort",s));
        labelAt(root,"Availability",440,202,156,false,MUTED);
        button(f["online"]=="true"?"Online only":"All sellers",440,222,156,()->filter("online",f["online"]=="true"?"false":"true"),f["online"]=="true"?"unaccept":"");
        labelAt(root,"Class",612,202,464,false,MUTED);
        for(i in 0...4) {
            var name=["Warrior","Rogue","Mage","Priest"][i],selected=f["classes"].split(",").indexOf(name)>=0;
            button(name,612+i*116,222,108,()->{
                var classes=f["classes"].split(",").filter(s->s!="");
                if(classes.indexOf(name)>=0)classes.remove(name);else classes.push(name);
                filter("classes",classes.join(","));
            },selected?"unaccept":"",f["category"]==""||f["category"]=="Equipment");
        }
    }

    function row(item:TradeItem,y:Int,height:Int,price:String,seller:String,rarity:String,online:Bool,action:Void->Void,selected:Bool):Void {
        stage="item row container";
        var root=frame.container, row=G.field(node("element",G.field(root,"dom"),[],"marketRow"+(sequence++)),"obj");
        partialRow=row;
        absolute(root,row);padding(row,0);size(row,680,height-4);position(row,28,y);
        var bg=graphic(row);
        function draw(over:Bool):Void {
            G.call("h2d.Graphics","clear",bg);
            rounded(bg,0,0,680,height-4,5,selected?0xBC9146:over?0xC6B297:0xD7C5AC);
            rounded(bg,1,1,678,height-6,4,selected?0xF0D7A2:over?0xE2D1B7:0xE9DDC9);
            if(selected)rounded(bg,1,5,3,height-14,1,0xB78534);
        }
        draw(false);
        G.call("ui.UIElement","set_onOver",row,[()->draw(true)]);
        G.call("ui.UIElement","set_onOut",row,[()->draw(false)]);
        var iconY=Std.int((height-4-38)/2);
        stage="item row icon";
        itemIcon(row,item,8,iconY,38);
        stage="item row labels";
        largeLabel(labelAt(row,item.name+(item.count>1?" ×"+item.count:""),58,Std.int((height-4)/2)-18,426,true,INK,true));
        if(rarity=="") labelAt(row,seller,58,Std.int((height-4)/2)+4,426,false,MUTED,true);
        else {
            labelAt(row,rarity,58,Std.int((height-4)/2)+4,88,true,rarityColor(rarity),true);
            labelAt(row,"·  "+seller,150,Std.int((height-4)/2)+4,334,false,MUTED,true);
        }
        largeLabel(labelAt(row,price,502,Std.int((height-4)/2)-18,166,true,INK,true));
        labelAt(row,c.tab=="Sell an item"?"items":online?"Online":"Offline",502,Std.int((height-4)/2)+4,166,false,online?0x426138:MUTED,true);
        G.call("ui.UIElement","set_onClick",row,[()->{if(!c.busy)action();}]);
        stage="item row tooltip";
        tooltip(row,item);
        partialRow=null;
    }
    function itemIcon(parent:Dynamic,item:TradeItem,x:Int,y:Int,sizePx:Int):Void {
        var bg=graphic(parent);rounded(bg,x,y,sizePx,sizePx,5,EDGE);rounded(bg,x+1,y+1,sizePx-2,sizePx-2,4,0xF5EBDD);
        var definition=TradeInventory.definition(item.kind);
        if(definition!=null) {
            var icon=G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[definition]),parent]);
            absolute(parent,icon);position(icon,x+2,y+2);
            G.call("h2d.Bitmap","set_width",icon,[(sizePx-4)*1.0]);G.call("h2d.Bitmap","set_height",icon,[(sizePx-4)*1.0]);
        }
    }
    function tooltip(object:Dynamic,item:TradeItem):Void {
        G.call("ui.UIElement","set_getTip",object,[()->item.preview==null?null:TradeTooltips.create(item,c.tab=="Sell an item"?c.inv:null)]);
        G.set(object,"showTipOnOver",true);style(object,"show-tip-on-over",true);
    }
    function selectedItem(item:TradeItem):Void {
        var root=frame.container, y=contentY+58;
        itemIcon(root,item,754,y,60);
        largeLabel(labelAt(root,item.name,826,y+4,242,true,INK,true));
        labelAt(root,"Quantity: "+item.count,826,y+38,242,false,MUTED);
        if(item.detail=="") labelAt(root,"Hover the item in the list for its full tooltip.",754,y+76,316,false,MUTED);
        else {
            var lines=item.detail.split("\n").slice(0,4);
            for(i in 0...lines.length)labelAt(root,lines[i],754,y+76+i*20,316,false,MUTED,true);
        }
    }
    function emptyList():Void {
        var root=frame.container, y=contentY+Std.int((734-contentY)/2)-40;
        labelAt(root,c.busy?"Finding listings...":c.tab=="Sell an item"?"No tradable items":c.tab=="My listings"?"No active listings":"No listings found",64,y,596,true);
        labelAt(root,c.tab=="Sell an item"?"Unlocked items that can be traded will appear here.":c.tab=="My listings"?c.ready?"Select Sell an item to create your first listing.":"Sign in with Steam to view and manage your listings.":"Try another search or clear your filters. New listings will appear here as players add them.",64,y+32,560,false,MUTED);
        if(!c.busy&&c.tab=="Browse")button("Clear filters",64,y+94,152,resetFilters,"");
        if(!c.busy&&c.tab=="My listings"&&c.ready)button("Sell an item",64,y+94,152,()->c.chooseTab("Sell an item"),"");
    }
    function emptyDetails(selling:Bool):Void {
        var y=contentY+96;
        labelAt(frame.container,selling?"Choose an item":"Select a listing",762,y,308,true);
        labelAt(frame.container,selling?"Select an item from your backpack to choose the quantity and set a price.":"Item details, price, and seller information will appear here.",762,y+36,300,false,MUTED);
        line(frame.container,754,y+122,316);
        labelAt(frame.container,selling?"Listings last 3 days. You can have up to 10 active listings.":"Hover an item to see its in-game tooltip, including upgrades and enchantments.",762,y+144,300,false,MUTED);
    }
    function priceFields(y:Int):Void {
        labelAt(frame.container,"Price for the entire listing",754,y,316,true);
        button(offers?"Open to offers":"Fixed price",754,y+28,316,()->{offers=!offers;dirty=true;},offers?"unaccept":"");
        if(!offers) {
            input(trays,754,y+76,132,s->trays=s.substr(0,6),"1");
            labelAt(frame.container,"Silver Trays",900,y+82,170,true);
            labelAt(frame.container,"1 Silver Tray = 500 gold",754,y+117,316,false,MUTED);
        } else labelAt(frame.container,"Buyers can contact you to agree on a price.",754,y+78,316,false,MUTED);
    }
    function sellPanel():Void {
        if(c.chosen==null){emptyDetails(true);return;}
        selectedItem(c.chosen);
        line(frame.container,754,contentY+224,316);
        labelAt(frame.container,"Quantity to sell",754,contentY+246,316,true);
        input(quantity,754,contentY+274,132,s->quantity=s.substr(0,5),"1");
        labelAt(frame.container,"of "+c.chosen.count+" available",900,contentY+282,170,false,MUTED);
        priceFields(contentY+334);
        button(c.ready?"List item for sale":"Sign in to sell",754,682,316,()->{if(c.ready)c.list(int(quantity),int(trays),offers);else c.signIn();},"accept");
    }
    function listingPanel():Void {
        if(c.selected==null){emptyDetails(false);return;}
        var row=c.selected;try selectedItem(MarketExport.offer(row))catch(error:Dynamic){report("selected item details",error);}
        if(c.tab=="My listings") {
            labelAt(frame.container,"Expires "+G.text(row.expiresAt).substr(0,16).split("T").join(" ")+" UTC",754,contentY+222,316,false,MUTED);
            priceFields(contentY+260);
            button("Save price",754,626,316,()->c.changePrice(int(trays),offers),"accept");
            button("Mark sold",754,682,152,()->c.remove(true),"");
            button("Remove",918,682,152,()->c.remove(false),"cancel");
        } else {
            line(frame.container,754,contentY+222,316);
            labelAt(frame.container,row.seller.characterName,754,contentY+238,220,true,INK,true);
            labelAt(frame.container,isOnline(row)?"Online":"Offline",988,contentY+238,82,false,isOnline(row)?0x426138:MUTED);
            labelAt(frame.container,MarketText.price(row.price),754,contentY+278,316,true);
            labelAt(frame.container,row.price.mode=="offers"?"Contact the seller to agree on a price.":MarketText.number(row.price.silverTrays*500)+" gold for the entire listing",754,contentY+308,316,false,MUTED);
            labelAt(frame.container,"Arrange a party and meet nearby to trade.",754,contentY+348,316,false,MUTED);
            button(row.seller.accountId==c.account?"Your listing":"Whisper seller",754,682,316,c.contact,"accept",row.seller.accountId!=c.account);
        }
    }
    static function isOnline(row:Dynamic):Bool return row.seller.onlineUntil!=null&&Protocol.expiry(row.seller.onlineUntil)>Date.now().getTime()/1000;
    static function labelAt(parent:Dynamic,value:String,x:Int,y:Int,width:Int,bold=false,color=INK,single=false):Dynamic {
        var obj=textAt(parent,value,x,y,width,bold);
        textColor(obj,color);
        if(single) {
            G.call("h2d.Text","set_lineBreak",obj,[false]);style(obj,"line-break",false);
            G.call("ui.comp.FmtText","set_useEllipsis",obj,[true]);
        } else {
            // FmtText maxWidthText shrinks a sentence; base Text maxWidth wraps it.
            G.call("ui.comp.FmtText","set_textMultiline",obj,[true]);
            G.call("h2d.Text","set_lineBreak",obj,[true]);style(obj,"line-break",true);
            G.call("ui.comp.FmtText","set_useEllipsis",obj,[false]);
            G.call("ui.comp.FmtText","set_maxWidthText",obj,[null]);
            G.call("h2d.Text","set_maxWidth",obj,[width*1.0]);
        }
        return obj;
    }
    static function largeLabel(obj:Dynamic):Void {
        G.call("domkit.Properties","removeClass",G.field(obj,"dom"),["bold-14"]);
        G.call("domkit.Properties","addClass",G.field(obj,"dom"),["bold-16"]);
    }
    static function rarityColor(rarity:String):Int return switch(rarity) {
        case "Uncommon":0x426138;case "Rare":0x346A91;case "Epic":0x80529A;
        case "Legendary":0xA86322;default:INK;
    };
    static function textColor(obj:Dynamic,value:Int):Void {
        if(obj==null)return;
        style(obj,"color",value);
        var tint=G.field(obj,"color");
        if(tint!=null)for(channel in ["x","y","z"])G.set(tint,channel,1.0);
        G.call("h2d.HtmlText","set_textColor",obj,[value]);
    }
    static function card(parent:Dynamic,x:Int,y:Int,w:Int,h:Int,color=PAPER):Void {
        var g=graphic(parent);rounded(g,x,y,w,h,8,EDGE);rounded(g,x+1,y+1,w-2,h-2,7,color);
    }
    static function line(parent:Dynamic,x:Int,y:Int,w:Int):Void {var g=graphic(parent);rounded(g,x,y,w,1,0,0xCFB99D);}
    static function badge(parent:Dynamic,value:String,x:Int,y:Int,w:Int,color:Int,ink:Int):Void {
        var g=graphic(parent);rounded(g,x,y,w,26,13,color);labelAt(parent,value,x+14,y+5,w-28,true,ink,true);
    }
    static function serverLabel(value:String):String return switch(value) {
        case "north-america":"North America";case "latin-america":"Latin America";case "europe":"Europe";
        case "asia":"Asia";case "mainland-china":"Mainland China";default:"Server unavailable";
    };
    static function int(text:String):Int {if(!~/^[0-9]+$/.match(text))return 0;var n=Std.parseInt(text);return n==null?0:n;}
    static function subcategories(category:String):Array<String> return switch(category) {
        case "Components":["Crafting materials","Upgrade materials","Finishing materials"];
        case "Equipment":["Weapons","Armour","Accessories"];
        case "Consumables":["Food","Potions","Elixirs","Scrolls","Enchantments","Demon enchantments","Skill point books","Other consumables"];
        case "Collections":["Recipes","Infusion patterns","Mounts","Gliders","Emotes","Other collectibles"];
        case "Containers":["Containers","Bags","Packages"];
        case "Miscellaneous":["Currency","Soulstones","Other"];default:[];
    };
}
