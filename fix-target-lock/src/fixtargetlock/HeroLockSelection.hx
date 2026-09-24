package fixtargetlock;

/** A short-lived extension of the native lock picker, never combat hostility. */
class HeroLockSelection {
    static var selectingHero:Dynamic;

    public static function includes(actor:Dynamic, target:Dynamic):Bool {
        return selectingHero != null && actor == selectingHero && target != actor
            && TargetLockGame.isHero(target);
    }

    public static function pick(controller:Dynamic):Dynamic {
        var previousTarget = TargetLockGame.field(controller, "autoTarget");
        var hero = TargetLockGame.field(controller, "unit");
        if (!TargetLockGame.isHero(hero)) return previousTarget;

        var previousHero = selectingHero;
        selectingHero = hero;
        var target:Dynamic;
        try {
            // updatePicked uses getAutoTarget(true), including the game's screen
            // scoring, distance, targetability and line-of-sight checks. Calling
            // it also preserves the native Ref<Bool> argument across HL modules.
            TargetLockGame.refreshPick(controller);
            target = TargetLockGame.field(controller, "autoTarget");
        } catch (error:Dynamic) {
            selectingHero = previousHero;
            TargetLockGame.set(controller, "autoTarget", previousTarget);
            throw error;
        }
        selectingHero = previousHero;
        // A hero is selected only by the user's explicit lock. Do not leave it
        // as the ordinary auto-target if the user was toggling/switching a lock.
        TargetLockGame.set(controller, "autoTarget", previousTarget);
        return target;
    }
}
