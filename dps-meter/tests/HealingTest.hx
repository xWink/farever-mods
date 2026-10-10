import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.HealingDisplay;
import dpsmeter.HealingObservation;
import dpsmeter.RiftRecapHistory;
import dpsmeter.SkillBreakdown;
import haxe.Json;

class HealingTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++; if (!value) throw message;
    }
    static function profile(id:String):PlayerInfo return {uid: id, name: id, isMe: id == "me", className: "cleric",
        weapon: null, classSkills: [], weaponSkills: []};
    static function event(time:Float, source:String, heal:Bool, amount:Float, actual:Null<Float> = null):DamageEvent return {
        time: time, source: source, amount: amount, actualHealing: actual, critical: true, kill: false,
        effect: heal ? 1 : 0, skill: "Mixed", target: heal ? "ally" : "boss", bossKind: heal ? "" : "Boss",
        bossFlags: heal ? 0 : 16, bossLevel: 30, bossFoeId: 1, damageType: "magical"
    };
    static function main():Void {
        var fight = new Fight(10, "0.3.0.test"); fight.me = "me";
        fight.add(event(10, "me", false, 100), profile("me"));
        fight.add(event(11, "me", true, 500, 125), profile("me"));
        fight.add(event(11.1, "me", true, 500, 0), profile("me"));
        fight.add(event(12, "healer", true, 2000, 1000), profile("healer"));
        fight.last = 20; fight.closed = 20;
        var me = fight.players["me"];
        check(me.damage == 100 && me.hits == 1 && me.crits == 1 && me.skills["Mixed"].damage == 100,
            "A mixed healing/damage skill keeps every damage statistic unchanged");
        check(me.heal == 1000 && me.healing.output == 1000 && me.healing.actual == 125,
            "Output includes partial and complete overheal; effective healing does not");
        check(me.healingSkills["Mixed"].casts == 1 && me.healingSkills["Mixed"].hits == 2
            && me.healingSkills["Mixed"].crits == 2, "Healing has independent cast/hit/crit counts");
        check(me.healing.complete() && me.healing.measuredOutput == 1000, "Zero effective healing is a known measurement");
        check(fight.ranked(true, true)[0].info.uid == "healer" && fight.ranked(false, true).length == 1,
            "Rank healing by output without inserting healing-only rows in damage view");
        var values = SkillBreakdown.healingValues(me.healingSkills["Mixed"], me.heal, fight.duration());
        check(values.damage == 1000 && values.dps == 100 && values.percent == 100 && values.crit == 100
            && values.avgHit == 500 && values.avgCast == 1000, "Healing breakdown uses output and full encounter duration");
        for (width in [300, 400, 550, 750, 900]) for (recap in [false, true]) {
            var damage = SkillBreakdown.columns(width, recap), healing = SkillBreakdown.columns(width, recap, true);
            check(damage.length == healing.length, "Modes retain the same responsive column counts");
            for (i in 0...damage.length) check(damage[i].width == healing[i].width && damage[i].x == healing[i].x,
                "Changing mode does not alter damage column geometry");
            check([for (c in healing) if (c.key == "distribution") c.title][0] == "Actual healing", "Healing replaces damage types");
        }
        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "healing")));
        var restored = FightHistory.decode(record), player = restored.players["me"];
        check(player.heal == 1000 && player.healing.actual == 125 && player.healingSkills["Mixed"].output == 1000,
            "History JSON roundtrip retains both meters including per-ability effective healing");
        var entry = FightHistory.entry(record);
        check(FightHistory.chartDetail(entry).indexOf("Your DPS: 10") >= 0 && FightHistory.chartDetail(entry).indexOf("Magical: 100%") >= 0,
            "Damage history header is unchanged");
        var summary = HealingDisplay.detail(entry, restored);
        check(summary.indexOf("Your HPS: 100") >= 0 && summary.indexOf("Actual healing: 125") >= 0
            && summary.indexOf("Magical") < 0, "Healing header shows HPS and restored health");
        check(HealingDisplay.detail(entry, restored, restored.players["healer"]).indexOf("HPS: 200") >= 0,
            "Selected healer owns the summary");
        var report = fight.json("time", 1), copy = fight.copy();
        var legacy = FightHistory.decode(FightHistory.legacy(Json.parse(Json.stringify(report)), 100000, "import"));
        check(legacy.players["me"].healing.actual == 125, "Report migration preserves healing");
        var recap = RiftRecapHistory.decode(RiftRecapHistory.encode({gate: fight, boss: fight}, "recap"));
        check(recap.gate.players["me"].healingSkills["Mixed"].output == 1000 && recap.boss.players["healer"].heal == 2000,
            "Persisted recaps carry healing in both phases");
        fight.add(event(21, "me", true, 100, 50), profile("me"));
        check(copy.players["me"].healing.actual == 125 && copy.players["me"].healingSkills["Mixed"].output == 1000,
            "Finalized snapshots do not share healing objects with ongoing collection");
        check(record.players[0].healing.actual == 125 && report.players[0].healing.skills[0].output == 1000,
            "Worker payloads are detached from live healing");
        restored.add(event(22, "me", true, 100), profile("me"));
        check(!player.healing.complete() && HealingDisplay.actual(player.healing, HealingDisplay.number) == "125 (partial)",
            "Missing health observations never silently count as zero/overheal");
        for (p in (cast record.players:Array<Dynamic>)) Reflect.deleteField(p, "healing");
        var old = FightHistory.decode(record);
        check(old.players["me"].damage == 100 && !old.players["me"].healingRecorded && !HealingDisplay.recorded(old),
            "Old logs load without inventing healing records");
        check(HealingDisplay.detail(entry, old).indexOf("Actual healing: unavailable") >= 0, "Old logs do not claim zero actual healing");
        observations(); boundaries();
        Sys.println('Healing meter: $checks checks passed');
    }
    static function observations():Void {
        var o = new HealingObservation();
        o.health("ally", 100, 250);
        check(o.consume("ally", 500, 250, 250) == 150, "Use the pre-RPC health delta, not post-heal missing HP");
        check(o.consume("ally", 500, 250, 250) == 0, "A full overheal restores zero, without reusing the previous healer's delta");
        check(o.consume("ally", 500, 100, 250) == null, "A missing non-full observation stays unknown");
        o.health("ally", 100, 160); o.health("ally", 160, 200);
        check(o.consume("ally", 500, 200, 250) == null, "Merged health changes cannot be attributed to one skill");
        o.health("ally", 200, 100);
        check(o.consume("ally", 500, 100, 250) == null, "Damage deltas cannot be counted as healing");
        o.health("ally", 100, 200);
        check(o.consume("ally", 50, 200, 250) == null, "A larger unrelated gain is not clamped into plausible fake healing");
        o.health("ally", 100, 200); o.clear();
        check(o.consume("ally", 500, 200, 250) == null, "Prior network batches cannot supply stale health gains");
        o.health("ally", 100, 200); o.invalidate("ally");
        check(o.consume("ally", 500, 200, 250) == null, "Damage events invalidate preceding health measurements");
        o.health("ally", 100, 250); o.nextBatch();
        check(o.consume("ally", 500, 250, 250) == null, "Split deliveries cannot turn a missed gain into a full overheal");
    }
    static function boundaries():Void {
        var m = new CombatModel(0, "test"); m.me = "me";
        for (id in ["me", "healer"]) { m.profiles[id] = profile(id); m.party[id] = true; }
        m.record(event(1, "me", true, 100, 50));
        check(m.current == null && m.boss == null, "Out-of-combat heals do not start/log phantom damage fights");
        m.onCombatEnter("me", 10); m.record(event(10, "me", false, 100));
        var start = m.current.start, lastDamage = m.boss.last;
        m.record(event(11, "healer", true, 1000, 200));
        check(m.current.players["healer"].heal == 1000 && m.boss.players["healer"].healing.actual == 200,
            "A healer need not damage the boss to be included in local and uploaded logs");
        check(m.current.start == start && m.boss.last == lastDamage && m.current.players["me"].damage == 100,
            "Healing preserves encounter start and uploader damage-idle boundaries");
        m.onCombatExit("me", 20); m.update(21, false);
        check(m.history.length == 1 && m.history[0].players["healer"].heal == 1000, "Encounter archive retains both meters");
        m.record(event(22, "me", true, 100, 50));
        check(m.history[0].players["me"].heal == 0, "Post-fight recovery does not leak into a completed log");
    }
}
