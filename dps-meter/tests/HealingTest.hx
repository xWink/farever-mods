import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.HealingDisplay;
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
    static function event(time:Float, source:String, heal:Bool, amount:Float):DamageEvent return {
        time: time, source: source, amount: amount, critical: true, kill: false,
        effect: heal ? 1 : 0, skill: "Mixed", target: heal ? "ally" : "boss", bossKind: heal ? "" : "Boss",
        bossFlags: heal ? 0 : 16, bossLevel: 30, bossFoeId: 1, damageType: "magical"
    };
    static function main():Void {
        var fight = new Fight(10, "0.3.0.test"); fight.me = "me";
        fight.add(event(10, "me", false, 100), profile("me"));
        fight.add(event(11, "me", true, 500), profile("me"));
        fight.add(event(11.1, "me", true, 500), profile("me"));
        fight.add(event(12, "healer", true, 2000), profile("healer"));
        fight.last = 20; fight.closed = 20;
        var me = fight.players["me"];
        check(me.damage == 100 && me.hits == 1 && me.crits == 1 && me.skills["Mixed"].damage == 100,
            "A mixed healing/damage skill keeps every damage statistic unchanged");
        check(me.heal == 1000 && me.healing.output == 1000, "Output retains the full amounts of both heals");
        check(me.healingSkills["Mixed"].casts == 1 && me.healingSkills["Mixed"].hits == 2
            && me.healingSkills["Mixed"].crits == 2, "Healing has independent cast/hit/crit counts");
        check(fight.ranked(true, true)[0].info.uid == "healer" && fight.ranked(false, true).length == 1,
            "Rank healing by output without inserting healing-only rows in damage view");
        var values = SkillBreakdown.healingValues(me.healingSkills["Mixed"], me.heal, fight.duration());
        check(values.damage == 1000 && values.dps == 100 && values.percent == 100 && values.crit == 100
            && values.avgHit == 500 && values.avgCast == 1000, "Healing breakdown uses output and full encounter duration");
        for (width in [300, 400, 550, 750, 900]) for (recap in [false, true]) {
            var damage = SkillBreakdown.columns(width, recap), healing = SkillBreakdown.columns(width, recap, true);
            check(healing.length == damage.length && healing[2].key == "distribution" && healing[2].title == "Team/Self",
                "Healing has a Team/Self column at every width and in recaps");
            var x = 0;
            for (column in healing) {
                check(column.x == x && column.width > 0, "Remaining healing columns are contiguous and nonempty");
                x += column.width;
            }
            check(x == width, "Healing columns fit the available width");
            check(Json.stringify(SkillBreakdown.columns(width, recap)) == Json.stringify(damage),
                "Switching to healing and back leaves damage columns untouched");
        }
        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "healing")));
        var restored = FightHistory.decode(record), player = restored.players["me"];
        check(player.heal == 1000 && player.healing.output == 1000 && player.healingSkills["Mixed"].output == 1000,
            "History JSON roundtrip retains both meters including per-ability healing output");
        var entry = FightHistory.entry(record);
        check(FightHistory.chartDetail(entry).indexOf("Your DPS: 10") >= 0 && FightHistory.chartDetail(entry).indexOf("Magical: 100%") >= 0,
            "Damage history header is unchanged");
        var summary = HealingDisplay.detail(entry, restored);
        check(summary.indexOf("Your HPS: 100") >= 0 && summary.indexOf("Actual healing") < 0
            && summary.indexOf("Magical") < 0, "Healing header shows HPS without an actual-healing value");
        check(HealingDisplay.detail(entry, restored, restored.players["healer"]).indexOf("HPS: 200") >= 0,
            "Selected healer owns the summary");
        check(summary.indexOf("Total healing: 1,000") >= 0, "History header retains total healing");
        check(HealingDisplay.detail(entry, restored, restored.players["healer"]).indexOf("Total healing: 2,000") >= 0,
            "Total healing follows the selected player rather than the local player");
        var report = fight.json("time", 1), copy = fight.copy();
        var legacy = FightHistory.decode(FightHistory.legacy(Json.parse(Json.stringify(report)), 100000, "import"));
        check(legacy.players["me"].healing.output == 1000, "Report migration preserves healing");
        var recap = RiftRecapHistory.decode(RiftRecapHistory.encode({gate: fight, boss: fight}, "recap"));
        check(recap.gate.players["me"].healingSkills["Mixed"].output == 1000 && recap.boss.players["healer"].heal == 2000,
            "Persisted recaps carry healing in both phases");
        var recapHeader = HealingDisplay.recapDetail(recap);
        check(recapHeader.indexOf("Total healing: 2,000") >= 0 && recapHeader.indexOf("Actual healing") < 0,
            "Rift recap header combines healing output across both phases without actual healing");
        fight.add(event(21, "me", true, 100), profile("me"));
        check(copy.players["me"].healing.output == 1000 && copy.players["me"].healingSkills["Mixed"].output == 1000,
            "Finalized snapshots do not share healing objects with ongoing collection");
        check(record.players[0].healing.output == 1000 && report.players[0].healing.skills[0].output == 1000,
            "Worker payloads are detached from live healing");
        restored.add(event(22, "me", true, 100), profile("me"));
        check(player.healing.output == 1100, "Output does not depend on having a matched HP observation");
        player.healing.estimatedHits = 1; player.healing.unknownOutputHits = 1; player.healing.knownCritHits = 1;
        var clean = HealingDisplay.detail(entry, restored);
        check(clean.indexOf("~") < 0 && clean.indexOf("≥") < 0 && clean.indexOf("(partial)") < 0,
            "Healing headers remove every requested uncertainty decoration");
        check(HealingDisplay.crit(player.healing).indexOf("~") < 0, "Mixed critical samples also omit the tilde");
        for (data in [record, report, RiftRecapHistory.encode(recap, "output_recap")]) outputOnly(data);
        // The previous build stored guessed effective healing. Ignore it on
        // read, and strip it if that record is saved/exported/imported again.
        for (p in (cast record.players:Array<Dynamic>)) addObsolete(p.healing);
        var oldHealing = FightHistory.decode(record);
        check(oldHealing.players["me"].healing.output == 1000
            && oldHealing.players["me"].healingSkills["Mixed"].output == 1000,
            "Older healing logs retain their player and skill output");
        outputOnly(FightHistory.encode(oldHealing, "resaved"));
        outputOnly(oldHealing.json("time", 1));
        for (p in (cast report.players:Array<Dynamic>)) addObsolete(p.healing);
        var imported = FightHistory.legacy(report, 100000, "old-import");
        outputOnly(imported);
        check(FightHistory.decode(imported).players["healer"].heal == 2000,
            "Legacy import strips effective fields without changing healing totals");
        for (p in (cast record.players:Array<Dynamic>)) Reflect.deleteField(p, "healing");
        var old = FightHistory.decode(record);
        check(old.players["me"].damage == 100 && !old.players["me"].healingRecorded && !HealingDisplay.recorded(old),
            "Old logs load without inventing healing records");
        check(HealingDisplay.detail(entry, old).indexOf("Total healing: unavailable") >= 0
            && HealingDisplay.detail(entry, old).indexOf("Actual healing") < 0, "Damage-only logs do not invent healing totals");
        boundaries(); zeroContributionIdentity(); recipients();
        Sys.println('Healing meter: $checks checks passed');
    }
    static final OBSOLETE = ["actual", "overheal", "measuredOutput", "measuredHits", "estimatedActualHits", "actualMethod"];
    static function outputOnly(value:Dynamic):Void {
        if (value == null || Std.isOfType(value, String)) return;
        if (Std.isOfType(value, Array)) {
            for (item in (cast value:Array<Dynamic>)) outputOnly(item);
        } else if (Reflect.isObject(value)) {
            for (key in Reflect.fields(value)) {
                check(!OBSOLETE.contains(key), "History, recaps and uploader reports must not save " + key);
                outputOnly(Reflect.field(value, key));
            }
        }
    }
    static function addObsolete(healing:Dynamic):Void {
        for (key in OBSOLETE) Reflect.setField(healing, key, key == "actualMethod" ? "replicated-health-correlation" : cast 125);
        for (s in (cast healing.skills:Array<Dynamic>))
            for (key in OBSOLETE) Reflect.setField(s, key, 125);
    }
    static function recipients():Void {
        var fight = new Fight(10); fight.me = "me"; fight.meName = "me";
        var e = event(11, "me", true, 300); e.target = "me";
        fight.add(e, profile("me"));
        e = event(12, "me", true, 700); e.target = "ally";
        fight.add(e, profile("me"));
        e = event(13, "healer", true, 500); e.target = "me";
        fight.add(e, profile("healer"));
        e = event(14, "healer", true, 200); e.target = "healer";
        fight.add(e, profile("healer"));
        var stats = fight.players["me"].healing, skill = fight.players["me"].healingSkills["Mixed"];
        check(stats.teamOutput == 700 && stats.selfOutput == 300 && stats.output == 1000,
            "Caster identity splits outgoing healing into team and self without changing total output");
        check(skill.distribution().team == .7 && skill.distribution().self == .3,
            "An ability's bar uses its own team/self percentages");
        check(fight.healingReceived.total("me") == 800 && fight.healingReceived.total("ally") == 700
            && fight.healingReceived.total("healer") == 200,
            "Incoming healing credits recipients, including self-heals, exactly once");
        check(!fight.players.exists("ally") && fight.healingReceived.total("nobody") == 0,
            "Receiving-only players are tracked without inventing outgoing healing or damage rows");
        e = event(15, "me", true, 100); e.target = "me"; e.unattributedHealing = true; e.skill = "Regen / unattributed";
        fight.add(e, profile("me"));
        check(stats.selfOutput == 300 && stats.unattributedOutput == 100
            && fight.players["me"].healingSkills[e.skill].distribution() == null,
            "Unattributed recovery never becomes confirmed self-healing");
        check(Math.abs(stats.distribution().team + stats.distribution().self - 1000 / 1100) < .000001,
            "Unattributed output stays neutral rather than inflating the colored shares");
        check(fight.healingReceived.total("me") == 900, "Unattributed recovery still has a known recipient");
        var unknown = new dpsmeter.HealingStats();
        e = event(16, "me", true, 80); e.target = ""; unknown.add(e);
        check(unknown.distribution() == null && unknown.unattributedOutput == 80,
            "Missing recipients cannot be classified as team healing");
        fight.healingReceived.add(e);
        check(fight.healingReceived.total("me") == 900 && fight.healingReceived.total("") == null,
            "An unknown recipient never becomes the caster's incoming healing");
        fight.last = 20; fight.closed = 20;
        var record = Json.parse(Json.stringify(FightHistory.encode(fight, "recipients")));
        var restored = FightHistory.decode(record), copy = fight.copy();
        var report = fight.json("time", 1);
        var imported = FightHistory.decode(FightHistory.legacy(Json.parse(Json.stringify(report)), 100000, "recipients-import"));
        for (f in [restored, copy, imported]) {
            check(f.healingReceived.total("me") == 900 && f.healingReceived.total("ally") == 700,
                "Recipient totals survive detached copies, archives and report imports");
            check(f.players["me"].healing.teamOutput == 700 && f.players["me"].healing.selfOutput == 300
                && f.players["me"].healing.unattributedOutput == 100
                && f.players["me"].healingSkills["Mixed"].distribution().team == .7,
                "Player and ability distributions survive every persistence path");
        }
        var entry = FightHistory.entry(record);
        check(HealingDisplay.detail(entry, restored).indexOf("Total healing received: 900") >= 0
            && HealingDisplay.detail(entry, restored, restored.players["healer"]).indexOf("Total healing received: 200") >= 0,
            "Incoming header follows the selected player");
        var recap = RiftRecapHistory.decode(RiftRecapHistory.encode({gate: fight, boss: fight}, "recipient-recap"));
        check(HealingDisplay.recapDetail(recap).indexOf("Total healing received: 1,800") >= 0,
            "Recap header sums incoming healing across both recorded phases");
        var onlyRecipient = new Fight(10); onlyRecipient.me = "ally";
        e = event(11, "healer", true, 700); e.target = "ally";
        onlyRecipient.add(e, profile("healer"));
        check(HealingDisplay.detail(FightHistory.entry(FightHistory.encode(onlyRecipient, "only-recipient")), onlyRecipient)
            .indexOf("Total healing received: 700") >= 0,
            "The local header includes incoming healing even when that player has no output row");
        e = event(21, "me", true, 100); e.target = "me";
        fight.add(e, profile("me"));
        check(copy.healingReceived.total("me") == 900 && record.healingReceived.me == 900 && report.healing_received.me == 900
            && copy.players["me"].healing.selfOutput == 300,
            "Later heals cannot mutate saved or worker-bound recipient totals and distributions");
        Reflect.deleteField(record, "healingReceived");
        for (p in (cast record.players:Array<Dynamic>)) {
            Reflect.deleteField(p.healing, "distribution");
            for (s in (cast p.healing.skills:Array<Dynamic>)) Reflect.deleteField(s, "distribution");
        }
        var old = FightHistory.decode(record);
        check(old.healingReceived.total("me") == null && old.players["me"].healingSkills["Mixed"].distribution() == null
            && old.players["me"].healing.output == 1100,
            "Older healing logs keep output without inventing a recipient split");
        check(HealingDisplay.detail(entry, old).indexOf("Total healing received: unavailable") >= 0,
            "Old logs show unavailable instead of a misleading zero");
        var resaved = FightHistory.decode(FightHistory.encode(old, "resaved-recipients"));
        check(resaved.healingReceived.total("me") == null && resaved.players["me"].healing.distribution() == null,
            "Re-saving an older log preserves missing-data status");
        check(HealingDisplay.recapDetail({gate: old, boss: restored}).indexOf("Total healing received: unavailable") >= 0,
            "A recap with an older phase cannot present a partial incoming total as complete");
    }
    static function zeroContributionIdentity():Void {
        var m = new CombatModel(0, "test"); m.me = "me";
        for (id in ["me", "healer"]) { m.profiles[id] = profile(id); m.party[id] = true; }
        m.onCombatEnter("me", 10); m.record(event(10, "healer", false, 100));
        check(!m.current.players.exists("me") && m.current.meName == "me" && m.current.meClass == "cleric",
            "Local identity is recorded without inventing a damage or healing contribution");
        m.onCombatExit("me", 20); m.update(21, false);
        var record = Json.parse(Json.stringify(FightHistory.encode(m.history[0], "zero")));
        var entry = FightHistory.entry(record);
        check(entry.playerName == "me" && entry.playerClass == "cleric" && entry.personalDps == 0,
            "A zero-contribution player's name and class survive archive copying and JSON storage");
        var reopened = FightHistory.encode(FightHistory.decode(record), "reopened");
        check(reopened.meClass == "cleric" && FightHistory.entry(reopened).playerClass == "cleric",
            "Reopening a zero-contribution fight preserves the independent character class");
        Reflect.deleteField(record, "meClass");
        check(FightHistory.entry(record).playerClass == "" && FightHistory.decode(record).meClass == "",
            "Older records without local class remain readable without borrowing an ally's class");

        m = new CombatModel(0, "test"); m.me = "me";
        for (id in ["me", "healer"]) { m.profiles[id] = profile(id); m.party[id] = true; }
        m.enableRift(); m.updateRiftState(1, false, false, "Boss"); m.startRiftGates();
        m.onCombatEnter("me", 10);
        var gateHit = event(10, "healer", false, 100); gateHit.bossFlags = 0; gateHit.bossKind = "";
        m.record(gateHit);
        check(m.current.meClass == "cleric" && !m.current.players.exists("me"),
            "Rift gates store local class even when only another player contributes");
        m.updateRiftState(20, true, false, "Boss"); m.record(event(21, "healer", false, 100));
        m.updateRiftState(30, true, true, "Boss"); m.update(31, false);
        check(m.recapHistory.length == 1 && m.recapHistory[0].boss.meClass == "cleric",
            "The rift boss and its detached recap retain the zero-contribution local class");
        record = Json.parse(Json.stringify(RiftRecapHistory.encode(m.recapHistory[0], "zero_recap")));
        entry = FightHistory.entry(record);
        check(entry.playerName == "me" && entry.playerClass == "cleric" && entry.personalDps == 0,
            "The recap log list retains a class colour when local damage is zero in both phases");
        Reflect.deleteField(record.boss, "meClass");
        check(FightHistory.entry(record).playerClass == "cleric",
            "A recap can retain the same character's known class from the gate phase");
    }
    static function boundaries():Void {
        var m = new CombatModel(0, "test"); m.me = "me";
        for (id in ["me", "healer"]) { m.profiles[id] = profile(id); m.party[id] = true; }
        m.record(event(1, "me", true, 100));
        check(m.current == null && m.boss == null, "Out-of-combat heals do not start/log phantom damage fights");
        m.onCombatEnter("me", 10); m.record(event(10, "me", false, 100));
        var start = m.current.start, lastDamage = m.boss.last;
        m.record(event(11, "healer", true, 1000));
        check(m.current.players["healer"].heal == 1000 && m.boss.players["healer"].healing.output == 1000,
            "A healer need not damage the boss to be included in local and uploaded logs");
        check(m.current.start == start && m.boss.last == lastDamage && m.current.players["me"].damage == 100,
            "Healing preserves encounter start and uploader damage-idle boundaries");
        m.onCombatExit("me", 20); m.update(21, false);
        check(m.history.length == 1 && m.history[0].players["healer"].heal == 1000, "Encounter archive retains both meters");
        m.record(event(22, "me", true, 100));
        check(m.history[0].players["me"].heal == 0, "Post-fight recovery does not leak into a completed log");
    }
}
