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
        m.onCombatEnter(m.me, 100);
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
        m.onCombatEnter(m.me, 100);
        m.record(event());
        m.record(event(100.2));
        m.record(event(100.7));
        check(m.current.players[m.me].skills["Warrior_Test"].casts == 2, "Multi-hit grouping uses the 350ms hit-gap rule");
        m.record(event(101, m.me, 50, false, false, "2", 1));
        check(m.current.players[m.me].heal == 50 && m.current.players[m.me].damage == 300, "Healing remains separate from damage");
        check(m.boss.players[m.me].heal == 0, "Original boss accumulator excludes healing events");
        m.record(event(107, "2", 50, false, false, "another-mob"));
        m.update(110, true);
        check(m.current != null, "Recent ally damage keeps the party encounter active");
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

        m = model();
        m.update(100, true);
        m.record(event(100, m.me, 100, false, false));
        m.record(event(101, m.me, 150, true, false));
        m.update(101.1, false);
        check(m.current == null && m.lastCombat != null && m.boss == null,
            "Leaving combat after an ordinary mob immediately ends Current");
        var previous = m.lastCombat;
        check(previous.players[m.me].damage == 250 && Math.abs(previous.duration(200) - 1.1) < 0.00001,
            "Last keeps the completed damage and freezes elapsed time at combat exit");
        m.record(event(102, m.me, 20, false, false, m.me, 1));
        m.update(103, false);
        check(m.current == null && m.lastCombat == previous && m.session.players[m.me].heal == 20,
            "Resting healing remains in Session without reopening Current or replacing Last");
        m.record(event(104, m.me, 75, false, false, "another-mob"));
        m.onCombatEnter(m.me, 104.2);
        check(m.current.start == 104 && m.current.players[m.me].damage == 75 && m.lastCombat == previous,
            "The next ordinary mob starts a separate encounter");

        m = model();
        m.record(event(100, m.me, 100, true, false));
        m.update(100.25, false);
        check(m.displayedFight() == null, "Unconfirmed damage cannot start a visible timer");
        m.record(event(101.2, m.me, 20, false, false, m.me, 1));
        m.update(108, false);
        check(m.displayedFight() == null && m.session.players[m.me].damage == 100 && m.session.players[m.me].heal == 20,
            "Out-of-combat damage and healing remain in Session without creating a phantom encounter");
        m.onCombatEnter(m.me, 109);
        check(m.current.start == 109 && !m.current.players.iterator().hasNext(),
            "Expired unconfirmed damage cannot leak into a later encounter");

        m = model();
        m.onCombatEnter("2", 100);
        check(m.current == null, "Another hero's entry does not start our timer");
        m.onCombatEnter(m.me, 100);
        check(m.current != null && m.current.duration(102) == 2 && !m.current.players.iterator().hasNext(),
            "Native combat entry starts the timer even before anyone deals damage");
        m.record(event(101, m.me, 100, false, false));
        m.record(event(102, m.me, 150, true, false));
        m.update(106, true);
        check(m.displayedFight().duration(106) == 6 && m.current.players[m.me].damage == 250,
            "Elapsed time advances during combat without requiring another damage event");
        m.record(event(108, m.me, 20, false, false, m.me, 1));
        m.update(120, true);
        check(m.current != null && m.current.start == 100 && m.current.duration(120) == 20,
            "A long dodge/mechanic phase does not expire a fight that is still in combat");
        m.record(event(121, "2", 50, false, false));
        check(m.current.start == 100 && m.current.players[m.me].damage == 250 && m.current.players["2"].damage == 50,
            "Damage after more than eight seconds of active combat stays in the same encounter");
        previous = m.current;
        m.onCombatExit(m.me, 122);
        check(m.displayedFight() == previous && previous.duration(200) == 22,
            "The finished encounter stays visible with its actual frozen elapsed time");
        var finishedDps = previous.players[m.me].damage / previous.duration(122);
        m.record(event(125, m.me, 20, false, false, m.me, 1));
        m.update(130, false);
        check(m.displayedFight() == previous && previous.players[m.me].damage / previous.duration(130) == finishedDps,
            "Resting and healing cannot change the displayed previous damage or DPS");
        m.onCombatEnter(m.me, 131);
        check(m.displayedFight() != previous && Std.int(m.displayedFight().duration(131)) == 0
            && !m.displayedFight().players.iterator().hasNext(),
            "The new fight resets rows and timer together instead of applying a new clock to old totals");
        m.record(event(132, m.me, 80, false, false));
        check(m.current.players[m.me].damage == 80 && previous.players[m.me].damage == 250 && previous.duration(300) == 22,
            "New encounter damage cannot mutate the finished encounter");

        m = model();
        m.record(event(100, m.me, 100, false, false));
        m.onCombatEnter(m.me, 100.2);
        check(m.current.start == 100 && m.current.players[m.me].damage == 100,
            "The first hit is retained if the combat-entry event arrives just afterward");
        m.onCombatExit(m.me, 102);
        previous = m.lastCombat;
        m.onCombatEnter(m.me, 103);
        m.onCombatExit(m.me, 104);
        check(m.displayedFight() == previous, "An empty combat does not erase the last recorded result");

        m = model();
        m.update(100, true);
        m.record(event(100, m.me, 100, false, false));
        m.record(event(101, m.me, 150, true, false));
        previous = m.current;
        m.onCombatExit("2", 101.01);
        check(m.current == previous, "Another hero leaving combat must not reset our meter");
        m.onCombatExit(m.me, 101.02);
        check(m.current == null && m.displayedFight() == previous && Math.abs(previous.duration(200) - 1.02) < 0.00001,
            "The local native exit immediately freezes the displayed encounter, without waiting for a poll or timeout");
        m.record(event(101.03, m.me, 150, true, false));
        check(m.current == null, "A late duplicate kill notification cannot reopen the finished encounter");
        m.update(102, false);
        m.onCombatEnter(m.me, 103);
        m.record(event(103, m.me, 150, true, false, "new-mob"));
        check(m.current.start == 103 && m.current.players[m.me].damage == 150 && Std.int(m.current.duration(103)) == 0,
            "Re-entering within eight seconds starts at zero with fresh totals");
        check(m.lastCombat == previous && previous.players[m.me].damage == 250 && Math.abs(previous.duration() - 1.02) < 0.00001,
            "The short gap and next kill do not alter the previous encounter");
        m.onCombatExit(m.me, 103.01);
        previous = m.lastCombat;
        m.onCombatExit(m.me, 103.02);
        check(m.current == null && m.lastCombat == previous, "Duplicate exit callbacks are harmless");
        m.onCombatEnter(m.me, 103.03);
        m.record(event(103.03, m.me, 50, false, false, "third-mob"));
        check(m.current.start == 103.03 && m.current.players[m.me].damage == 50 && Std.int(m.current.duration(103.03)) == 0,
            "Exit and re-entry between roster polls still create separate encounters");

        m = model();
        m.record(event());
        m.onCombatEnter(m.me, 100);
        var pendingBoss = m.boss;
        m.onCombatExit(m.me, 100.5);
        check(m.current == null && m.boss == pendingBoss && m.session.players[m.me].damage == 100,
            "Resetting the visible encounter does not discard boss collection or session totals");

        m = model();
        var bossHit = event();
        bossHit.bossName = "The Ancient Guardian";
        m.record(bossHit);
        m.onCombatEnter(m.me, 100.2);
        check(m.displayedFight().bossName == "The Ancient Guardian" && m.displayedFight().bossKind == "TestBoss",
            "The header uses the detected boss's display name while preserving its data ID");
        m.record(event(101, m.me, 25, false, false, "add"));
        check(m.current.bossName == "The Ancient Guardian", "Boss names persist while fighting that encounter's adds");
        bossHit = event(102); bossHit.bossName = "The Awakened Guardian";
        m.record(bossHit);
        check(m.current.bossName == "The Awakened Guardian", "The displayed boss name follows phase-name changes");
        m.onCombatExit(m.me, 103);
        previous = m.displayedFight();
        check(previous.bossName == "The Awakened Guardian", "The boss name stays paired with the finished encounter");
        m.onCombatEnter(m.me, 104);
        m.record(event(104, m.me, 50, false, false, "ordinary-mob"));
        check(m.current.bossName == "" && previous.bossName == "The Awakened Guardian",
            "A new ordinary fight cannot inherit the previous boss's header name");

        m = model();
        m.onCombatEnter(m.me, 100);
        m.record(event(100, m.me, 100, false, false));
        m.onCombatExit(m.me, 102);
        previous = m.displayedFight();
        m.update(102.01, true);
        m.update(102.25, true);
        check(m.current == null && m.displayedFight() == previous && previous.duration(102.25) == 2,
            "A stale true combat poll cannot restart the timer after a native exit");
        // These are distinct events, so lethal-hit deduplication cannot mask a restart.
        m.record(event(102.3, m.me, 40, false, false, "late-hit"));
        m.record(event(102.4, "2", 75, true, false, "ally-target"));
        check(m.current == null && m.displayedFight() == previous && previous.players[m.me].damage == 100,
            "Delayed local hits and a party member's kill cannot reopen or alter the finished encounter");
        m.update(102.5, false);
        for (time in 103...114) {
            m.record(event(time, "2", 25, false, false, "ally-target"));
            m.update(time, false);
        }
        check(m.current == null && m.displayedFight() == previous && previous.duration(114) == 2
            && previous.players[m.me].damage / previous.duration(114) == 50,
            "Continuous party damage while resting leaves the last timer, damage, and DPS frozen beyond eight seconds");
        m.record(event(114, m.me, 80, false, false, "new-mob"));
        m.onCombatEnter(m.me, 114.2);
        check(m.current.start == 114 && m.current.players[m.me].damage == 80 && !m.current.players.exists("2")
            && previous.players[m.me].damage == 100,
            "A genuine entry retains its opening hit but excludes earlier out-of-combat damage");
        check(m.session.players[m.me].damage == 220,
            "Applying a buffered opening hit does not count it twice in Session");
        m.update(117, true);
        check(m.current.duration(117) == 3 && m.current.players[m.me].damage == 80,
            "The confirmed timer still advances without further damage");

        m.onCombatExit(m.me, 118);
        m.record(event(118.1, m.me, 30, false, false, "third-mob"));
        m.onCombatEnter(m.me, 118.2);
        check(m.current.start == 118.1 && m.current.players[m.me].damage == 30,
            "A real native re-entry works even before the next poll acknowledges the exit");
        m.onCombatExit(m.me, 119);
        m.update(119.1, false);
        m.update(120, true);
        check(m.current.start == 120 && !m.current.players.iterator().hasNext(),
            "Polling still recovers a new combat entry after observing the previous exit");

        m = model();
        m.record(event(100, "2", 60, false, false));
        m.reset(100.1);
        m.me = "2"; m.profiles["2"] = player("2", "Different character", true); m.party["2"] = true;
        m.onCombatEnter("2", 100.2);
        check(!m.current.players.iterator().hasNext(), "A character or zone reset clears buffered opening damage");

        m = model();
        m.record(event(100, m.me, 100, false, true));
        m.record(event(101, m.me, 150, true, true));
        check(m.current == null && m.completed.length == 1 && m.completed[0].players[m.me].damage == 250,
            "Boss report collection remains independent of the visible encounter's combat-entry requirement");
        Sys.println(checks + " combat/report checks passed");
    }
}
