package dpsmeter;

import dpsmeter.CombatModel;

private typedef HealEvidence = {
    event:DamageEvent, scope:HealingScope, key:String, exact:Bool, fx:Bool,
    time:Float, lastTime:Float, resultTime:Null<Float>, outputFloor:Float
};
private typedef HealthEvidence = {
    time:Float, scope:Null<HealingScope>, settled:Bool, remaining:Float
};
private typedef HealingTarget = {heals:Array<HealEvidence>, health:Array<HealthEvidence>};

/** Reconcile the owner-only result RPC with widely visible heal FX and replicated
    HP. HP correlation only supplies a lower bound for missing output estimates
    and keeps sourced healing out of the unattributed-recovery fallback.
    A replicated gain is spent once across all casters. Bounded, event-driven;
    no scanning units, polling HP, or retaining native objects. */
class HealingCapture {
    public static inline var WINDOW:Float = 1.5;
    // A network/render burst can contain several heals contributing to one HP
    // update. Use the nearest burst, not every heal in the 3-second search span.
    static inline var BURST:Float = .12;
    static inline var LIMIT:Int = 64;
    var targets:Map<String, HealingTarget> = [];
    var targetCount:Int = 0;
    var lastUpdate:Float = -1;
    public function new() {}

    function target(uid:String, now:Float):HealingTarget {
        var t = targets[uid];
        if (t == null) {
            // An exceptionally crowded scene still cannot grow this forever.
            if (targetCount >= 128) flush(now, true);
            t = {heals: [], health: []}; targets[uid] = t; targetCount++;
        }
        return t;
    }
    public function heal(e:DamageEvent, scope:Null<HealingScope>, key:String, exact:Bool):Void {
        if (scope == null) return;
        var t = target(e.target, e.time);
        // Pair only complementary notifications, one-to-one. Repeated ticks,
        // self-heals and equal-sized casts remain separate healing events.
        for (h in t.heals) if (h.event.source == e.source && h.key == key
            && Math.abs(h.time - e.time) <= WINDOW && (exact ? !h.exact : !h.fx)) {
            if (exact) { h.event = e; h.exact = true; h.resultTime = e.time; }
            else h.fx = true;
            h.lastTime = Math.max(h.lastTime, e.time);
            scope.finish();
            return;
        }
        t.heals.push({event: e, scope: scope, key: key, exact: exact, fx: !exact,
            time: e.time, lastTime: e.time,
            resultTime: exact ? e.time : null, outputFloor: 0});
        if (t.heals.length > LIMIT) {
            var old = t.heals.shift();
            finish(old);
            // Dropping matching context must not relabel its HP as new regen.
            for (c in t.health) {
                c.settled = true; c.remaining = 0;
                if (c.scope != null) { c.scope.finish(); c.scope = null; }
            }
        }
    }
    public function health(uid:String, before:Float, after:Float, now:Float, scope:Null<HealingScope>):Void {
        if (uid == "" || before <= 0 || !Math.isFinite(before) || !Math.isFinite(after) || before >= after) {
            if (scope != null) scope.finish();
            return; // No initial spawn/revive health as regeneration.
        }
        var t = target(uid, now);
        t.health.push({time: now, scope: scope, settled: false, remaining: after - before});
        if (t.health.length > LIMIT) {
            var old = t.health.shift();
            if (old.scope != null) old.scope.finish();
        }
    }
    static function distance(h:HealEvidence, time:Float):Float {
        var d = Math.abs(h.time - time);
        return h.resultTime == null ? d : Math.min(d, Math.abs(h.resultTime - time));
    }
    function allocate(t:HealingTarget, c:HealthEvidence):Void {
        c.settled = true;
        if (c.remaining <= 0) return;
        var nearest = WINDOW + 1;
        var candidates:Array<HealEvidence> = [];
        for (h in t.heals) {
            var d = distance(h, c.time);
            if (d > WINDOW || (h.exact && h.outputFloor >= h.event.amount)) continue;
            candidates.push(h); nearest = Math.min(nearest, d);
        }
        candidates = candidates.filter(h -> distance(h, c.time) <= nearest + BURST);
        // A shared HP gain does not reveal each caster's effective amount.
        // Estimate shares by remaining output, bounded by an exact result's
        // output. FX-only estimates may be raised by observed recovery.
        while (c.remaining > .000001 && candidates.length > 0) {
            var knownWeight = 0.0, knownCount = 0;
            for (h in candidates) if (h.event.amount > 0) {
                knownWeight += Math.max(.001, h.event.amount - h.outputFloor); knownCount++;
            }
            var unknownWeight = knownCount == 0 ? 1.0 : knownWeight / knownCount;
            var weights = [for (h in candidates) h.event.amount > 0 ? Math.max(.001, h.event.amount - h.outputFloor) : unknownWeight];
            var weight = 0.0;
            for (w in weights) weight += w;
            var available = c.remaining, spent = 0.0;
            var next:Array<HealEvidence> = [];
            for (i in 0...candidates.length) {
                var h = candidates[i];
                var share = available * weights[i] / weight;
                if (h.exact) share = Math.min(share, Math.max(0, h.event.amount - h.outputFloor));
                h.outputFloor += share; spent += share;
                if (!h.exact || h.outputFloor < h.event.amount - .000001) next.push(h);
            }
            c.remaining = Math.max(0, c.remaining - spent);
            if (spent <= .000001) break;
            candidates = next;
        }
    }
    public function flush(now:Float, force:Bool = false):Void {
        if (!force && now - lastUpdate < .1) return;
        lastUpdate = now;
        var remove:Array<String> = [];
        for (uid => t in targets) {
            // Wait for either arrival order before allocating each gain once.
            // A separate damage update is not a reason to discard this gain.
            for (c in t.health) if (!c.settled && (force || now > c.time + WINDOW)) allocate(t, c);
            var ready:Array<HealEvidence> = [];
            for (h in t.heals) {
                // Allow either arrival order. Only extend the normal grace
                // period when a later HP update still needs to settle.
                var until = h.lastTime + WINDOW;
                for (c in t.health) if (distance(h, c.time) <= WINDOW)
                    until = Math.max(until, c.time + WINDOW);
                if (force || now > until) ready.push(h);
            }
            for (h in ready) {
                t.heals.remove(h);
                finish(h);
            }
            var keep:Array<HealthEvidence> = [];
            for (c in t.health) {
                // Keep tombstones until every overlapping heal has settled.
                var pending = false;
                for (h in t.heals) if (distance(h, c.time) <= WINDOW) pending = true;
                if (!force && (pending || now <= c.time + WINDOW)) { keep.push(c); continue; }
                if (c.scope != null) {
                    if (c.remaining > .000001 && c.scope.combat) {
                        // HP has no cause field. This is recovered HP credited
                        // to its recipient, NOT confirmed caster output/regen.
                        var e = event(c.time, uid, uid, "Regen / unattributed", c.remaining);
                        e.estimatedHealing = true;
                        e.unknownHealing = true; e.unknownHealingCrit = true; e.unattributedHealing = true;
                        c.scope.finish(e);
                    } else c.scope.finish();
                }
            }
            t.health = keep;
            if (t.heals.length == 0 && t.health.length == 0) remove.push(uid);
        }
        for (uid in remove) { targets.remove(uid); targetCount--; }
    }
    function finish(h:HealEvidence):Void {
        var e = h.event;
        if (!h.exact) {
            e.estimatedHealing = true; e.unknownHealingCrit = true;
            // Measured recovery is a lower bound even if scaling/scripts/crit
            // made the heal larger than the client-side base calculation.
            e.amount = Math.max(e.amount, h.outputFloor);
        }
        h.scope.finish(e);
    }
    public static function event(time:Float, source:String, target:String, skill:String, amount:Float):DamageEvent {
        return {time: time, source: source, target: target, skill: skill, amount: Math.max(0, amount),
            critical: false, kill: false, effect: 1, bossKind: "", bossFlags: 0, bossLevel: 0, bossFoeId: 0};
    }
}
