package moddependencies;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class Build {
    public static macro function modId():Expr {
        var id = Context.definedValue("dependency-mod");
        if (["dps-meter", "minimap", "item-utilities", "more-settings", "fix-target-lock", "trade"].indexOf(id) < 0)
            Context.error("Set dependency-mod to a supported mod ID", Context.currentPos());
        return macro $v{id};
    }

    public static macro function implementationHash():Expr {
        var id = Context.definedValue("dependency-mod");
        var path = "build/" + id + "/implementation/" + id + ".hl";
        var hash = haxe.crypto.Sha256.make(sys.io.File.getBytes(path)).toHex();
        return macro $v{hash};
    }
}
