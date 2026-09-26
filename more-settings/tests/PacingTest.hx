import moresettings.TerrainPacing;
import moresettings.AppearanceJobs;
import moresettings.CombatTextPool;
import moresettings.GameAccess as G;

class PacingTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw why + ': expected ' + b + ', got ' + a;
    }
    static function main():Void {
        terrain(); appearances(); combatText();
        Sys.println('Performance pacing and reuse: $checks checks passed.');
    }
    static function terrain():Void {
        var now = 0.0;
        var pacing = new TerrainPacing(() -> now);
        var owner:Dynamic = {qualityLoaded: true};
        var chunk:Dynamic = {terrain: owner, featuresQuality: {items: [0, 0, 0, 0, 0, 0]}};
        pacing.begin(owner, 0.004, true);
        eq(pacing.deferQuality(chunk, 2, 0), false, 'unchanged detail consumes no job');
        eq(pacing.deferQuality(chunk, 2, 1), false, 'first detail allowed');
        eq(pacing.deferQuality(chunk, 3, 1), false, 'second detail allowed');
        eq(pacing.deferQuality(chunk, 4, 1), true, 'detail burst deferred');
        eq(owner.qualityLoaded, false, 'deferred details do not claim completion');
        eq(chunk.featuresQuality.items[4], 0, 'deferred feature stays dirty for native retry');
        now = 1;
        for (feature in [0, 1, 5, 6]) eq(pacing.deferQuality(chunk, feature, 1), false, 'essential feature ' + feature);
        eq(pacing.deferRemoval(owner), false, 'explicit removal outside retirement unaffected');
        pacing.unloading(owner, true);
        eq(pacing.deferRemoval(owner), false, 'retirement guarantees one job');
        eq(pacing.deferRemoval(owner), true, 'deadline limits further retirement');
        pacing.unloading(owner, false);
        eq(pacing.deferRemoval(owner), false, 'other removal paths stay immediate');
        for (pass in 2...5) {
            pacing.begin(owner, 0.004, true); now += 1;
            eq(pacing.deferQuality(chunk, 2, 1), pass != 4, 'bounded starvation pass ' + pass);
        }
        pacing.begin(owner, 0.004, true);
        pacing.unloading(owner, true);
        eq(pacing.deferRemoval(owner), false, 'retirement first');
        eq(pacing.deferRemoval(owner), false, 'retirement second');
        eq(pacing.deferRemoval(owner), true, 'retirement count cap');
        pacing.begin(owner, 1.25, true);
        eq(pacing.deferQuality(chunk, 2, 1), false, 'fast loading no deferral');
        pacing.begin(owner, 0.004, false);
        eq(pacing.deferQuality(chunk, 2, 1), false, 'loading screen unchanged');
        pacing.clear();
        eq(pacing.deferQuality(chunk, 2, 1), false, 'toggle/disposal clears scope');
    }
    static function appearances():Void {
        var queue:Array<Void->Void> = [];
        var built:Array<String> = [];
        var ready = 0;
        var jobs = new AppearanceJobs();
        var view:Dynamic = {async: true, parent: {}, gameObject: {removed: false}};
        G.nativeCall = (type, method, obj, args) -> {
            switch method {
                case 'get': return {};
                case 'addJob': eq(args[1], false, 'scene job never threaded'); queue.push(args[0]);
                case 'clearWeapon': jobs.cancel(obj, args[0], args[1]);
                case 'addWeapon': built.push(args[0]);
                case 'checkReady': if (!jobs.deferReady(obj)) ready++;
                default: throw 'Unexpected ' + method;
            }
            return null;
        };
        function drain():Void {
            jobs.beginWorker();
            while (queue.length > 0) queue.shift()();
            jobs.finishWorker();
        }
        eq(jobs.schedule(view, 'old', {}, 0, 0), true, 'queued old weapon');
        eq(jobs.schedule(view, 'new', {}, 0, 0), true, 'queued replacement');
        jobs.schedule(view, 'offhand', {}, 0, 1);
        drain();
        eq(built.join(','), 'new,offhand', 'superseded job skipped, other slot preserved');
        eq(ready, 1, 'one native readiness scan for completed batch');
        jobs.schedule(view, 'cleared', {}, 0, 0);
        jobs.cancel(view, 0, 0); drain();
        eq(built.length, 2, 'clear invalidates outstanding work');
        jobs.schedule(view, 'removed', {}, 0, 0);
        view.parent = null; drain();
        eq(built.length, 2, 'detached model not built');
        view.parent = {};
        jobs.schedule(view, 'other-owner', {}, 0, 0);
        view.gameObject = {}; drain();
        eq(built.length, 2, 'reassigned view rejects old owner');
        view.async = false;
        eq(jobs.schedule(view, 'sync', {}, 0, 0), false, 'synchronous models retain native path');
        view.async = true;
        jobs.beginWorker(); jobs.beginWorker();
        eq(jobs.deferReady(view), true, 'nested ready deferred');
        jobs.finishWorker(); eq(ready, 1, 'nested finish does not flush outer work');
        jobs.finishWorker(); eq(ready, 2, 'outer finish flushes once');
        jobs.beginWorker(); jobs.deferReady(view); jobs.recoverWorker();
        eq(ready, 3, 'failed worker scope recovered at next frame');
        eq(jobs.deferReady(view), false, 'readiness no longer stuck after recovery');
        jobs.schedule(view, 'dispose', {}, 0, 0); jobs.dispose(); drain();
        eq(built.length, 2, 'world disposal invalidates jobs');
        G.nativeCall = null;
    }
    static function combatText():Void {
        var now = 0.0;
        var pool = new CombatTextPool(() -> now);
        var ui:Dynamic = {widgets: {items: new Array<Dynamic>()}};
        G.data = {current: ui, UI: {DamageNumbersEnabled: true, DamageNumbersOffsetZ: 2.0}};
        var amountUpdates = 0;
        var removals = 0;
        var failUpdate = false;
        G.nativeCall = (type, method, obj, args) -> {
            switch method {
                case 'get_critical': return obj.crit;
                case 'getFollowWPos': return obj.point;
                case 'set_visible': obj.visible = args[0];
                case 'push': (cast obj.items:Array<Dynamic>).push(args[0]);
                case 'remove':
                    if (type == 'h2d.Object') { obj.parent = null; if (obj.types != null) removals++; }
                    else (cast obj.items:Array<Dynamic>).remove(args[0]);
                case 'updateDamage': amountUpdates++; obj.textAmount = obj.dmg.amount;
                case 'update': if (failUpdate) throw 'update failed';
                default: throw 'Unexpected ' + method;
            }
            return null;
        };
        function damage(skill:String, crit:Bool, amount:Int):Dynamic return {baseSkill: {kind: skill}, affinity: 'Physical', crit: crit, amount: amount};
        var dmg = damage('Attack', false, 10);
        var pos = {x: 3.0, y: 4.0, z: 5.0};
        eq(pool.reuse(dmg, pos), null, 'cold pool delegates to native display');
        var widget:Dynamic = {types: ['ui.Widget'], parent: {}, currUI: ui, point: {}, active: true};
        ui.widgets.items.push(widget);
        var display:Dynamic = {parent: {parent: widget}, dmg: dmg, lifetime: 0.0, maxLifetime: 1.0};
        var nativeCalls = 0;
        var callback = pool.capture(display, dt -> {
            nativeCalls++; display.lifetime += dt;
            if (display.lifetime > display.maxLifetime) display.parent = null;
        });
        callback(0.5);
        eq(nativeCalls, 1, 'live text uses native animation');
        callback(0.6);
        eq(widget.visible, false, 'expired pooled widget hidden');
        eq(ui.widgets.items.length, 0, 'idle widgets do not project each frame');
        eq(display.dmg, null, 'idle pool releases damage target references');
        callback(1.0); eq(nativeCalls, 1, 'idle animation paused');
        eq(pool.reuse(damage('DifferentSkill', false, 20), pos), null, 'status icon/skill style isolated');
        eq(pool.reuse(damage('Attack', true, 20), pos), null, 'critical style isolated');
        var next = damage('Attack', false, 99);
        // The PTR skill field has the same kind, without sharing object identity.
        next.skill = next.baseSkill; Reflect.deleteField(next, 'baseSkill');
        eq(pool.reuse(next, pos), display, 'same style reuses complete native display');
        eq(display.dmg, next, 'new damage result'); eq(display.textAmount, 99, 'native formatting updated');
        eq(widget.point.z, 7.0, 'native damage offset preserved');
        eq(pos.z, 5.0, 'source world position not mutated');
        eq(ui.widgets.items.length, 1, 'widget registered exactly once');
        callback(50); eq(display.lifetime, 0.0, 'reactivation cannot inherit an idle time gap');
        callback(1.1); now = 7; pool.sweep();
        eq(removals, 1, 'idle entries expire through native removal');
        eq(display.parent, null, 'native empty-container waiter can release expired widget');
        eq(pool.reuse(next, pos), null, 'expired entry not reused');
        display.parent = {parent: widget}; widget.parent = {}; display.dmg = next; display.lifetime = 0;
        callback = pool.capture(display, dt -> { nativeCalls++; display.lifetime += dt; });
        pool.clear(); callback(0.1);
        eq(display.lifetime, 0.1, 'disabling lets active native animation finish');

        // Failed reactivation must remove the partial widget before native fallback.
        pool.reuse(next, pos);
        widget.parent = {}; display.parent = {parent: widget}; display.lifetime = 0;
        callback = pool.capture(display, dt -> display.lifetime += dt);
        callback(1.1); failUpdate = true;
        var failed = false;
        try pool.reuse(next, pos) catch (_:Dynamic) failed = true;
        eq(failed, true, 'reactivation failure reaches hook fallback');
        eq(widget.parent, null, 'partially reactivated widget removed');
        failUpdate = false;
        eq(pool.reuse(next, pos), null, 'failed entry cannot be reused');

        // A new UI cannot adopt widgets from the previous world.
        widget.parent = {}; display.parent = {parent: widget}; display.dmg = next; display.lifetime = 0;
        callback = pool.capture(display, dt -> display.lifetime += dt);
        callback(1.1);
        G.data.current = {widgets: {items: new Array<Dynamic>()}};
        pool.sweep();
        eq(widget.parent, null, 'world transition disposes old idle widget');
        eq(pool.reuse(next, pos), null, 'no cross-world reuse');
        for (i in 0...CombatTextPool.LIMIT) pool.capture({dmg: next}, dt -> {});
        var extra:Float->Void = dt -> {};
        eq(pool.capture({dmg: next}, extra), extra, 'pool limit leaves further damage numbers native');
        pool.clear();
        G.nativeCall = null;
    }
}
