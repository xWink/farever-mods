import fixtargetlock.HeroLockSelection;
import fixtargetlock.TargetLockGame as G;

class HeroLockSelectionTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        var local:Dynamic = {hero:true}, other:Dynamic = {hero:true};
        var monster:Dynamic = {hero:false}, npc:Dynamic = {hero:false};
        var controller:Dynamic = {unit:local, autoTarget:monster};
        eq(HeroLockSelection.includes(local, other), false, "unlocked auto-aim is unchanged");
        G.refresh = function(c) {
            eq(c, controller, "use the local controller's native picker");
            eq(HeroLockSelection.includes(local, other), true, "other heroes participate in lock selection");
            eq(HeroLockSelection.includes(local, local), false, "never target yourself");
            eq(HeroLockSelection.includes(local, null), false, "ignore missing targets");
            eq(HeroLockSelection.includes(local, npc), false, "do not make NPCs hostile");
            eq(HeroLockSelection.includes(local, monster), false, "monsters use the native enemy result");
            eq(HeroLockSelection.includes(other, local), false, "other controllers are unaffected");
            c.autoTarget = other;
        };
        eq(HeroLockSelection.pick(controller), other, "return the native hero selection");
        eq(controller.autoTarget, monster, "restore ordinary enemy auto-targeting");
        eq(HeroLockSelection.includes(local, other), false, "skill/hit checks do not inherit hostility");

        // A failed native targetability/visibility query must stay a failed pick.
        G.refresh = c -> c.autoTarget = null;
        eq(HeroLockSelection.pick(controller), null, "preserve native rejection");
        eq(controller.autoTarget, monster, "rejected pick preserves auto-target");
        G.refresh = c -> c.autoTarget = monster;
        eq(HeroLockSelection.pick(controller), monster, "normal enemies can still win the native scoring");

        G.refresh = function(c) { c.autoTarget = other; throw "native picker failed"; };
        var caught = false;
        try HeroLockSelection.pick(controller) catch (_:Dynamic) caught = true;
        eq(caught, true, "report picker failures");
        eq(controller.autoTarget, monster, "failure restores auto-target");
        eq(HeroLockSelection.includes(local, other), false, "failure clears temporary hostility");

        // Nested queries must restore the enclosing owner rather than leaking it.
        var nested:Dynamic = {unit:other, autoTarget:null};
        G.refresh = function(c) {
            if (c == controller) {
                eq(HeroLockSelection.pick(nested), local, "nested query returns its own target");
                eq(HeroLockSelection.includes(local, other), true, "outer query scope restored");
                eq(HeroLockSelection.includes(other, local), false, "nested owner no longer allowed");
                c.autoTarget = other;
            } else {
                eq(HeroLockSelection.includes(other, local), true, "nested query has its own owner");
                eq(HeroLockSelection.includes(local, other), false, "outer owner inactive during nested query");
                c.autoTarget = local;
            }
        };
        eq(HeroLockSelection.pick(controller), other, "outer query returns its own target");
        eq(controller.autoTarget, monster, "outer auto-target restored");
        eq(nested.autoTarget, null, "nested auto-target restored");
        eq(HeroLockSelection.includes(local, other), false, "all query scopes cleared");

        G.refresh = _ -> throw "should not query";
        eq(HeroLockSelection.pick({unit:monster, autoTarget:other}), other, "non-player controllers untouched");
        eq(HeroLockSelection.pick({unit:null, autoTarget:null}), null, "no hero during teardown");
        Sys.println('Hero lock selection: $checks checks passed');
    }
}
