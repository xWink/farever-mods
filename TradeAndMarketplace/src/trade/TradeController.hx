package trade;
import trade.GameAccess as G;
class TradeController {
    public var player:Dynamic;
    public var state:TradeSession;
    public var inv:TradeInventory;
    public var peerName = "Player";
    public var status = "";
    public var open = false;
    public var view:TradeWindow;
    public var requestPopup:TradeRequestPopup;
    var group:Dynamic;
    var wire:TradeWire;
    var movement = new TradeMovement();
    var exchange:TradeExchange;
    var exchangeId = "";
    var pendingCommits = 0;
    var announcements:Array<Dynamic> = [];
    var outgoing:Array<{id:String,to:String,op:String,parts:Array<String>}> = [];
    var nextSend = 0.0;
    var nextCheck = 0.0;
    var reportedEnd = "";
    var errorLogged = false;
    public function new() { wire = new TradeWire(StringTools.hex(Std.random(0x3fffffff))); view = new TradeWindow(this); requestPopup = new TradeRequestPopup(this); }
    public function ensure(player:Dynamic):Bool {
        if (player == null || G.field(player,"isMe") != true || G.field(player,"hero") == null) return false;
        if (this.player != player) { dispose(); this.player = player; state = new TradeSession(G.text(G.field(player,"uid"))); inv = new TradeInventory(player); }
        return inv.inventory != null;
    }
    public function partyMember(uid:String):Dynamic {
        for (p in G.array(G.field(G.field(player,"group"),"players"),true))
            if (G.text(G.field(p,"uid")) == uid && G.field(p,"removed") != true) return p;
        return null;
    }
    public function environment(?uid:String):String {
        if (uid == null) uid = state.peer;
        var peer = partyMember(uid), hero = G.field(peer,"hero");
        if (peer == null || peer == player) return "Both players must be in the same party.";
        if (hero == null || G.field(hero,"removed") == true || G.field(inv.hero,"removed") == true || G.field(player,"layer") != G.field(peer,"layer")) return "Both players must be in the same area.";
        if (G.call("ent.GameObject","isDead",inv.hero) == true || G.call("ent.GameObject","isDead",hero) == true) return "Both players must be alive to trade.";
        if (state.phase != "exchanging" && TradeInventory.distance(inv.hero,hero) > 5) return "Move closer to each other to trade.";
        return "";
    }
    public function requestName(name:String):Void {
        if (!TradeMod.enabled() || !ensure(G.field(G.staticCall("GameApp","get",[]),"me"))) return;
        name = StringTools.trim(name).toLowerCase();
        var matches = [for(p in G.array(G.field(G.field(player,"group"),"players"),true))
            if (p != player && (name == "" || G.text(G.call("st.Player","getName",p)).toLowerCase() == name)) p];
        if (matches.length != 1) { chat(name == "" ? "Use /trade PlayerName to trade with a nearby party member." : "No unique party member matches that name."); return; }
        request(G.text(G.field(matches[0],"uid")));
    }
    public function request(uid:String):Void {
        if (!TradeMod.enabled() || !ensure(G.field(G.staticCall("GameApp","get",[]),"me"))) return;
        if (state.active()) { chat("Finish or cancel your current trade first."); return; }
        var reason = environment(uid);
        if (reason != "") { chat(reason); return; }
        var id = StringTools.hex(Std.random(0x3fffffff))+StringTools.hex(Std.random(0x3fffffff));
        if (state.start(uid,id,haxe.Timer.stamp())) { begin(); flush(); }
    }
    function begin():Void {
        releaseMovement(); group = G.field(player,"group"); peerName = G.text(G.call("st.Player","getName",partyMember(state.peer)),"Player");
        exchange = null; exchangeId = ""; pendingCommits = 0; announcements = []; reportedEnd = "";
        outgoing = outgoing.filter(p->p.op == "cancel"); status = ""; open = state.phase != "invited"; view.dispose(); requestPopup.dispose();
    }
    public function receive(client:Dynamic,message:Dynamic,text:String):Void {
        var me = G.field(G.staticCall("GameApp","get",[]),"me");
        if (!TradeMod.enabled() || !TradeChat.isLocalClient(client,me) || !ensure(me)) return;
        var sender = TradeChat.sender(message);
        if (sender == "" || sender == state.self || partyMember(sender) == null) return;
        var p = wire.receive(sender,text,haxe.Timer.stamp());
        if (p == null) return;
        var previousId = state.id;
        if (p.op == "invite") { if (environment(sender) != "") return; }
        else if (sender != state.peer || p.id != state.id || p.to != state.self) return;
        if (p.key == state.key() && ((p.op == "prepare" && state.phase == "offering")
            || ((p.op == "prepared" || p.op == "commit") && state.phase == "preparing"))) {
            var reason = readyReason(); if (reason != "") { state.cancel(reason); flush(); return; }
        }
        if ((p.op == "drop" || p.op == "collected") && (state.phase == "exchanging" || state.phase == "preparing")) announcements.push(p);
        else state.receive(sender,p,haxe.Timer.stamp());
        if (state.id != previousId) begin();
        flush();
    }
    public function join():Void {
        if (state == null || state.phase != "invited") return;
        var reason = environment(); if (reason != "") { cancel(reason); return; }
        state.join(haxe.Timer.stamp()); flush(); requestPopup.dispose(); open = true;
    }
    public function readyReason():String {
        var reason = environment(); if (reason != "") return reason;
        if (!controlsHeld()) return "Wait a moment for trade controls to become ready.";
        reason = inv.validate(state.mine); return reason == "" ? inventorySpaceReason() : reason;
    }
    public function inventorySpaceReason():String {
        if (state == null || inv == null) return "Backpack is unavailable.";
        var missing = state.theirs.length-inv.freeSlotsAfterOffering(state.mine);
        return missing <= 0 ? "" : "Need "+missing+" more backpack slot"+(missing == 1 ? "" : "s")+" after dropping your offer.";
    }
    public function accept():Void {
        if (state == null || !state.editable()) return;
        if (!state.accepted) { var reason = readyReason(); if (reason != "") { status = reason; chat(reason); return; } }
        status = state.accept(haxe.Timer.stamp()) ? "" : "Wait for both offers to finish syncing."; flush();
    }
    public function canAccept():Bool return state != null && state.canAccept() && (state.accepted || (controlsHeld() && inventorySpaceReason() == ""));
    public function controlsLocked(?nativeController:Dynamic):Bool return open && TradeMod.enabled() && state != null && state.active() && inv != null
        && (nativeController == null || G.field(nativeController,"unit") == inv.hero);
    function controlsHeld():Bool return inv != null && movement.holding(G.current("client.PlayerController","inst"),inv.hero,state);
    function prepareExchangeAction():String {
        if (!controlsHeld()) return "Trade controls are unavailable. Exchange stopped.";
        driveMovement(G.current("client.PlayerController","inst"));
        return state.phase == "exchanging" && movement.ready(haxe.Timer.stamp()) ? "" : "Trade controls stopped responding. Exchange stopped.";
    }
    public function driveMovement(controller:Dynamic):Void {
        if (!controlsLocked(controller)) return;
        var target = state.phase == "exchanging" && exchange != null ? exchange.collectionTarget : null;
        var reason = movement.drive(controller,inv.hero,G.field(partyMember(state.peer),"hero"),state,target,haxe.Timer.stamp());
        if (reason != "") cancel(reason);
    }
    public function blocksPickup(target:Dynamic,heroUid:String):Bool return controlsLocked() && G.uid(inv.hero) == heroUid
        && G.isA(target,"ent.interactible.LootDrop") && !TradeExchange.authorizesPickup(target);
    function releaseMovement():Void { try movement.release() catch(e:Dynamic) TradeDiagnostics.log("Movement cleanup: "+e); }
    public function addSlot(slot:Dynamic,dragged:Bool):Bool {
        if (!open || state == null || !state.editable() || inv == null) return false;
        var stack = inv.fromSlot(slot); if (stack == null) return false;
        for (i in state.mine) if (i.uid == G.uid(stack.item)) { if (!dragged) remove(i.uid); return true; }
        var count = dragged ? G.integer(G.field(slot,"dragCountOverride"),stack.count) : stack.count;
        if (!inv.canDrop(stack,count)) return rejectOffer("This item is locked or cannot be dropped.");
        if (state.mine.length >= 6) return rejectOffer("You can offer up to six items or stacks.");
        var items = TradeOffer.copy(state.mine); items.push(TradeInventory.describe(stack.item,count));
        if (!state.setOffer(items,haxe.Timer.stamp())) return rejectOffer("This item's preview could not be shared.");
        status = ""; flush(); return true;
    }
    function rejectOffer(reason:String):Bool {
        status = reason; chat(reason); return true;
    }
    public function remove(uid:String):Void {
        if (state == null || !state.editable()) return;
        state.setOffer(state.mine.filter(i->i.uid != uid),haxe.Timer.stamp()); status = ""; flush();
    }
    public function cancelByUser():Void { if (state != null && !state.cancelByUser()) return; cancel(); }
    public function cancel(reason = "Trade cancelled."):Void {
        if (state != null) { state.cancel(reason); reportedEnd = state.id; }
        chat(reason); open = false; releaseMovement(); flush(); view.dispose(); requestPopup.dispose();
    }
    public function flush():Void {
        if (state == null) return;
        while (state.outbox.length > 0) {
            var p = state.outbox.shift();
            if (p.op == "offer") outgoing = outgoing.filter(q->q.op != "offer" || q.id != p.id);
            if (p.op == "cancel") outgoing = [];
            outgoing.push({id:p.id,to:p.to,op:p.op,parts:wire.encode(p,G.text(G.call("st.Player","getName",player),"Player"))});
        }
    }
    public function update(app:Dynamic,now:Float):Void {
        if (state == null && !open) return;
        var me = G.field(app,"me");
        if (me != player || G.field(me,"hero") != (inv == null ? null : inv.hero)) { dispose(); return; }
        if (!TradeMod.enabled() && state.active()) cancel("Trade disabled.");
        if (state.active() && now >= nextCheck) {
            nextCheck = now+0.2;
            var reason = G.field(player,"group") != group ? "Your party changed." : environment();
            if (reason == "" && state.phase != "exchanging") reason = inv.validate(state.mine);
            if (reason != "") state.cancel(reason);
        }
        state.tick(now); flush();
        if (outgoing.length > 0 && now >= nextSend) {
            nextSend = now+0.25;
            var p = outgoing[0], text = p.parts.shift(); if (p.parts.length == 0) outgoing.shift();
            var current = state, id = p.id, commit = p.op == "commit" && id == state.id;
            if (commit) pendingCommits++;
            var peer = partyMember(p.to);
            TradeChat.send(player,p.to,peer == null ? "Player" : G.text(G.call("st.Player","getName",peer)),text,function(ok:Bool) {
                if (state != current || state.id != id) return;
                if (commit) pendingCommits--;
                if (!ok && state.active()) {
                    state.cancel("Could not deliver a trade whisper. Check that the other player is online.",false);
                    outgoing = outgoing.filter(q->q.id != id);
                }
            });
        }
        if (state.phase == "exchanging") {
            if (exchangeId != state.id) { exchangeId = state.id; exchange = new TradeExchange(state,inv,prepareExchangeAction); }
            while (announcements.length > 0) {
                var p = announcements.shift(); if (p.op == "collected") exchange.collected(p,now); else exchange.announced(p,now);
            }
            if (pendingCommits == 0 && !Lambda.exists(outgoing,p->p.op == "commit")) exchange.update(now);
            status = exchange.status; flush();
        }
        if ((state.phase == "complete" || state.phase == "cancelled") && reportedEnd != state.id) {
            reportedEnd = state.id; chat(state.phase == "complete" ? "Trade complete" : state.error,state.phase == "complete");
            open = false; releaseMovement(); view.dispose(); requestPopup.dispose();
        }
        if (state.phase == "invited") requestPopup.update(now);
        if (open) view.update();
    }
    public function chat(text:String,success = false):Void {
        var ui = G.current("ui.BaseUI","current"); if (ui == null || !G.isA(ui,"ui.GameUI")) return;
        var chat = G.call("ui.GameUI","get_chat",ui); if (chat == null) return;
        var line = G.create("ui.hud.ChatBoxLine",[G.field(chat,"messages")]), label = G.field(line,"msgText");
        TradeUi.setText(label,text); var color = success ? 0x59DB70 : 0xEF5350;
        G.call("h2d.Text","set_textColor",label,[color]); TradeUi.style(label,"color",color);
    }
    public function fail(error:Dynamic):Void {
        if (!errorLogged) { errorLogged = true; TradeDiagnostics.log("Error: "+error); }
        if (state != null && state.active()) cancel("Trade stopped: "+error);
        else { chat("Trade stopped: "+error); open = false; releaseMovement(); view.dispose(); requestPopup.dispose(); }
    }
    public function dispose():Void {
        open = false; releaseMovement(); view.dispose(); requestPopup.dispose(); outgoing = []; announcements = [];
        state = null; player = group = null; inv = null; exchange = null; exchangeId = ""; pendingCommits = 0;
    }
}
