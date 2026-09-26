package dpsmeter;

import dpsmeter.CombatModel.DamageEvent;
import dpsmeter.CombatModel.SkillStats;

typedef DamageDistribution = {physical:Float, magical:Float, raw:Float};

private class DamageBucket {
    public var damage:Float = 0;
    public var hits:Int = 0;
    public var crits:Int = 0;
    public var criticalDamage:Float = 0;
    public function new() {}
    public function add(e:DamageEvent):Void {
        damage += e.amount;
        hits++;
        if (e.critical) { crits++; criticalDamage += e.amount; }
    }
    public function merge(other:DamageBucket):Void {
        damage += other.damage; hits += other.hits;
        crits += other.crits; criticalDamage += other.criticalDamage;
    }
    public function subtract(other:DamageBucket):Void {
        damage = Math.max(0, damage - other.damage);
        hits = Std.int(Math.max(0, hits - other.hits));
        crits = Std.int(Math.max(0, crits - other.crits));
        criticalDamage = Math.max(0, criticalDamage - other.criticalDamage);
    }
    public function json(total:Float):Dynamic return {
        damage: damage, percent: DamageBreakdown.percent(damage, total), hits: hits, crits: crits,
        critical_damage: criticalDamage
    };
    public static function read(value:Dynamic):DamageBucket {
        var result = new DamageBucket();
        if (value == null) return result;
        result.damage = FightHistory.number(value.damage);
        result.hits = Std.int(FightHistory.number(value.hits));
        result.crits = Std.int(FightHistory.number(value.crits));
        result.criticalDamage = FightHistory.number(value.critical_damage);
        return result;
    }
}

/** Classify actual hits, never infer their type from a class, weapon, or skill name. */
class DamageBreakdown {
    static final TYPES = ["physical", "magical", "raw", "unclassified"];
    var types:Map<String, DamageBucket> = [];
    var affinities:Map<String, Map<String, DamageBucket>> = [];
    public function new() { for (type in TYPES) types[type] = new DamageBucket(); }
    public static function classify(physical:Dynamic, magical:Dynamic, ?affinity:String):String {
        if (affinity == "Raw") return "raw";
        if (physical == true && magical == false) return "physical";
        if (magical == true && physical == false) return "magical";
        return "unclassified";
    }
    public function add(e:DamageEvent):Void {
        if (e.effect == 1) return; // Healing never contributes to damage percentages.
        var type = TYPES.indexOf(e.damageType) >= 0 ? e.damageType : "unclassified";
        types[type].add(e);
        var affinity = e.affinity == null ? "" : e.affinity;
        if (!affinities.exists(affinity)) affinities[affinity] = new Map<String, DamageBucket>();
        if (!affinities[affinity].exists(type)) affinities[affinity][type] = new DamageBucket();
        affinities[affinity][type].add(e);
    }
    public function hasData():Bool {
        for (bucket in types) if (bucket.hits > 0) return true;
        return false;
    }
    public function merge(other:DamageBreakdown):Void {
        for (type in TYPES) types[type].merge(other.types[type]);
        for (id => values in other.affinities) {
            if (!affinities.exists(id)) affinities[id] = new Map<String, DamageBucket>();
            for (type => bucket in values) {
                if (!affinities[id].exists(type)) affinities[id][type] = new DamageBucket();
                affinities[id][type].merge(bucket);
            }
        }
    }
    public function copy():DamageBreakdown {
        var result = new DamageBreakdown(); result.merge(this); return result;
    }
    public static function percent(amount:Float, total:Float):Float
        return total > 0 ? SkillStats.rounded(amount / total * 100, 1) : 0;
    public function distribution(total:Float):Null<DamageDistribution> {
        var physical = types["physical"].damage, magical = types["magical"].damage, raw = types["raw"].damage;
        var known = physical + magical + raw;
        // Gray means Raw, so incomplete/older records must not look like Raw.
        // Exported totals are rounded to whole damage; type buckets stay exact.
        if (total <= 0 || known <= 0 || types["unclassified"].damage > 0
            || Math.abs(known - total) > Math.max(0.5, total * 0.000001)) return null;
        return {physical: physical / known, magical: magical / known, raw: raw / known};
    }
    public function summary(total:Float):String {
        if (!hasData() || total <= 0) return "";
        // Keep missing/unsupported hits in the denominator, including an older
        // rift phase merged with a new one. Unclassified is only shown in logs.
        return "Physical: " + percent(types["physical"].damage, total) + "%"
            + "  ·  Magical: " + percent(types["magical"].damage, total) + "%"
            + "  ·  Raw: " + percent(types["raw"].damage, total) + "%";
    }
    public function json(total:Float):Dynamic {
        if (!hasData()) return null; // Older logs must not acquire invented zeroes.
        var result:Dynamic = {};
        for (type in TYPES) Reflect.setField(result, type, types[type].json(total));
        var ids = [for (id in affinities.keys()) id]; ids.sort(Reflect.compare);
        var details:Array<Dynamic> = [];
        for (id in ids) for (type in TYPES) if (affinities[id].exists(type)) {
            var row = affinities[id][type].json(total);
            Reflect.setField(row, "affinity", id); Reflect.setField(row, "type", type);
            details.push(row);
        }
        Reflect.setField(result, "affinities", details);
        return result;
    }
    public static function read(value:Dynamic):DamageBreakdown {
        var result = new DamageBreakdown();
        if (value == null) return result;
        for (type in TYPES) result.types[type] = DamageBucket.read(Reflect.field(value, type));
        for (row in FightHistory.array(value.affinities)) {
            var id = FightHistory.text(row.affinity), type = FightHistory.text(row.type);
            if (TYPES.indexOf(type) < 0) continue;
            if (!result.affinities.exists(id)) result.affinities[id] = new Map<String, DamageBucket>();
            result.affinities[id][type] = DamageBucket.read(row);
        }
        // Earlier breakdowns put Raw hits in unclassified but retained the
        // exact affinity. Recover only those recorded hits, without rewriting
        // the source log or inferring a type for any other unknown damage.
        var rawAffinities = result.affinities["Raw"];
        if (Reflect.field(value, "raw") == null && rawAffinities != null && rawAffinities.exists("unclassified")) {
            var raw = rawAffinities["unclassified"];
            result.types["raw"].merge(raw);
            result.types["unclassified"].subtract(raw);
            rawAffinities.remove("unclassified");
            rawAffinities["raw"] = raw;
        }
        return result;
    }
}
