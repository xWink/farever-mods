package dpsmeter;

import dpsmeter.CombatModel.DamageEvent;

/** Incoming output, including overheal. Recipients need not deal damage or heal. */
class HealingReceived {
    var totals:Map<String, Float> = [];
    var recorded:Bool = true;
    public function new() {}
    public function add(e:DamageEvent):Void {
        if (!recorded || e.target == "" || e.target == "0") return;
        totals[e.target] = (totals.exists(e.target) ? totals[e.target] : 0) + e.amount;
    }
    public function total(uid:String):Null<Float> {
        if (!recorded || uid == "" || uid == "0") return null;
        return totals.exists(uid) ? totals[uid] : 0;
    }
    public function json():Dynamic {
        if (!recorded) return null;
        var result:Dynamic = {};
        for (uid => amount in totals) Reflect.setField(result, uid, amount);
        return result;
    }
    public function copy():HealingReceived return read(json());
    public static function read(value:Dynamic):HealingReceived {
        var result = new HealingReceived();
        result.recorded = value != null && Reflect.isObject(value) && !Std.isOfType(value, Array) && !Std.isOfType(value, String);
        if (result.recorded) for (uid in Reflect.fields(value))
            result.totals[uid] = Math.max(0, FightHistory.number(Reflect.field(value, uid)));
        return result;
    }
}
