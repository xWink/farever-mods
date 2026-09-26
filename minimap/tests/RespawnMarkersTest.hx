import minimap.RespawnMarkers as R;
import minimap.GameAccess as G;

class RespawnMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        G.nativeCall = function(type, name, progress, args) {
            if (type != "st.player.Progress" || name != "hasElementCompleted" || args.length != 1)
                throw "Respawn markers must only query native completion, without creating progress";
            // Native completion accepts a nonnegative timestamp. A discovery
            // entry with completed=-1 has not unlocked the respawn point.
            var completed:Null<Float> = (cast progress:Map<String, Float>).get(args[0]);
            return completed != null && completed >= 0;
        };
        var progress:Map<String, Float> = [];
        var inf = {id: "World_Pool_17", texts: {name: "Localized name"}};
        eq(R.unlocked(inf, progress), false, "unseen pool is empty");
        progress[inf.id] = -1;
        eq(R.unlocked(inf, progress), false, "discovery alone does not fill the pool");
        progress[inf.id] = 0;
        eq(R.unlocked(inf, progress), true, "activation at time zero is valid");
        progress[inf.id] = 12345;
        eq(R.unlocked(inf, progress), true, "later activation fills the pool");
        eq(R.name(R.unlocked(inf, progress)), "Respawn Point", "unlocked hover label");
        var otherCharacter:Map<String, Float> = [];
        eq(R.unlocked(inf, otherCharacter), false, "unlocks do not leak between characters");
        progress.remove(inf.id);
        eq(R.unlocked(inf, progress), false, "refreshed progress updates cached landmarks");
        eq(R.name(R.unlocked(inf, progress)), "Respawn Point (Undiscovered)", "undiscovered hover label");
        eq(R.unlocked(null, progress), false, "missing definition");
        eq(R.unlocked({}, progress), false, "missing ID");
        eq(R.unlocked(inf, null), false, "missing character progress");
        G.nativeCall = null;
        Sys.println('Respawn marker tests passed ($checks checks)');
    }
}
