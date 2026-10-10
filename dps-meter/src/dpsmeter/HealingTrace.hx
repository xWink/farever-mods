package dpsmeter;

import dpsmeter.GameAccess as G;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** Opt-in observation only. Copy scalars in hooks; write batches after game update.
    Experimental effective/overheal values never enter meter stats or uploads. */
class HealingTrace {
    public static var updateId:Int = 0;
    public static inline var PATH:String = "hlx/mods/dps-meter/healing-trace.jsonl";
    static inline var LIMIT:Int = 20000;
    var active:Bool = false;
    var stopped:Bool = false;
    var sequence:Int = 0;
    var start:Float = 0;
    var lastWrite:Float = 0;
    var pending:Array<Dynamic> = [];
    var write:String->Void;
    public function new(?write:String->Void) {
        this.write = write == null ? append : write;
    }
    static function append(text:String):Void {
        FileSystem.createDirectory("hlx/mods/dps-meter");
        var file = File.append(PATH, false);
        try { file.writeString(text); file.close(); }
        catch (error:Dynamic) { try file.close() catch (_:Dynamic) {} throw error; }
    }
    public function setEnabled(value:Bool, now:Float):Void {
        if (active == value) return;
        if (!value) {
            add("stop", now, {}); flush(now, true); active = false;
            return;
        }
        active = true; stopped = false; sequence = 0; start = now; lastWrite = now;
        add("start", now, {startedAt: Date.now().toString(), windowMs: HealingCapture.WINDOW * 1000,
            note: "update is the GameApp.update counter; HP at rpc is not assumed pre-heal"});
    }
    function add(kind:String, now:Float, value:Dynamic):Void {
        if (!active || stopped) return;
        // Bound memory even when many hooks arrive before the next update.
        if (sequence >= LIMIT || pending.length >= 1024) {
            pending.push({kind: "limit", seq: ++sequence, ms: (now - start) * 1000, update: updateId});
            stopped = true;
            return;
        }
        Reflect.setField(value, "kind", kind);
        Reflect.setField(value, "seq", ++sequence);
        Reflect.setField(value, "ms", (now - start) * 1000);
        Reflect.setField(value, "update", updateId);
        pending.push(value);
    }
    /** Exactly the proposed arithmetic, conditional on valid observed inputs. */
    public static function calculate(raw:Float, hp:Float, max:Float):Dynamic {
        if (!Math.isFinite(raw) || !Math.isFinite(hp) || !Math.isFinite(max) || raw < 0 || max <= 0) return null;
        var effective = Math.min(raw, Math.max(0, max - hp));
        return {effective: effective, overheal: raw - effective};
    }
    static function finite(value:Float):Null<Float> return Math.isFinite(value) ? value : null;
    public function rpc(receiver:Dynamic, result:Dynamic, now:Float):Void {
        if (!active || stopped) return;
        try {
            var target = G.field(result, "target");
            // These native getters use attr.get(27) and Unit.atb(this, 28).
            var hp = target == null ? Math.NaN : G.number(G.call("ent.Unit", "get_health", target), Math.NaN);
            var max = target == null ? Math.NaN : G.number(G.call("ent.Unit", "get_maxHealth", target), Math.NaN);
            var raw = G.number(G.field(result, "_amount"), Math.NaN);
            var skill = gamecompat.HitSkill.read(result, G.field);
            var onTarget = receiver == target && target != null;
            add("rpc", now, {receiver: G.uid(receiver), source: G.uid(G.call("st.skill.DamageResult", "get_source", result)),
                weakSource: G.text(G.field(result, "weakSource")), target: G.uid(target),
                skill: NativeHealing.key(skill, G.integer(G.field(result, "stepIdx"))), raw: finite(raw),
                critical: G.field(result, "_critical") == true, hp: finite(hp), max: finite(max),
                wouldCount: onTarget, candidate: calculate(raw, hp, max),
                proposed: onTarget ? calculate(raw, hp, max) : null});
        } catch (error:Dynamic) add("error", now, {hook: "rpc", message: Std.string(error)});
    }
    public function health(uid:String, before:Float, after:Float, now:Float):Void {
        if (uid != "") add("hp", now, {target: uid, before: finite(before), after: finite(after)});
    }
    public function fx(target:Dynamic, hit:Dynamic, now:Float):Void {
        if (!active || stopped) return;
        try add("fx", now, {target: G.uid(target), source: G.uid(G.call("st.skill.ScriptHitData", "get_source", hit)),
            skill: NativeHealing.key(G.field(hit, "skill"), G.integer(G.field(G.field(hit, "step"), "index")))})
        catch (error:Dynamic) add("error", now, {hook: "fx", message: Std.string(error)});
    }
    public function flush(now:Float, force:Bool = false):Void {
        if (pending.length == 0 || (!force && now - lastWrite < .5)) return;
        var batch = pending; pending = []; lastWrite = now;
        try write([for (event in batch) Json.stringify(event)].join("\n") + "\n")
        catch (error:Dynamic) {
            stopped = true;
            trace("[DPS Meter] Healing trace stopped: " + Std.string(error));
        }
    }
}
