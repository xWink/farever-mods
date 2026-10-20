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
    var cart:MarketCartIcon;
    var controls:Array<Dynamic> = [];
    var sequence = 0;
    var shown = false;
    var connectionNoticeShown=false;
    var connectionDialog:Dynamic;
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
    public function open():Void { shown = true; connectionNoticeShown=false; recovery = false; dirty = true; }
    public function close():Void {
        shown = false; closeDropdowns();
        if(cart!=null){cart.dispose();cart=null;}
        if(connectionDialog!=null&&frame!=null&&G.field(connectionDialog,"allocated")==true)
            G.call("ui.BaseUI","removeWindow",frame.ui,[connectionDialog]);
        connectionDialog=null;
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
            frame = new trade.TradeFrame(ui, "Marketplace", 1120, 948, close);
            headerCart();
            frame.x = px; frame.y = py; frame.onMoved = (x,y) -> { px = x; py = y; }; dirty = true;
        }
        if (dirty) { dirty = false; render(); }
        stage="window layout";frame.layout();
        stage="dropdown input";dismissOutsideDropdowns();
        if(c.connectionIssue&&!c.signingIn&&!connectionNoticeShown)showConnectionError();
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
            button("Sell",234,130,190,()->{recovery=false;c.chooseTab("Sell");},"");
            button("My listings",440,130,190,()->{recovery=false;c.chooseTab("My listings");},"");
            labelAt(root,"The underlying error was recorded in the HLX log.",28,196,1000,false,MUTED);
            return;
        }
        stage="navigation and filters";
        for (i in 0...3) {
            var title = ["Browse", "Sell", "My listings"][i];
            tabButton(title,16+i*182,12,174,()->c.chooseTab(title),c.tab==title);
        }
        var regionBox=G.field(node("element",G.field(root,"dom"),[],"marketRegion"+(sequence++)),"obj");
        absolute(root,regionBox);padding(regionBox,0);size(regionBox,286,36);position(regionBox,802,12);
        var region=labelAt(regionBox,"Region: "+serverLabel(c.server),0,0,286,false,MUTED,true);
        G.call("h2d.Text","set_textAlign",region,[G.enumeration("h2d.Align","Right")]);
        G.call("h2d.Text","set_maxWidth",region,[286.0]);
        afterReflow(regionBox,()->{
            centerDropdownCaption(region,36,0);position(region,0,G.number(G.field(region,"y")));
        });
        if(c.tab=="My listings")labelAt(root,"You can have up to 10 active listings. Listings expire 3 days after posting.",20,76,1064,false,MUTED);
        if(c.tab=="Sell") {
            tabButton("Inventory",20,68,150,()->c.setBankOnly(false),!c.bankOnly);
            tabButton("Bank",182,68,150,()->c.setBankOnly(true),c.bankOnly);
            input(c.sellSearch,352,68,612,s->c.sellSearch=s.substr(0,100),"Search items to sell...",c.searchInventory);
            button("Search",980,68,96,c.searchInventory,"");
            labelAt(root,"Choose an unlocked, tradable item to list on the marketplace. It won't be removed from your inventory until you trade it.",20,116,1064,false,MUTED);
        }
        contentY = c.tab == "Browse" ? (c.filtersExpanded?340:176) : 146;
        if (c.tab == "Browse") filters();
        card(root,16,contentY,704,806-contentY);
        card(root,736,contentY,352,806-contentY);
        labelAt(root,c.tab == "Sell" ? (c.bankOnly?"YOUR BANK":"YOUR INVENTORY") : "ITEM",32,contentY+16,420,true);
        rightText(labelAt(root,c.tab == "Sell" ? "AVAILABLE" : "TOTAL PRICE",456,contentY+16,240,true),240);
        labelAt(root,"ITEM DETAILS",754,contentY+16,300,true);
        line(root,30,contentY+42,676); line(root,750,contentY+42,324);
        var rowHeight = 68;
        if (c.tab == "Sell") {
            var start = (c.page-1)*c.pageSize();
            for (i in 0...c.pageSize()) if (start+i < c.inventory.length) {
                var item = c.inventory[start+i];
                row(item,contentY+48+i*rowHeight,rowHeight,Std.string(item.count),c.inventoryLocation(item),item.detail.split("\n")[0],false,
                    ()->{c.chosen=item;quantity=Std.string(item.count);dirty=true;},c.chosen==item);
            }
            sellPanel();
        } else {
            for (i in 0...Std.int(Math.min(c.rows.length,c.pageSize()))) savedRow(c.rows[i],contentY+48+i*rowHeight,rowHeight,i);
            stage="selected listing";
            listingPanel();
        }
        stage="footer";
        if (c.total == 0) emptyList();
        button("Previous",16,820,118,()->{c.page--;c.refresh();},"",c.page>1);
        var pageLabel=labelAt(root,"Page "+c.page+(c.tab=="Sell"?" of "+c.pages:""),152,830,172,true);
        var next=button("Next",342,820,104,()->{c.page++;c.refresh();},"",c.page<c.pages);
        var footer=G.field(node("element",G.field(root,"dom"),[],"marketPagination"+(sequence++)),"obj");
        absolute(root,footer);padding(footer,0);size(footer,430,36);position(footer,152,820);
        G.call("h2d.Object","addChild",footer,[pageLabel]);absolute(footer,pageLabel);position(pageLabel,0,10);
        G.call("h2d.Object","addChild",footer,[next]);absolute(footer,next);
        // Observe an actual Flow's reflow; FmtText does not have this callback.
        afterReflow(footer,()->{
            var bounds=G.call("h2d.Object","getSize",pageLabel,[null]);
            position(next,G.number(G.field(bounds,"xMax"))*G.number(G.field(pageLabel,"scaleX"),1)+18,0);
        });
        button("Refresh",970,820,118,c.refresh,"");
        var message = c.message;
        if (message == "Loading..." || message == "No matching listings." || message == "Listings updated." || message == "Connected to Fareverly.") message = "";
        if (message != "") labelAt(root,message.split("\n").join(" "),20,862,1064,false,INK,true);
    }
    function savedRow(listing:Dynamic,y:Int,height:Int,index:Int):Void {
        stage="listing "+(index+1)+" data";
        var select=()->{c.selected=listing;dirty=true;};
        try {
            var item=MarketExport.offer(listing);
            var price:Dynamic=G.field(listing,"price"),seller:Dynamic=G.field(listing,"seller");
            var priceText=MarketText.price(price);
            row(item,y,height,priceText,G.text(G.field(seller,"characterName")),G.text(G.field(G.field(listing,"item"),"rarity")),isOnline(listing),select,c.selected==listing,price);
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
        G.call("ui.UIElement", "set_enable", obj, [enabled]); return obj;
    }
    function tabButton(label:String,x:Int,y:Int,width:Int,action:Void->Void,selected:Bool):Void {
        // Match Better Mod Settings' native brown selected state.
        G.call("ui.UIElement","set_selected",button(label,x,y,width,action,""),[selected]);
    }
    function input(value:String,x:Int,y:Int,width:Int,changed:String->Void,hint="",?submit:Void->Void):Dynamic {
        var root = frame.container, box = G.field(node("input-box",G.field(root,"dom"),[],"marketInput"+(sequence++)),"obj");
        absolute(root,box); padding(box,0); size(box,width,36); position(box,x,y);
        var input = G.field(box,"input");
        G.call("h2d.TextInput","set_text",input,[value]); style(input,"width",width-20); style(input,"color",0xF5F0E8);
        G.call("ui.comp.InputBox","set_hintText",box,[hint]); style(G.field(box,"inputHint"),"color",0xE0D8CD);
        for(text in [input,G.field(box,"inputHint")]) {
            absolute(G.field(text,"parent"),text);centerControlText(text,36,12);
            G.call("h2d.Text","set_maxWidth",text,[(width-24)*1.0]);style(text,"width",width-24);
        }
        afterReflow(box,()->{
            for(text in [input,G.field(box,"inputHint")])centerControlText(text,36,12);
        });
        G.set(box,"onChange",()->changed(G.text(G.field(input,"text"))));
        if(submit!=null) {
            G.set(input,"ignoreEnter",true);
            G.set(input,"onEnter",function():Void {
                if(c.busy)return;
                changed(G.text(G.field(input,"text")));submit();
            });
        }
        return box;
    }
    function counter(value:String,x:Int,y:Int,width:Int,max:Int,changed:String->Void):Dynamic {
        var current=MarketQuantity.normalize(value,1,max,"1");
        var box:Dynamic=null;
        function commit(text:String):Void {
            if(c.busy)return;
            current=MarketQuantity.normalize(text,1,max,current);
            if(G.text(G.field(G.field(box,"input"),"text"))!=current)
                G.call("h2d.TextInput","set_text",G.field(box,"input"),[current]);
            changed(current);
        }
        box=input(current,x,y,width-30,commit,"1");
        changed(current);
        var textInput=G.field(box,"input"),previous=G.field(textInput,"onFocusLost");
        G.set(textInput,"onFocusLost",function(event:Dynamic):Void {
            if(previous!=null)Reflect.callMethod(textInput,previous,[event]);
            if(current=="")commit("1");
        });
        for(i in 0...2) {
            var delta=i==0?1:-1;
            var arrow=G.field(node("button-icon",G.field(frame.container,"dom"),[i==0?"ArrowUp":"ArrowDown"],"marketCounterArrow"+(sequence++)),"obj");
            absolute(frame.container,arrow);padding(arrow,0);size(arrow,28,17);position(arrow,x+width-28,y+i*19);
            G.call("h2d.Object","set_visible",G.field(arrow,"iconBmp"),[false]);
            var glyph=graphic(arrow);
            // Identical mirrored triangles, including the fractional-pixel fringe.
            // Keep both paths clockwise so native triangulation sees the same shape.
            for(layer in [{grow:0.7,alpha:0.18},{grow:0.3,alpha:0.45},{grow:0.0,alpha:1.0}]) {
                var left=7.0-layer.grow,right=21.0+layer.grow,tip=4.5-layer.grow,base=12.5+layer.grow;
                polygon(glyph,i==0?[left,base,14.0,tip,right,base]:[left,17-base,right,17-base,14.0,17-tip],0xF5F0E8,layer.alpha);
            }
            G.call("ui.UIElement","set_onClick",arrow,[function():Void {commit(Std.string(Std.int(Math.max(1,int(current)+delta))));}]);
            G.call("ui.UIElement","set_enable",arrow,[true]);
        }
        return box;
    }
    function dropdown(label:String,values:Array<String>,labels:Array<String>,selected:String,x:Int,y:Int,width:Int,changed:String->Void):Void {
        var root = frame.container;
        labelAt(root,label,x,y-28,width,false,MUTED);
        var control = G.field(node("dropdown",G.field(root,"dom"),[false,false,"options-dropdown-list"],"marketSelect"+(sequence++)),"obj");
        absolute(root,control); padding(control,0); size(control,width,36); position(control,x,y);
        // The nested select retains a large native minimum width unless sized too.
        var select = G.field(control,"select"); padding(select,0); size(select,width,36);
        var options = G.call("hl.types.ArrayObj","slice",G.field(control,"items"),[0,0]);
        for (i in 0...values.length) G.call("hl.types.ArrayObj","pushDyn",options,[{name:escape(labels[i]),value:i,icon:null,group:null}]);
        G.call("ui.comp.Dropdown","set_options",control,[options]);
        G.call("ui.comp.Dropdown","initSelectedIndex",control,[Std.int(Math.max(0,values.indexOf(selected)))]);
        var caption = G.field(control,"selectText");
        absolute(G.field(caption,"parent"),caption);
        G.call("ui.comp.FmtText","set_maxWidthText",caption,[width-54]);
        var arrows=[for(child in children(select))if(G.isA(child,"ui.comp.Icon"))child];
        for(arrow in arrows) {absolute(select,arrow);padding(arrow,0);size(arrow,22,22);}
        afterReflow(select,()->{
            centerDropdownCaption(caption,36,12);
            for(arrow in arrows) {
                var bounds=G.call("h2d.Object","getSize",arrow,[null]);
                var right=G.number(G.field(bounds,"xMax"),22);
                centerControlText(arrow,36,width-10-right+G.number(G.field(bounds,"xMin")));
            }
        });
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
        G.call("ui.comp.Dropdown","set_enable",control,[true]); controls.push(control);
    }
    function filter(key:String,value:String):Void {
        if(c.busy)return; c.filters[key]=value; c.page=1;
        if(key=="category") {c.filters["subcategory"]="";if(value!="Equipment"&&value!="")c.filters["classes"]="";}
        c.refresh(); dirty=true;
    }
    function resetFilters():Void {
        if(c.busy)return;
        for(key in c.filters.keys())c.filters[key]=key=="sort"?"price-asc":key=="online"?"true":"";
        c.page=1;c.refresh();dirty=true;
    }
    function filters():Void {
        var f=c.filters, root=frame.container;
        card(root,16,64,1072,c.filtersExpanded?260:96,0xDCCAB5);
        labelAt(root,"Search items",28,80,792,false,MUTED);
        input(f["search"],28,108,792,s->f["search"]=s.substr(0,100),"Item name...",()->filter("search",f["search"]));
        button("Search",836,108,96,()->filter("search",f["search"]),"");
        button(c.filtersExpanded?"Hide filters":"Show filters",948,108,128,c.toggleFilters,"");
        if(!c.filtersExpanded)return;
        var cats=["","Components","Equipment","Consumables","Collections","Containers","Miscellaneous"];
        dropdown("Category",cats,["All items"].concat(cats.slice(1)),f["category"],28,190,256,s->filter("category",s));
        var subs=[""].concat(subcategories(f["category"]));
        dropdown("Subcategory",subs,["All subcategories"].concat(subs.slice(1)),f["subcategory"],300,190,312,s->filter("subcategory",s));
        var rarities=["","Common","Uncommon","Rare","Epic","Legendary"];
        dropdown("Rarity",rarities,["Any rarity"].concat(rarities.slice(1)),f["rarity"],628,190,210,s->filter("rarity",s));
        dropdown("Pricing",["","fixed","offers"],["Any price","Fixed price","Open to offers"],f["pricing"],854,190,222,s->filter("pricing",s));
        checkbox("Online only",f["online"]=="true",756,272,156,value->filter("online",value?"true":"false"));
        button("Clear filters",928,272,148,resetFilters,"");
        labelAt(root,"Class",28,244,464,false,MUTED);
        for(i in 0...4) {
            var name=["Warrior","Rogue","Mage","Priest"][i],selected=f["classes"].split(",").indexOf(name)>=0;
            button(name,28+i*116,272,108,()->{
                var classes=f["classes"].split(",").filter(s->s!="");
                if(classes.indexOf(name)>=0)classes.remove(name);else classes.push(name);
                filter("classes",classes.join(","));
            },selected?"unaccept":"",f["category"]==""||f["category"]=="Equipment");
        }
    }

    function row(item:TradeItem,y:Int,height:Int,price:String,seller:String,rarity:String,online:Bool,action:Void->Void,selected:Bool,?listingPrice:Dynamic):Void {
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
        var iconY=Std.int((height-4-44)/2);
        stage="item row icon";
        itemIcon(row,item,8,iconY,44);
        stage="item row labels";
        var rarityLabel=rarity==""?null:labelAt(row,rarity,64,0,90,true,rarityColor(rarity),true);
        var nameX=rarity==""?64:162;
        var nameRight=c.tab=="Sell"?484:414;
        var nameLabel=labelAt(row,item.name+(item.count>1?" ×"+item.count:""),nameX,0,nameRight-nameX,true,INK,true);
        largeLabel(nameLabel);
        var sellerLabel=c.tab=="Sell"?labelAt(row,seller,64,0,270,false,MUTED,true):null;
        if(c.tab!="Sell")sellerLine(row,seller,online,64,33,350);
        var priceLabel:Dynamic=null;
        if(c.tab=="Sell") {priceLabel=labelAt(row,price,502,0,166,true,INK,true);largeLabel(priceLabel);rightText(priceLabel,166);}
        else priceDisplay(row,listingPrice,428,Std.int((height-4-28)/2),240,true);
        afterReflow(row,()->{
            if(rarityLabel!=null)centerControlText(rarityLabel,24,64,5);
            centerControlText(nameLabel,24,nameX,5);
            if(sellerLabel!=null)centerControlText(sellerLabel,24,64,33);
            if(priceLabel!=null){centerControlText(priceLabel,height-4,502);position(priceLabel,502,G.number(G.field(priceLabel,"y")));}
        });
        G.call("ui.UIElement","set_onClick",row,[()->{if(!c.busy)action();}]);
        partialRow=null;
    }
    function priceDisplay(parent:Dynamic,value:Dynamic,x:Int,y:Int,width:Int,right=false):Void {
        if(value==null||G.field(value,"mode")=="offers") {
            var label=labelAt(parent,MarketText.price(value),x,y,width,true,INK,true);
            if(right)rightText(label,width);
            centerControlText(label,28,x,y);if(right)position(label,x,G.number(G.field(label,"y")));
        } else currencyLine(parent,G.integer(G.field(value,"silverTrays")),x,y,width,false,right);
    }
    /** Reuses the native item artwork and existing text objects when the price changes. */
    function currencyLine(parent:Dynamic,amount:Int,x:Int,y:Int,width:Int,conversion=false,right=false):Int->Void {
        var box=G.field(node("element",G.field(parent,"dom"),[],"marketMoney"+(sequence++)),"obj");
        absolute(parent,box);padding(box,0);size(box,width,28);position(box,x,y);
        var content=G.field(node("element",G.field(box,"dom"),[],"marketMoneyContent"+(sequence++)),"obj");
        absolute(box,content);padding(content,0);
        var first=labelAt(content,"",0,0,600,!conversion,conversion?MUTED:INK,true);
        var firstIcon=currencyIcon(content,conversion?"SilverTray":"Gold");
        var separator=labelAt(content,conversion?"=":"/",0,0,30,!conversion,conversion?MUTED:INK,true);
        var second=labelAt(content,"",0,0,600,!conversion,conversion?MUTED:INK,true);
        var secondIcon=currencyIcon(content,conversion?"Gold":"SilverTray");
        function layout():Void {
            var cursor=0.0;
            for(part in [first,firstIcon,separator,second,secondIcon]) {
                if(part==null)continue;
                if(part==firstIcon||part==secondIcon) {position(part,cursor,2);cursor+=20;}
                else {
                    centerDropdownCaption(part,24,cursor);
                    var bounds=G.call("h2d.Object","getSize",part,[null]);
                    cursor+=(G.number(G.field(bounds,"xMax"))-G.number(G.field(bounds,"xMin")))*G.number(G.field(part,"scaleX"),1);
                }
                cursor+=5;
            }
            var scale=Math.min(1,width/Math.max(1,cursor-5));
            G.call("h2d.Object","setScale",content,[scale]);position(content,right?width-(cursor-5)*scale:0,(28-24*scale)/2);
        }
        function update(value:Int):Void {
            setText(first,conversion?MarketText.count(value,"Silver Tray"):MarketText.number(value*500));
            setText(second,conversion?MarketText.number(value*500)+" gold":MarketText.number(value));
            layout();
        }
        afterReflow(box,layout);
        update(amount);
        return update;
    }
    function currencyIcon(parent:Dynamic,kind:String):Dynamic {
        var definition=TradeInventory.definition(kind);
        if(definition==null)return null;
        var bitmap=G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[definition]),parent]);
        absolute(parent,bitmap);G.set(bitmap,"smooth",true);
        G.call("h2d.Bitmap","set_width",bitmap,[20.0]);G.call("h2d.Bitmap","set_height",bitmap,[20.0]);
        return bitmap;
    }
    function headerCart():Void {
        try cart=new MarketCartIcon(frame.header,G.field(frame.ui,"windows"))catch(error:Dynamic){report("cart icon",error);return;}
        afterReflow(frame.header,()->{
            if(cart==null)return;
            var title=frame.title,bounds=G.call("h2d.Object","getBounds",title,[title,null]);
            var sx=G.number(G.field(title,"scaleX"),1),sy=G.number(G.field(title,"scaleY"),1);
            position(cart.bitmap,G.number(G.field(title,"x"))+G.number(G.field(bounds,"xMax"))*sx+8,
                G.number(G.field(title,"y"))+(G.number(G.field(bounds,"yMin"))+G.number(G.field(bounds,"yMax")))*sy/2-14);
            cart.tint(G.integer(G.field(title,"textColor"),INK));
        });
    }
    static function polygon(graphics:Dynamic,points:Array<Float>,tint:Int,opacity=1.0):Void {
        #if hl
        var color:hl.Ref<Int>=tint,alpha:hl.Ref<Float>=opacity;
        #else
        var color=tint,alpha=opacity;
        #end
        G.call("h2d.Graphics","beginFill",graphics,[color,alpha]);
        G.call("h2d.Graphics","moveTo",graphics,[points[0],points[1]]);
        for(i in 1...Std.int(points.length/2))G.call("h2d.Graphics","lineTo",graphics,[points[i*2],points[i*2+1]]);
        G.call("h2d.Graphics","lineTo",graphics,[points[0],points[1]]);
        G.call("h2d.Graphics","endFill",graphics);
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
        G.call("ui.UIElement","set_getTip",object,[()->TradeTooltips.create(item,c.tab=="Sell"?MarketInventory.source(c.inv,item.uid,c.bankOnly):null)]);
        G.set(object,"showTipOnOver",true);style(object,"show-tip-on-over",true);
    }
    function selectedItem(item:TradeItem):Void {
        var root=frame.container, y=contentY+58;
        var details=G.field(node("element",G.field(root,"dom"),[],"marketDetails"+(sequence++)),"obj");
        absolute(root,details);padding(details,0);size(details,316,164);position(details,754,y);
        var picture=G.field(node("element",G.field(details,"dom"),[],"marketDetailsIcon"+(sequence++)),"obj");
        absolute(details,picture);padding(picture,0);size(picture,60,60);position(picture,0,0);
        // set_getTip installs UIElement hover handlers; enabling only the base Flow skips them.
        itemIcon(picture,item,0,0,60);
        tooltip(picture,item);
        var name=labelAt(details,item.name,72,0,244,true);
        largeLabel(name);G.call("h2d.Text","set_wordBreak",name,[true]);
        var quantityLabel=labelAt(details,"Quantity: "+item.count,72,0,244,false,MUTED);
        var rarity=item.detail.split("\n")[0];
        var rarityLabel=["Common","Uncommon","Rare","Epic","Legendary"].indexOf(rarity)<0?null:
            labelAt(details,rarity,72,0,244,true,rarityColor(rarity));
        afterReflow(details,()->{
            var bounds=G.call("h2d.Object","getSize",name,[null]);
            var below=G.number(G.field(name,"y"))+G.number(G.field(bounds,"yMax"),22)+10;
            position(quantityLabel,72,below);
            if(rarityLabel!=null)position(rarityLabel,72,below+24);
        });
    }
    function emptyList():Void {
        var root=frame.container, y=contentY+Std.int((806-contentY)/2)-40;
        labelAt(root,c.busy?"Finding listings...":c.tab=="Sell"?"No tradable items":c.tab=="My listings"?"No active listings":"No listings found",64,y,596,true);
        labelAt(root,c.tab=="Sell"?"Unlocked items that can be traded will appear here.":c.tab=="My listings"?c.ready?"Select Sell to create your first listing.":"Sign in with Steam to view and manage your listings.":"Try another search or clear your filters. New listings will appear here as players add them.",64,y+32,560,false,MUTED);
        if(!c.busy&&c.tab=="My listings"&&c.ready)button("Sell",64,y+94,152,()->c.chooseTab("Sell"),"");
    }
    function priceFields(y:Int):Void {
        labelAt(frame.container,"Price for the entire listing",754,y,316,true);
        button(offers?"Open to offers":"Fixed price",754,y+28,316,()->{offers=!offers;dirty=true;},offers?"unaccept":"");
        if(!offers) {
            var conversion=currencyLine(frame.container,int(trays),754,y+120,316,true);
            var box=counter(trays,754,y+76,132,200000,s->{
                trays=s.substr(0,6);conversion(int(trays));
            });
            var unit=labelAt(frame.container,"Silver Trays",900,y+76,170,true);
            afterReflow(box,()->centerControlText(unit,36,900,y+76));
        } else labelAt(frame.container,"Buyers can contact you to agree on a price.",754,y+78,316,false,MUTED);
    }
    function sellPanel():Void {
        if(c.chosen==null)return;
        selectedItem(c.chosen);
        line(frame.container,754,contentY+224,316);
        labelAt(frame.container,"Quantity to sell",754,contentY+246,316,true);
        counter(quantity,754,contentY+274,132,Std.int(Math.min(10000,c.chosen.count)),s->quantity=s);
        labelAt(frame.container,"of "+c.chosen.count+" available",900,contentY+282,170,false,MUTED);
        priceFields(contentY+334);
        button("List item for sale",754,752,316,()->c.list(int(quantity),int(trays),offers),"accept");
    }
    function listingPanel():Void {
        if(c.selected==null)return;
        var row=c.selected;try selectedItem(MarketExport.offer(row))catch(error:Dynamic){report("selected item details",error);}
        if(c.tab=="My listings") {
            labelAt(frame.container,"Expires "+MarketText.expiry(G.text(row.expiresAt)),754,contentY+222,316,false,MUTED);
            labelAt(frame.container,"Asking price:",754,contentY+260,316,true);
            priceDisplay(frame.container,row.price,754,contentY+288,316);
            button("Remove listing",754,752,316,c.remove,"cancel");
        } else {
            line(frame.container,754,contentY+222,316);
            sellerLine(frame.container,G.text(row.seller.characterName),isOnline(row),754,contentY+238,316,true);
            labelAt(frame.container,"Asking price:",754,contentY+278,316,true);
            priceDisplay(frame.container,row.price,754,contentY+306,316);
            button(row.seller.accountId==c.account?"Your listing":"Whisper seller",754,752,316,c.contact,"accept",row.seller.accountId!=c.account);
        }
    }
    function sellerLine(parent:Dynamic,name:String,online:Bool,x:Int,y:Int,width:Int,bold=false):Void {
        var box=G.field(node("element",G.field(parent,"dom"),[],"marketSeller"+(sequence++)),"obj");
        absolute(parent,box);padding(box,0);size(box,width,24);position(box,x,y);
        var caption=labelAt(box,"Seller: "+name,0,0,width-18,bold,bold?INK:MUTED,true);
        var dot=graphic(box);
        rounded(dot,0,0,10,10,5,online?0x426138:0x888888);
        afterReflow(box,()->{
            centerDropdownCaption(caption,24,0);
            var bounds=G.call("h2d.Object","getBounds",caption,[caption,null]);
            var right=G.number(G.field(caption,"x"))+G.number(G.field(bounds,"xMax"))*G.number(G.field(caption,"scaleX"),1);
            position(dot,Math.min(width-10,Math.round(right)+6),7);
        });
    }
    function checkbox(text:String,value:Bool,x:Int,y:Int,width:Int,changed:Bool->Void):Void {
        var root=frame.container,box=G.field(node("check-box",G.field(root,"dom"),[text],"marketCheck"+(sequence++)),"obj");
        absolute(root,box);size(box,width,36);position(box,x,y);
        padding(box,0);G.call("h2d.Flow","set_paddingLeft",box,[12]);style(box,"padding-left",12);
        G.call("h2d.Flow","set_paddingRight",box,[12]);style(box,"padding-right",12);
        G.call("ui.comp.CheckBox","set_selected",box,[value]);
        textColor(G.field(box,"fmtText"),0xF5F0E8);
        afterReflow(box,()->{
            var caption=G.field(box,"fmtText");
            if(caption!=null) {
                // CheckBox creates/replaces its label during native initialization.
                var tint=G.field(caption,"color");
                if(tint!=null)for(channel in ["x","y","z"])G.set(tint,channel,1.0);
                G.call("h2d.HtmlText","set_textColor",caption,[0xF5F0E8]);
            }
        });
        G.call("ui.UIElement","set_enable",box,[true]);
        G.set(box,"onValueChange",(selected:Bool)->{
            if(c.busy)G.call("ui.comp.CheckBox","set_selected",box,[value]);else changed(selected);
        });
    }
    static function afterReflow(object:Dynamic,layout:Void->Void):Void {
        var previous=G.field(object,"onAfterReflow");
        G.set(object,"onAfterReflow",()->{
            if(previous!=null)Reflect.callMethod(object,previous,[]);
            layout();
        });
        layout();
    }
    static function centerControlText(text:Dynamic,height:Int,left:Float,top:Float=0):Void {
        var bounds=G.call("h2d.Object","getSize",text,[null]);
        var yMin=G.number(G.field(bounds,"yMin")),yMax=G.number(G.field(bounds,"yMax"),18);
        position(text,left-G.number(G.field(bounds,"xMin")),top+Math.floor((height-(yMax-yMin))/2)-yMin);
    }
    static function centerDropdownCaption(text:Dynamic,height:Int,left:Float):Void {
        // getSize() deliberately uses y=0 and calcSizeHeight (line box). getBounds()
        // uses calcYMin/calcHeight, including the glyph offset that made captions low.
        if(G.field(text,"needUpdateScale")==true) {
            G.call("ui.comp.FmtText","updateScale",text);
            G.set(text,"needUpdateScale",false);
        }
        var bounds=G.call("h2d.Object","getBounds",text,[text,null]);
        var sx=G.number(G.field(text,"scaleX"),1),sy=G.number(G.field(text,"scaleY"),1);
        var top=G.number(G.field(bounds,"yMin"))*sy,bottom=G.number(G.field(bounds,"yMax"),18)*sy;
        position(text,left-G.number(G.field(bounds,"xMin"))*sx,Math.round((height-bottom+top)/2)-top);
    }
    function showConnectionError():Void {
        connectionNoticeShown=true;
        try {
            var buttons=G.call("hl.types.ArrayObj","slice",G.field(frame.ui,"windows"),[0,0]);
            G.call("hl.types.ArrayObj","pushDyn",buttons,[{ic:"Confirm",input:null,checkEnable:null,onBack:true}]);
            connectionDialog=G.call("ui.BaseUI","displayDialog",frame.ui,["Marketplace connection",escape(MarketText.CONNECTION_ERROR),buttons,function(_:String):Void {connectionDialog=null;}]);
            if(connectionDialog!=null)G.call("ui.comp.Button","setText",G.call("hl.types.ArrayObj","getDyn",G.field(connectionDialog,"buttons"),[0]),["OK"]);
        }catch(error:Dynamic) {report("connection notice",error);c.message=MarketText.CONNECTION_ERROR;dirty=true;}
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
    static function rightText(obj:Dynamic,width:Int):Void {
        var align=G.enumeration("h2d.Align","Right");
        G.call("h2d.Text","set_textAlign",obj,[align]);style(obj,"text-align",align);
        G.call("h2d.Text","set_maxWidth",obj,[width*1.0]);
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
