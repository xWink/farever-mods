package itemutilities;

/** Item inheritance is shared by bank buttons and their tests. */
class DepositItems {
    public static function collectible(isType:String->Bool):Bool
        return isType("Mount") || isType("GearGlider") || isType("Recipe") || isType("InfusionPattern")
            || isType("Emote") || isType("Collection");

    public static function matches(mode:Int, isType:String->Bool):Bool {
        if (mode == 1) return true; // All eligible items.
        var demonic = isType("AugmentDemon") || isType("AugmentDemonSigil") || isType("Soulstone");
        return switch mode {
            case 2: !demonic && !collectible(isType) && (isType("Food") || isType("Consumable"));
            case 3: collectible(isType);
            case 4: demonic;
            case 5: !collectible(isType) && (isType("Gear") || isType("Weapon") || isType("Armor") || isType("GearTool"));
            default: isType("CraftingComponent") || isType("UpgradeComponent");
        };
    }
}
