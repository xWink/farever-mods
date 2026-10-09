package dpsmeter;

typedef IncomingHit = {
    time:Float,
    amount:Float,
    heal:Bool,
    critical:Bool,
    kill:Bool,
    skill:String,
    ?skillId:String,
    source:String,
    ?className:String,
    ?hp:Float,
    ?maxHp:Float
};

/** One row in the death timeline, oldest first. The final row is the death itself. */
typedef DeathEvent = {
    ago:Float,
    timeText:String,
    hp:Float,
    amountText:String,
    heal:Bool,
    death:Bool,
    spell:String,
    skillId:String,
    source:String,
    className:String
};

typedef DeathReport = {
    at:Float,
    damage:Float,
    healing:Float,
    healthScale:Float,
    rows:Array<DeathEvent>
};

/** Incoming damage and healing on the local player, kept for the death dialog. */
class DeathLog {
    public static inline var WINDOW:Float = 10;

    var events:Array<IncomingHit> = [];
    var alive:Bool = true;
    var pending:Null<DeathReport>;

    public function new() {}

    public function record(hit:IncomingHit):Void {
        if (hit == null || !Math.isFinite(hit.time) || !Math.isFinite(hit.amount)) return;
        if (!(hit.amount > 0) && !hit.kill) return;
        if (!alive) return;
        var sourceName = hit.source == null || StringTools.trim(hit.source) == "" ? "Unknown" : StringTools.trim(hit.source);
        var skillName = hit.skill == null ? "" : hit.skill;
        var amount = hit.amount > 0 ? hit.amount : 0;
        if (hit.heal && events.length > 0) {
            var prev = events[events.length - 1];
            if (prev.heal && prev.time == hit.time && prev.skill == skillName && prev.source == sourceName && prev.amount == amount)
                return;
        }
        events.push({
            time: hit.time,
            amount: amount,
            heal: hit.heal,
            critical: hit.critical,
            kill: hit.kill && !hit.heal && hit.amount >= 0,
            skill: skillName,
            skillId: hit.skillId == null ? "" : hit.skillId,
            source: sourceName,
            className: hit.className == null ? "" : hit.className,
            hp: hit.hp != null && Math.isFinite(hit.hp) ? hit.hp : Math.NaN,
            maxHp: hit.maxHp != null && Math.isFinite(hit.maxHp) ? hit.maxHp : Math.NaN
        });
        var newest = hit.time;
        while (events.length > 0 && (events[0].time < newest - WINDOW - 1 || events.length > 500)) events.shift();
    }

    /** First transition to dead snapshots the window. Returns true when the player is alive again. */
    public function observe(dead:Bool, now:Float):Bool {
        if (dead) {
            if (!alive) return false;
            alive = false;
            pending = build(now);
            events = [];
            return false;
        }
        if (!alive) {
            alive = true;
            events = [];
            return true;
        }
        return false;
    }

    public function take():Null<DeathReport> {
        var report = pending;
        pending = null;
        return report;
    }

    /** True when a dead player is dropped, such as when respawn replaces the hero. */
    public function reset():Bool {
        var revived = !alive;
        events = [];
        alive = true;
        return revived;
    }

    /** Scaled heal shown by the game. Values below 1 are the ones the native feed suppresses. */
    public static function shownHeal(amount:Float, scale:Float):Float {
        if (!Math.isFinite(amount) || !(amount > 0)) return 0;
        if (!Math.isFinite(scale) || !(scale > 0)) scale = 1;
        var shown = amount * scale;
        return shown >= 1 ? shown : 0;
    }

    /** A damage result is a heal only when the game marks that result as healing. */
    public static function isHeal(effectName:String, effectIndex:Int):Bool {
        var name = effectName == null ? "" : effectName;
        if (name == "Heal" || name == "HoT" || StringTools.endsWith(name, ".Heal")) return true;
        // Damage results still use effect 1 for healing. Std.string of that index is "1".
        return effectIndex == 1 && (name == "" || name == "1");
    }

    /** Health remaining after this hit. The damage hook runs before the game applies it. */
    public static function healthAfter(before:Float, maxHp:Float, amount:Float, heal:Bool):Float {
        if (!Math.isFinite(before)) return Math.NaN;
        var next = heal ? before + amount : before - amount;
        if (next < 0) next = 0;
        if (Math.isFinite(maxHp) && maxHp > 0 && next > maxHp) next = maxHp;
        return next;
    }

    public static function fraction(hp:Float, scale:Float):Float {
        if (!(scale > 0) || !Math.isFinite(hp)) return 0;
        return Math.max(0, Math.min(1, hp / scale));
    }

    function build(now:Float):DeathReport {
        var kept:Array<{i:Int, hit:IncomingHit}> = [];
        var damage = 0.0;
        var healing = 0.0;
        var scale = 0.0;
        var index = 0;
        for (hit in events) {
            if (hit.time >= now - WINDOW && hit.time <= now + 0.001) {
                kept.push({i: index, hit: hit});
                if (hit.heal) healing += hit.amount;
                else damage += hit.amount;
                if (hit.maxHp > scale) scale = hit.maxHp;
                if (hit.hp > scale) scale = hit.hp;
            }
            index++;
        }
        kept.sort((a, b) -> a.hit.time < b.hit.time ? -1 : a.hit.time > b.hit.time ? 1 : a.i - b.i);
        var rows:Array<DeathEvent> = [for (entry in kept) event(entry.hit, now)];
        rows.push({
            ago: 0, timeText: "0.0 s", hp: 0, amountText: "Death", heal: false, death: true,
            spell: "", skillId: "", source: "", className: ""
        });
        return {at: now, damage: damage, healing: healing, healthScale: scale, rows: rows};
    }

    static function event(hit:IncomingHit, now:Float):DeathEvent {
        return {
            ago: now - hit.time,
            timeText: timeText(now - hit.time),
            hp: hit.hp,
            amountText: signed(hit.amount, hit.heal),
            heal: hit.heal,
            death: false,
            spell: spell(hit.skill),
            skillId: hit.skillId,
            source: hit.source,
            className: hit.className
        };
    }

    static function spell(skill:String):String {
        var name = StringTools.trim(skill);
        return name == "" ? "Unknown" : name;
    }

    public static function timeText(secondsBefore:Float):String {
        var tenths = Math.fround(Math.max(0, secondsBefore) * 10) / 10;
        if (tenths < 0.05) return "0.0 s";
        var text = Std.string(-tenths);
        if (text.indexOf(".") < 0) text += ".0";
        else text = text.substr(0, text.indexOf(".") + 2);
        return text + " s";
    }

    public static function signed(value:Float, heal:Bool):String
        return (heal ? "+" : "-") + amount(value);

    public static function amount(value:Float):String {
        var n = Std.int(Math.fround(value));
        if (n < 0) n = 0;
        var text = Std.string(n);
        var out = "";
        var count = 0;
        var i = text.length;
        while (i > 0) {
            if (count == 3) { out = "," + out; count = 0; }
            out = text.charAt(--i) + out;
            count++;
        }
        return out;
    }
}
