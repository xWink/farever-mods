import hlx.runtime.HlxPrefixResult;
import moresettings.PerformanceHooks;
import moresettings.GameAccess as G;

/** Exercise the production hook through a simulated HLX/native dispatch boundary. */
class UpdateBindingTest {
    static var checks = 0;
    static var originalCalls = 0;
    static var depth = 0;
    static var maxDepth = 0;

    // This must remain a by-value closure argument, matching both native clients.
    static var hook:Dynamic->(Float->Void)->HlxPrefixResult<Void> = @:privateAccess PerformanceHooks.damageAnimation;

    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++; if (actual != expected) throw why + ': expected ' + expected + ', got ' + actual;
    }
    static function dispatch(instance:Dynamic, callback:Float->Void):Void {
        depth++; maxDepth = Std.int(Math.max(maxDepth, depth));
        try {
            switch Type.enumIndex(hook(instance, callback)) {
                case 0:
                    originalCalls++;
                    (cast instance.callbacks:Array<Float->Void>).push(callback);
                    callback(0); // Native bindUpdate invokes this after registering it.
                case 1:
                default: throw 'Void binding returned a value';
            }
        } catch (e:Dynamic) { depth--; throw e; }
        depth--;
    }
    static function element(damage:Bool):Dynamic {
        return {types: [damage ? 'ui.comp.DamageDisplay' : 'ui.Fader'],
            callbacks: new Array<Float->Void>(), parent: {}, lifetime: 0.0, maxLifetime: 1.0,
            dmg: damage ? {baseSkill: {kind: 'Attack'}, affinity: 'Physical', crit: false} : null};
    }
    static function main():Void {
        var forwarded = 0;
        G.nativeCall = (type, method, obj, args) -> {
            switch method {
                case 'bindUpdate': forwarded++; dispatch(obj, args[0]);
                case 'get_critical': return obj.crit;
                case 'remove': obj.parent = null;
                default: throw 'Unexpected native call ' + type + '.' + method;
            }
            return null;
        };
        for (enabled in [false, true]) {
            PerformanceHooks.enabled = enabled;
            var fader = element(false);
            var calls = 0;
            var animation:Float->Void = dt -> calls++;
            dispatch(fader, animation);
            eq(calls, 1, 'startup fader receives its immediate native callback');
            eq(fader.callbacks.length, 1, 'startup fader bound once');
            eq(fader.callbacks[0], animation, 'startup callback remains unchanged');
        }
        eq(forwarded, 0, 'non-damage UI never enters the replacement path');

        PerformanceHooks.enabled = false;
        var display:Dynamic = element(true);
        var animation:Float->Void = dt -> display.lifetime += dt;
        dispatch(display, animation);
        eq(display.callbacks[0], animation, 'disabled optimization keeps original damage callback');
        eq(forwarded, 0, 'disabled optimization never forwards');

        PerformanceHooks.enabled = true;
        display = element(true);
        var calls = 0;
        animation = dt -> { calls++; display.lifetime += dt; };
        var before = originalCalls;
        dispatch(display, animation);
        eq(forwarded, 1, 'pooled damage callback forwarded once');
        eq(originalCalls - before, 1, 'original binding runs once, not twice');
        eq(display.callbacks.length, 1, 'one animation registered');
        eq(calls, 1, 'native immediate callback preserved');
        eq(maxDepth, 2, 'recursive dispatch stops at native binding');
        display.callbacks[0](0.25);
        eq(display.lifetime, 0.25, 'wrapped animation receives native frame delta');
        PerformanceHooks.enabled = false;
        display.callbacks[0](0.25);
        eq(display.lifetime, 0.5, 'active animation continues after disabling');

        PerformanceHooks.enabled = true;
        var failedDisplay = element(true);
        before = originalCalls;
        dispatch(failedDisplay, dt -> { throw 'synthetic animation failure'; });
        eq(originalCalls - before, 1, 'failed native registration is not retried');
        eq(failedDisplay.callbacks.length, 1, 'failed callback is not duplicated');
        eq(failedDisplay.parent, null, 'failed visual detached for native widget cleanup');
        eq(@:privateAccess PerformanceHooks.forwardingDamageAnimation, false, 'forwarding guard resets after exception');
        var fader = element(false);
        dispatch(fader, dt -> {});
        eq(fader.callbacks.length, 1, 'startup UI still works after a failed damage binding');
        G.nativeCall = null;
        Sys.println('Native UI update binding: $checks checks passed.');
    }
}
