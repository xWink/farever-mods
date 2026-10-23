package moresettings;

/** Never suppress skill, area hit, damage result, or replicated state. */
class BombletEffectPolicy {
    public static function travel(enabled:Bool, step:String, fx:String, server:Bool):Bool
        return enabled && !server && ((step == "Bomblet" && fx == "Projectile_CheeseBomb")
            || (step == "GoldenBomblet" && fx == "Projectile_CheeseBomb_Gold"));
    public static function explosion(enabled:Bool, skill:String, step:String, server:Bool):Bool
        return enabled && !server && skill == "Infusion_Kobold_DPS"
            && (step == "Bomblet" || step == "GoldenBomblet");
}
