package fareverly;

/** All callers acquire/release on the game thread; Registry is shared across HLX modules. */
class SessionLease {
    static inline var BUCKET = "fareverly/auth";
    public static function acquire(owner:String):Bool {
        if (hlx.runtime.Registry.get(BUCKET, "owner") != null) return false;
        hlx.runtime.Registry.register(BUCKET, "owner", owner); return true;
    }
    public static function release(owner:String):Void {
        if (hlx.runtime.Registry.get(BUCKET, "owner") == owner) hlx.runtime.Registry.unregister(BUCKET, "owner");
    }
}
