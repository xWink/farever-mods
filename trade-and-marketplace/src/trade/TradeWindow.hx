package trade;
import trade.GameAccess as G;
import trade.TradeUi.*;
import trade.TradeFrame.*;
import trade.TradeTypes;
class TradeWindow {
    var controller:TradeController;
    var frame:TradeFrame;
    var yours:Dynamic;
    var theirs:Dynamic;
    var selfCount:Dynamic;
    var peerCount:Dynamic;
    var selfBadge:Dynamic;
    var peerBadge:Dynamic;
    var selfStatus:Dynamic;
    var peerStatus:Dynamic;
    var status:Dynamic;
    var acceptButton:Dynamic;
    var cancelButton:Dynamic;
    var capacityWarning:Dynamic;
    var lastOffer = "";
    var lastStatuses = "";
    var lastAccepted:Null<Bool>;
    var tooltipFailed = false;
    var marks = new TradeInventoryMarks();
    var dragUid = "";
    var dragStartX = 0.0;
    var dragStartY = 0.0;
    var ghost:Dynamic;
    var slotViews:Array<{background:Dynamic,color:Int,fill:Int,empty:Bool,disabled:Bool}> = [];
    static inline var WIDTH = 612;
    static inline var HEIGHT = 560;
    static inline var PANEL_WIDTH = 568;
    static inline var PANEL_HEIGHT = 96;
    public function new(controller:TradeController) this.controller = controller;
    public function shown():Bool return frame != null && frame.intact();
    public function blocksClosing(window:Dynamic):Bool return frame != null && window == frame.window && controller.state != null && controller.state.closingLocked();
    public function closeFromBack(window:Dynamic):Bool {
        if (frame == null || window != frame.window) return false; controller.cancelByUser(); return true;
    }
    public function update():Void {
        var ui = G.current("ui.BaseUI","current");
        if (ui == null || !G.isA(ui,"ui.GameUI")) return;
        if (frame != null && (frame.ui != ui || !frame.intact())) { controller.cancelByUser(); return; }
        if (frame == null) build(ui);
        var s = controller.state, offer = s.id+":"+s.revision+":"+s.peerRevision;
        if (lastOffer != offer) {
            clearTooltip(); lastOffer = offer; slotViews = []; render(yours,s.mine,true); render(theirs,s.theirs,false);
            setText(selfCount,s.mine.length+" / 6"); setText(peerCount,s.theirs.length+" / 6");
        }
        for (slot in slotViews) if (slot.disabled != !s.editable()) { slot.disabled = !s.editable(); paintSlot(slot); }
        var a = s.accepted ? "Accepted" : s.phase == "inviting" ? "Offers locked" : s.ack == s.revision ? "Not accepted" : "Syncing...";
        var b = s.peerAccepted ? "Accepted" : s.phase == "inviting" ? "Request sent" : s.peerRevision < 0 ? "Syncing..." : "Not accepted";
        var statuses = a+":"+b;
        if (statuses != lastStatuses) { lastStatuses = statuses; badge(selfBadge,selfStatus,a,s.accepted); badge(peerBadge,peerStatus,b,s.peerAccepted); }
        var spaceReason = s.editable() ? controller.inventorySpaceReason() : "";
        show(capacityWarning,s.editable() && !s.accepted && controller.inv != null && spaceReason != "");
        var message = controller.status;
        if (message == "") message = spaceReason;
        if (message == "") message = switch(s.phase) {
            case "inviting": "Offers unlock when "+controller.peerName+" accepts the request.";
            case "preparing": "Both offers accepted. Preparing the exchange...";
            case "exchanging": "Exchanging items...";
            default: s.accepted ? "Waiting for the other player to accept." : "Review both offers, then accept.";
        }
        setText(status,message); G.call("ui.comp.FmtText","updateScale",status);
        var bounds = G.call("h2d.Object","getBounds",status,[status,null]);
        var min = G.number(G.field(bounds,"yMin")), max = G.number(G.field(bounds,"yMax")), sy = G.number(G.field(status,"scaleY"),1);
        position(status,20,408+(47-(max-min)*sy)/2-min*sy);
        if (lastAccepted != s.accepted) {
            G.call("ui.comp.Button","setText",acceptButton,[s.accepted ? "Unaccept" : "Accept trade"]);
            setClass(acceptButton,s.accepted ? "unaccept" : "accept"); lastAccepted = s.accepted;
        }
        G.call("ui.UIElement","set_enable",acceptButton,[controller.canAccept()]);
        G.call("ui.UIElement","set_enable",cancelButton,[!s.closingLocked()]);
        G.call("ui.UIElement","set_enable",frame.closeButton,[!s.closingLocked()]);
        frame.layout(inventoryWindow()); updateDrag(); marks.update(inventoryWindow(),controller.inv,s);
    }
    function build(ui:Dynamic):Void {
        frame = new TradeFrame(ui,"Trade with "+controller.peerName,WIDTH,HEIGHT,controller.cancelByUser);
        var saved = TradeMod.tradePosition(); frame.x = saved.x; frame.y = saved.y; frame.onMoved = TradeMod.saveTradePosition;
        var c = frame.container, bg = graphic(c);
        rounded(bg,6,20,584,188,8,15260877); rounded(bg,6,220,584,188,8,15260877);
        textAt(c,"Your offer",20,31,450,true); textAt(c,controller.peerName+"'s offer",20,231,450,true);
        selfCount = textAt(c,"0 / 6",528,31,52); peerCount = textAt(c,"0 / 6",528,231,52);
        selfBadge = graphic(c); position(selfBadge,14,56); peerBadge = graphic(c); position(peerBadge,14,256);
        selfStatus = textAt(c,"",40,62,530,true); peerStatus = textAt(c,"",40,262,530,true);
        yours = panel(14,94); theirs = panel(14,294);
        status = textAt(c,"",20,408,556);
        acceptButton = frame.button("Accept trade",324,455,258,controller.accept,"accept");
        cancelButton = frame.button("Cancel",14,455,128,controller.cancelByUser,"cancel");
        capacityWarning = inventoryFullIcon(c); position(capacityWarning,278,455); show(capacityWarning,false);
        lastOffer = lastStatuses = ""; lastAccepted = null; tooltipFailed = false; showInventory();
    }
    function inventoryFullIcon(parent:Dynamic):Dynamic {
        var root = G.create("h2d.Object",[parent]); absolute(parent,root);
        var definition = TradeInventory.definition("SmallPouch");
        if (definition != null) {
            var icon = G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[definition]),root]);
            position(icon,2,2);
            G.call("h2d.Bitmap","set_width",icon,[32.0]); G.call("h2d.Bitmap","set_height",icon,[32.0]);
        }
        // Draw the warning over the native item icon once, when the window opens.
        var g = G.create("h2d.Graphics",[root]);
        var width = 2.4, red = 0xB8443A, opacity = 1.0, segments = 64;
        var w:hl.Ref<Float> = width, c:hl.Ref<Int> = red, a:hl.Ref<Float> = opacity, n:hl.Ref<Int> = segments;
        G.call("h2d.Graphics","lineStyle",g,[w,c,a]);
        G.call("h2d.Graphics","drawCircle",g,[18.0,18.0,16.0,n]);
        G.call("h2d.Graphics","moveTo",g,[6.7,6.7]);
        G.call("h2d.Graphics","lineTo",g,[29.3,29.3]);
        return root;
    }
    function panel(x:Int,y:Int):Dynamic {
        var o = G.field(node("element",G.field(frame.container,"dom"),[],"tradePanel"+x+"_"+y),"obj");
        absolute(frame.container,o); padding(o,0); size(o,PANEL_WIDTH,PANEL_HEIGHT); position(o,x,y); G.call("ui.UIElement","set_onClick",o,[()->{}]); return o;
    }
    function badge(graphic:Dynamic,label:Dynamic,text:String,accepted:Bool):Void {
        G.call("h2d.Graphics","clear",graphic); rounded(graphic,0,0,PANEL_WIDTH,28,5,accepted ? 4154186 : 14273207);
        rounded(graphic,11,11,6,6,3,accepted ? 12445103 : 10191981); setText(label,text); ink(label,accepted ? 16187376 : 6969158);
    }
    function paintSlot(slot:{background:Dynamic,color:Int,fill:Int,empty:Bool,disabled:Bool}):Void {
        var g = slot.background; G.call("h2d.Graphics","clear",g);
        rounded(g,0,2,80,80,7,4601647,0.15); rounded(g,0,0,80,80,7,slot.disabled ? 10262933 : slot.color);
        if(slot.empty||slot.disabled)rounded(g,2,2,76,76,5,slot.disabled?12170929:13022367);
        else {
            rounded(g,2,2,76,76,5,TradeRarity.shade(slot.fill,0.80));
            for(layer in TradeRarity.gradient(slot.fill,76,76,5))
                rounded(g,2+layer.x,2+layer.y,layer.width,layer.height,layer.radius,layer.color);
        }
    }
    function render(parent:Dynamic,items:Array<TradeItem>,own:Bool):Void {
        for (c in children(parent)) G.call("h2d.Object","remove",c);
        for (index in 0...6) {
            var row = G.field(node("element",G.field(parent,"dom"),[],"tradeSlot"+index),"obj");
            absolute(parent,row); padding(row,0); size(row,80,80); position(row,14+index*92,0);
            var empty = index >= items.length, item = empty ? null : items[index];
            var tier=empty?"":marketplace.MarketText.rarityId("","",
                item.preview==null?"":item.preview.rarity,item.detail);
            var fill=empty?13022367:tier!=""?TradeRarity.fill(tier):TradeRarity.fromTint(item.color);
            var slot = {background:graphic(row),empty:empty,color:empty ? 10127480 : item.color,fill:fill,disabled:!controller.state.editable()};
            slotViews.push(slot); paintSlot(slot); G.call("ui.UIElement","set_onClick",row,[()->{}]);
            if (empty) continue;
            var cursor = G.enumeration("hxd.Cursor","Button");
            G.call("h2d.Interactive","set_cursor",G.field(row,"interactive"),[cursor]); style(row,"cursor",cursor);
            var definition = TradeInventory.definition(item.kind);
            if (definition != null) {
                var tile = G.staticCall("HItem","getGfx",[definition]), icon = G.create("h2d.Bitmap",[tile,row]);
                absolute(row,icon); position(icon,10,8); G.call("h2d.Bitmap","set_width",icon,[60.0]); G.call("h2d.Bitmap","set_height",icon,[60.0]);
            } else ink(textAt(row,item.name,7,16,66,true),16116957);
            var quantity = textAt(row,"x"+item.count,73,60,66,true); ink(quantity,0xffffff);
            var right = G.enumeration("h2d.Align","Right"); G.call("h2d.Text","set_textAlign",quantity,[right]); style(quantity,"text-align",right);
            G.call("ui.UIElement","set_getTip",row,[()->TradeTooltips.create(item,own ? controller.inv : new TradeInventory(controller.partyMember(controller.state.peer)))]);
            G.set(row,"showTipOnOver",true); style(row,"show-tip-on-over",true);
            if (own) {
                G.call("ui.UIElement","set_onRightClick",row,[()->controller.remove(item.uid)]);
                G.call("ui.UIElement","set_onPush",row,[()->{
                    if (!controller.state.editable()) return;
                    var p = frame.mouse(); dragStartX = p.x; dragStartY = p.y; dragUid = item.uid;
                }]);
            }
        }
    }
    function updateDrag():Void {
        if (dragUid == "") return;
        var p = frame.mouse(), distance = Math.abs(p.x-dragStartX)+Math.abs(p.y-dragStartY);
        if (distance > 8 && ghost == null) for (i in controller.state.mine) if (i.uid == dragUid) {
            var d = TradeInventory.definition(i.kind); if (d == null) break;
            ghost = G.create("h2d.Bitmap",[G.staticCall("HItem","getGfx",[d]),frame.root]); absolute(frame.root,ghost);
            G.call("h2d.Bitmap","set_width",ghost,[44.0]); G.call("h2d.Bitmap","set_height",ghost,[44.0]); G.set(ghost,"alpha",0.8);
        }
        if (ghost != null) position(ghost,p.x-22,p.y-22);
        if (G.staticCall("hxd.Key","isDown",[0]) != true) {
            var p = frame.mouse(yours);
            if (ghost != null && (p.x < 0 || p.y < 0 || p.x > PANEL_WIDTH || p.y > PANEL_HEIGHT)) controller.remove(dragUid);
            dragUid = ""; clearGhost();
        }
    }
    function clearGhost():Void { if (ghost != null) G.call("h2d.Object","remove",ghost); ghost = null; }
    public function owns(object:Dynamic):Bool {
        while (object != null) { if (object == yours) return true; object = G.field(object,"parent"); } return false;
    }
    public function dropTarget():Bool {
        if (frame == null) return false;
        var ignored = G.call("hl.types.ArrayObj","slice",G.field(frame.ui,"windows"),[0,0]);
        var interactive = G.field(G.field(frame.ui,"draggingComponent"),"interactive");
        if (interactive != null) G.call("hl.types.ArrayObj","pushDyn",ignored,[interactive]);
        return owns(G.call("ui.BaseUI","getTopInteractiveElement",frame.ui,[ignored]));
    }
    public function inventoryWindow():Dynamic {
        if (frame == null) return null;
        for (w in G.array(G.field(frame.ui,"windows"))) if (G.isA(w,"ui.win.InventoryUI") && G.field(w,"removed") != true && G.field(w,"parent") != null) return w;
        return null;
    }
    public function showInventory():Void {
        if (frame != null && inventoryWindow() == null) G.call("ui.win.TitleWindow","openInventory",frame.window);
    }
    function ownsTooltip(tip:Dynamic):Bool {
        if (frame == null || tip == null) return false;
        var anchor = G.field(tip,"anchor"), backpack = inventoryWindow();
        for (_ in 0...8) {
            if (anchor == null) return false;
            for (window in [frame.window,backpack]) if (window != null && (anchor == window || G.call("h2d.Object","contains",window,[anchor]) == true)) return true;
            anchor = G.field(anchor,"anchor");
        }
        return false;
    }
    public function fitTooltip(tip:Dynamic):Void {
        if (tooltipFailed) return;
        try {
            if (!ownsTooltip(tip)) return;
            var parent = G.field(tip,"parent"), scene = G.call("h2d.Object","getScene",tip);
            if (parent == null || scene == null) return;
            var b = G.call("h2d.Object","getBounds",tip,[tip,null]), top = frame.point(8,8,parent);
            var bottom = frame.point(G.number(G.field(scene,"width"))-8,G.number(G.field(scene,"height"))-8,parent);
            var fit = TradeTooltipPlacement.fit(G.number(G.field(tip,"x")),G.number(G.field(tip,"y")),{
                xMin:G.number(G.field(b,"xMin")),yMin:G.number(G.field(b,"yMin")),xMax:G.number(G.field(b,"xMax")),yMax:G.number(G.field(b,"yMax"))
            },{xMin:top.x,yMin:top.y,xMax:bottom.x,yMax:bottom.y});
            G.call("h2d.Object","setScale",tip,[fit.scale]); position(tip,fit.x,fit.y);
        } catch(e:Dynamic) { tooltipFailed = true; TradeDiagnostics.log("Tooltip positioning: "+e); }
    }
    function clearTooltip():Void {
        if (frame != null && ownsTooltip(G.field(frame.ui,"currentTip"))) G.call("ui.BaseUI","removeTip",frame.ui,[null]);
    }
    public function dispose():Void {
        clearGhost(); dragUid = ""; marks.clear(); clearTooltip();
        var old = frame; frame = null; if (old != null) old.dispose();
        yours = theirs = status = capacityWarning = null; slotViews = [];
    }
}
