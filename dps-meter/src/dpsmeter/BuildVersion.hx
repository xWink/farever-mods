package dpsmeter;

/** Embedded at compile time so archived logs retain their recording version. */
class BuildVersion {
    public static macro function value():haxe.macro.Expr {
        var version = Sys.getEnv("DPS_METER_VERSION");
        if (version == null || StringTools.trim(version) == "") version = "dev-local";
        return macro $v{version};
    }
}
