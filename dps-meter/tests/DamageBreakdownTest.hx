import dpsmeter.CombatModel;
import dpsmeter.DamageBreakdown;
import dpsmeter.FightHistory;
import haxe.Json;

class DamageBreakdownTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function profile(id:String = "me"):PlayerInfo return {
        uid: id, name: id == "me" ? "Wink" : "Ally", isMe: id == "me", className: "mage",
        weapon: null, classSkills: [], weaponSkills: []
    };
    static function hit(amount:Float, type:String, affinity:String, critical:Bool = false, skill:String = "Mixed"):DamageEvent return {
        time: 2, source: "me", amount: amount, critical: critical, kill: false, effect: 0, skill: skill,
        target: "boss", bossKind: "Boss", bossFlags: 16, bossLevel: 1, bossFoeId: 1,
        damageType: type, affinity: affinity
    };
    static function main():Void {
        check(DamageBreakdown.classify(true, false) == "physical", "Native physical flag");
        check(DamageBreakdown.classify(false, true) == "magical", "Native magic flag");
        check(DamageBreakdown.classify(false, false, "Raw") == "raw", "Explicit Raw affinity is its own type");
        check(DamageBreakdown.classify(null, null, "Raw") == "raw", "Raw does not need physical/magic getters");
        check(DamageBreakdown.classify(false, true, "Chaos") == "magical", "Chaos retains its native magical classification");
        for (flags in [[false, false], [true, true], [null, true], [false, null]])
            check(DamageBreakdown.classify(flags[0], flags[1]) == "unclassified", "Unavailable/ambiguous flags never guess a type");

        var fight = new Fight(1); fight.me = "me"; fight.outcome = "Victory";
        fight.add(hit(60, "physical", "TestPhysical"), profile());
        fight.add(hit(30, "magical", "TestFire", true), profile());
        fight.add(hit(10, "magical", "TestIce"), profile());
        var healing = hit(900, "physical", "TestPhysical", true); healing.effect = 1;
        fight.add(healing, profile());
        var ally = hit(1000, "magical", "TestFire"); ally.source = "ally";
        fight.add(ally, profile("ally"));
        var player = fight.players["me"];
        var data:Dynamic = player.damageBreakdown.json(player.damage);
        check(player.damage == 100 && player.heal == 900, "Damage/healing totals retain existing behavior");
        check(data.physical.damage == 60 && data.magical.damage == 40 && data.unclassified.damage == 0,
            "Damage buckets use actual amounts and exclude healing");
        check(data.physical.percent == 60 && data.magical.percent == 40, "Percentages are per-player, not party damage or hit counts");
        check(data.physical.hits == 1 && data.physical.crits == 0 && data.magical.hits == 2 && data.magical.crits == 1,
            "Separate type hit/crit counts exclude healing");
        check(data.magical.critical_damage == 30 && data.physical.critical_damage == 0, "Critical damage is retained separately");
        check((cast data.affinities:Array<Dynamic>).length == 3, "Raw per-hit affinities are preserved");
        var fire = [for (a in (cast data.affinities:Array<Dynamic>)) if (a.affinity == "TestFire") a][0];
        check(fire.type == "magical" && fire.damage == 30 && fire.percent == 30 && fire.crits == 1,
            "Affinity details include type, amount, contribution, and critical hits");
        var skill:Dynamic = player.skills["Mixed"].json("Mixed", 1).damage_breakdown;
        check(skill.physical.damage == 60 && skill.magical.damage == 40 && skill.magical.percent == 40,
            "The same ability can deal both types; it is not assigned one fixed type");
        var distribution = player.skills["Mixed"].damageBreakdown.distribution(100);
        check(distribution.physical == 0.6 && distribution.magical == 0.4 && distribution.raw == 0,
            "Distribution uses each ability's damage, independently of party contribution");
        var mixed = new DamageBreakdown();
        mixed.add(hit(581, "physical", "Physical")); mixed.add(hit(9884, "magical", "Magic"));
        distribution = mixed.distribution(10465);
        check(Math.abs(distribution.physical - 581 / 10465) < 0.000001
            && Math.abs(distribution.magical - 9884 / 10465) < 0.000001,
            "Recorded mixed Gaping Wound damage retains unrounded bar proportions");
        mixed.add(hit(1000, "raw", "Raw"));
        distribution = mixed.distribution(11465);
        check(Math.abs(distribution.physical + distribution.magical + distribution.raw - 1) < 0.000001
            && Math.abs(distribution.raw - 1000 / 11465) < 0.000001, "Raw occupies the remaining gray share");
        var rawOnly = new DamageBreakdown(); rawOnly.add(hit(20, "raw", "Raw"));
        distribution = rawOnly.distribution(20);
        check(distribution.physical == 0 && distribution.magical == 0 && distribution.raw == 1,
            "A fully Raw skill has a completely gray bar");
        var rounded = new DamageBreakdown(); rounded.add(hit(10.4, "magical", "Magic"));
        check(rounded.distribution(10).magical == 1, "Rounded exported totals do not invent a Raw remainder");
        check(new DamageBreakdown().distribution(100) == null && mixed.distribution(0) == null
            && mixed.distribution(12000) == null, "Missing, zero and incomplete totals have no distribution bar");
        mixed.add(hit(1, "unclassified", ""));
        check(mixed.distribution(11466) == null, "Unknown damage cannot be mistaken for Raw");

        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "mixed")));
        var restored = FightHistory.decode(record);
        check(Json.stringify(restored.players["me"].damageBreakdown.json(100)) == Json.stringify(data), "Player breakdown survives archive JSON roundtrip");
        check(restored.players["me"].skills["Mixed"].damageBreakdown.json(100).magical.critical_damage == 30,
            "Ability detail survives archive JSON roundtrip");
        var summary = FightHistory.chartDetail(FightHistory.entry(record));
        check(StringTools.endsWith(summary, "Victory  ·  Physical: 60%  ·  Magical: 40%  ·  Raw: 0%") && summary.indexOf("\n") < 0,
            "The named player's split follows the outcome in the same chart/snapshot summary row");
        check(FightHistory.attemptHeading(FightHistory.entry(record)).indexOf("Physical") < 0, "Attempt-list headings stay compact");

        var report = fight.json("time", 1);
        var me = [for (p in (cast report.players:Array<Dynamic>)) if (p.is_me) p][0];
        check(me.damage_breakdown.magical.percent == 40 && me.skills[0].damage_breakdown.physical.damage == 60,
            "Uploader log includes player and ability breakdowns");
        var imported = FightHistory.legacy(Json.parse(Json.stringify(report)), fight.startedAt + 1000, "imported");
        check(FightHistory.entry(imported).damageTypeSummary == "Physical: 60%  ·  Magical: 40%  ·  Raw: 0%", "Report import preserves new breakdowns");

        var frozen = fight.copy();
        fight.add(hit(100, "magical", "TestFire"), profile());
        check(frozen.players["me"].damageBreakdown.json(100).magical.damage == 40
            && frozen.players["me"].skills["Mixed"].damageBreakdown.json(100).magical.damage == 40,
            "Completed player and skill copies never change when live hits arrive");
        check(me.damage_breakdown.magical.damage == 40 && me.skills[0].damage_breakdown.magical.damage == 40
            && record.players[1].damageBreakdown.magical.damage == 40, "Worker-bound reports and archives are detached");
        data.magical.damage = 999;
        fire.damage = 999;
        check(player.damageBreakdown.json(200).magical.damage == 140, "Serialized data does not mutate live buckets");

        for (p in (cast record.players:Array<Dynamic>)) {
            Reflect.deleteField(p, "damageBreakdown");
            for (s in (cast p.skills:Array<Dynamic>)) Reflect.deleteField(s, "damageBreakdown");
        }
        var old = FightHistory.decode(record);
        check(old.players["me"].damage == 100 && old.players["me"].skills["Mixed"].damage == 100, "Old charts retain all damage");
        check(old.players["me"].damageBreakdown.json(100) == null && old.players["me"].skills["Mixed"].damageBreakdown.json(100) == null,
            "Missing historical types remain unavailable");
        check(StringTools.endsWith(FightHistory.chartDetail(FightHistory.entry(record)), "Victory"), "Old chart summaries do not fabricate percentages");
        for (p in (cast report.players:Array<Dynamic>)) {
            Reflect.deleteField(p, "damage_breakdown");
            for (s in (cast p.skills:Array<Dynamic>)) Reflect.deleteField(s, "damage_breakdown");
        }
        check(FightHistory.entry(FightHistory.legacy(report, fight.startedAt + 1000, "old")).damageTypeSummary == "",
            "Original uploader reports still import without type data");

        var unknown = hit(100, "unclassified", "", false, "");
        frozen.add(unknown, profile());
        check(frozen.players["me"].damageBreakdown.summary(200) == "Physical: 30%  ·  Magical: 20%  ·  Raw: 0%",
            "Unsupported and unattributed hits stay in the denominator but are omitted from the display");
        check(frozen.players["me"].damageBreakdown.json(200).unclassified.hits == 1, "Unattributed hits still have player-level details");
        check(DamageBreakdown.percent(1, 3) == 33.3 && DamageBreakdown.percent(0, 0) == 0, "Rounded percentages and zero denominator");
        var zero = new PlayerStats(profile()); zero.add(hit(0, "physical", ""), profile());
        check(zero.damageBreakdown.summary(0) == "" && zero.damageBreakdown.json(0).physical.percent == 0,
            "Zero-damage fights have finite data and no misleading split");

        var gates = new Fight(1); gates.me = "me"; gates.add(hit(100, "physical", "TestPhysical"), profile());
        var boss = new Fight(3); boss.me = "me"; boss.outcome = "Defeat"; boss.add(hit(300, "magical", "TestFire"), profile());
        check(StringTools.endsWith(FightHistory.recapDetail({gate: gates, boss: boss}), "Defeat  ·  Physical: 25%  ·  Magical: 75%  ·  Raw: 0%"),
            "Recap combines both phases by damage, not an average of percentages");
        check(StringTools.endsWith(FightHistory.recapDetail({gate: null, boss: boss}), "Defeat  ·  Physical: 0%  ·  Magical: 100%  ·  Raw: 0%"),
            "Boss-only recap has its own split");
        check(StringTools.endsWith(FightHistory.recapDetail({gate: old, boss: boss}), "Physical: 0%  ·  Magical: 75%  ·  Raw: 0%"),
            "A phase without recorded types cannot inflate a recap's known shares");
        rawBreakdowns();
        Sys.println('Damage breakdown: $checks checks passed');
    }

    static function rawBreakdowns():Void {
        var fight = new Fight(1); fight.me = "me"; fight.outcome = "Victory";
        fight.add(hit(60, "physical", "Physical"), profile());
        fight.add(hit(40, "magical", "Chaos"), profile());
        fight.add(hit(50, DamageBreakdown.classify(false, false, "Raw"), "Raw", true), profile());
        fight.add(hit(30, "raw", "Raw"), profile());
        fight.add(hit(20, "unclassified", "Unknown", true), profile());
        var healing = hit(900, "raw", "Raw", true); healing.effect = 1;
        fight.add(healing, profile());
        var split = "Physical: 30%  ·  Magical: 20%  ·  Raw: 40%";
        var stats = fight.players["me"];
        var data = stats.damageBreakdown.json(stats.damage);
        check(stats.damage == 200 && stats.heal == 900 && data.raw.damage == 80 && data.raw.percent == 40,
            "Raw damage uses actual damage and excludes Raw-affinity healing");
        check(data.raw.hits == 2 && data.raw.crits == 1 && data.raw.critical_damage == 50,
            "Raw logs retain hit counts, crit counts, and critical damage");
        check(data.unclassified.damage == 20 && data.unclassified.percent == 10 && data.unclassified.critical_damage == 20,
            "Unclassified details are still logged separately");
        var raw = [for (a in (cast data.affinities:Array<Dynamic>)) if (a.affinity == "Raw") a][0];
        check(raw.type == "raw" && raw.damage == 80 && raw.hits == 2 && raw.crits == 1,
            "Raw affinity detail uses the Raw type");
        check(stats.damageBreakdown.summary(200) == split, "Displayed percentages include Raw and do not renormalize away unclassified damage");
        var report = fight.json("time", 1);
        var logged:Dynamic = report.players[0];
        check(logged.damage_breakdown.raw.damage == 80 && logged.skills[0].damage_breakdown.raw.critical_damage == 50
            && logged.skills[0].damage_breakdown.unclassified.damage == 20, "Player and ability uploader logs include Raw and unclassified");
        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "raw")));
        var restored = FightHistory.decode(record);
        check(Json.stringify(restored.players["me"].damageBreakdown.json(200)) == Json.stringify(data)
            && restored.players["me"].skills["Mixed"].damageBreakdown.json(200).raw.damage == 80,
            "Raw player and ability details survive history roundtrip");
        check(StringTools.endsWith(FightHistory.chartDetail(FightHistory.entry(record)), "Victory  ·  " + split),
            "History and snapshot detail includes Raw after the outcome");
        check(FightHistory.entry(FightHistory.legacy(report, fight.startedAt + 1000, "raw-import")).damageTypeSummary == split,
            "Raw survives uploader report import");
        var copy = fight.copy(); fight.add(hit(100, "raw", "Raw"), profile());
        check(copy.players["me"].damageBreakdown.json(200).raw.damage == 80
            && copy.players["me"].skills["Mixed"].damageBreakdown.json(200).raw.damage == 80, "Raw copies remain detached from new hits");
        var gates = new Fight(1); gates.me = "me"; gates.add(hit(200, "physical", "Physical"), profile());
        check(StringTools.endsWith(FightHistory.recapDetail({gate: gates, boss: copy}), "Physical: 65%  ·  Magical: 10%  ·  Raw: 20%"),
            "Recap weights Raw across phases and leaves unclassified out of the display");

        // Reproduce the previous schema: Raw was included in unclassified,
        // but its exact per-affinity totals were already recorded.
        var previous:Dynamic = Json.parse(Json.stringify(data));
        Reflect.deleteField(previous, "raw");
        previous.unclassified = {damage: 100, percent: 50, hits: 3, crits: 2, critical_damage: 70};
        for (a in (cast previous.affinities:Array<Dynamic>)) if (a.affinity == "Raw") a.type = "unclassified";
        var untouched = Json.stringify(previous);
        var recovered = DamageBreakdown.read(previous).json(200);
        check(Json.stringify(recovered) == Json.stringify(data), "Previous Raw affinities move all damage and crit details out of unclassified");
        check(Json.stringify(previous) == untouched, "Opening earlier breakdowns does not mutate source data");
        check(Json.stringify(DamageBreakdown.read(recovered).json(200)) == Json.stringify(data), "Reading a migrated breakdown does not count Raw twice");
        record.players[0].damageBreakdown = previous;
        record.players[0].skills[0].damageBreakdown = previous;
        check(FightHistory.entry(record).damageTypeSummary == split
            && FightHistory.decode(record).players["me"].skills["Mixed"].damageBreakdown.json(200).raw.damage == 80,
            "Earlier fight history recovers Raw for both summary and ability data");
        previous.affinities = [];
        var unavailable = DamageBreakdown.read(previous).json(200);
        check(unavailable.raw.damage == 0 && unavailable.unclassified.damage == 100,
            "History without Raw affinity evidence stays unclassified in logs");
    }
}
