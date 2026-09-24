package fixtargetlock;

import hlx.runtime.ResolvedMember;

class TargetLockGame {
    static var updatePicked:ResolvedMember;

    public static function field(object:Dynamic, name:String):Dynamic {
        return object == null ? null : HlxRuntime.resolveField(object, name);
    }

    public static function set(object:Dynamic, name:String, value:Dynamic):Void {
        HlxRuntime.setField(object, name, value);
    }

    public static function isHero(object:Dynamic):Bool {
        return object != null && hl.Type.getDynamic(object).getTypeName() == "ent.Hero";
    }

    public static function refreshPick(controller:Dynamic):Void {
        if (updatePicked == null) {
            var type = HlxRuntime.resolveType("client.UnitController");
            if (type != null) updatePicked = HlxRuntime.resolveMember(type, "updatePicked");
        }
        if (updatePicked == null) throw "Farever target picker is unavailable";
        HlxRuntime.callResolved(updatePicked, [controller]);
    }
}
