package moresettings;

import moresettings.GameAccess as G;

/** Resolve the destination from world definitions, even when the NPC is not streamed in. */
class BoxCommand {
    static inline var NAVELIN = "Z1_Primevalley_Hub";

    public static function run(box:Dynamic, player:Dynamic):Bool {
        var hero = G.field(player, "hero");
        var world = G.field(G.field(player, "layer"), "world");
        var level = G.text(G.field(world, "level"));
        if (hero == null || G.field(hero, "removed") == true || level == "")
            return fail(box, "Your character is not ready to teleport.");

        var destination:Dynamic = null;
        for (definition in G.array(G.current("HElement", "npcs"))) {
            var inf = G.field(definition, "inf");
            var props = G.field(inf, "props");
            if (G.text(G.field(inf, "zoneBaked")) != NAVELIN
                || G.text(G.field(G.field(props, "npc"), "unit")) != "WanderingMerchant") continue;
            if (G.field(props, "enabled") == false
                || G.field(G.field(props, "interactible"), "hidden") == true
                || G.staticCall("HData", "checkStatus", [G.field(props, "releaseStatus")]) != true) continue;
            if (destination != null)
                return fail(box, "More than one Guild Merchant was found in Navelin. Teleport cancelled.");
            destination = definition;
        }
        if (destination == null)
            return fail(box, "Could not locate the Guild Merchant in Navelin.");
        // rpcTeleportPosition changes coordinates only; it cannot enter another map.
        if (G.text(G.field(destination, "mapId")) != level)
            return fail(box, "Return to Navelin's overworld map before using /box.");
        var prefab = G.field(destination, "prefab");
        if (prefab == null) return fail(box, "The Guild Merchant's position is unavailable.");
        var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
        var x = G.number(G.field(matrix, "_41"), Math.NaN);
        var y = G.number(G.field(matrix, "_42"), Math.NaN);
        var z = G.number(G.field(matrix, "_43"), Math.NaN);
        if (!Math.isFinite(x) || !Math.isFinite(y) || !Math.isFinite(z))
            return fail(box, "The Guild Merchant's position is unavailable.");
        // Null rotation preserves facing; do not substitute a local-space prefab angle.
        G.call("ent.Unit", "rpcTeleportPosition", hero, [{x:x, y:y, z:z}, null]);
        return true;
    }

    static function fail(box:Dynamic, message:String):Bool {
        SocialChat.error(box, message);
        return false;
    }
}
