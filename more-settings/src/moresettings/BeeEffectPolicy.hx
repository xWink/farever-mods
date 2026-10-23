package moresettings;

/** Restrict cosmetic suppression to the exact known bee effect types. */
class BeeEffectPolicy {
    public static function aura(enabled:Bool, skill:String, fx:String, server:Bool):Bool
        return enabled && !server && skill == "GM_MassGrab_Skill2_Status" && fx == "Honey_Aura";
    public static function unit(enabled:Bool, kind:String, server:Bool):Bool
        return enabled && !server && kind == "Summon_Bee";
    public static function projectile(enabled:Bool, skill:String, server:Bool):Bool
        return enabled && !server && skill == "SummonBee_HoneyBolt";
}
