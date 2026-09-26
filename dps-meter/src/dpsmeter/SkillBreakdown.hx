package dpsmeter;

import dpsmeter.CombatModel.SkillStats;

typedef SkillColumn = {key:String, title:String, x:Int, width:Int};
typedef SkillValues = {damage:Float, percent:Float, casts:Int, avgCast:Float, hits:Int, avgHit:Float, crit:Float, dps:Float};

class SkillBreakdown {
    public static final KEYS = ["ability", "percent", "distribution", "damage", "casts", "avgCast", "hits", "avgHit", "crit"];

    public static function values(skill:SkillStats, total:Float, duration:Float):SkillValues return {
        damage: skill.damage, percent: total > 0 ? skill.damage * 100 / total : 0,
        casts: skill.casts, avgCast: skill.casts > 0 ? skill.damage / skill.casts : 0,
        hits: skill.hits, avgHit: skill.hits > 0 ? skill.damage / skill.hits : 0,
        crit: skill.hits > 0 ? skill.crits * 100 / skill.hits : 0,
        // Match the player chart: each ability uses the whole fight's duration.
        dps: skill.damage / Math.max(1, duration)
    };
    public static function columns(width:Int):Array<SkillColumn> {
        // Keep names, total damage, share, and damage types legible in the small live
        // meter too. Wide history windows show every statistic in its own cell.
        var keys = width >= 800 ? KEYS
            : width >= 700 ? ["ability", "percent", "distribution", "damage", "casts", "hits", "crit"]
            : ["ability", "percent", "distribution", "damage"];
        var ratios = width >= 800 ? [.23, .125, .165, .10, .065, .085, .06, .085, .085]
            : width >= 700 ? [.275, .155, .20, .125, .085, .075, .085]
            : width >= 500 ? [.36, .21, .27, .16]
            : width >= 360 ? [.40, .19, .24, .17] : [.36, .22, .21, .21];
        var titles = ["ability" => "Ability", "percent" => width < 360 ? "Dmg%" : width < 500 ? "Dmg %" : "Damage (%)",
            "distribution" => "Phys/Magic/Raw", "damage" => width < 500 ? "Dmg" : "Damage",
            "casts" => "Casts", "avgCast" => "Avg cast",
            "hits" => "Hits", "avgHit" => "Avg hit", "crit" => "Crit %"];
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
