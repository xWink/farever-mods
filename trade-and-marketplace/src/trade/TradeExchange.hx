package trade;
import trade.GameAccess as G;
import trade.TradeTypes;
/** Drop/pickup requests are deliberately serialized and never retried after ambiguous drop responses. */
class TradeExchange {
    static var pickupTarget:Dynamic;
    public static function authorizesPickup(target:Dynamic):Bool return target != null && target == pickupTarget;
    var session:TradeSession;
    var sessionId:String;
    var inv:TradeInventory;
    var beforeAction:Void->String;
    var baseline:Map<String,Int>;
    var beforeDrops:Map<String,Bool> = [];
    var mine:Map<String,String> = [];
    var peerDrops:Map<String,String> = [];
    var approved:Map<String,Bool> = [];
    var peerPickups:Map<String,Bool> = [];
    var pending:TradeItem;
    var pendingCount = 0;
    var dropReply = false;
    var droppingAt = 0.0;
    var pickupPending = "";
    var nextPickup = 0.0;
    var nextUpdate = 0.0;
    var lastNow = 0.0;
    var pickupAttempts:Map<String,Int> = [];
    public var collectionTarget:Dynamic;
    public var status = "Preparing items...";
    public function new(session:TradeSession,inv:TradeInventory,beforeAction:Void->String) {
        this.session = session; sessionId = session.id; this.inv = inv; baseline = inv.totals(); this.beforeAction = beforeAction;
    }
    public function announced(p:Dynamic,?now:Float):Void {
        if (session.id != sessionId || p.key != session.key() || !TradeOffer.str(p.item,48) || !TradeOffer.str(p.drop,48) || p.drop == "") return;
        if (!Lambda.exists(session.theirs,i->i.uid == p.item)) return;
        if (peerDrops.exists(p.item)) {
            if (peerDrops[p.item] != p.drop) fail("The offered ground item changed.");
            return;
        }
        for (item=>drop in peerDrops) if (item != p.item && drop == p.drop) { fail("Two offers referred to the same ground item."); return; }
        session.progress(now == null ? lastNow : now); peerDrops[p.item] = p.drop;
    }
    public function collected(p:Dynamic,now:Float):Void {
        if (!current() || p.key != session.key() || !TradeOffer.str(p.item,48) || !TradeOffer.str(p.drop,48)
            || !mine.exists(p.item) || mine[p.item] != p.drop || peerPickups.exists(p.item)) return;
        peerPickups[p.item] = true; session.progress(now);
    }
    function current():Bool return session.id == sessionId && session.phase == "exchanging";
    function allAnnounced():Bool { for (i in session.theirs) if (!peerDrops.exists(i.uid)) return false; return true; }
    public function update(now:Float):Void {
        if (!current() || now < nextUpdate) return;
        lastNow = now; collectionTarget = null; nextUpdate = now+0.05;
        var drops = inv.drops();
        if (pending != null) {
            var stack = inv.find(pending.uid), remaining = stack == null ? 0 : stack.count;
            if (dropReply && remaining <= pendingCount-pending.count) {
                var matches = [for(d in drops) if (!beforeDrops.exists(G.uid(d)) && G.integer(G.field(d,"count")) == pending.count
                    && G.field(d,"item") != null && TradeInventory.fingerprint(G.field(d,"item")) == pending.fingerprint
                    && TradeInventory.distance(d,inv.hero) <= 6) d];
                var sameUid = [for(d in matches) if (G.uid(G.field(d,"item")) == pending.uid) d];
                if (sameUid.length == 1) matches = sameUid;
                if (matches.length == 1) {
                    var drop = G.uid(matches[0]); mine[pending.uid] = drop;
                    session.emit("drop",{key:session.key(),item:pending.uid,drop:drop}); session.progress(now); pending = null;
                }
            }
            if (pending != null) {
                if (now-droppingAt >= TradeSession.STALL_SECONDS) fail("Could not confirm the dropped item within 10 seconds. Check your inventory and the ground.");
                return;
            }
        }
        if (!session.leader && !allAnnounced()) { status = "Waiting for their items..."; return; }
        for (i in session.mine) if (!mine.exists(i.uid)) {
            if (!controlsReady()) return;
            var stack = inv.find(i.uid);
            if (stack == null || TradeInventory.fingerprint(stack.item) != i.fingerprint || !inv.canDrop(stack,i.count)) {
                fail("An offered item changed, is locked, or cannot be dropped."); return;
            }
            beforeDrops = []; for (d in drops) beforeDrops[G.uid(d)] = true;
            pending = i; pendingCount = stack.count; dropReply = false; droppingAt = now; status = "Dropping "+i.name+"...";
            G.call("st.Inventory","requestDropIndex",inv.inventory,[stack.index,true,i.count,function(ok:Bool) {
                if (!current()) return;
                if (!ok) fail("The server rejected an item drop."); else dropReply = true;
            }]);
            return;
        }
        if (!allAnnounced()) { status = "Waiting for their items..."; return; }
        if (pickupPending != "" || now < nextPickup) return;
        for (i in session.theirs) if (!approved.exists(i.uid)) {
            if (!controlsReady()) return;
            var uid = peerDrops[i.uid];
            for (own in mine) if (uid == own) { fail("The other offer referred to your own drop."); return; }
            var matches = [for(d in drops) if (G.uid(d) == uid) d];
            if (matches.length != 1) { status = "Waiting for "+i.name+"..."; return; }
            var d = matches[0], item = G.field(d,"item");
            if (item == null) return;
            if (G.integer(G.field(d,"count")) != i.count || TradeInventory.fingerprint(item) != i.fingerprint) {
                fail("A dropped item did not match the accepted offer."); return;
            }
            var range = G.number(G.call("ent.interactible.LootDrop","getInteractRange",d),5);
            if (TradeInventory.distance(d,inv.hero) > range) { collectionTarget = d; status = "Moving to "+i.name+"..."; return; }
            if (G.call("ent.interactible.LootDrop","canInteract",d,[inv.hero]) != true
                || G.call("ent.interactible.LootDrop","allowedToLoot",d,[inv.player]) != true) {
                status = "Waiting for "+i.name+" to become available..."; return;
            }
            var heroUid = G.field(inv.hero,"__uid"), allowed = false;
            pickupTarget = d;
            try allowed = G.call("ent.Interactible","canRequestInteraction",d,[heroUid]) == true
            catch(e:Dynamic) { pickupTarget = null; throw e; }
            pickupTarget = null;
            if (!allowed) return;
            pickupPending = i.uid; pickupAttempts[i.uid] = (pickupAttempts.exists(i.uid) ? pickupAttempts[i.uid] : 0)+1;
            status = "Picking up "+i.name+"..."; pickupTarget = d;
            try G.call("ent.Interactible","requestInteraction",d,[heroUid,function(ok:Bool) {
                if (!current()) return;
                pickupPending = "";
                if (ok) {
                    approved[i.uid] = true; session.progress(lastNow);
                    session.emit("collected",{key:session.key(),item:i.uid,drop:uid});
                } else {
                    // Only failed requests back off; successful pickups proceed on the next update.
                    nextPickup = lastNow+0.5;
                    if (pickupAttempts[i.uid] >= 3) fail("The server rejected a pickup. Check the items on the ground.");
                }
            }]) catch(e:Dynamic) { pickupTarget = null; throw e; }
            pickupTarget = null; return;
        }
        // An RPC acknowledgement is insufficient: wait until replicated inventory proves receipt.
        var totals = inv.totals(), expected:Map<String,Int> = [];
        for (i in session.theirs) expected[i.fingerprint] = baseline.exists(i.fingerprint) ? baseline[i.fingerprint] : 0;
        for (i in session.mine) if (expected.exists(i.fingerprint)) expected[i.fingerprint] -= i.count;
        for (i in session.theirs) expected[i.fingerprint] += i.count;
        for (f=>count in expected) if (!totals.exists(f) || totals[f] < count) { status = "Confirming received items..."; return; }
        status = "Waiting for the other player's confirmation...";
        if (!session.received) session.progress(now);
        session.gotItems();
    }
    function controlsReady():Bool {
        var reason = beforeAction == null ? "" : beforeAction();
        if (reason == "") return true;
        fail(reason); return false;
    }
    function fail(reason:String):Void { collectionTarget = null; if (session.id == sessionId) { status = reason; session.cancel(reason); } }
}
