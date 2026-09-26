import minimap.EnemyMarkers;
import minimap.GameAccess as G;

class EnemyMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var markers = new EnemyMarkers();
        eq(EnemyMarkers.highlighted(null), false, "missing definition has no yellow ring");
        for (flags in [0, 1, 4, 16, 32, 64])
            eq(EnemyMarkers.highlighted({flags: flags}), false, "ordinary and non-elite boss flags do not add a ring");
        for (flags in [8, 8 | 16, 8 | 32, 1 << 22, (1 << 22) | 8])
            eq(EnemyMarkers.highlighted({flags: flags}), true, "elites and sparkling variants share the yellow ring");
        // Deliberately use a different group index from the current game.
        // Localized names and new unit IDs must not change classification.
        var dummy = {id: "FuturePracticeTarget", name: "Mannequin", group: 42, flags: 0x38,
            inCodex: true, thresholds: [1., 8., 20.]};
        for (bits in 0...8) {
            eq(markers.kind(dummy, 100, bits & 1 != 0, bits & 2 != 0, bits & 4 != 0),
                bits & 4 != 0 ? "" : "targetDummy", "dummy filter is independent of Codex and boss flags");
        }
        eq(G.codexMembershipReads, 0, "dummy markers skip Codex lookups");
        eq(G.dummyGroupReads, 1, "native group resolved once across refreshes");

        var nonCodex = {id: "NoCodex", group: 4, flags: 0, inCodex: false};
        for (bits in 0...8) {
            eq(markers.kind(nonCodex, 100, bits & 1 != 0, bits & 2 != 0, bits & 4 != 0),
                "enemy", "ordinary enemies without Codex entries stay visible");
        }
        eq(markers.kind({id: "Dummy_NameOnly", group: 4}, 0, false, false, true), "enemy",
            "an ID containing Dummy does not classify unrelated units");
        eq(markers.kind({id: "NoGroup"}, 0, false, false, true), "enemy", "missing metadata stays visible");
        eq(markers.kind(null, 0, true, true, true), "", "missing definition is ignored");

        var mob = {id: "Coyote", group: 8, flags: 0, inCodex: true, thresholds: [1., 8., 20.]};
        eq(markers.kind(mob, 8, false, true, true), "enemy", "partial completion survives mastery-only filter");
        eq(markers.kind(mob, 20, false, true, false), "", "mastered enemies can still be hidden");
        eq(markers.kind(mob, 0, false, true, false), "enemy", "character changes use fresh kills");
        eq(markers.kind(mob, 8, true, false, false), "", "partial filter retains its XP milestone");
        for (flags in [8, 16, 32])
            eq(markers.kind({id: "Boss" + flags, group: 37, flags: flags}, 0, false, false, true),
                "boss", "boss markers survive the dummy filter");

        G.dummyGroup = null;
        eq(new EnemyMarkers().kind({id: "MissingGroup"}, 0, false, false, true), "enemy",
            "unavailable native metadata cannot classify every enemy as a dummy");
        G.dummyGroup = 0;
        eq(new EnemyMarkers().kind({id: "ZeroGroup", group: 0}, 0, false, false, false), "targetDummy",
            "zero remains a valid native group value");
        Sys.println('Enemy marker tests passed ($checks checks)');
    }
}
