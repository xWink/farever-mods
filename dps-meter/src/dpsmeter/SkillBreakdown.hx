package dpsmeter;

import dpsmeter.CombatModel.SkillStats;

typedef SkillColumn = {key:String, title:String, x:Int, width:Int};
typedef SkillValues = {damage:Float, percent:Float, casts:Int, avgCast:Float, hits:Int, avgHit:Float, crit:Float, dps:Float};

class SkillBreakdown {
    public static final KEYS = ["ability", "percent", "distribution", "damage", "casts", "avgCast", "hits", "avgHit", "crit", "dps"];

    public static function values(skill:SkillStats, total:Float, duration:Float):SkillValues return {
        damage: skill.damage, percent: total > 0 ? skill.damage * 100 / total : 0,
        casts: skill.casts, avgCast: skill.casts > 0 ? skill.damage / skill.casts : 0,
        hits: skill.hits, avgHit: skill.hits > 0 ? skill.damage / skill.hits : 0,
        crit: skill.hits > 0 ? skill.crits * 100 / skill.hits : 0,
        // Match the player chart: each ability uses the whole fight's duration.
        dps: skill.damage / Math.max(1, duration)
    };
    public static function healingValues(skill:HealingStats, total:Float, duration:Float):SkillValues return {
        damage: skill.output, percent: total > 0 ? skill.output * 100 / total : 0,
        casts: skill.casts, avgCast: skill.casts > 0 ? skill.output / skill.casts : 0,
        hits: skill.hits, avgHit: skill.hits > 0 ? skill.output / skill.hits : 0,
        crit: skill.hits > 0 ? skill.crits * 100 / skill.hits : 0,
        dps: skill.output / Math.max(1, duration)
    };
    public static function columns(width:Int, recap:Bool = false, healing:Bool = false):Array<SkillColumn> {
        // Keep names, total damage, share, and damage types legible in the small live
        // meter too. Wide history windows show every statistic in its own cell.
        var keys = recap ? ["ability", "percent", "distribution", "damage"] : width >= 800 ? KEYS
            : width >= 700 ? ["ability", "percent", "distribution", "damage", "casts", "hits", "crit", "dps"]
            : ["ability", "percent", "distribution", "damage", "dps"];
        // Recaps keep the ability and its three metrics on one line. A compact
        // damage cell leaves room for the name and keeps totals beside the bar.
        // Leave room for full-size recap headings; DPS belongs only to regular tables.
        var ratios = recap ? [.33, .20, .31, .16] : width >= 800 ? [.22, .12, .16, .09, .065, .09, .045, .075, .075, .06]
            : width >= 700 ? [.25, .14, .19, .11, .09, .08, .075, .065]
            : width >= 500 ? [.32, .17, .25, .14, .12]
            : width >= 360 ? [.35, .16, .22, .14, .13] : [.31, .18, .22, .145, .145];
        var titles = ["ability" => "Ability", "percent" => recap ? "Damage %" : width < 360 ? "Dmg%" : width < 500 ? "Dmg %" : "Damage (%)",
            "distribution" => "Phys/Magic/Raw", "damage" => !recap && width < 500 ? "Dmg" : "Damage",
            "casts" => "Casts", "avgCast" => "Avg cast",
            "hits" => "Hits", "avgHit" => "Avg hit", "crit" => "Crit %", "dps" => "DPS"];
        if (healing) {
            titles["percent"] = width < 500 && !recap ? "Heal %" : "Healing %";
            titles["distribution"] = "Actual healing";
            titles["damage"] = width < 500 && !recap ? "Heal" : "Healing";
            titles["dps"] = "HPS";
        }
        var result:Array<SkillColumn> = [];
        var x = 0; var ratio = 0.0;
        for (i in 0...keys.length) {
            ratio += ratios[i];
            var end = i == keys.length - 1 ? width : Std.int(width * ratio);
            result.push({key: keys[i], title: titles[keys[i]], x: x, width: end - x});
            x = end;
        }
        return result;
    }
}
