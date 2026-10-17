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
        var roots = ["Boss", "WorldElite", "ChestOrb", "TimerCollectRun", "ArenaChest", "WorldCamp", "FightStone"];
        var icons = ["boss", "boss", "orbChest", "orbRace", "ambushChest", "battle", "battle"];
        for (i in 0...roots.length) {
            definition(roots[i]);
            definition("Template" + i, roots[i]);
            var inf = definition("Encounter" + i, "Template" + i);
            equal(ActivityMarkers.icon(inf), icons[i], "Artwork follows inherited native activity type");
            equal(ActivityMarkers.kind(inf), "activity", "Artwork does not change filter category");
        }
        equal(ActivityMarkers.icon(definition("BossNamedPuzzle")), "activity", "Names do not identify artwork");
        equal(ActivityMarkers.icon(null), "activity", "Unknown activities keep generic artwork");
        // Synthetic atlas cells exercise native icon matching without relying on
        // encounter names or fixed coordinates from a particular game version.
        var bossGfx = {file:"UI/icons/activities.png", size:128, x:0, y:0};
        G.definitions["Boss"].gfx = bossGfx;
        G.definitions["WorldElite"].gfx = bossGfx;
        G.definitions["WorldCamp"].gfx = {file:bossGfx.file, size:128, x:1, y:0};
        ActivityMarkers.prepareIcons();
        var variant:Dynamic = definition("DifferentEncounterFamily", "WorldCamp");
        variant.gfx = bossGfx;
        equal(ActivityMarkers.icon(variant), "boss", "Native boss icon overrides non-boss activity ancestry");
        equal(ActivityMarkers.kind(variant), "activity", "Icon override preserves activity filtering");
        var independent:Dynamic = definition("IndependentEncounter");
        independent.gfx = {file:"UI\\icons\\activities.png", size:128, x:0, y:0, width:1, height:1};
        equal(ActivityMarkers.icon(independent), "boss", "Unrelated ancestry with equivalent atlas rectangle matches");
        independent.gfx = {file:bossGfx.file, size:128, x:1, y:0};
        equal(ActivityMarkers.icon(independent), "battle", "Different cells in the same atlas stay distinct");
        independent.gfx = {file:bossGfx.file, size:128, x:0, y:0, width:2};
        equal(ActivityMarkers.icon(independent), "activity", "Different atlas crop is not the boss icon");
        independent.gfx = {file:"Other/icons.png", size:128, x:0, y:0};
        equal(ActivityMarkers.icon(independent), "activity", "Coordinates in another atlas do not match");
        G.definitions["WorldCamp"].gfx = bossGfx;
        ActivityMarkers.prepareIcons();
        equal(ActivityMarkers.icon(variant), "activity", "Ambiguous shared placeholder cannot imply boss artwork");
        G.definitions["Boss"].gfx = G.definitions["WorldElite"].gfx = {file:bossGfx.file, size:128, x:5, y:2};
        ActivityMarkers.prepareIcons();
        independent.gfx = G.definitions["Boss"].gfx;
        equal(ActivityMarkers.icon(independent), "boss", "Rebuilding follows updated native atlas coordinates");

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
                    if (inf == dungeon) expected = config.hideDungeons;
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
