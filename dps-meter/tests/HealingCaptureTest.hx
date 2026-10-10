import dpsmeter.CombatModel;
import dpsmeter.HealingCapture;
import dpsmeter.HealingDisplay;
import dpsmeter.FightHistory;
import haxe.Json;

class HealingCaptureTest {
    static var checks = 0;
    static function check(ok:Bool, text:String):Void { checks++; if (!ok) throw text; }
    static function model():CombatModel {
        var m = new CombatModel(0, "test"); m.me = "me";
        for (id in ["me", "a", "b"]) {
            m.party[id] = true;
            m.profiles[id] = {uid: id, name: id, isMe: id == "me", className: "cleric", weapon: null, classSkills: [], weaponSkills: []};
        }
        m.onCombatEnter("me", 10); m.record(damage(10)); return m;
    }
    static function damage(time:Float):DamageEvent return {time: time, source: "me", target: "boss", skill: "Attack", amount: 100,
        critical: false, kill: false, effect: 0, bossKind: "Boss", bossFlags: 16, bossLevel: 30, bossFoeId: 1};
    static function heal(c:HealingCapture, m:CombatModel, time:Float, source:String = "a", exact:Bool = false,
        amount:Float = 500):Void {
        var e = HealingCapture.event(time, source, "me", "Heal", amount);
        e.critical = exact; e.unknownHealing = !exact && amount == 0;
        c.heal(e, m.captureHealing(source), "Heal/0", exact);
    }
    static function main():Void {
        // Both RPC/FX orders and both HP orders must produce the same result.
        for (exactFirst in [true, false]) for (hpFirst in [true, false]) {
            var m = model(), c = new HealingCapture();
            if (hpFirst) c.health("me", 100, 200, 10.99, m.captureHealing("me"));
            heal(c, m, 11, "a", exactFirst, exactFirst ? 500 : 200);
            heal(c, m, 11.01, "a", !exactFirst, exactFirst ? 200 : 500);
            if (!hpFirst) c.health("me", 100, 200, 11.02, m.captureHealing("me"));
            c.flush(14.1);
            var s = m.current.players["a"].healing;
            check(s.hits == 1 && s.output == 500, "Complementary FX/RPC count once and match either HP order");
            check(s.knownCritHits == 1 && s.crits == 1 && s.estimatedHits == 0, "The exact amount/crit replaces the estimate");
            check(m.current.players["me"].heal == 0, "A matched HP gain is not counted again as regen");
            check(m.current.healingReceived.total("me") == 500 && s.teamOutput == 500 && s.selfOutput == 0,
                "Merged FX/RPC adds one team heal and one full incoming amount, independent of HP gain");
            check(m.current.pendingHealing == 0 && m.boss.pendingHealing == 0, "All merged scope holds released");
        }
        var m = model(), c = new HealingCapture();
        heal(c, m, 11); heal(c, m, 11.1, "b"); c.health("me", 100, 400, 11.2, m.captureHealing("me")); c.flush(15.1);
        check(m.current.players["a"].heal == 500 && m.current.players["b"].heal == 500, "Concurrent healers keep their individual output");
        check(m.current.players["me"].heal == 0, "An ambiguous matched gain is never counted again as regeneration");
        check(m.current.healingReceived.total("me") == 1000, "Concurrent healers add to the same recipient without overwriting");

        m = model(); c = new HealingCapture();
        heal(c, m, 11); heal(c, m, 11.2); c.flush(15.1);
        check(m.current.players["a"].healing.hits == 2, "Equal-sized repeated FX are two heals, not duplicate casts");
        check(HealingDisplay.crit(m.current.players["a"].healing) == "—", "Missing remote crit rolls are unknown, not non-critical");
        check(HealingDisplay.output(m.current.players["a"].healing, 1000, Std.string) == "1000", "Output display omits estimate decorations");

        m = model(); c = new HealingCapture();
        c.health("me", 100, 150, 11, m.captureHealing("me")); c.flush(14.1);
        var s = m.current.players["me"].healing;
        check(s.output == 50 && s.unattributedHits == 1 && s.unknownOutputHits == 1 && !Reflect.hasField(s.json(), "overheal"),
            "Unmatched recovery is explicit unattributed HP, not fabricated total/overheal");
        check(HealingDisplay.output(s, s.output, Std.string) == "50", "Recovery-only output also omits decorations");
        check(s.selfOutput == 0 && s.teamOutput == 0 && s.unattributedOutput == 50 && m.current.healingReceived.total("me") == 50,
            "Unmatched recovery counts as received but remains unclassified by caster");
        c.health("me", 0, 200, 14, m.captureHealing("me")); c.flush(17.1);
        check(s.hits == 1 && m.current.pendingHealing == 0, "Spawn/revive HP is excluded and releases its scope");

        m = model(); c = new HealingCapture();
        heal(c, m, 11, "a", false, 0); c.health("me", 100, 175, 11.1, m.captureHealing("me")); c.flush(14.1);
        s = m.current.players["a"].healing;
        check(s.output == 75 && s.unknownOutputHits == 1, "Unknown spell size retains observed recovery as a lower bound");
        var copy = FightHistory.decode(Json.parse(Json.stringify(FightHistory.encode(m.current, "test"))));
        check(copy.players["a"].healing.unknownOutputHits == 1 && copy.players["a"].healing.knownCritHits == 0
            && copy.players["a"].healing.estimatedHits == 1, "Evidence quality survives history serialization");
        heal(c, m, 14, "b", false, 0); c.flush(17.1);
        check(m.current.ranked(true, true).length == 2 && HealingDisplay.output(m.current.players["b"].healing, 0, Std.string) == "Unavailable",
            "Observed heals with unknown size remain inspectable, not silently discarded");

        m = model(); c = new HealingCapture();
        heal(c, m, 11, "a", true, 500); c.flush(14.1);
        check(m.current.players["a"].heal == 500, "Missing HP changes never remove known healing output");
        heal(c, m, 15, "a", true, 500); c.health("me", 200, 100, 15.1, m.captureHealing("me")); c.flush(18.1);
        check(m.current.players["a"].heal == 1000 && m.current.players["me"].heal == 0,
            "HP loss does not cancel healing output or count as regeneration");
        heal(c, m, 19, "a", true, 50); c.health("me", 100, 200, 19.1, m.captureHealing("me")); c.flush(22.1);
        check(m.current.players["a"].heal == 1050 && m.current.players["me"].heal == 50,
            "Exact output is retained and surplus recovery remains unattributed");

        m = model(); c = new HealingCapture();
        heal(c, m, 11); c.health("me", 100, 150, 11.1, m.captureHealing("me")); m.onCombatExit("me", 11.2); m.update(12, false);
        check(m.history.length == 0, "Archive waits for healing correlation rather than freezing incomplete data");
        c.flush(14.1); m.update(15, false);
        check(m.history.length == 1 && m.history[0].players["a"].heal == 500 && m.history[0].last == 11.2,
            "Final heal enters its original closed fight without extending duration");
        check(m.history[0].healingReceived.total("me") == 500, "Recipient totals settle in the original closed encounter");
        c.health("me", 150, 200, 14, m.captureHealing("me")); c.flush(17.1);
        check(m.history[0].players["me"].heal == 0 && m.session.players["me"].heal == 0, "Out-of-combat regeneration stays out of encounters");

        m = model(); m.enableRift(); m.updateRiftState(10, false, false, "Boss"); m.startRiftGates();
        var d = damage(11); d.bossKind = "Mob"; d.bossFlags = 0; m.record(d); c = new HealingCapture();
        heal(c, m, 12); m.updateRiftState(12.1, true, false, "Boss"); m.record(damage(12.2)); m.update(13, true);
        check(m.history.length == 0, "Rift gates also wait for pending heals");
        c.flush(15.1); m.update(16, true);
        check(m.history.length == 1 && m.history[0].players["a"].heal == 500 && !m.current.players.exists("a"),
            "A delayed gate heal cannot leak into the boss phase");
        check(m.history[0].healingReceived.total("me") == 500 && m.current.healingReceived.total("me") == 0,
            "Delayed incoming healing stays in gates instead of leaking into the boss phase");

        m = model(); c = new HealingCapture();
        for (i in 0...80) heal(c, m, 11 + i * .001);
        c.flush(12, true); m.reset(12);
        check(m.history.length == 1 && m.history[0].players["a"].healing.hits == 80 && m.history[0].pendingHealing == 0,
            "Queue pressure and quit flush preserve output and release every archive hold");
        busyFight();
        Sys.println('Healing evidence: $checks checks passed');
    }
    static function busyFight():Void {
        var m = model(), c = new HealingCapture();
        c.health("me", 800, 500, 10.99, null);
        heal(c, m, 11, "a", false, 200); heal(c, m, 11.04, "b", false, 100);
        c.health("me", 500, 620, 11.05, m.captureHealing("me"));
        c.health("me", 620, 520, 11.1, null); c.flush(15);
        check(m.current.players["a"].heal == 200 && m.current.players["b"].heal == 100
            && m.current.players["me"].heal == 0,
            "Overlapping heals and damage retain full output without duplicate recovery entries");

        m = model(); c = new HealingCapture();
        heal(c, m, 11, "a", false, 20); c.health("me", 100, 160, 11.01, m.captureHealing("me"));
        c.health("me", 160, 250, 11.08, m.captureHealing("me")); c.flush(15);
        check(m.current.players["a"].heal == 150,
            "The existing output estimate still uses HP evidence as a lower bound");

        m = model(); c = new HealingCapture();
        heal(c, m, 11, "a", false, 20); heal(c, m, 12, "b", false, 20);
        c.health("me", 100, 200, 12.01, m.captureHealing("me")); c.flush(16);
        check(m.current.players["a"].heal == 20 && m.current.players["b"].heal == 100,
            "A nearer heal owns the output fallback rather than an unrelated older heal");

        m = model(); c = new HealingCapture();
        for (i in 0...10) {
            var time = 11 + i * .5;
            heal(c, m, time, "a", false, 20);
            c.health("me", 100 + i * 10, 110 + i * 10, time + .01, m.captureHealing("me"));
            c.flush(time + .02);
        }
        c.flush(20);
        var stats = m.current.players["a"].healing;
        check(stats.hits == 10 && stats.output == 200 && m.current.players["me"].heal == 0,
            "Continuous ticks retain total output and never double count their HP gains");

        m = model(); c = new HealingCapture();
        heal(c, m, 11, "a", false, 100); heal(c, m, 11.03, "b", false, 100); c.flush(15);
        check(m.current.players["a"].heal == 100 && m.current.players["b"].heal == 100,
            "Both healers retain their output even when no HP change follows");
        check(m.current.pendingHealing == 0, "No obsolete effective-healing measurement holds the archive open");
    }
}
