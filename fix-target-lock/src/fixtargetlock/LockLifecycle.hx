package fixtargetlock;

import fixtargetlock.GameAccess as G;

/** Lock intent belongs to one controller, hero and map. */
class LockLifecycle {
    var controller:Dynamic;
    var hero:Dynamic;
    var layer:Dynamic;

    public function new() {}

    /** Run before PlayerController.update can reach native lock reacquisition. */
    public function observe(nextController:Dynamic, enabled:Bool):Bool {
        if (nextController == null) return false;
        var nextHero = G.field(nextController, "unit");
        var nextLayer = G.field(nextHero, "layer");
        var changed = controller != null && (controller != nextController || hero != nextHero || layer != nextLayer);
        if (enabled && changed) {
            // syncPlayer reuses the controller, including its previous autoTarget
            // and inLock. Clear both before updateInputs can acquire another foe.
            G.set(nextController, "autoTarget", null);
            if (nextHero != null)
                G.call("client.PlayerController", "leaveLock", nextController);
            else
                G.set(nextController, "inLock", false);
        }
        // Commit the observation after cleanup so a failed native call is retried.
        controller = nextController;
        hero = nextHero;
        layer = nextLayer;
        return enabled && changed;
    }

    public function reset():Void {
        controller = null;
        hero = null;
        layer = null;
    }
}
