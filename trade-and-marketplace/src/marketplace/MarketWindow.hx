package marketplace;

import trade.GameAccess as G;
import trade.TradeUi.*;
import trade.TradeFrame.*;
import trade.TradeTypes;
import trade.TradeInventory;
import trade.TradeTooltips;

/** Native controls with explicit inner bounds; dropdown lists live above the window. */
class MarketWindow {
    static inline var INK = 0x5B4334;
    static inline var MUTED = 0x806B5B;
    static inline var PAPER = 0xEFE3D1;
    static inline var EDGE = 0xB69B7F;
    static inline var LEVEL_X = 420;
    static inline var LEVEL_WIDTH = 84;
    final c:MarketController;
    var frame:trade.TradeFrame;
    var cart:MarketCartIcon;
    final badges=new MarketBadges();
    var backdrop:Dynamic;
    final drawer=new MarketDrawer();
    var drawerTab="";
    var closingListing:Dynamic;
    var detailLayer:Dynamic;
    var detailClip:Dynamic;
    var detailBackdrop:Dynamic;
    var tableLayouts:Array<Int->Void>=[];
    var tableExtra=0;
    var listingViewport:Dynamic;
    var listingContent:Dynamic;
    var listingScrollbar:MarketScrollbar;
    var listingScrollState:{offset:Float};
    var listingScrollRestored=false;
    var listingData:Array<Dynamic>=[];
    var listingStart=-1;
    var listingEnd=-1;
    var rowLayouts:Array<Int->Void>=[];
    var rowPresence:Array<Void->Void>=[];
    static inline var ROW_HEIGHT=68;
    var presenceLabels:Array<Void->Void>=[];
    var presenceCheckAt=0.0;
    var controls:Array<Dynamic> = [];
    var searchClearButtons:Array<{box:Dynamic,button:Dynamic}>=[];
    final filterControls=new MarketFilterControls();
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
    var buyViewport:Dynamic;
    var buyContent:Dynamic;
    var buyScrollbar:MarketScrollbar;
    var buyScrollState:{offset:Float};
    var buyScrollRestored=false;
    var buyItems:Array<MarketBuy.CatalogItem>=[];
    var buyStart=-1;
    var buyEnd=-1;
    var inventoryViewport:Dynamic;
    var sellScrollbar:MarketScrollbar;
    var inventoryScroll=0.0;
    var inventoryScrollKey="";
    static inline var SELL_FORM_Y=500;
    var stage = "initialization";
    var recovery = false;
    var partialRow:Dynamic;
    var reported:Map<String,Bool> = [];
    public var dirty = true;

    public function new(controller:MarketController) c = controller;
    public function isOpen():Bool return shown;
    public function open():Void { shown = true; connectionNoticeShown=false; recovery = false; dirty = true; }
    public function close():Void {
        rememberInventoryScroll();rememberListingScroll();rememberBuyScroll();
        sellScrollbar=null;listingScrollbar=null;buyScrollbar=null;
        shown = false; closeDropdowns();
        filterControls.clear();searchClearButtons=[];
        if(cart!=null){cart.dispose();cart=null;}
        backdrop=null;presenceLabels=[];detailLayer=detailClip=detailBackdrop=null;tableLayouts=[];drawerTab="";closingListing=null;
        if(connectionDialog!=null&&frame!=null&&G.field(connectionDialog,"allocated")==true)
            G.call("ui.BaseUI","removeWindow",frame.ui,[connectionDialog]);
        connectionDialog=null;
        if (frame != null) {
            var old=frame;frame=null;px=old.x;py=old.y;
            old.dispose();
        }
        badges.dispose();
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
        advanceDetails(haxe.Timer.stamp());
        var now=Date.now().getTime()/1000;
        if(now>=presenceCheckAt){presenceCheckAt=now+1;for(refresh in presenceLabels)refresh();}
        stage="listing scroll";
        updateListingRows();updateBuyGrid();
        stage="window layout";frame.layout();
        if(listingViewport!=null&&listingScrollRestored) {
            var offset=G.number(G.field(listingViewport,"scrollPosY"));
            var height=G.number(G.call("h2d.Flow","get_outerHeight",listingViewport));
            if(height>0&&offset+height+ROW_HEIGHT*2>=listingData.length*ROW_HEIGHT)c.loadMore();
        }
        if(buyScrollbar!=null)try buyScrollbar.update() catch(error:Dynamic){report("Buy scrollbar skin",error);buyScrollbar=null;}
        if(listingScrollbar!=null)try listingScrollbar.update() catch(error:Dynamic) {
            report("Listing scrollbar skin",error);listingScrollbar=null;
        }
        // Skin only. If it fails, do not take down the marketplace or native
        // scrollbar input; the existing viewport remains intact.
        if(sellScrollbar!=null)try sellScrollbar.update() catch(error:Dynamic) {
            report("Sell scrollbar skin",error);
            sellScrollbar=null;
        }
        stage="dropdown input";dismissOutsideDropdowns();
        if(c.tab!="Buy"&&c.connectionIssue&&!c.signingIn&&!connectionNoticeShown)showConnectionError();
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
        presenceLabels=[];tableLayouts=[];detailLayer=detailClip=detailBackdrop=null;
        var now=haxe.Timer.stamp(),changedTab=drawerTab!=c.tab;
        drawer.set(c.tab!="Buy"&&c.selected!=null,now,changedTab);drawer.update(now);
        if(changedTab)closingListing=null;
        drawerTab=c.tab;
        if(c.selected!=null)closingListing=c.selected;
        if(drawer.value==0&&c.selected==null)closingListing=null;
        tableExtra=c.tab=="Sell"||c.tab=="Buy"?0:Math.round(368*(1-drawer.value));
        stage="clear old controls";
        rememberInventoryScroll();rememberListingScroll();rememberBuyScroll();
        closeDropdowns();
        if(changedTab)filterControls.clear();
        filterControls.begin();
        var keepScrollbar=c.tab=="Sell"&&!recovery,keepListingScrollbar=(c.tab=="Browse"||c.tab=="My listings")&&!recovery;
        var keepBuyScrollbar=c.tab=="Buy"&&!recovery;
        for (child in children(frame.container))
            if(child!=backdrop&&!filterControls.contains(child)
                &&!(keepScrollbar&&sellScrollbar!=null&&sellScrollbar.owns(child))
                &&!(keepListingScrollbar&&listingScrollbar!=null&&listingScrollbar.owns(child))
                &&!(keepBuyScrollbar&&buyScrollbar!=null&&buyScrollbar.owns(child)))
                G.call("h2d.Object", "remove", child);
        if(!keepScrollbar)sellScrollbar=null;
        if(!keepListingScrollbar)listingScrollbar=null;
        if(!keepBuyScrollbar)buyScrollbar=null;
        var root = frame.container;
        // Keep one background below the retained inputs. Inserting new cards into
        // a native Flow during refresh can put them over its first controls.
        if(backdrop==null)backdrop=graphic(root);
        else G.call("h2d.Graphics","clear",backdrop);
        if(recovery) {
            filterControls.finish();
            stage="recovery screen";
            labelAt(root,"The marketplace could not display this page.",28,38,1000,true);
            labelAt(root,"Any listing already submitted is kept. You can reload the page or switch tabs below.",28,78,1000);
            button("Browse",28,130,190,()->{recovery=false;c.chooseTab("Browse");},"");
            button("Sell",234,130,190,()->{recovery=false;c.chooseTab("Sell");},"");
            button("Buy",440,130,190,()->{recovery=false;c.chooseTab("Buy");},"");
            button("My listings",646,130,190,()->{recovery=false;c.chooseTab("My listings");},"");
            labelAt(root,"The underlying error was recorded in the HLX log.",28,196,1000,false,MUTED);
            return;
        }
        stage="navigation and filters";
        for (i in 0...4) {
            var title = ["Browse", "Sell", "Buy", "My listings"][i];
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
        if(c.tab=="My listings")labelAt(root,"You can have up to 20 active listings per region. Listings expire 3 days after posting.",20,76,1064,false,MUTED);
        if(c.tab=="Sell") {
            tabButton("Inventory",20,68,150,()->c.setBankOnly(false),!c.bankOnly);
            tabButton("Bank",182,68,150,()->c.setBankOnly(true),c.bankOnly);
            filterControls.active=true;
            var search=input(c.sellSearch,352,68,724,s->{c.sellSearch=s.substr(0,100);c.searchInventory();},"Search items to sell...",null,true);
            filterControls.active=false;
            // Keep the same focused input across live grid refreshes. Enter is
            // deliberately inert rather than submitting/blurring the text box.
            G.set(G.field(search,"input"),"ignoreEnter",true);
            G.set(G.field(search,"input"),"onEnter",function():Void {});
            labelAt(root,"Choose an unlocked, tradable item to list on the marketplace. It won't be removed from your inventory until you trade it.",20,116,1064,false,MUTED);
        }
        contentY = c.tab == "Buy"?(c.buy.expanded?368:176):c.tab == "Browse" ? (c.filtersExpanded?340:176) : 146;
        if (c.tab == "Browse") {
            filterControls.active=true;
            try filters()catch(error:Dynamic){filterControls.active=false;throw error;}
        }
        if(c.tab=="Buy") {
            filterControls.active=true;
            try buyFilters()catch(error:Dynamic){filterControls.active=false;throw error;}
        }
        filterControls.finish();
        searchClearButtons=searchClearButtons.filter(entry->G.field(entry.box,"parent")!=null);
        if(c.tab=="Sell") {
            card(16,contentY,704,806-contentY);card(736,contentY,352,806-contentY);
            labelAt(root,c.bankOnly?"YOUR BANK":"YOUR INVENTORY",32,contentY+16,420,true);
            labelAt(root,"ITEM DETAILS",754,contentY+16,184,true);searchItemButton();
            line(root,30,contentY+42,676);line(root,750,contentY+42,324);
            inventoryGrid();sellPanel();
        } else if(c.tab=="Buy") {
            card(16,contentY,704,806-contentY);card(736,64,352,742);
            labelAt(root,"ALL ITEMS",32,contentY+16,420,true);
            labelAt(root,"ITEM DETAILS",754,80,316,true);
            line(root,30,contentY+42,676);line(root,750,106,324);
            catalogGrid();buyPanel();
        } else {
            var tableBackground=graphic(root);
            tableLayouts.push(extra->{
                G.call("h2d.Graphics","clear",tableBackground);
                rounded(tableBackground,16,contentY,704+extra,806-contentY,8,EDGE);
                rounded(tableBackground,17,contentY+1,702+extra,804-contentY,7,PAPER);
                rounded(tableBackground,30,contentY+42,676+extra,1,0,0xCFB99D);
            });
            labelAt(root,"ITEM",32,contentY+16,420,true);
            sortHeader("LEVEL","required-level",LEVEL_X,LEVEL_WIDTH,c.sortByLevel);
            sortHeader("TOTAL PRICE","price",512,168,c.sortByPrice,true);
            listingRows();
            if(closingListing!=null) {
                // Native UIElement ancestry supplies the window's fonts and button
                // styles. Hidden overflow clips drawing without breaking that chain.
                var previous=children(root);
                detailClip=G.field(node("element",G.field(root,"dom"),[],"marketDetailsClip"),"obj");
                absolute(root,detailClip);padding(detailClip,0);size(detailClip,1104,888);position(detailClip,0,0);
                var hidden=G.enumeration("h2d.FlowOverflow","Hidden");
                G.call("h2d.Flow","set_overflow",detailClip,[hidden]);style(detailClip,"overflow",hidden);
                detailLayer=G.field(node("element",G.field(detailClip,"dom"),[],"marketDetailsDrawer"),"obj");
                absolute(detailClip,detailLayer);padding(detailLayer,0);size(detailLayer,1104,888);
                detailBackdrop=graphic(root);
                rounded(detailBackdrop,736,contentY,352,806-contentY,8,EDGE);
                rounded(detailBackdrop,737,contentY+1,350,804-contentY,7,PAPER);
                labelAt(root,"ITEM DETAILS",754,contentY+16,184,true);
                line(root,750,contentY+42,324);
                stage="selected listing";listingPanel(closingListing);
                for(child in children(root))if(child!=detailClip&&previous.indexOf(child)<0) {
                    G.call("h2d.Object","addChild",detailLayer,[child]);
                    absolute(detailLayer,child);
                }
            }
            applyDetailsLayout();
        }
        stage="footer";
        if (c.total == 0 && c.tab!="Sell"&&c.tab!="Buy") emptyList();
        if(c.tab=="Sell") {
            if(c.bankOnly&&c.bankNames.length>0) {
                for(i in 0...Std.int(Math.min(4,c.bankNames.length)))
                    tabButton(c.bankNames[i],16+i*176,820,166,()->c.setBankTab(i),c.bankTab==i);
            }
        } else if(c.tab=="Buy")labelAt(root,c.buy.visible.length+" items",20,830,850,false,MUTED);
        else {
            if(c.loadMoreFailed()) {
                button("Retry",16,820,118,()->c.loadMore(true),"");
                labelAt(root,"Could not load more listings.",152,830,700,false,MUTED);
            } else labelAt(root,c.loadingMore()?"Loading more listings…":c.total+" listing"+(c.total==1?"":"s"),20,830,850,false,MUTED);
        }
        button("Refresh",970,820,118,c.refresh,"",true,true);
        var message = c.tab=="Buy"?"":c.message;
        if (message == "Loading..." || message == "No matching listings." || message == "Listings updated." || message == "Connected to Fareverly.") message = "";
        if (message != "") labelAt(root,message.split("\n").join(" "),20,862,1064,false,INK,true);
    }
    function listingRows():Void {
        var root=frame.container;
        var viewport=G.field(node("flow",G.field(root,"dom"),[],"marketListingViewport"+(sequence++),"vertical"),"obj");
        absolute(root,viewport);padding(viewport,0);size(viewport,692,806-contentY-60);position(viewport,22,contentY+48);
        var vertical=G.enumeration("h2d.FlowLayout","Vertical"),scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_layout",viewport,[vertical]);style(viewport,"layout",vertical);
        G.call("h2d.Flow","set_multiline",viewport,[false]);style(viewport,"multiline",false);
        G.call("h2d.Flow","set_overflow",viewport,[scroll]);style(viewport,"overflow",scroll);
        var content=G.field(node("element",G.field(viewport,"dom"),[],"marketListingRows"+(sequence++)),"obj");
        listingData=c.rows.copy();
        padding(content,0);size(content,674,listingData.length*ROW_HEIGHT);alignScrollContent(viewport,content);
        listingViewport=viewport;listingContent=content;listingScrollState=c.listingScrollState();
        listingScrollRestored=false;listingStart=listingEnd=-1;rowLayouts=[];rowPresence=[];
        tableLayouts.push(extra->{
            size(viewport,692+extra,806-contentY-60);size(content,674+extra,listingData.length*ROW_HEIGHT);
            inventoryScrollbar(viewport,692+extra);
        });
        inventoryScrollbar(viewport,692+tableExtra);
        if(listingScrollbar==null||!listingScrollbar.attachedTo(root))listingScrollbar=new MarketScrollbar(root);
        listingScrollbar.bind(viewport,content);
        var saved=listingScrollState.offset,previous=G.field(viewport,"onAfterReflow");
        G.set(viewport,"onAfterReflow",()->{
            if(previous!=null)Reflect.callMethod(viewport,previous,[]);
            if(!listingScrollRestored){listingScrollRestored=true;G.call("h2d.Flow","set_scrollPosY",viewport,[saved]);}
        });
        updateListingRows();
    }
    function updateListingRows():Void {
        if(listingViewport==null||listingContent==null)return;
        var height=806-contentY-60;
        var offset=listingScrollRestored?G.number(G.field(listingViewport,"scrollPosY")):listingScrollState.offset;
        offset=Math.max(0,Math.min(offset,Math.max(0,listingData.length*ROW_HEIGHT-height)));
        var start=Std.int(Math.max(0,Math.floor(offset/ROW_HEIGHT)-2));
        var end=Std.int(Math.min(listingData.length,Math.ceil((offset+height)/ROW_HEIGHT)+2));
        if(start==listingStart&&end==listingEnd)return;
        listingStart=start;listingEnd=end;
        for(layout in rowLayouts)tableLayouts.remove(layout);
        for(refresh in rowPresence)presenceLabels.remove(refresh);
        for(child in children(listingContent))G.call("h2d.Object","remove",child);
        var layouts=tableLayouts.length,presence=presenceLabels.length;
        for(i in start...end)savedRow(listingData[i],i*ROW_HEIGHT,ROW_HEIGHT,i,listingContent);
        rowLayouts=tableLayouts.slice(layouts);rowPresence=presenceLabels.slice(presence);
        for(layout in rowLayouts)layout(tableExtra);
    }
    function savedRow(listing:Dynamic,y:Int,height:Int,index:Int,parent:Dynamic):Void {
        stage="listing "+(index+1)+" data";
        var select=()->c.toggleListing(listing);
        try {
            var item=MarketExport.offer(listing);
            var price:Dynamic=G.field(listing,"price"),seller:Dynamic=G.field(listing,"seller");
            var priceText=MarketText.price(price);
            row(item,y,height,priceText,G.text(G.field(seller,"characterName")),G.text(G.field(G.field(listing,"item"),"rarity")),c.listingOnline(listing),select,c.selected==listing,price,G.field(G.field(listing,"item"),"requiredLevel"),parent,listing);
        } catch(error:Dynamic) {
            report(stage,error);
            if(partialRow!=null) {try G.call("h2d.Object","remove",partialRow)catch(_:Dynamic){}partialRow=null;}
            // Keep the listing selectable/removable even if its icon or tooltip cannot be drawn.
            var name=G.text(G.field(G.field(listing,"item"),"name"),"Listing");
            var fallback=button(name.substr(0,55)+" — details unavailable",6,y,664,select,"");
            G.call("h2d.Object","addChild",parent,[fallback]);absolute(parent,fallback);
            tableLayouts.push(extra->size(fallback,664+extra,36));
        }
    }

    function button(label:String,x:Int,y:Int,width:Int,action:Void->Void,kind:String,enabled=true,whileLoading=false):Dynamic {
        var click=()->{if((!c.busy||whileLoading||c.tab=="Buy")&&enabled)action();};
        var obj=filterControls.get("button:"+x+":"+y,()->frame.button(label,x,y,width,click,kind));
        setText(G.field(obj,"btnText"),label);trade.TradeFrame.setClass(obj,kind);
        G.call("ui.UIElement","set_onClick",obj,[click]);
        G.call("ui.UIElement", "set_enable", obj, [enabled]); return obj;
    }
    function tabButton(label:String,x:Int,y:Int,width:Int,action:Void->Void,selected:Bool):Void {
        // Match Better Mod Settings' native brown selected state.
        G.call("ui.UIElement","set_selected",button(label,x,y,width,action,"",true,true),[selected]);
    }
    function sortHeader(title:String,column:String,x:Int,width:Int,action:Void->Void,right=false):Void {
        var root=frame.container;
        var header=G.field(node("element",G.field(root,"dom"),[],"marketSort"+column),"obj");
        absolute(root,header);padding(header,0);size(header,width,36);position(header,x,contentY+4);
        tableLayouts.push(extra->position(header,x+extra,contentY+4));
        var order=c.listingSort();
        var caption=labelAt(header,title+(order==column+"-asc"?" ↑":order==column+"-desc"?" ↓":""),0,12,width,true);
        if(right)rightText(caption,width);
        else afterReflow(header,()->centerTextX(caption,0,width));
        G.call("ui.UIElement","set_onClick",header,[action]);
    }
    function searchItemButton():Void {
        var control=button("",1048,contentY+7,28,c.searchSelectedItem,"",c.chosen!=null);
        padding(control,0);size(control,28,28);
        var icon=graphic(control);
        // A small ring and handle stay crisp without relying on a font glyph.
        for(i in 0...32) {
            var a=i*Math.PI/16,b=(i+1)*Math.PI/16;
            polygon(icon,[12+6*Math.cos(a),11+6*Math.sin(a),12+6*Math.cos(b),11+6*Math.sin(b),
                12+4*Math.cos(b),11+4*Math.sin(b),12+4*Math.cos(a),11+4*Math.sin(a)],0xF5F0E8);
        }
        polygon(icon,[15,16,17,14,23,20,21,22],0xF5F0E8);
    }
    function input(value:String,x:Int,y:Int,width:Int,changed:String->Void,hint="",?submit:Void->Void,clearable=false):Dynamic {
        var root=frame.container;
        var box=filterControls.get("input:"+x+":"+y,()->{
            var box = G.field(node("input-box",G.field(root,"dom"),[],"marketInput"+(sequence++)),"obj");
            absolute(root,box); padding(box,0); size(box,width,36); position(box,x,y);
            var input = G.field(box,"input");
            style(input,"width",width-(clearable?52:20)); style(input,"color",0xF5F0E8);
            G.call("ui.comp.InputBox","set_hintText",box,[hint]); style(G.field(box,"inputHint"),"color",0xE0D8CD);
            for(text in [input,G.field(box,"inputHint")]) {
                absolute(G.field(text,"parent"),text);centerControlText(text,36,12);
                G.call("h2d.Text","set_maxWidth",text,[(width-(clearable?56:24))*1.0]);style(text,"width",width-(clearable?56:24));
            }
            afterReflow(box,()->{
                for(text in [input,G.field(box,"inputHint")])centerControlText(text,36,12);
            });
            return box;
        });
        var input=G.field(box,"input");
        if(G.text(G.field(input,"text"))!=value)G.call("h2d.TextInput","set_text",input,[value]);
        var clear:Dynamic=null;
        if(clearable) {
            for(entry in searchClearButtons)if(entry.box==box)clear=entry.button;
            if(clear==null) {
                clear=G.field(node("button",G.field(box,"dom"),["×"],"marketSearchClear"),"obj");
                absolute(box,clear);padding(clear,0);size(clear,26,26);position(clear,width-32,5);
                searchClearButtons.push({box:box,button:clear});
            }
            var control=clear;
            G.call("ui.UIElement","set_onClick",control,[()->{
                if((c.busy&&c.tab!="Buy"&&submit!=null)||G.text(G.field(input,"text"))=="")return;
                G.call("h2d.TextInput","set_text",input,[""]);changed("");
                if(submit!=null)submit();
            }]);
            G.call("h2d.Object","set_visible",control,[true]);
        }
        G.set(box,"onChange",()->{
            var text=G.text(G.field(input,"text"));
            changed(text);
        });
        if(submit!=null) {
            G.set(input,"ignoreEnter",true);
            G.set(input,"onEnter",function():Void {
                if(c.busy&&c.tab!="Browse"&&c.tab!="Buy")return;
                changed(G.text(G.field(input,"text")));submit();
            });
        }
        return box;
    }
    function counter(value:String,x:Int,y:Int,width:Int,max:Int,changed:String->Void,priceSteps=false):Dynamic {
        var current=MarketQuantity.normalize(value,1,max,"1");
        var box:Dynamic=null;
        function commit(text:String):Void {
            if(c.busy&&c.tab!="Buy")return;
            current=MarketQuantity.normalize(text,1,max,current);
            if(G.text(G.field(G.field(box,"input"),"text"))!=current)
                G.call("h2d.TextInput","set_text",G.field(box,"input"),[current]);
            changed(current);
        }
        box=input(current,x,y,priceSteps?96:width-30,commit,"1");
        changed(current);
        var textInput=G.field(box,"input"),previous=G.field(textInput,"onFocusLost");
        G.set(textInput,"onFocusLost",function(event:Dynamic):Void {
            if(previous!=null)Reflect.callMethod(textInput,previous,[event]);
            if(current=="")commit("1");
        });
        if(priceSteps) {
            for(i in 0...4) {
                var delta=[1,-1,10,-10][i];
                var step=button(delta>0?"+"+delta:Std.string(delta),x+102+Std.int(i/2)*44,y+(i%2)*24,40,()->commit(Std.string(MarketQuantity.priceStep(int(current),delta,max))),"");
                padding(step,0);size(step,40,22);
                var caption=G.field(step,"btnText");absolute(step,caption);
                afterReflow(step,()->{
                    updateTextScale(caption);G.call("h2d.Object","setScale",caption,[0.8]);
                    centerDropdownCaption(caption,22,0);centerTextX(caption,0,40);
                });
            }
            return box;
        }
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
        var control=filterControls.get("dropdown:"+x+":"+y,()->{
            var control = G.field(node("dropdown",G.field(root,"dom"),[false,false,"options-dropdown-list"],"marketSelect"+(sequence++)),"obj");
            absolute(root,control); padding(control,0); size(control,width,36); position(control,x,y);
            // The nested select retains a large native minimum width unless sized too.
            var select = G.field(control,"select"); padding(select,0); size(select,width,36);
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
            return control;
        });
        var oldOptions=G.array(G.field(control,"options")),same=oldOptions.length==values.length;
        if(same)for(i in 0...labels.length)if(G.text(G.field(oldOptions[i],"name"))!=escape(labels[i])){same=false;break;}
        if(!same) {
            var options=G.call("hl.types.ArrayObj","slice",G.field(control,"items"),[0,0]);
            for(i in 0...values.length)G.call("hl.types.ArrayObj","pushDyn",options,[{name:escape(labels[i]),value:i,icon:null,group:null}]);
            G.call("ui.comp.Dropdown","set_options",control,[options]);
        }
        G.call("ui.comp.Dropdown","initSelectedIndex",control,[Std.int(Math.max(0,values.indexOf(selected)))]);
        var select=G.field(control,"select");
        var popupRoot = G.field(frame.ui,"root");
        G.set(control,"getListLayout",()->popupRoot);
        G.call("ui.UIElement","set_onClick",select,[()->{
            for (other in controls) if(other!=control) G.call("ui.comp.Dropdown","close",other,[null]);
            G.call("ui.comp.Dropdown","toggle",control,[null]);
            var popup=G.field(control,"listWindow");
            if(popup!=null&&G.field(popup,"parent")==popupRoot)absolute(popupRoot,popup);
            limitDropdown(control);
            for(item in G.array(G.field(control,"items"))) for(child in children(item))
                if(G.field(child,"font")!=null)textColor(child,INK);
        }]);
        G.set(control,"onSelectOption",(_:Dynamic)->{
            var i=G.integer(G.field(control,"selectedIndex"),-1);
            if(i>=0&&i<values.length)changed(values[i]);
        });
        G.call("ui.comp.Dropdown","set_enable",control,[true]); controls.push(control);
    }
    function limitDropdown(control:Dynamic):Void {
        var popup=G.field(control,"listWindow"),content=G.field(popup,"content");
        if(content==null)return;
        var items=G.array(G.field(control,"items"));
        if(items.length<=10)return;
        var scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_overflow",content,[scroll]);style(content,"overflow",scroll);
        padding(content,0);G.call("h2d.Flow","set_verticalSpacing",content,[0]);
        // Ten fixed-height rows prevent long weapon lists from leaving the screen.
        for(item in items) {
            G.call("h2d.Flow","set_minHeight",item,[30]);G.call("h2d.Flow","set_maxHeight",item,[30]);
            style(item,"height",30);style(item,"min-height",30);style(item,"max-height",30);
        }
        G.call("h2d.Flow","set_minHeight",content,[300]);G.call("h2d.Flow","set_maxHeight",content,[300]);
        style(content,"height",300);style(content,"min-height",300);style(content,"max-height",300);
        // Scroll to the selected option when reopening a long list.
        var previous=G.field(content,"onAfterReflow"),restored=false;
        G.set(content,"onAfterReflow",()->{
            if(previous!=null)Reflect.callMethod(content,previous,[]);
            if(!restored){restored=true;G.call("h2d.Flow","set_scrollPosY",content,[Math.max(0,G.integer(G.field(control,"selectedIndex"))-9)*30.0]);}
        });
    }
    function filter(key:String,value:String):Void {
        if(key=="rarity") {
            c.filters["prismatic"]=value=="Epic (Prismatic)"?"true":"";
            value=value=="Epic (Prismatic)"?"Epic":value;
        }
        c.filters[key]=value; c.page=1;
        if(key=="online")c.saveFilterPreferences();
        if(key=="category") {c.filters["subcategory"]="";if(!MarketCategory.supportsClasses(value))c.filters["classes"]="";}
        c.refresh(); dirty=true;
    }
    function resetFilters():Void {
        for(key in c.filters.keys())if(key!="online")c.filters[key]="";
        c.page=1;c.refresh();dirty=true;
    }
    function filters():Void {
        var f=c.filters, root=frame.container;
        card(16,64,1072,c.filtersExpanded?260:96,0xDCCAB5);
        labelAt(root,"Search items",28,80,792,false,MUTED);
        input(f["search"],28,108,792,s->f["search"]=s.substr(0,100),"Item name...",()->filter("search",f["search"]),true);
        button("Search",836,108,96,()->filter("search",f["search"]),"",true,true);
        button(c.filtersExpanded?"Hide filters":"Show filters",948,108,128,c.toggleFilters,"",true,true);
        if(!c.filtersExpanded)return;
        var cats=["","Components","Weapon","Armor","Accessory","Consumables","Collections","Containers","Miscellaneous"];
        dropdown("Category",cats,["All items"].concat(cats.slice(1).map(MarketCategory.label)),f["category"],28,190,256,s->filter("category",s));
        var subs=[""].concat(MarketCategory.subcategories(f["category"]));
        dropdown("Subcategory",subs,["All subcategories"].concat(subs.slice(1)),f["subcategory"],300,190,312,s->filter("subcategory",s));
        var rarities=["","Common","Uncommon","Rare","Epic","Epic (Prismatic)","Legendary"];
        dropdown("Rarity",rarities,["Any rarity"].concat(rarities.slice(1)),f["rarity"]=="Epic"&&f["prismatic"]=="true"?"Epic (Prismatic)":f["rarity"],628,190,210,s->filter("rarity",s));
        dropdown("Pricing",["","fixed","offers"],["Any price","Buyout","Open to offers"],f["pricing"],854,190,222,s->filter("pricing",s));
        checkbox("Hide mine",c.hideMine,600,272,140,c.setHideMine,true);
        checkbox("Online only",f["online"]=="true",756,272,156,value->filter("online",value?"true":"false"),true);
        button("Clear filters",928,272,148,resetFilters,"",true,true);
        labelAt(root,"Class",28,244,464,false,MUTED);
        for(i in 0...4) {
            var name=["Warrior","Rogue","Mage","Priest"][i],selected=f["classes"].split(",").indexOf(name)>=0;
            button(name,28+i*116,272,108,()->{
                var classes=f["classes"].split(",").filter(s->s!="");
                if(classes.indexOf(name)>=0)classes.remove(name);else classes.push(name);
                filter("classes",classes.join(","));
            },selected?"unaccept":"",MarketCategory.supportsClasses(f["category"]),true);
        }
    }

    function row(item:TradeItem,y:Int,height:Int,price:String,seller:String,rarity:String,online:Bool,action:Void->Void,selected:Bool,?listingPrice:Dynamic,?requiredLevel:Dynamic,?parent:Dynamic,?listing:Dynamic):Void {
        stage="item row container";
        var root=parent==null?frame.container:parent, row=G.field(node("element",G.field(root,"dom"),[],"marketRow"+(sequence++)),"obj");
        partialRow=row;
        var baseWidth=c.tab=="Sell"?680:664;
        absolute(root,row);padding(row,0);size(row,baseWidth,height-4);position(row,parent==null?28:6,y);
        var bg=graphic(row),rowWidth=baseWidth,hovered=false;
        function draw(over:Bool):Void {
            hovered=over;
            G.call("h2d.Graphics","clear",bg);
            rounded(bg,0,0,rowWidth,height-4,5,selected?0xBC9146:over?0xC6B297:0xD7C5AC);
            rounded(bg,1,1,rowWidth-2,height-6,4,selected?0xF0D7A2:over?0xE2D1B7:0xE9DDC9);
            if(selected)rounded(bg,1,5,3,height-14,1,0xB78534);
        }
        draw(false);
        G.call("ui.UIElement","set_onOver",row,[()->draw(true)]);
        G.call("ui.UIElement","set_onOut",row,[()->draw(false)]);
        var iconY=Std.int((height-4-44)/2);
        stage="item row icon";
        var prismatic=G.field(G.field(listing,"item"),"prismatic")==true
            ||(item.preview!=null&&(item.preview.flags&2)!=0);
        itemIcon(row,item,8,iconY,44,rarity,prismatic);
        stage="item row labels";
        var nameX=64;
        var nameRight=c.tab=="Sell"?484:392,extraWidth=0;
        var fullName=item.name+(item.count>1?" ×"+item.count:"");
        var nameLabel=labelAt(row,fullName,nameX,0,nameRight-nameX,true,INK,true);
        // FmtText's native ellipsis overwrites its source text; fit from the original
        // name after the font, rarity and price columns have their final bounds.
        G.call("ui.comp.FmtText","set_useEllipsis",nameLabel,[false]);
        G.call("ui.comp.FmtText","set_maxWidthText",nameLabel,[null]);
        G.call("h2d.Text","set_maxWidth",nameLabel,[null]);
        var displayedName=fullName;
        largeLabel(nameLabel);
        var sellerLabel=c.tab=="Sell"?labelAt(row,seller,64,0,270,false,MUTED,true):null;
        var level:Dynamic=null;
        if(c.tab!="Sell") {
            sellerLine(row,seller,online,64,33,350,false,listing);
            level=labelAt(row,requiredLevel==null?"—":MarketText.number(requiredLevel),LEVEL_X-28,0,LEVEL_WIDTH,true,INK,true);
        }
        var priceLabel:Dynamic=null;
        function layoutLabels():Void {
            var available=Std.int(Math.max(1,nameRight-nameX));
            var fitted=MarketText.ellipsis(fullName,available,text->G.number(G.call("h2d.Text","calcTextWidth",nameLabel,[text])));
            if(fitted!=displayedName){setText(nameLabel,fitted);displayedName=fitted;}
            centerControlText(nameLabel,24,nameX,5);
            if(sellerLabel!=null)centerControlText(sellerLabel,24,64,33);
            if(level!=null) {
                centerControlText(level,height-4,LEVEL_X-28+extraWidth);
                centerTextX(level,LEVEL_X-28+extraWidth,LEVEL_WIDTH);
            }
            if(priceLabel!=null){centerControlText(priceLabel,height-4,502);position(priceLabel,502,G.number(G.field(priceLabel,"y")));}
        }
        if(c.tab=="Sell") {priceLabel=labelAt(row,price,502,0,166,true,INK,true);largeLabel(priceLabel);rightText(priceLabel,166);}
        else {
            var beforePrice=children(row);
            var unitPrice=MarketText.unitPrice(listingPrice,item.count);
            priceDisplay(row,listingPrice,484,unitPrice==""?Std.int((height-4-28)/2):5,168,true);
            if(unitPrice!="") {
                var unit=labelAt(row,unitPrice,484,34,168,false,MUTED,true);
                rightText(unit,168);
            }
            var priceParts=[for(child in children(row))if(beforePrice.indexOf(child)<0){obj:child,x:G.number(G.field(child,"x")),y:G.number(G.field(child,"y"))}];
            tableLayouts.push(extra->{
                extraWidth=extra;nameRight=392+extra;rowWidth=baseWidth+extra;
                size(row,rowWidth,height-4);draw(hovered);layoutLabels();
                for(part in priceParts)position(part.obj,part.x+extra,part.y);
            });
        }
        afterReflow(row,layoutLabels);
        G.call("ui.UIElement","set_onClick",row,[()->{if(!c.busy)action();}]);
        partialRow=null;
    }
    function rememberListingScroll():Void {
        if(listingViewport!=null&&listingScrollRestored&&listingScrollState!=null)
            listingScrollState.offset=G.number(G.field(listingViewport,"scrollPosY"));
        listingViewport=listingContent=null;listingScrollState=null;listingData=[];rowLayouts=[];rowPresence=[];
    }
    function applyDetailsLayout():Void {
        if(detailLayer!=null)position(detailLayer,tableExtra,0);
        for(layout in tableLayouts)layout(tableExtra);
    }
    function advanceDetails(now:Float):Void {
        if(c.tab=="Sell"||c.tab=="Buy"||recovery)return;
        drawer.update(now);
        var extra=Math.round(368*(1-drawer.value));
        if(extra!=tableExtra){tableExtra=extra;applyDetailsLayout();}
        if(drawer.value==0&&drawer.target==0&&detailLayer!=null) {
            G.call("h2d.Object","remove",detailLayer);G.call("h2d.Object","remove",detailClip);
            detailLayer=detailClip=detailBackdrop=null;closingListing=null;
        }
    }
    function rememberInventoryScroll():Void {
        if(inventoryViewport!=null)inventoryScroll=G.number(G.field(inventoryViewport,"scrollPosY"));
        inventoryViewport=null;
    }
    function rememberBuyScroll():Void {
        if(buyViewport!=null&&buyScrollRestored&&buyScrollState!=null)
            buyScrollState.offset=G.number(G.field(buyViewport,"scrollPosY"));
        buyViewport=buyContent=null;buyScrollState=null;buyItems=[];
    }
    function buyFilters():Void {
        var b=c.buy,f=b.filters,root=frame.container;
        card(16,64,704,b.expanded?288:96,0xDCCAB5);
        labelAt(root,"Search items",28,80,414,false,MUTED);
        var search=input(f["search"],28,108,414,s->{b.setFilter("search",s.substr(0,100));dirty=true;},"Item name...",null,true);
        G.set(G.field(search,"input"),"ignoreEnter",true);
        button("Search",454,108,96,()->{b.applyFilters();dirty=true;},"");
        button(b.expanded?"Hide filters":"Show filters",566,108,138,()->{b.expanded=!b.expanded;dirty=true;},"");
        if(!b.expanded)return;
        var categories=["","Components","Weapon","Armor","Accessory","Consumables","Collections","Containers","Miscellaneous"];
        dropdown("Category",categories,["All items"].concat(categories.slice(1).map(MarketCategory.label)),f["category"],28,190,322,s->{b.setFilter("category",s);dirty=true;});
        var subs=[""].concat(MarketCategory.subcategories(f["category"]));
        dropdown("Subcategory",subs,["All subcategories"].concat(subs.slice(1)),f["subcategory"],366,190,338,s->{b.setFilter("subcategory",s);dirty=true;});
        var rarities=["","Common","Uncommon","Rare","Epic","Epic (Prismatic)","Legendary"];
        dropdown("Rarity",rarities,["Any rarity"].concat(rarities.slice(1)),f["rarity"],28,258,322,s->{b.setFilter("rarity",s);dirty=true;});
        button("Clear filters",530,258,174,()->{b.clearFilters();dirty=true;},"");
        labelAt(root,"Class",28,316,54,false,MUTED);
        for(i in 0...4) {
            var name=["Warrior","Rogue","Mage","Priest"][i],selected=f["classes"].split(",").indexOf(name)>=0;
            button(name,88+i*154,306,146,()->{
                var classes=f["classes"].split(",").filter(s->s!="");
                if(classes.indexOf(name)>=0)classes.remove(name);else classes.push(name);
                b.setFilter("classes",classes.join(","));dirty=true;
            },selected?"unaccept":"",MarketCategory.supportsClasses(f["category"]));
        }
    }
    function catalogGrid():Void {
        var root=frame.container;
        buyViewport=G.field(node("flow",G.field(root,"dom"),[],"marketBuyViewport"+(sequence++),"vertical"),"obj");
        var viewport=buyViewport;
        absolute(root,viewport);padding(viewport,0);size(viewport,676,806-contentY-64);position(viewport,30,contentY+52);
        var vertical=G.enumeration("h2d.FlowLayout","Vertical"),scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_layout",viewport,[vertical]);style(viewport,"layout",vertical);
        G.call("h2d.Flow","set_multiline",viewport,[false]);style(viewport,"multiline",false);
        G.call("h2d.Flow","set_overflow",viewport,[scroll]);style(viewport,"overflow",scroll);
        buyContent=G.field(node("element",G.field(viewport,"dom"),[],"marketBuyGrid"+(sequence++)),"obj");
        buyItems=c.buy.visible.copy();buyScrollState=c.buy.scroll;buyScrollRestored=false;buyStart=buyEnd=-1;
        padding(buyContent,0);size(buyContent,634,Std.int(Math.ceil(buyItems.length/10))*64);alignScrollContent(viewport,buyContent,true);
        inventoryScrollbar(viewport,676);
        if(buyScrollbar==null||!buyScrollbar.attachedTo(root))buyScrollbar=new MarketScrollbar(root);
        buyScrollbar.bind(viewport,buyContent);
        var saved=buyScrollState.offset,previous=G.field(viewport,"onAfterReflow");
        G.set(viewport,"onAfterReflow",()->{
            if(previous!=null)Reflect.callMethod(viewport,previous,[]);
            if(!buyScrollRestored){buyScrollRestored=true;G.call("h2d.Flow","set_scrollPosY",viewport,[saved]);}
        });
        updateBuyGrid();
        if(buyItems.length==0)labelAt(root,"No items found. Try another search or clear your filters.",44,contentY+80,640,false,MUTED);
    }
    function updateBuyGrid():Void {
        if(buyViewport==null||buyContent==null)return;
        var height=806-contentY-64,offset=buyScrollRestored?G.number(G.field(buyViewport,"scrollPosY")):buyScrollState.offset;
        offset=Math.max(0,Math.min(offset,Math.max(0,Math.ceil(buyItems.length/10)*64-height)));
        var start=Std.int(Math.max(0,Math.floor(offset/64)-1))*10;
        var end=Std.int(Math.min(buyItems.length,(Math.ceil((offset+height)/64)+1)*10));
        if(start==buyStart&&end==buyEnd)return;
        buyStart=start;buyEnd=end;
        for(child in children(buyContent))G.call("h2d.Object","remove",child);
        for(i in start...end) {
            var entry=buyItems[i];
            var slot=G.field(node("element",G.field(buyContent,"dom"),[],"marketBuySlot"+(sequence++)),"obj");
            absolute(buyContent,slot);padding(slot,0);size(slot,58,58);position(slot,(i%10)*64,Std.int(i/10)*64);
            try {itemIcon(slot,entry.offer,0,0,58,entry.rarity);tooltip(slot,entry.offer);}catch(error:Dynamic){report("catalog item "+entry.kind,error);}
            if(c.buy.selected==entry)selectionBorder(graphic(slot),58,58);
            G.call("ui.UIElement","set_onClick",slot,[()->{
                c.buy.select(entry,G.integer(G.field(G.field(c.player,"hero"),"_level"),1));dirty=true;
            }]);
        }
    }
    function buyFormY():Int return c.buy.bonuses.length>0?438:534;
    function buyPanel():Void {
        var b=c.buy;
        if(b.selected==null){labelAt(frame.container,"Select an item to set up a buy order.",754,144,316,false,MUTED);return;}
        selectedItem(b.preview,b.metadata());
        var y=buyFormY();
        line(frame.container,754,y-42,316);
        if(b.selected.gear) {
            labelAt(frame.container,"Level requirement",754,y-28,152,true);
            counter(Std.string(b.level),754,y,152,b.maxLevel,s->{
                if(s!=""&&int(s)!=b.level){b.setLevel(s);dirty=true;}
            });
        }
        var quantityX=b.selected.gear?918:754;
        labelAt(frame.container,"Quantity to buy",quantityX,y-28,152,true);
        counter(b.quantity,quantityX,y,152,10000,s->b.quantity=s);
        if(b.bonuses.length>0) {
            dropdown("Infusion bonus",[""].concat(b.bonuses.map(v->v.id)),["Any bonus"].concat(b.bonuses.map(v->v.name)),b.bonus,754,508,316,s->{b.setBonus(s);dirty=true;});
            checkbox("Prismatic",b.prismatic,754,556,316,value->{b.setPrismatic(value);dirty=true;},true);
        }
        labelAt(frame.container,"Price for the entire order",754,592,316,true);
        tabButton("Buyout",754,620,152,()->{b.offers=false;dirty=true;},!b.offers);
        tabButton("Open to offers",918,620,152,()->{b.offers=true;dirty=true;},b.offers);
        if(b.offers)labelAt(frame.container,"Sellers can contact you to agree on a price.",754,670,316,false,MUTED);
        else {
            var conversion=currencyLine(frame.container,int(b.trays),754,720,316,true);
            counter(b.trays,754,668,190,200000,s->{b.trays=s;conversion(int(s));},true);
        }
        // The order API is not defined yet. This prototype deliberately sends
        // nothing, spends nothing, and does not claim an order was created.
        button("Place buy order",754,752,316,()->{},"accept");
    }
    function inventoryGrid():Void {
        var key=(c.bankOnly?"bank:"+c.bankTab:"inventory")+":"+c.sellSearch;
        if(key!=inventoryScrollKey){inventoryScroll=0;inventoryScrollKey=key;}
        var root=frame.container,viewportWidth=676;
        // A dedicated native Flow avoids UIElement's component layout rules
        // being reapplied over the scroll-specific Vertical measurement.
        inventoryViewport=G.field(node("flow",G.field(root,"dom"),[],"marketInventoryViewport"+(sequence++),"vertical"),"obj");
        var viewport=inventoryViewport;
        absolute(root,viewport);padding(viewport,0);size(viewport,viewportWidth,806-contentY-64);position(viewport,30,contentY+52);
        // Native Vertical Flow measures the full content height, unlike an
        // element's Stack layout which can clamp it to the clipped viewport.
        var vertical=G.enumeration("h2d.FlowLayout","Vertical");
        G.call("h2d.Flow","set_layout",viewport,[vertical]);style(viewport,"layout",vertical);
        G.call("h2d.Flow","set_multiline",viewport,[false]);style(viewport,"multiline",false);
        var scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_overflow",viewport,[scroll]);style(viewport,"overflow",scroll);
        var content=G.field(node("element",G.field(viewport,"dom"),[],"marketInventoryGrid"+(sequence++)),"obj");
        var columns=c.bankOnly?10:7,pitch=64,slotSize=58;
        padding(content,0);size(content,columns*pitch-(pitch-slotSize),Std.int(Math.ceil(c.inventorySlots.length/columns))*pitch);
        alignScrollContent(viewport,content,true);
        var selection:Dynamic = null;
        for(index in 0...c.inventorySlots.length) {
            var item=c.inventorySlots[index];
            var x=(index%columns)*pitch,y=Std.int(index/columns)*pitch;
            var selected=item!=null&&c.chosen!=null&&c.chosen.uid==item.uid;
            var stack=item==null?null:c.inventoryStack(item);
            // ItemSlot uses the game's rarity-styled inner frame, without the
            // transfer/equip/drag actions attached by InventorySlot.
            var slot=G.field(node("item-slot",G.field(content,"dom"),[stack,G.field(G.field(stack,"item"),"inf")],"marketInventorySlot"+(sequence++)),"obj");
            absolute(content,slot);padding(slot,0);size(slot,slotSize,slotSize);position(slot,x,y);
            var inner=G.field(slot,"innerSlot"),itemButton=G.field(slot,"button");
            if(inner!=null){absolute(slot,inner);padding(inner,0);size(inner,slotSize,slotSize);position(inner,0,0);}
            if(item==null||stack==null)continue;
            var customArtwork=false;
            if(itemButton!=null) {
                var mask=G.field(itemButton,"parent");
                if(mask!=null&&inner!=null) {
                    absolute(inner,mask);position(mask,3,3);
                    G.set(mask,"width",slotSize-6);G.set(mask,"height",slotSize-6);
                    style(mask,"width",slotSize-6);style(mask,"height",slotSize-6);
                    padding(itemButton,0);size(itemButton,slotSize-6,slotSize-6);position(itemButton,0,0);
                    customArtwork=trade.TradeNativeSlot.replaceMarketplaceArtwork(
                        itemButton,G.field(stack,"item"),slotSize-6);
                }
                var count=G.field(itemButton,"countTxt");
                if(count!=null) {
                    // Native count placement assumes a larger icon mask. Keep its
                    // font and visibility, but place the label outside that mask.
                    G.call("h2d.Object","addChild",slot,[count]);absolute(slot,count);
                    afterReflow(slot,()->{
                        updateTextScale(count);
                        var bounds=G.call("h2d.Object","getBounds",count,[count,null]);
                        var sx=G.number(G.field(count,"scaleX"),1),sy=G.number(G.field(count,"scaleY"),1);
                        position(count,slotSize-5-G.number(G.field(bounds,"xMax"))*sx,
                            slotSize-5-G.number(G.field(bounds,"yMax"))*sy);
                    });
                }
            }
            if(selected)selection = slot;
            tooltip(slot,item);
            if(c.isBound(item)||c.isLocked(item)||c.isListed(item)) {
                var badge=G.field(node("element",G.field(slot,"dom"),[],"marketSaleBadge"+(sequence++)),"obj");
                G.call("h2d.Object","addChild",slot,[badge]);
                absolute(slot,badge);padding(badge,0);size(badge,52,16);position(badge,3,3);
                rounded(graphic(badge),0,0,52,16,3,0x5B4334,0.95);
                var caption=labelAt(badge,c.isBound(item)?"Bound":c.isLocked(item)?"Locked":"For sale",0,0,80,false,0xF5EEE4,true);
                // FmtText applies its own scale during reflow; fit after that pass.
                afterReflow(badge,()->{
                    updateTextScale(caption);
                    G.call("h2d.Object","setScale",caption,[0.65]);
                    centerDropdownCaption(caption,16,0);
                    var width=G.number(G.call("h2d.Text","get_textWidth",caption))*G.number(G.field(caption,"scaleX"),1);
                    position(caption,Math.round((52-width)/2),G.number(G.field(caption,"y")));
                });
            }
            var select=()->{c.chosen=item;quantity=Std.string(item.count);dirty=true;};
            G.call("ui.UIElement","set_onClick",slot,[select]);
            // A hidden native button cannot capture input. The visible slot
            // retains the same selection callback and original item tooltip.
            if(itemButton!=null&&!customArtwork){
                tooltip(itemButton,item);G.call("ui.UIElement","set_onClick",itemButton,[select]);
            }
        }
        if(selection != null) {
            // A sibling overlay stays above ItemSlot's frame and icon mask. Native
            // slot styling must not clip or offset any of the four selection edges.
            var overlay=G.create("h2d.Object",[content]);absolute(content,overlay);
            var border=G.create("h2d.Graphics",[overlay]);
            var selectedSlot=selection;
            afterReflow(content,()->{
                var inner=G.field(selectedSlot,"innerSlot");
                var bounds=G.call("h2d.Object","getBounds",inner==null?selectedSlot:inner,[content,null]);
                var x=G.number(G.field(bounds,"xMin")),y=G.number(G.field(bounds,"yMin"));
                position(overlay,x,y);
                G.call("h2d.Graphics","clear",border);
                selectionBorder(border,G.number(G.field(bounds,"xMax"))-x,G.number(G.field(bounds,"yMax"))-y);
            });
        }
        inventoryScrollbar(viewport,viewportWidth);
        if(sellScrollbar==null||!sellScrollbar.attachedTo(root))
            sellScrollbar=new MarketScrollbar(root);
        sellScrollbar.bind(viewport,content);
        // Restore only once, after Flow has measured the content and can clamp scrolling.
        var saved=inventoryScroll,previous=G.field(viewport,"onAfterReflow"),restored=false;
        G.set(viewport,"onAfterReflow",()->{
            if(previous!=null)Reflect.callMethod(viewport,previous,[]);
            if(!restored){restored=true;G.call("h2d.Flow","set_scrollPosY",viewport,[saved]);}
        });
    }
    static function inventoryScrollbar(viewport:Dynamic,viewportWidth:Int):Void {
        // Native visibility and scrolling already work. With Right alignment,
        // however, the game's Flow places this UIElement at x=viewportWidth,
        // outside the clipped viewport. An absolute, unaligned native bar at
        // a known in-bounds position survives Flow reflows and CSS restyling.
        // Do not touch its background, children, thumb or event handlers.
        var bar=G.field(viewport,"scrollBar"),cursor=G.field(viewport,"scrollBarCursor");
        if(bar==null||cursor==null)return;
        absolute(viewport,bar);padding(bar,0);size(bar,10);size(cursor,10);
        // Explicitly discard inherited Right/Top Flow alignment. The native
        // UIElement had been aligning to x=viewportWidth (outside the clip).
        var layout=G.call("h2d.Flow","getProperties",viewport,[bar]);
        G.set(layout,"horizontalAlign",null);G.set(layout,"verticalAlign",null);
        style(bar,"halign",null);style(bar,"valign",null);
        // Four pixels of clearance from the right edge, with room for the
        // native 10-pixel-wide bar inside the inventory/bank scroll region.
        position(bar,viewportWidth-14,0);
    }
    static function selectionBorder(border:Dynamic,width:Float,height:Float):Void {
        var arm=Math.min(width,height)*0.28;
        for(layer in [{inset:0.0,width:5.0,color:0x5B4334},{inset:1.0,width:3.0,color:0xF3CD70},{inset:2.0,width:1.0,color:0xFFF1B5}]) {
            var outer=layer.inset,inner=outer+layer.width;
            // Four connected L shapes, with open edge centres and square ends.
            var corner=[outer,outer,arm,outer,arm,inner,inner,inner,inner,arm,outer,arm];
            for(x in 0...2)for(y in 0...2) {
                var points=[];
                for(i in 0...Std.int(corner.length/2)) {
                    points.push(x==0?corner[i*2]:width-corner[i*2]);
                    points.push(y==0?corner[i*2+1]:height-corner[i*2+1]);
                }
                polygon(border,points,layer.color);
            }
        }
    }

    static function alignScrollContent(viewport:Dynamic,content:Dynamic,center=false):Void {
        var top=G.enumeration("h2d.FlowAlign","Top"),left=G.enumeration("h2d.FlowAlign",center?"Middle":"Left");
        G.call("h2d.Flow","set_verticalAlign",viewport,[top]);G.call("h2d.Flow","set_horizontalAlign",viewport,[left]);
        style(viewport,"content-valign",top);style(viewport,"content-halign",left);
        var layout=G.call("h2d.Flow","getProperties",viewport,[content]);
        G.call("h2d.FlowProperties","set_isAbsolute",layout,[false]);style(content,"position",false);
        G.set(layout,"verticalAlign",top);G.set(layout,"horizontalAlign",left);style(content,"valign",top);style(content,"halign",left);
    }
    function priceDisplay(parent:Dynamic,value:Dynamic,x:Int,y:Int,width:Int,right=false,?leftEdge:Float->Void):Void {
        if(value==null||G.field(value,"mode")=="offers") {
            var label=labelAt(parent,MarketText.price(value),x,y,width,true,INK,true);
            if(right)rightText(label,width);
            centerControlText(label,28,x,y);if(right)position(label,x,G.number(G.field(label,"y")));
            if(leftEdge!=null)afterReflow(parent,()->{
                var bounds=G.call("h2d.Object","getBounds",label,[label,null]);
                leftEdge(x+G.number(G.field(bounds,"xMin"))*G.number(G.field(label,"scaleX"),1));
            });
        } else currencyLine(parent,G.integer(G.field(value,"silverTrays")),x,y,width,false,right,leftEdge);
    }
    /** Reuses the native item artwork and existing text objects when the price changes. */
    function currencyLine(parent:Dynamic,amount:Int,x:Int,y:Int,width:Int,conversion=false,right=false,?leftEdge:Float->Void):Int->Void {
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
            if(leftEdge!=null)leftEdge(x+G.number(G.field(content,"x")));
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
        var holder=G.create("h2d.Object",[frame.header]);absolute(frame.header,holder);
        try cart=new MarketCartIcon(holder,G.field(frame.ui,"windows"))catch(error:Dynamic){report("cart icon",error);return;}
        afterReflow(frame.header,()->{
            if(cart==null)return;
            var title=frame.title;
            // Measure the current styled font, not the pre-style glyph cache.
            // Force scale reconciliation even when a dropdown restyle reset it.
            G.call("ui.comp.FmtText","updateScale",title);G.set(title,"needUpdateScale",false);
            var titleWidth=G.number(G.call("h2d.Text","calcTextWidth",title,[G.field(title,"text")]))*G.number(G.field(title,"scaleX"),1);
            position(title,28,17);
            position(holder,28+Math.ceil(titleWidth)+8,12);
            position(cart.bitmap,0,0);
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
    function itemIcon(parent:Dynamic,item:TradeItem,x:Int,y:Int,sizePx:Int,?rarity="",prismatic=false,?nativeItem:Dynamic):Void {
        var tier=MarketText.rarityId(rarity,"",item.preview==null?"":item.preview.rarity,item.detail);
        var nativeFrame=trade.TradeNativeSlot.background(parent,item,x,y,sizePx,nativeItem,true);
        if(!nativeFrame) {
            // Legacy/unsupported previews cannot always make a detached
            // native item. Keep the previous gradient only for those cases.
            var bg=graphic(parent),tint=trade.TradeRarity.fill(tier);
            rounded(bg,x,y,sizePx,sizePx,5,trade.TradeRarity.border(tier,prismatic));
            rounded(bg,x+1,y+1,sizePx-2,sizePx-2,4,trade.TradeRarity.shade(tint,0.80));
            for(layer in trade.TradeRarity.gradient(tint,sizePx-2,sizePx-2,4))
                rounded(bg,x+1+layer.x,y+1+layer.y,layer.width,layer.height,layer.radius,layer.color);
        }
        // Marketplace artwork is fitted inside the native mask. Only previews
        // without a native frame need this external fallback Bitmap.
        var definition=nativeFrame?null:TradeInventory.definition(item.kind);
        if(definition!=null) {
            var icon=G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[definition]),parent]);
            // Match the 52px art within the native 58px frame at any
            // rendered slot size; don't overflow smaller 44px listing icons.
            var fullSize:Float=sizePx;
            var nativeSize:Float=trade.TradeNativeSlot.NATIVE_SIZE;
            var artSize:Float=trade.TradeNativeSlot.MARKET_ART_PIXELS*fullSize/nativeSize;
            var inset:Float=(fullSize-artSize)/2.0;
            absolute(parent,icon);position(icon,x+inset,y+inset);
            G.call("h2d.Bitmap","set_width",icon,[artSize]);G.call("h2d.Bitmap","set_height",icon,[artSize]);
        }
    }
    function tooltip(object:Dynamic,item:TradeItem):Void {
        G.call("ui.UIElement","set_getTip",object,[()->TradeTooltips.create(item,c.tab=="Sell"?MarketInventory.source(c.inv,item.uid,c.bankOnly):null)]);
        G.set(object,"showTipOnOver",true);style(object,"show-tip-on-over",true);
    }
    function selectedItem(item:TradeItem,?metadata:Dynamic):Void {
        var root=frame.container, y=c.tab=="Buy"?122:contentY+58;
        var bottom=c.tab=="Buy"?buyFormY()-56:c.tab=="Sell"||c.editingListingId!=""?SELL_FORM_Y-20:(c.tab=="My listings"?704:726);
        rounded(detailBackdrop==null?backdrop:detailBackdrop,754,y-8,316,bottom-y+16,4,0x4A423C);
        var viewport=G.field(node("element",G.field(root,"dom"),[],"marketDetailViewport"+(sequence++)),"obj");
        absolute(root,viewport);padding(viewport,0);size(viewport,300,bottom-y);position(viewport,762,y);
        var scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_overflow",viewport,[scroll]);style(viewport,"overflow",scroll);
        var details=G.field(node("element",G.field(viewport,"dom"),[],"marketDetails"+(sequence++)),"obj");
        // Keep the content in normal flow so the viewport measures its scrollable height.
        padding(details,0);size(details,284,164);
        var top=G.enumeration("h2d.FlowAlign","Top"),left=G.enumeration("h2d.FlowAlign","Left");
        G.call("h2d.Flow","set_verticalAlign",viewport,[top]);
        G.call("h2d.Flow","set_horizontalAlign",viewport,[left]);
        style(viewport,"content-valign",top);style(viewport,"content-halign",left);
        var contentLayout=G.call("h2d.Flow","getProperties",viewport,[details]);
        G.call("h2d.FlowProperties","set_isAbsolute",contentLayout,[false]);style(details,"position",false);
        G.set(contentLayout,"verticalAlign",top);G.set(contentLayout,"horizontalAlign",left);
        style(details,"valign",top);style(details,"halign",left);
        var requiredLevel=G.integer(G.field(metadata,"requiredLevel")),nativeItem:Dynamic=null;
        if(c.tab=="Sell") {
            var stack=c.inventoryStack(item);
            nativeItem=G.field(stack,"item");
            if(nativeItem!=null)requiredLevel=G.integer(G.call("st.Item","getRequiredLevel",nativeItem));
        }
        if(c.tab=="Buy")nativeItem=c.buy.nativePreview;
        // Show rarity in the icon's native-coloured background, not in text.
        var nativeRarity=(c.tab=="Sell"||c.tab=="Buy")&&nativeItem!=null
            ?G.staticCall("HItem","getRarity",[G.field(nativeItem,"inf")]):null;
        var rarity=MarketText.rarityId(
            G.text(G.field(metadata,"rarity")),G.text(G.field(nativeRarity,"id")),
            item.preview==null?"":item.preview.rarity,item.detail);
        var prismatic=G.field(metadata,"prismatic")==true || (item.preview!=null && (item.preview.flags&2)!=0);
        var picture=G.field(node("element",G.field(details,"dom"),[],"marketDetailsIcon"+(sequence++)),"obj");
        absolute(details,picture);padding(picture,0);size(picture,60,60);position(picture,0,0);
        // set_getTip installs UIElement hover handlers; enabling only the base Flow skips them.
        itemIcon(picture,item,0,0,60,rarity,prismatic,nativeItem);
        tooltip(picture,item);
        var name=labelAt(details,item.name,72,0,212,true,0xFFFFFF);
        largeLabel(name);G.call("h2d.Text","set_wordBreak",name,[true]);
        var levelLabel=requiredLevel>0?labelAt(details,"Level "+requiredLevel,72,0,212,false,0xC9BEB5):null;
        var upgrade=item.preview==null?G.integer(G.field(metadata,"upgradeLevel")):item.preview.upgrade;
        var stars:Array<Dynamic>=[];
        if(upgrade>0)for(i in 0...Std.int(Math.min(10,upgrade))) {
            var icon=G.field(node("icon",G.field(details,"dom"),["GearUpgrade"],"marketUpgrade"+(sequence++)),"obj");
            absolute(details,icon);padding(icon,0);size(icon,20,20);stars.push(icon);
        }
        var quantityLabel=c.tab=="Buy"?null:labelAt(details,"Quantity: "+item.count,72,0,212,false,0xC9BEB5);
        var prismaticLabel=prismatic?labelAt(details,"Prismatic",72,0,212,false,0xFFFFFF):null;
        if(prismaticLabel!=null) {
            var colors=["FF7B7B","FFA96B","FFD76B","BFE870","7DDF93","76DDCF","7FBEFF","A99AFF","DA94F0"];
            var rainbow=[for(i in 0...colors.length)"<font color='#"+colors[i]+"'>"+"Prismatic".charAt(i)+"</font>"].join("");
            G.call("ui.comp.FmtText","set_text",prismaticLabel,[rainbow]);
        }
        var lines=[];
        var category=G.text(G.field(metadata,"category")),subcategory=G.text(G.field(metadata,"subcategory"));
        if(category!="")lines.push("Category: "+MarketCategory.label(category));
        if(subcategory!="")lines.push("Subcategory: "+subcategory);
        var restrictions=MarketCategory.classLabels(G.field(metadata,"classes")).join(", ");
        if(restrictions!="")lines.push("Class: "+restrictions);
        var meta=labelAt(details,lines.join("\n"),0,0,334,false,0xC9BEB5);
        G.call("h2d.Object","setScale",meta,[0.85]);
        lines=[];
        var formattedDetail=MarketText.detail(item.detail,TradeInventory.skillName);
        var itemLines=MarketText.withoutRarityHeading(formattedDetail,G.text(G.field(nativeRarity,"name"))).split("\n");
        for(entry in itemLines) {
            // Level and upgrade icons belong beside the portrait.
            entry=~/^Level [0-9]+(?:\s*\|\s*)?/.replace(entry,"");
            entry=~/\s*Upgrade \+[0-9]+/.replace(entry,"");
            if(StringTools.trim(entry)!="")lines.push(entry);
        }
        var stats=labelAt(details,lines.join("\n"),0,0,284,false,0xFFFFFF);
        try {
            var nativeText=MarketDetails.text(item,nativeItem);
            if(nativeText!=null)G.call("ui.comp.FmtText","set_text",stats,[nativeText]);
        }catch(error:Dynamic)report("native item details",error);
        G.call("h2d.Text","set_wordBreak",stats,[true]);
        afterReflow(details,()->{
            var bounds=G.call("h2d.Object","getSize",name,[null]);
            var below=G.number(G.field(name,"y"))+G.number(G.field(bounds,"yMax"),22)+10;
            if(levelLabel!=null||stars.length>0){
                var starX=72.0;
                if(levelLabel!=null){position(levelLabel,72,below);updateTextScale(levelLabel);starX+=G.number(G.call("h2d.Text","get_textWidth",levelLabel))*G.number(G.field(levelLabel,"scaleX"),1)+6;}
                for(i in 0...stars.length)position(stars[i],starX+i*24,below-1);
                below+=24;
            }
            if(quantityLabel!=null){position(quantityLabel,72,below);below+=24;}
            if(prismaticLabel!=null){position(prismaticLabel,72,below);below+=24;}
            var statsY=Std.int(Math.max(72,below+8));
            position(meta,0,statsY);
            if(category!=""||subcategory!=""||restrictions!="") {
                var metaBounds=G.call("h2d.Object","getSize",meta,[null]);
                statsY+=Std.int(Math.ceil(G.number(G.field(metaBounds,"yMax"),22)*0.85))+12;
            }
            position(stats,0,statsY);
            var statsBounds=G.call("h2d.Object","getSize",stats,[null]);
            size(details,284,Std.int(Math.max(164,statsY+G.number(G.field(statsBounds,"yMax"),22)+12)));
        });
    }
    function emptyList():Void {
        var root=frame.container, y=contentY+Std.int((806-contentY)/2)-40;
        var signIn=c.tab=="Browse"&&!c.canBrowse();
        labelAt(root,signIn?"Steam sign-in required":c.busy?"Finding listings...":c.tab=="My listings"?"No active listings":"No listings found",64,y,596,true);
        labelAt(root,signIn?MarketText.SIGN_IN_TO_BROWSE:c.tab=="My listings"?c.ready?"Select Sell to create your first listing.":"Sign in with Steam to view and manage your listings.":"Try another search or clear your filters. New listings will appear here as players add them.",64,y+32,560,false,MUTED);
        if(c.tab=="My listings"&&c.ready)button("Sell",64,y+94,152,()->c.chooseTab("Sell"),"",true,true);
    }
    function priceFields(y:Int):Void {
        labelAt(frame.container,"Price for the entire listing",754,y,316,true);
        tabButton("Buyout",754,y+28,152,()->{if(offers){offers=false;dirty=true;}},!offers);
        tabButton("Open to offers",918,y+28,152,()->{if(!offers){offers=true;dirty=true;}},offers);
        if(!offers) {
            var conversion=currencyLine(frame.container,int(trays),754,y+128,316,true);
            var box=counter(trays,754,y+76,190,200000,s->{
                trays=s.substr(0,6);conversion(int(trays));
            },true);
        } else labelAt(frame.container,"Buyers can contact you to agree on a price.",754,y+78,316,false,MUTED);
    }
    function sellPanel():Void {
        if(c.chosen==null)return;
        selectedItem(c.chosen,MarketCategory.item(c.chosen.kind));
        if(c.isBound(c.chosen)||c.isLocked(c.chosen)) {
            labelAt(frame.container,c.isBound(c.chosen)?"Item cannot be traded":"Item is locked",754,752,316,true,MUTED);
            return;
        }
        if(c.isListed(c.chosen)) {
            labelAt(frame.container,"Already for sale",754,752,316,true,MUTED);
            return;
        }
        line(frame.container,754,SELL_FORM_Y-8,316);
        labelAt(frame.container,"Quantity to sell",754,SELL_FORM_Y+8,316,true);
        var available=c.availableToList(c.chosen);
        counter(quantity,754,SELL_FORM_Y+36,132,Std.int(Math.max(1,available)),s->quantity=s);
        labelAt(frame.container,"of "+available+" available",900,SELL_FORM_Y+44,170,false,MUTED);
        priceFields(SELL_FORM_Y+92);
        var limited=c.listingLimitReached();
        button(limited?"Too many listings":"List item for sale",754,752,316,()->c.list(int(quantity),int(trays),offers),"accept",!limited);
    }
    function listingPanel(row:Dynamic):Void {
        try selectedItem(MarketExport.offer(row),row.item)catch(error:Dynamic){report("selected item details",error);}
        if(c.tab=="My listings") {
            if(c.editingListingId==G.text(row.id)) {
                line(frame.container,754,SELL_FORM_Y-8,316);
                labelAt(frame.container,"Quantity to sell",754,SELL_FORM_Y+8,316,true);
                counter(quantity,754,SELL_FORM_Y+36,132,c.editQuantityLimit,s->quantity=s);
                priceFields(SELL_FORM_Y+92);
                button("Save changes",754,752,152,()->c.edit(int(quantity),int(trays),offers),"accept",!c.busy);
                button("Cancel",918,752,152,c.cancelEdit,"",!c.busy);
            } else {
                labelAt(frame.container,"Expires "+MarketText.expiry(G.text(row.expiresAt)),754,714,316,false,MUTED);
                button("Edit listing",754,752,152,()->{
                    if(c.beginEdit()) {
                        quantity=Std.string(row.item.quantity);trays=Std.string(G.integer(row.price.silverTrays,1));
                        offers=row.price.mode=="offers";dirty=true;
                    }
                },"",c.selected!=null&&!c.busy);
                button("Remove listing",918,752,152,c.remove,"cancel",c.selected!=null&&!c.busy);
            }
        } else {
            button(row.seller.accountId==c.account?"Your listing":"Whisper seller",754,752,316,c.contact,"accept",c.selected!=null&&row.seller.accountId!=c.account);
        }
    }
    function sellerLine(parent:Dynamic,name:String,online:Bool,x:Int,y:Int,width:Int,bold=false,?listing:Dynamic):Void {
        var box=G.field(node("element",G.field(parent,"dom"),[],"marketSeller"+(sequence++)),"obj");
        absolute(parent,box);padding(box,0);size(box,width,24);position(box,x,y);
        var badge:Dynamic=null;
        try badge=badges.create(box,G.text(G.field(G.field(listing,"seller"),"badge")),G.field(frame.ui,"windows"))
        catch(error:Dynamic)report("seller badge",error);
        var badgeSpace=badge==null?0:MarketBadges.SIZE+MarketBadges.GAP;
        var caption=labelAt(box,"Seller: "+name,0,0,width-90-badgeSpace,bold,bold?INK:MUTED,true);
        var status=labelAt(box,online?"Online":"Offline",0,0,70,false,MUTED,true);
        var dot=graphic(box);
        rounded(dot,0,0,10,10,5,online?0x426138:0x888888);
        if(listing!=null)presenceLabels.push(()->{
            var current=c.listingOnline(listing);
            if(current==online)return;
            online=current;setText(status,current?"Online":"Offline");
            G.call("h2d.Graphics","clear",dot);
            rounded(dot,0,0,10,10,5,current?0x426138:0x888888);
        });
        afterReflow(box,()->{
            centerDropdownCaption(caption,24,0);
            var bounds=G.call("h2d.Object","getBounds",caption,[caption,null]);
            var right=G.number(G.field(caption,"x"))+G.number(G.field(bounds,"xMax"))*G.number(G.field(caption,"scaleX"),1);
            if(badge!=null) {
                // Keep the badge with the rendered (possibly ellipsized) name,
                // inside the existing seller line and before the presence dot.
                var badgeX=Math.min(width-90-badgeSpace,Math.round(right))+MarketBadges.GAP;
                position(badge,badgeX,(24-MarketBadges.SIZE)/2);
                right=badgeX+MarketBadges.SIZE;
            }
            var dotX=Math.min(width-84,Math.round(right)+6);
            position(dot,dotX,7);
            centerDropdownCaption(status,24,dotX+16);
        });
    }
    function checkbox(text:String,value:Bool,x:Int,y:Int,width:Int,changed:Bool->Void,whileLoading=false):Void {
        var root=frame.container;
        var box=filterControls.get("checkbox:"+x+":"+y,()->{
            var box=G.field(node("check-box",G.field(root,"dom"),[text],"marketCheck"+(sequence++)),"obj");
            absolute(root,box);size(box,width,36);position(box,x,y);
            padding(box,0);G.call("h2d.Flow","set_paddingLeft",box,[12]);style(box,"padding-left",12);
            G.call("h2d.Flow","set_paddingRight",box,[12]);style(box,"padding-right",12);
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
            return box;
        });
        G.call("ui.comp.CheckBox","set_selected",box,[value]);
        G.call("ui.UIElement","set_enable",box,[true]);
        G.set(box,"onValueChange",(selected:Bool)->{
            if(c.busy&&!whileLoading)G.call("ui.comp.CheckBox","set_selected",box,[value]);else changed(selected);
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
        updateTextScale(text);
        var bounds=G.call("h2d.Object","getBounds",text,[text,null]);
        var sx=G.number(G.field(text,"scaleX"),1),sy=G.number(G.field(text,"scaleY"),1);
        var top=G.number(G.field(bounds,"yMin"))*sy,bottom=G.number(G.field(bounds,"yMax"),18)*sy;
        position(text,left-G.number(G.field(bounds,"xMin"))*sx,Math.round((height-bottom+top)/2)-top);
    }
    static function updateTextScale(text:Dynamic):Void {
        if(G.field(text,"needUpdateScale")==true) {
            G.call("ui.comp.FmtText","updateScale",text);G.set(text,"needUpdateScale",false);
        }
    }
    static function centerTextX(text:Dynamic,left:Float,width:Float):Void {
        updateTextScale(text);
        var bounds=G.call("h2d.Object","getBounds",text,[text,null]),scale=G.number(G.field(text,"scaleX"),1);
        position(text,left+width/2-(G.number(G.field(bounds,"xMin"))+G.number(G.field(bounds,"xMax")))*scale/2,
            G.number(G.field(text,"y")));
    }
    function showConnectionError():Void {
        connectionNoticeShown=true;
        try {
            var buttons=G.call("hl.types.ArrayObj","slice",G.field(frame.ui,"windows"),[0,0]);
            G.call("hl.types.ArrayObj","pushDyn",buttons,[{ic:"Confirm",input:null,checkEnable:null,onBack:true}]);
            connectionDialog=G.call("ui.BaseUI","displayDialog",frame.ui,["Marketplace connection",escape(c.canBrowse()?MarketText.CONNECTION_ERROR:MarketText.SIGN_IN_TO_BROWSE),buttons,function(_:String):Void {connectionDialog=null;}]);
            if(connectionDialog!=null)G.call("ui.comp.Button","setText",G.call("hl.types.ArrayObj","getDyn",G.field(connectionDialog,"buttons"),[0]),["OK"]);
        }catch(error:Dynamic) {report("connection notice",error);c.message=MarketText.CONNECTION_ERROR;dirty=true;}
    }
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
    static function textColor(obj:Dynamic,value:Int):Void {
        if(obj==null)return;
        style(obj,"color",value);
        var tint=G.field(obj,"color");
        if(tint!=null)for(channel in ["x","y","z"])G.set(tint,channel,1.0);
        G.call("h2d.HtmlText","set_textColor",obj,[value]);
    }
    function card(x:Int,y:Int,w:Int,h:Int,color=PAPER):Void {
        rounded(backdrop,x,y,w,h,8,EDGE);rounded(backdrop,x+1,y+1,w-2,h-2,7,color);
    }
    static function line(parent:Dynamic,x:Int,y:Int,w:Int):Void {var g=graphic(parent);rounded(g,x,y,w,1,0,0xCFB99D);}
    static function serverLabel(value:String):String return switch(value) {
        case "north-america":"North America";case "latin-america":"Latin America";case "europe":"Europe";
        case "asia":"Asia";case "mainland-china":"Mainland China";default:"Server unavailable";
    };
    static function int(text:String):Int {if(!~/^[0-9]+$/.match(text))return 0;var n=Std.parseInt(text);return n==null?0:n;}
}
