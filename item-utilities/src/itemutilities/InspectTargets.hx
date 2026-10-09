package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectMenuContext.InspectTarget;

/** Resolve identities and equipment already replicated to this client. */
class InspectTargets {
    public static function fromSocialButton(button:Dynamic):InspectTarget {
        var card = G.field(button, "parent");
        while (card != null && !G.isA(card, "ui.win.PlayerCard")) card = G.field(card, "parent");
        if (card == null || G.field(card, "removed") == true || G.field(card, "settingsBtn") != button) return null;
        var info = G.field(card, "pInfo");
        var player = G.field(info, "player");
        var uid = G.text(G.field(info, "uid"));
        if (uid == "") uid = G.text(G.field(player, "uid"));
        var me = G.call("ui.BaseElement", "get_myPlayer", card);
        if (me == null || uid == "" || uid == G.text(G.field(me, "uid"))) return null;
        var ui = G.call("ui.BaseElement", "get_baseUI", card);
        if (ui == null) return null;
        var name = player == null ? G.text(G.field(info, "name")) : G.text(G.call("st.Player", "getName", player));
        return {ui: ui, uid: uid, name: name, fromSocialWindow: true};
    }

    public static function remoteHero(local:Dynamic, uid:String):Dynamic {
        if (local == null || uid == null || uid == "") return null;
        var me = G.field(local, "player");
        var layer = G.field(me, "layer");
        var hero = layer == null ? null : playerHero(G.call("st.GameLayer", "getPlayerById", layer, [uid]));
        if (hero != null) return hero;
        // Party metadata can outlive an area change. Use a party hero only if
        // its live replicated instance is actually present; never a name match.
        for (player in G.array(G.field(G.field(me, "group"), "players"), true))
            if (G.text(G.field(player, "uid")) == uid) return playerHero(player);
        return null;
    }

    static function playerHero(player:Dynamic):Dynamic {
        if (player == null || G.field(player, "removed") == true) return null;
        var hero = G.field(player, "hero");
        return G.field(hero, "removed") == true ? null : hero;
    }

    public static function equipment(hero:Dynamic):Dynamic {
        if (hero == null) return null;
        var result = G.field(G.field(hero, "loadout"), "equipment");
        if (result != null) return result;
        try return G.call("ent.Hero", "get_equipment", hero) catch (_:Dynamic) return null;
    }

    public static function available(hero:Dynamic):Bool {
        if (hero == null || G.field(hero, "removed") == true) return false;
        var gear = equipment(hero);
        if (gear != null && (G.field(gear, "content") != null || G.field(gear, "stacks") != null)) return true;
        // Keep the existing Inspect fallbacks when only weapons have replicated.
        for (method in ["get_weapon1", "get_weapon2"])
            try { if (G.call("ent.Hero", method, hero) != null) return true; } catch (_:Dynamic) {}
        return false;
    }
}
