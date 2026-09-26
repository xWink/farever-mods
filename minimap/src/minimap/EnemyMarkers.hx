package minimap;

import minimap.GameAccess as G;

/** Classification uses native unit metadata, independent of translated names. */
class EnemyMarkers {
    var codex = new CodexMarkers();
    var dummyGroup:Null<Int>;

    public function new() {}

    public static function highlighted(inf:Dynamic):Bool {
        // Native Unit flags: Elite (bit 3) and Spark (bit 22).
        // This is only used for hostile enemy/boss markers, never pet alerts.
        return (G.integer(G.field(inf, "flags")) & ((1 << 3) | (1 << 22))) != 0;
    }

    public function kind(inf:Dynamic, kills:Int, hideCompleted:Bool, hideMastered:Bool, hideTargetDummies:Bool):String {
        if (inf == null) return "";
        // Resolve the native group value once; do not assume its numeric index.
        if (dummyGroup == null) {
            var value = G.current("_Data.Unit_group_Impl_", "Dummy");
            if (value != null) dummyGroup = G.integer(value);
        }
        var group = G.field(inf, "group");
        if (dummyGroup != null && group != null && G.integer(group) == dummyGroup)
            return hideTargetDummies ? "" : "targetDummy";
        if (codex.hidden(G.text(G.field(inf, "id")), inf, kills, hideCompleted, hideMastered)) return "";
        return (G.integer(G.field(inf, "flags")) & 0x38) != 0 ? "boss" : "enemy";
    }
}
