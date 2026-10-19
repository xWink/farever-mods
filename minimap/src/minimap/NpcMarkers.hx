package minimap;

import minimap.GameAccess as G;

/** Service roles from resolved world definitions, shared by static and live markers. */
class NpcMarkers {
    // Shared by classification and drawing: every recognized service is drawn.
    public static final KINDS:Array<String> = ["npc", "quest", "bank", "demon", "recycler", "upgrade", "craft", "glory", "infusion", "soulWell", "pilgrim"];

    public static function stationKind(type:Int):String return switch type {
        // Data.Element_type.
        case 23: "craft";
        case 24: "upgrade";
        case 31: "recycler";
        case 33: "infusion";
        default: "";
    };

    public static function isNpc(kind:String):Bool return KINDS.indexOf(kind) >= 0;

    public static function forProgress(kind:String, inf:Dynamic, progress:Dynamic, showCompleted:Bool = false):String {
        if (kind != "quest" || progress == null) return kind;
        // Native ProgressState: 0=no goals, 1=available, 2=started,
        // 3=ready to turn in, 4=completed. Check all goals on every sample.
        var state = G.integer(G.call("st.player.Progress", "getNpcProgressState", progress, [inf]));
        return state == 0 || state == 4 && !showCompleted ? "npc" : "quest";
    }

    public static function availableDefinition(inf:Dynamic):Bool {
        if (inf == null) return false;
        var props = G.field(inf, "props");
        // HElement lists include definitions the server never spawns. Match
        // World.makePrefabServer's release gate, then the initial visibility.
        // Loaded entities remain authoritative if gameplay enables them later.
        return G.staticCall("HData", "checkStatus", [G.field(props, "releaseStatus")]) == true
            && G.field(props, "enabled") != false
            && G.field(G.field(props, "interactible"), "hidden") != true;
    }

    public static function eventVisible(inf:Dynamic, events:Dynamic, access:WorldEventAccess):Bool {
        if (G.text(G.field(G.field(inf, "props"), "event")) == "") return true;
        // An event-bound prefab alone is insufficient evidence of an active NPC.
        if (events == null) return false;
        var status = access.elementStatus(events, G.text(G.field(inf, "id")));
        return G.text(G.field(status, "status")) != "Disabled";
    }

    public static function kind(inf:Dynamic):String {
        var station = stationKind(G.integer(G.field(inf, "type")));
        // Element.create uses ScrapStation (31) for both services, then
        // checks Soulwell ancestry before constructing SoulwellStation.
        if (station == "recycler" && G.staticCall("HElement", "isOfType", [inf, "Soulwell"]) == true)
            return "soulWell";
        if (station != "") return station;
        var props = G.field(inf, "props");
        var npc = G.field(props, "npc");
        var unit = G.text(G.field(npc, "unit"));
        // Huntresses can also sell Glory-priced rewards. Their explicit native
        // identity takes precedence over the generic shop/title heuristics.
        switch unit {
            case "HildaLambert", "NellyXyr": return "pilgrim";
            case "DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi": return "demon";
            default:
        }
        // The native data has this distinct UnitKind alongside WanderingMerchant.
        // Match the resolved instance's unit, as Npc.get_uinf does: its shop
        // prices and localized service title need not be present here.
        if (unit == "TODO_MOG_Merchant") return "glory";
        var texts = G.field(inf, "texts");
        // Some merchants reuse another unit model and name the world instance.
        var personalName = G.text(G.field(texts, "name"));
        if (personalName == "Hilda Lambert" || personalName == "Nelly Xyr") return "pilgrim";
        // Some world NPCs expose their service in npcTitle / the popup's
        // texts.type without exposing Glory-priced offers in props.shop.
        // Only match the complete service label; personal names, templates,
        // dialogue and incidental mentions of glory are not a role.
        if (gloryTitle(G.field(npc, "npcTitle")) || gloryTitle(G.field(texts, "type"))) return "glory";
        // Element.getShopItems copies props.shop[].cost[].kind as the price
        // currency. Match the currency, not an NPC's translated name, model,
        // or the items it sells. shopList entries use the ordinary gold price.
        for (offer in G.array(G.field(props, "shop")))
            for (cost in G.array(G.field(offer, "cost")))
                if (G.text(G.field(cost, "kind")) == "BadgeOfGlory") return "glory";

        // Match Npc.get_uinf: the resolved instance's unit is authoritative.
        // Ancestor templates and inherited dialogue do not identify its role.
        return switch unit {
            case "WanderingMerchant": "bank";
            default: G.field(inf, "dialog") != null
                && G.integer(G.field(G.staticCall("HElement", "getDialogGoals", [inf]), "length")) > 0 ? "quest" : "npc";
        };
    }

    static function gloryTitle(value:Dynamic):Bool
        return StringTools.trim(G.text(value)).toLowerCase() == "glory merchant";
}
