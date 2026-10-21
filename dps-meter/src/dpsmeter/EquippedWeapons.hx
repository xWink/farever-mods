package dpsmeter;

typedef EquippedWeapon = {kind:String, rarity:String, requiredLevel:Int, upgradeLevel:Int};
typedef WeaponSlots = {
    primary:Null<EquippedWeapon>, secondary:Null<EquippedWeapon>, arsenal:Null<EquippedWeapon>
};

/** Detached equipment metadata. A null loadout is unknown; a null slot is empty. */
class EquippedWeapons {
    public static function copy(value:Null<WeaponSlots>):Null<WeaponSlots> {
        return value == null ? null : {primary: copyItem(value.primary), secondary: copyItem(value.secondary),
            arsenal: copyItem(value.arsenal)};
    }
    static function copyItem(item:Null<EquippedWeapon>):Null<EquippedWeapon> {
        return item == null ? null : {kind: item.kind, rarity: item.rarity,
            requiredLevel: item.requiredLevel, upgradeLevel: item.upgradeLevel};
    }
    public static function read(value:Dynamic):Null<WeaponSlots> {
        if (value == null) return null;
        for (slot in ["primary", "secondary", "arsenal"]) {
            if (!Reflect.hasField(value, slot)) return null;
            var item:Dynamic = Reflect.field(value, slot);
            if (item == null) continue;
            if (!Std.isOfType(item.kind, String) || item.kind == "" || !Std.isOfType(item.rarity, String)
                || !Std.isOfType(item.requiredLevel, Int) || item.requiredLevel < 0
                || !Std.isOfType(item.upgradeLevel, Int) || item.upgradeLevel < 0) return null;
        }
        return copy(cast value);
    }
}
