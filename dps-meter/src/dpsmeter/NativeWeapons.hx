package dpsmeter;

import dpsmeter.EquippedWeapons;
import dpsmeter.GameAccess as G;

/** Read the same replicated slots as the character sheet and Inspect. */
class NativeWeapons {
    public static function capture(hero:Dynamic):Null<WeaponSlots> {
        var equipment = G.field(G.field(hero, "loadout"), "equipment");
        if (equipment == null || G.field(equipment, "content") == null) return null;
        try return {
            primary: item(G.call("st.Equipment", "getSlot", equipment, ["Slot_Weapon1"])),
            secondary: item(G.call("st.Equipment", "getSlot", equipment, ["Slot_OffhandWeapon"])),
            arsenal: item(G.call("st.Equipment", "getSlot", equipment, ["Slot_Weapon2"]))
        } catch (_:Dynamic) return null; // Replication may not have delivered this player's items yet.
    }
    static function item(value:Dynamic):Null<EquippedWeapon> {
        if (value == null) return null;
        var kind = G.text(G.field(value, "kind")), inf = G.field(value, "inf");
        if (kind == "" || inf == null) throw "Weapon metadata unavailable";
        return {kind: kind, rarity: G.text(G.field(G.staticCall("HItem", "getRarity", [inf]), "id")),
            requiredLevel: G.integer(G.call("st.Item", "getRequiredLevel", value)),
            upgradeLevel: G.integer(G.field(value, "upgradeLevel"))};
    }
}
