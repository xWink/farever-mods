package trade;
import trade.TradeTypes;
/** Pure protocol state. Native inventory mutations belong exclusively to TradeExchange. */
class TradeSession {
    public var self:String;
    public var peer = "";
    public var id = "";
    public var phase = "idle";
    public var leader = false;
    public var mine:Array<TradeItem> = [];
    public var theirs:Array<TradeItem> = [];
    public var revision = 0;
    public var peerRevision = -1;
    public var ack = -1;
    public var accepted = false;
    public var peerAccepted = false;
    public var received = false;
    public var peerReceived = false;
    public var error = "";
    public var changed = 0;
    public var deadline = 0.0;
    public var outbox:Array<Dynamic> = [];
    var used:Map<String,Bool> = [];
    var usedOrder:Array<String> = [];
    public function new(self:String) this.self = Std.string(self);
    public function active():Bool return phase != "idle" && phase != "complete" && phase != "cancelled";
    public function editable():Bool return phase == "offering";
    public function closingLocked():Bool return phase == "preparing" || phase == "exchanging";
    public function cancelByUser(reason = "Trade cancelled."):Bool { if (closingLocked()) return false; cancel(reason); return true; }
    public function progress(now:Float):Void { if (phase == "exchanging") deadline = now+5; }
    public function start(peer:String,id:String,now:Float):Bool {
        if (active() || peer == self || peer == "" || id == "" || used.exists(id)) return false;
        reset(peer,id,true,now); phase = "inviting"; deadline = now+45; emit("invite"); changed++; return true;
    }
    function reset(peer:String,id:String,leader:Bool,now:Float):Void {
        this.peer = Std.string(peer); this.id = Std.string(id); this.leader = leader;
        mine = []; theirs = []; revision = 0; peerRevision = ack = -1;
        accepted = peerAccepted = received = peerReceived = false; error = ""; outbox = []; deadline = now+180; remember(id);
    }
    function remember(id:String):Void {
        if (used.exists(id)) return; used[id] = true; usedOrder.push(id);
        if (usedOrder.length > 128) used.remove(usedOrder.shift());
    }
    public function join(now:Float):Void {
        if (phase != "invited") return;
        phase = "offering"; deadline = now+180; emit("join"); offer(); changed++;
    }
    public function setOffer(items:Array<TradeItem>,now:Float):Bool {
        if (!editable() || !TradeOffer.valid(items)) return false;
        mine = TradeOffer.copy(items); revision++; ack = -1; accepted = peerAccepted = false;
        deadline = now+180; offer(); changed++; return true;
    }
    function offer():Void emit("offer",{revision:revision,items:mine});
    public function canAccept():Bool return editable() && peerRevision >= 0 && ack == revision && mine.length+theirs.length > 0;
    public function accept(now:Float):Bool {
        if (!canAccept()) return false;
        accepted = !accepted; deadline = now+180; emit("ready",{key:key(),ready:accepted}); changed++; commitIfReady(now); return true;
    }
    public function key():String {
        var a = revision+":"+TradeOffer.hash(mine), b = peerRevision+":"+TradeOffer.hash(theirs);
        return haxe.crypto.Sha256.encode(id+"|"+(leader ? a+"|"+b : b+"|"+a));
    }
    function commitIfReady(now:Float):Void {
        if (leader && canAccept() && accepted && peerAccepted) {
            phase = "preparing"; deadline = now+5; emit("prepare",{key:key()}); changed++;
        }
    }
    public function receive(sender:String,p:Dynamic,now:Float):Void {
        if (p == null || !Reflect.isObject(p) || Std.isOfType(p,String) || Std.isOfType(p,Array)
            || !TradeOffer.str(p.id,48) || p.id == "" || p.to != self || !TradeOffer.str(p.op,16) || sender == self) return;
        if (p.op == "invite") {
            if (used.exists(p.id)) return;
            if (active() && !(phase == "inviting" && sender == peer && sender < self)) { remember(p.id); return; }
            reset(sender,p.id,false,now); phase = "invited"; deadline = now+45; changed++; return;
        }
        if (!active() || sender != peer || p.id != id) return;
        switch (p.op) {
            case "ack": if (editable() && p.revision == revision && p.hash == TradeOffer.hash(mine)) { ack = revision; changed++; }
            case "cancel": cancel(TradeOffer.str(p.reason,160) ? p.reason : "The other player cancelled.",false);
            case "commit": if (!leader && phase == "preparing" && p.key == key()) { phase = "exchanging"; deadline = now+5; changed++; }
            case "done": if (phase == "exchanging" && p.key == key() && !peerReceived) { peerReceived = true; progress(now); finish(); changed++; }
            case "join": if (phase == "inviting" && leader) { phase = "offering"; deadline = now+180; offer(); changed++; }
            case "offer":
                if (!editable() || !TradePreview.integer(p.revision,0,100000) || p.revision < peerRevision || !TradeOffer.valid(p.items)) return;
                if (p.revision == peerRevision && TradeOffer.hash(p.items) != TradeOffer.hash(theirs)) { cancel("The other player's offer changed unexpectedly."); return; }
                if (p.revision > peerRevision) { peerRevision = p.revision; theirs = TradeOffer.copy(p.items); accepted = peerAccepted = false; deadline = now+180; changed++; }
                emit("ack",{revision:peerRevision,hash:TradeOffer.hash(theirs)});
            case "prepare": if (!leader && editable() && canAccept() && accepted && peerAccepted && p.key == key()) {
                phase = "preparing"; deadline = now+5; emit("prepared",{key:key()}); changed++;
            }
            case "prepared": if (leader && phase == "preparing" && p.key == key()) {
                phase = "exchanging"; deadline = now+5; emit("commit",{key:key()}); changed++;
            }
            case "ready": if (editable() && p.key == key() && Std.isOfType(p.ready,Bool)) { peerAccepted = p.ready; changed++; commitIfReady(now); }
            default:
        }
    }
    public function gotItems():Void {
        if (phase != "exchanging" || received) return;
        received = true; emit("done",{key:key()}); finish(); changed++;
    }
    function finish():Void { if (received && peerReceived) phase = "complete"; }
    public function cancel(reason:String,notify = true):Void {
        if (!active()) return;
        if (notify) emit("cancel",{reason:reason.substr(0,160)});
        phase = "cancelled"; error = reason; accepted = peerAccepted = false; changed++;
    }
    public function tick(now:Float):Void {
        if (active() && now >= deadline) cancel(phase == "inviting" ? "Trade request timed out. Both players need Trade + Marketplace installed."
            : closingLocked() ? "Trade stalled for 5 seconds. Check your inventory and any items on the ground." : "Trade timed out.");
    }
    public function emit(op:String,?payload:Dynamic):Void {
        var p:Dynamic = {id:id,to:peer,op:op};
        if (payload != null) for (f in Reflect.fields(payload)) Reflect.setField(p,f,Reflect.field(payload,f));
        outbox.push(p);
    }
}
