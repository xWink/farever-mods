import dpsmeter.CombatModel;
import haxe.Json;

class CombatModelTest {
    static var checks = 0;
    static function check(condition:Bool, message:String):Void {
        checks++;
        if (!condition) throw message;
    }
    static function player(id:String, name:String, me:Bool = false):PlayerInfo {
        return {uid: id, name: name, isMe: me, className: "warrior",
            weapon: {kind: "TestSword", rarity: "Legendary", level: 25, upgrade: 5},
            classSkills: ["Warrior_Test"], weaponSkills: ["Sword_Test"]};
    }
    static function model():CombatModel {
        var m = new CombatModel(100);
        m.me = "9007199254740993";
        m.profiles[m.me] = player(m.me, "Test \"Hero\"", true);
        m.profiles["2"] = player("2", "Ally");
        m.profiles["3"] = player("3", "Nearby player");
        m.party[m.me] = true; m.party["2"] = true;
        m.difficulty = 2; m.activityId = "TestActivity";
        return m;
    }
    static function event(time:Float = 100, source:String = "9007199254740993", damage:Float = 100,
        kill:Bool = false, boss:Bool = true, target:String = "99", effect:Int = 0):DamageEvent {
        return {time: time, source: source, amount: damage, critical: true, kill: kill,
            effect: effect, skill: "Warrior_Test", target: target, bossKind: boss ? "TestBoss" : "Add",
            bossFlags: boss ? 16 : 0, bossLevel: 25, bossFoeId: 123};
    }
    static function main():Void {
        var m = model();
        m.record(event(100, "3"));
        check(m.boss == null && m.current == null, "Nearby players must not start our encounter");
        m.record(event());
        m.record(event(100.1, "2"));
        m.record(event(100.2, "3"));
        check(m.boss.players.exists("3"), "Named players hitting the same boss participate in its report");
        check(!m.current.players.exists("3"), "The party meter excludes nearby non-party players");
        m.record(event(100.3, "2", 50, true, false, "100"));
        check(m.completed.length == 0 && m.boss != null, "An add kill must not export a run");
        m.record(event(100.4, "2", 70, true, true, "101"));
        check(m.completed.length == 0, "A same-kind boss clone must not finish the real boss");
        m.record(event(101, m.me, 250, true));
        check(m.completed.length == 1 && m.boss == null, "Confirmed real boss kill exports exactly one encounter");
        var report = m.completed[0].json("20260907-120000", 1234);
        var roundTrip:Dynamic = Json.parse(Json.stringify(report));
        check(roundTrip.session_id == "TestBoss-20260907-120000-1234", "Session ID follows the original format");
        check(roundTrip.duration_sec == 1 && roundTrip.difficulty == 2, "Correct duration and difficulty");
        check(roundTrip.players[0].uid == "9007199254740993", "UID remains an exact string beyond Float's integer precision");
        check(roundTrip.players[0].name == 'Test "Hero"', "Player names survive JSON escaping");
        check(roundTrip.players[0].total_damage == 350 && roundTrip.players[0].dps == 350, "Final hit is included in damage and DPS");
        check(roundTrip.players[0].skills[0].damage == 350, "Final hit is included in per-skill totals");
        check(roundTrip.players[0].weapon.upgrade == 5 && roundTrip.players[0].weapons_seen.length == 1, "Equipment metadata is retained and deduplicated");
        m.record(event(101, m.me, 250, true));
        check(m.completed.length == 1, "Duplicate lethal damage does not export again");
        m.record(event(102, m.me, 25));
        check(m.completed[0].players[m.me].damage == 350 && m.completed[0].defeated,
            "A same-frame phase resumption cannot mutate the completed report");

        m = model();
        m.record(event());
        m.record(event(100.2));
        m.record(event(100.7));
        check(m.current.players[m.me].skills["Warrior_Test"].casts == 2, "Multi-hit grouping uses the 350ms hit-gap rule");
        m.record(event(101, m.me, 50, false, false, "2", 1));
        check(m.current.players[m.me].heal == 50 && m.current.players[m.me].damage == 300, "Healing remains separate from damage");
        check(m.boss.players[m.me].heal == 0, "Original boss accumulator excludes healing events");
        m.update(110, true);
        check(m.current != null, "Combat continues while an ally is still in combat");
        check(m.boss == null && m.completed.length == 0, "Boss inactivity times out without upload");
        m.record(event(115));
        check(m.boss.start == 100 && m.boss.players[m.me].damage == 400, "Same boss phase retains the original start time and totals");
        m.update(130, false);
        m.record(event(260));
        check(m.boss.start == 260 && m.boss.players[m.me].damage == 100, "Old attempts cannot be resumed indefinitely");

        m = model();
        m.record(event(100, m.me, 0));
        m.record(event(100, m.me, Math.NaN));
        check(m.current == null && m.boss == null, "Invalid damage cannot create an encounter");
        m.record(event());
        m.update(109, false);
        m.reset(110);
        m.me = "2"; m.profiles["2"] = player("2", "Different character", true); m.party["2"] = true;
        m.record(event(111, "2"));
        check(m.boss.start == 111 && !m.boss.players.exists("9007199254740993"), "Character/zone changes do not merge old encounters");
        Sys.println(checks + " combat/report checks passed");
    }
}
