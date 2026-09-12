import itemutilities.QuickLootState;

class QuickLootStateTest {
    static var assertions = 0;

    static function check(value:Bool, message:String):Void {
        assertions++;
        if (!value) throw message;
    }

    static function main():Void {
        var state = new QuickLootState();
        var player:Dynamic = {};
        var other:Dynamic = {};

        state.prepare(player, false);
        check(state.takeInput("Interact") == null, "Disabled must not arm a repeat");
        state.prepare(player, true);
        check(state.takeInput("Attack") == null, "Other actions must pass through");
        check(state.takeInput("Interact") == player, "Interact consumes the armed controller");
        check(state.takeInput("Interact") == null, "UI/nested queries must not repeat");
        state.beginInteraction(player);
        check(!state.filtersTarget(player), "A real tap must retain all interaction types");
        state.endInteraction(player);

        state.prepare(player, true);
        state.repeat(state.takeInput("Interact"));
        check(!state.filtersTarget(player), "Do not filter popup queries before tryInteract");
        state.beginInteraction(player);
        check(state.filtersTarget(player), "Filter a synthetic repeat inside tryInteract");
        check(!state.filtersTarget(other), "Never filter another controller");
        state.endInteraction(player);
        check(!state.filtersTarget(player), "Restore popup targeting after tryInteract");
        state.beginInteraction(player);
        check(!state.filtersTarget(player), "Repeat context must be single-use");

        state.prepare(player, true);
        state.repeat(state.takeInput("Interact"));
        state.finish(player);
        state.beginInteraction(player);
        check(!state.filtersTarget(player), "Frame end must clear unused repeat context");
        state.prepare(player, true);
        state.finish(player);
        check(state.takeInput("Interact") == null, "Frame end must clear unused input context");
        state.prepare(player, true);
        state.repeat(state.takeInput("Interact"));
        state.beginInteraction(player);
        state.prepare(other, true);
        check(!state.filtersTarget(player), "New controller must clear previous target scope");
        state.finish(other);
        check(!state.filtersTarget(null), "Null controller must never match");

        // Model the verified native update/tryInteract order, not the server.
        // Searches happen only after native cooldown; hooks add no searches.
        var low = simulate(60, "loot", true, false, true);
        var high = simulate(240, "loot", true, false, true);
        check(low.pickups > 1, "Holding must repeat pickups");
        check(Math.abs(low.pickups - high.pickups) <= 1, "Repeat rate must not scale with FPS");
        check(high.searches <= 17, "Do not scan every held frame");
        check(high.searches == high.pickups, "Do not perform a second targeting search");
        check(simulate(60, "npc", true, false, true).pickups == 1,
            "Holding on an NPC must only perform the original tap");
        check(simulate(60, "loot", false, false, true).pickups == 1,
            "A tap without holding must only pick up once");
        check(simulate(60, "loot", true, true, true).pickups == 0,
            "Blocked gameplay input must not initiate pickups");
        check(simulate(60, "loot", true, false, false).pickups == 0,
            "Native pickup eligibility must remain authoritative");
        check(simulate(60, null, true, false, true).pickups == 0,
            "No selected item must produce no request");
        Sys.println('Quick-loot: $assertions assertions passed.');
    }

    static function simulate(fps:Int, target:String, held:Bool, blocked:Bool,
        eligible:Bool):{pickups:Int, searches:Int} {
        var state = new QuickLootState();
        var player:Dynamic = {};
        var pickups = 0;
        var searches = 0;
        var lastInteract = -1.0;
        var holdDelay = 0.125;
        for (frame in 0...(2 * fps)) {
            var now = 1.0 + frame / fps;
            if (!blocked) {
                state.prepare(player, true);
                var pressed = frame == 0;
                var context = state.takeInput("Interact");
                if (!pressed && context != null && held) {
                    state.repeat(context);
                    pressed = true;
                }
                if (pressed) {
                    state.beginInteraction(player);
                    if (!(lastInteract > 0 && now - lastInteract < holdDelay)) {
                        lastInteract = now;
                        searches++;
                        var selected = target;
                        if (state.filtersTarget(player) && selected != "loot")
                            selected = null;
                        if (selected != null && eligible) pickups++;
                    }
                    state.endInteraction(player);
                } else {
                    lastInteract = -1;
                }
            }
            state.finish(player);
        }
        return {pickups: pickups, searches: searches};
    }
}
