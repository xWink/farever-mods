package moresettings;

import moresettings.GameAccess as G;

/** Soft deadlines at native operation boundaries; physics always runs natively. */
class TerrainPacing {
    public static inline var BUDGET = 0.002;
    var clock:Void->Float;
    var owner:Dynamic;
    var deadline:Float = 0;
    var retiring:Bool = false;
    var retired:Int = 0;
    var qualityJobs:Int = 0;
    var frame:Int = 0;

    public function new(?clock:Void->Float) this.clock = clock == null ? haxe.Timer.stamp : clock;

    public function begin(terrain:Dynamic, nativeBudget:Float, playing:Bool):Void {
        clear();
        // Fast/instant loading and loading screens retain their native behavior.
        if (!playing || !Math.isFinite(nativeBudget) || nativeBudget <= 0 || nativeBudget > 0.01) return;
        owner = terrain;
        deadline = clock() + Math.min(nativeBudget, BUDGET);
        frame++;
    }

    public function unloading(terrain:Dynamic, value:Bool):Void {
        if (terrain == owner) retiring = value;
    }

    public function deferRemoval(terrain:Dynamic):Bool {
        if (owner == null || owner != terrain || !retiring) return false;
        // Always make progress. Kept chunks remain native-owned and are
        // rechecked for distance next pass, including if the player turns back.
        if (retired > 0 && (retired >= 2 || clock() >= deadline)) return true;
        retired++;
        return false;
    }

    public function deferQuality(chunk:Dynamic, feature:Int, quality:Int):Bool {
        if (owner == null || G.field(chunk, "terrain") != owner) return false;
        // 0 = hard geometry, 1 = soft terrain, 5 = collision. Never defer these.
        if (feature < 2 || feature > 4) return false;
        var values = G.field(chunk, "featuresQuality");
        if (values == null || G.call("hl.types.ArrayBytes_Int", "getDyn", values, [feature]) == quality) return false;
        // Allow one optional change every fourth pass even under constant load.
        if (qualityJobs >= 2 || (clock() >= deadline && !(qualityJobs == 0 && frame % 4 == 0))) {
            G.set(owner, "qualityLoaded", false);
            return true;
        }
        qualityJobs++;
        return false;
    }

    public function clear():Void {
        owner = null; retiring = false; retired = 0; qualityJobs = 0;
    }
}
