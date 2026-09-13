import minimap.ActivityMarkers;
import minimap.ActivityMarkers.ActivityVisibility;
import minimap.GameAccess as G;

class ActivityMarkersTest {
    static var assertions:Int = 0;

    static function equal(actual:Dynamic, expected:Dynamic, message:String):Void {
        assertions++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function definition(id:String, ?parent:String):Dynamic {
        var inf = {id: id, inherit: parent};
        G.definitions[id] = inf;
        return inf;
    }

    static function main():Void {
        definition("Dungeon");
        definition("BaseDungeon", "Dungeon");
        var dungeon = definition("StoneHalls", "BaseDungeon");
        definition("Ascension");
        var ascension = definition("MountainClimb", "Ascension");
        definition("Rift");
        var rift = definition("UnstableEntrance", "Rift");
        var ordinary = definition("DungeonNamedPuzzle");
        equal(ActivityMarkers.kind(dungeon), "dungeon", "Inherited dungeon without Dungeon in its name");
        equal(ActivityMarkers.kind(G.definitions["Dungeon"]), "dungeon", "Base dungeon");
        equal(ActivityMarkers.kind(ascension), "ascension", "Ascension retains its own category");
        equal(ActivityMarkers.kind(rift), "activity", "Instance entrance alone does not imply dungeon");
        equal(ActivityMarkers.kind(ordinary), "activity", "Name alone does not imply dungeon");
        equal(ActivityMarkers.kind(null), "activity", "Missing optional definition");

        // Exercise all four visibility toggles with incomplete, complete, and
        // temporarily unavailable progress (such as during character loading).
        for (bits in 0...16) {
            var config:ActivityVisibility = {
                showActivities: bits & 1 != 0,
                hideCompletedActivities: bits & 2 != 0,
                hideAscensions: bits & 4 != 0,
                hideDungeons: bits & 8 != 0
            };
            for (inf in [dungeon, ascension, rift, ordinary]) {
                var kind = ActivityMarkers.kind(inf);
                for (state in 0...3) {
                    var progress:Dynamic = state == 0 ? null : {completed: state == 2 ? inf.id : "unrelated"};
                    var expected = !config.showActivities;
                    if (config.showActivities) {
                        if (inf == dungeon) expected = config.hideDungeons;
                        else if (inf == ascension) expected = config.hideAscensions;
                        else expected = config.hideCompletedActivities && state == 2;
                    }
                    G.completionReads = 0;
                    equal(ActivityMarkers.hidden(kind, inf, progress, config), expected,
                        inf.id + " toggles=" + bits + " progress=" + state);
                    var reads = config.showActivities && inf != dungeon && inf != ascension
                        && config.hideCompletedActivities && state != 0 ? 1 : 0;
                    equal(G.completionReads, reads, "Only ordinary activities need completion reads");
                }
            }
        }
        Sys.println("Activity marker tests passed (" + assertions + " assertions)");
    }
}
