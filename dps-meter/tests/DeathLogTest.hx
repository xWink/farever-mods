import dpsmeter.DeathLog;
import dpsmeter.MeterConfig;

class DeathLogTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function hit(time:Float, amount:Float, source:String, skill:String, heal:Bool = false, kill:Bool = false,
        hp:Float = 100, maxHp:Float = 1000, className:String = ""):IncomingHit {
        return {time: time, amount: amount, heal: heal, critical: false, kill: kill, skill: skill, skillId: skill,
            source: source, className: className, hp: hp, maxHp: maxHp};
    }
    static function main():Void {
        check(DeathLog.isHeal("Heal", 3), "A Heal result is healing even when its index is not 1");
        check(DeathLog.isHeal("1", 1), "Effect 1 stays healing when the value prints as a number");
        check(DeathLog.isHeal("HoT", 0), "Heal over time is healing");
        check(!DeathLog.isHeal("Damage", 0), "Ordinary damage is not healing");
        check(DeathLog.shownHeal(500, 1) == 500, "A displayed heal keeps its amount");
        check(DeathLog.shownHeal(2, 2) == 4, "Healing uses the game's scaled amount");
        check(DeathLog.shownHeal(0.4, 1) == 0, "Heals the native feed suppresses are not logged");
        check(!DeathLog.isHeal("Damage", 3), "A damage result is not a heal just because another number is positive");
        check(DeathLog.amount(1840) == "1,840", "Amounts use thousands separators");
        check(DeathLog.signed(1506, true) == "+1,506", "Healing is a positive amount");
        check(DeathLog.signed(11786, false) == "-11,786", "Damage is a negative amount");
        check(DeathLog.timeText(8.16) == "-8.2 s", "Times are tenths of a second before death");
        check(DeathLog.timeText(0) == "0.0 s", "The moment of death reads zero");
        check(DeathLog.timeText(10) == "-10.0 s", "A whole second keeps one decimal");
        check(DeathLog.healthAfter(1000, 5000, 400, false) == 600, "Damage is removed from health before the hit lands");
        check(DeathLog.healthAfter(100, 5000, 800, false) == 0, "Damage cannot push health below zero");
        check(DeathLog.healthAfter(1800, 2000, 500, true) == 2000, "Healing cannot raise health above the maximum");
        check(DeathLog.fraction(600, 5000) == 0.12, "The life bar uses health remaining over the maximum");
        check(DeathLog.fraction(Math.NaN, 5000) == 0, "Missing health draws an empty bar");

        var log = new DeathLog();
        log.record(hit(-0.01, 500, "Wolf", "Bite", false, false, 900));
        log.record(hit(9, 100, "The Guardian", "Slam", false, false, 800));
        log.record(hit(9.5, 40, "You", "Regeneration", true, false, 840, 1000, "cleric"));
        log.record(hit(10, 1840, "The Guardian", "Slam", false, true, 0));
        log.record(hit(10, 0, "Ignored", "Zero"));
        log.record(hit(10, 20, "  ", "Bash", false, false, 0));
        log.observe(true, 10);
        var report = log.take();
        check(report != null, "Dying publishes one report");
        check(log.take() == null, "The report is delivered once");
        check(report.damage == 1960, "Damage is only the last 10 seconds, including the killing hit");
        check(report.healing == 40, "Healing is totaled separately from damage");
        check(report.rows.length == 5, "Each hit stays on its own row, followed by death");
        check(report.rows[0].timeText == "-1.0 s" && report.rows[0].amountText == "-100"
            && report.rows[0].spell == "Slam" && report.rows[0].source == "The Guardian" && report.rows[0].hp == 800,
            "Older hits lead the history with health at that moment");
        check(report.rows[1].timeText == "-0.5 s" && report.rows[1].amountText == "+40" && report.rows[1].heal
            && report.rows[1].className == "cleric", "Heals keep their sign, spell, and healer class");
        check(report.rows[2].timeText == "0.0 s" && report.rows[2].amountText == "-1,840" && report.rows[2].spell == "Slam",
            "The killing hit stays a damage row at the moment of death");
        check(report.rows[3].source == "Unknown" && report.rows[3].spell == "Bash", "A blank attacker name is shown as Unknown");
        var death = report.rows[report.rows.length - 1];
        check(death.death && death.timeText == "0.0 s" && death.amountText == "Death" && death.hp == 0,
            "The history ends on a death row");
        check(report.healthScale == 1000, "Bars share the highest known maximum health");

        log.observe(true, 12);
        check(log.take() == null, "Staying dead does not open another log");
        log.record(hit(12.2, 80, "Wolf", "Bite"));
        check(log.observe(false, 13), "Coming back to life closes the dialog");
        check(!log.observe(false, 13.5), "Staying alive does not ask to close the dialog again");
        check(log.reset() == false, "Resetting a living player leaves the dialog alone");
        log.observe(true, 30);
        check(log.reset(), "Replacing a dead hero counts as living again");
        log.record(hit(20, 15, "Wolf", "Bite"));
        log.observe(true, 21);
        report = log.take();
        check(report != null && report.damage == 15 && report.rows.length == 2,
            "Reviving starts a fresh window and drops hits taken while dead");

        log = new DeathLog();
        log.record(hit(0, 5, "Old", "Hit", false, false, 50));
        log.record(hit(10.1, 7, "Edge", "Hit"));
        log.observe(true, 10);
        report = log.take();
        check(report.damage == 5 && report.rows[0].source == "Old" && report.rows[0].timeText == "-10.0 s",
            "A hit after the death time is excluded");

        log = new DeathLog();
        for (i in 0...9) log.record(hit(9 + i * 0.1, 100 - i, "Add " + i, "Swipe", false, false, 500 - i * 10));
        log.observe(true, 10);
        report = log.take();
        check(report.rows.length == 10 && report.rows[0].source == "Add 0" && report.rows[8].source == "Add 8",
            "Every hit in the window stays in time order");

        log = new DeathLog();
        log.observe(true, 4);
        report = log.take();
        check(report.damage == 0 && report.healing == 0 && report.rows.length == 1 && report.rows[0].death,
            "A death with no hits still ends the history");

        log = new DeathLog();
        log.record(hit(8, 900, "The Guardian", "Unknown ability", false, false, 400));
        log.record(hit(9.6, 200, "The Guardian", "Slam", false, true, 0));
        log.observe(true, 10);
        report = log.take();
        check(report.rows[0].timeText == "-2.0 s" && report.rows[0].spell == "Unknown ability",
            "An unresolved skill name is still shown in the spell column");
        check(report.rows[1].timeText == "-0.4 s" && report.rows[1].amountText == "-200",
            "The killing blow is placed by how long before death it landed");

        Sys.println('Death log: $checks checks passed');
    }
}
