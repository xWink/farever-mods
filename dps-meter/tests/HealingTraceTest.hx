import dpsmeter.HealingTrace;
import haxe.Json;

class HealingTraceTest {
    static var checks = 0;
    static function check(ok:Bool, message:String):Void { checks++; if (!ok) throw message; }
    static function main():Void {
        var rows:Array<Dynamic> = [];
        var t = new HealingTrace(text -> {
            for (line in text.split("\n")) if (line != "") rows.push(Json.parse(line));
        });
        var target:Dynamic = {__uid: "target", health: 600., maxHealth: 1000.};
        var source:Dynamic = {__uid: "source"};
        var result:Dynamic = {source: source, target: target, _amount: 500., _critical: true,
            skill: {kind: "Heal", __uid: "skill"}, stepIdx: 0};
        t.rpc(target, result, 10); t.flush(11, true);
        check(rows.length == 0, "Disabled tracing produces no output");
        t.setEnabled(true, 10);
        HealingTrace.updateId = 7;
        t.rpc(target, result, 10.01);
        t.health("target", 600, 1000, 10.02);
        target.health = 1000.;
        t.rpc(target, result, 10.03);
        t.rpc(source, result, 10.04);
        t.flush(10.1);
        check(rows.length == 0, "Hook records are buffered, not written synchronously");
        t.setEnabled(false, 10.2);
        check(rows.length == 6, "Disabling flushes the complete short capture including stop");
        var pre = rows[1], hp = rows[2], post = rows[3], caster = rows[4];
        check(pre.proposed.effective == 400 && pre.proposed.overheal == 100 && pre.hp == 600,
            "Pre-heal snapshot is detached and computes the supplied formula");
        check(post.proposed.effective == 0 && post.proposed.overheal == 500,
            "The same formula shows the post-update failure case");
        check(pre.update == hp.update && hp.update == post.update && pre.seq < hp.seq && hp.seq < post.seq
            && pre.ms < hp.ms && hp.ms < post.ms,
            "Sequence and timestamps distinguish ordering inside one update");
        check(caster.wouldCount == false && caster.proposed == null && caster.candidate.overheal == 500,
            "Healer-side notification is retained with the proposed target guard's rejection");
        check(HealingTrace.calculate(500, Math.NaN, 1000) == null && HealingTrace.calculate(500, 0, 0) == null,
            "Missing HP/max never becomes a plausible zero-overheal result");
        t.setEnabled(true, 11);
        for (i in 0...1100) t.health("target", 500, 600, 11.01);
        t.flush(12, true);
        check(rows.length <= 6 + 1025 && rows[rows.length - 1].kind == "limit",
            "A burst exceeding the queue limit is explicitly truncated and bounded");
        Sys.println('Healing trace: $checks checks passed');
    }
}
