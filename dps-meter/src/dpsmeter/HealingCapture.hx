package dpsmeter;

import dpsmeter.CombatModel;

private typedef HealEvidence = {
    event:DamageEvent, scope:HealingScope, key:String, exact:Bool, fx:Bool,
    full:Bool, ambiguous:Bool, time:Float
};
private typedef HealthEvidence = {
    time:Float, before:Float, after:Float, scope:Null<HealingScope>, used:Bool
};
private typedef HealingTarget = {heals:Array<HealEvidence>, health:Array<HealthEvidence>};

/** Reconcile the owner-only result RPC with widely visible heal FX and replicated
    HP. HP correlation is evidence, not a server combat log. Never assign an
    aggregated gain to one of several possible healers. Bounded, event-driven;
    no scanning units, polling HP, or retaining native objects. */
class HealingCapture {
    public static inline var WINDOW:Float = 1.5;
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
    public function heal(e:DamageEvent, scope:Null<HealingScope>, key:String, exact:Bool, full:Bool):Void {
        if (scope == null) return;
        var t = target(e.target, e.time);
        // Pair only complementary notifications, one-to-one. Repeated ticks,
        // self-heals and equal-sized casts remain separate healing events.
        for (h in t.heals) if (h.event.source == e.source && h.key == key
            && Math.abs(h.time - e.time) <= WINDOW && (exact ? !h.exact : !h.fx)) {
            if (exact) { h.event = e; h.exact = true; }
            else h.fx = true;
            h.full = h.full && full;
            scope.finish();
            return;
        }
        t.heals.push({event: e, scope: scope, key: key, exact: exact, fx: !exact,
            full: full, ambiguous: false, time: e.time});
        if (t.heals.length > LIMIT) {
            finish(t.heals.shift(), null, false);
            for (other in t.heals) other.ambiguous = true;
            // Dropping matching context must not relabel its HP as new regen.
            for (c in t.health) {
                c.used = true;
                if (c.scope != null) { c.scope.finish(); c.scope = null; }
            }
        }
    }
    public function health(uid:String, before:Float, after:Float, now:Float, scope:Null<HealingScope>):Void {
        if (uid == "" || before <= 0 || !Math.isFinite(before) || !Math.isFinite(after) || before == after) {
            if (scope != null) scope.finish();
            return; // No initial spawn/revive health as regeneration.
        }
        var t = target(uid, now);
        t.health.push({time: now, before: before, after: after, scope: scope, used: false});
        if (t.health.length > LIMIT) {
            var old = t.health.shift();
            if (old.scope != null) old.scope.finish();
            for (h in t.heals) h.ambiguous = true;
        }
    }
    public function flush(now:Float, force:Bool = false):Void {
        if (!force && now - lastUpdate < .1) return;
        lastUpdate = now;
        var remove:Array<String> = [];
        for (uid => t in targets) {
            var ready:Array<HealEvidence> = [];
            for (h in t.heals) {
                var until = h.time + WINDOW;
                for (c in t.health) if (Math.abs(c.time - h.time) <= WINDOW)
                    until = Math.max(until, c.time + WINDOW);
                if (force || now > until) ready.push(h);
            }
            for (h in ready) {
                var gains:Array<HealthEvidence> = [];
                var disturbed = h.ambiguous;
                for (c in t.health) if (Math.abs(c.time - h.time) <= WINDOW) {
                    if (c.after < c.before || c.used) disturbed = true;
                    else gains.push(c);
                }
                for (c in gains) {
                    var candidates = [for (other in t.heals) if (Math.abs(other.time - c.time) <= WINDOW) other];
                    if (candidates.length != 1) {
                        disturbed = true;
                        for (other in candidates) other.ambiguous = true;
                    }
                }
                var actual:Null<Float> = null;
                if (!disturbed && gains.length == 1) actual = gains[0].after - gains[0].before;
                // A full-health snapshot alone is not enough if damage or
                // another heal happened in the correlation window.
                var alone = true;
                for (other in t.heals) if (other != h && Math.abs(other.time - h.time) <= WINDOW) alone = false;
                if (!disturbed && gains.length == 0 && alone && h.full && !force) actual = 0;
                for (c in gains) {
                    c.used = true;
                    if (c.scope != null) { c.scope.finish(); c.scope = null; }
                }
                t.heals.remove(h);
                finish(h, actual, actual != null);
            }
            var keep:Array<HealthEvidence> = [];
            for (c in t.health) {
                // Keep tombstones until every overlapping heal has settled.
                var pending = false;
                for (h in t.heals) if (Math.abs(h.time - c.time) <= WINDOW) pending = true;
                if (!force && (pending || now <= c.time + WINDOW)) { keep.push(c); continue; }
                if (c.scope != null) {
                    if (!c.used && c.after > c.before && c.scope.combat) {
                        // HP has no cause field. This is recovered HP credited
                        // to its recipient, NOT confirmed caster output/regen.
                        var e = event(c.time, uid, uid, "Regen / unattributed", c.after - c.before);
                        e.actualHealing = e.amount; e.estimatedHealing = true;
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
    function finish(h:HealEvidence, actual:Null<Float>, estimatedActual:Bool):Void {
        var e = h.event;
        if (!h.exact) {
            e.estimatedHealing = true; e.unknownHealingCrit = true;
            // Measured recovery is a lower bound even if scaling/scripts/crit
            // made the heal larger than the client-side base calculation.
            if (actual != null) e.amount = Math.max(e.amount, actual);
        } else if (actual != null && actual > e.amount + .01) actual = null;
        e.actualHealing = actual; e.estimatedActual = actual != null && estimatedActual;
        h.scope.finish(e);
    }
    public static function event(time:Float, source:String, target:String, skill:String, amount:Float):DamageEvent {
        return {time: time, source: source, target: target, skill: skill, amount: Math.max(0, amount),
            critical: false, kill: false, effect: 1, bossKind: "", bossFlags: 0, bossLevel: 0, bossFoeId: 0};
    }
}
