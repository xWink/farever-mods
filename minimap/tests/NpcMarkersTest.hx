import minimap.NpcMarkers;
import minimap.GameAccess as G;

class NpcMarkersTest {
    static var checks = 0;

    static function expect(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        expect(NpcMarkers.kind(null), "npc", "Missing definition");
        expect(NpcMarkers.kind({dialog:[], testGoals:[{id:"Help"}]}), "quest", "Native dialogue goals identify quest givers");
        expect(NpcMarkers.kind({dialog:[], testGoals:[]}), "npc", "Conversation alone is not a quest");
        expect(NpcMarkers.kind({dialog:[], testGoals:[{id:"Help"}], props:{npc:{unit:"WanderingMerchant"}}}),
            "bank", "Service icons retain priority over quest artwork");
        expect(NpcMarkers.isNpc("quest"), true, "Quest givers retain NPC filtering and hover names");
        expect(NpcMarkers.kind({type: 22, props: {}}), "npc", "Ordinary NPC");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "WanderingMerchant"}}}), "bank", "Guild merchant");
        expect(NpcMarkers.kind({id: "World_NPC_17", type: 22, props: {npc: {unit: "TODO_MOG_Merchant"}}}),
            "glory", "Glory merchant is identified without shop or title fields");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "TODO_MOG_Merchant", npcTitle: "localized service"}},
            texts: {name: "localized name", type: "localized type"}}), "glory", "Native identity is language-independent");
        expect(NpcMarkers.kind({type: 22, inherit: "TODO_MOG_Merchant", props: {npc: {unit: "Other"}}}),
            "npc", "Borrowing an ancestor does not turn an unrelated NPC into a Glory merchant");
        for (unit in ["DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi"])
            expect(NpcMarkers.kind({type: 22, props: {npc: {unit: unit}}}), "demon", "Demon huntress " + unit);
        expect(NpcMarkers.kind({id: "World_Rumi", type: 22, props: {npc: {unit: "DemonHunterRumi", npcTitle: "localized title"}},
            texts: {name: "localized name"}}), "demon", "Rumi uses her native unit identity");
        expect(NpcMarkers.kind({type: 22, inherit: "DemonHunterMira", props: {npc: {unit: "Other"}}}),
            "npc", "Unrelated NPC borrowing a template");
        expect(NpcMarkers.kind({type: 23}), "craft", "Craft station");
        expect(NpcMarkers.kind({type: 24}), "upgrade", "Upgrade station");
        expect(NpcMarkers.kind({type: 31}), "recycler", "Recycler");
        G.elements["Soulwell"] = {id: "Soulwell", type: 31};
        G.elements["RegionalWell"] = {id: "RegionalWell", type: 31, inherit: "Soulwell"};
        expect(NpcMarkers.kind(G.elements["Soulwell"]), "soulWell", "Native Soulwell root shares recycler type");
        expect(NpcMarkers.kind({id: "World_Station", type: 31, inherit: "RegionalWell", texts: {name: "localized name"}}),
            "soulWell", "World Soul Well follows multiple ancestors without a translated name");
        expect(NpcMarkers.kind({id: "Soulwell_Decoration", type: 31, texts: {name: "Soul Well"}}),
            "recycler", "A name alone does not replace the recycler marker");
        expect(NpcMarkers.kind({type: 31, inherit: "Unavailable"}), "recycler", "Live recycler with unknown ancestry");
        expect(NpcMarkers.kind({type: 22, inherit: "Soulwell"}), "npc", "Soul Well requires the native station type");
        expect(NpcMarkers.stationKind(22), "", "NPC is not a station");
        expect(NpcMarkers.stationKind(32), "", "Wave spawner is not a station");
        expect(NpcMarkers.kind({id: "arbitrary-world-id", type: 33}), "infusion", "Crucible uses its native type");

        var gloryOffer = {item: "Reward", cost: [{kind: "BadgeOfGlory", amount: 5}]};
        for (unit in ["DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi"]) {
            expect(NpcMarkers.kind({type: 22, props: {npc: {unit: unit}, shop: [gloryOffer]}}),
                "demon", "Glory-priced rewards cannot override huntress identity: " + unit);
            expect(NpcMarkers.kind({type: 22, props: {npc: {unit: unit, npcTitle: "Glory Merchant"}},
                texts: {type: "Glory Merchant"}}), "demon", "Generic service labels cannot override huntress identity: " + unit);
        }
        expect(NpcMarkers.kind({type: 22, props: {shop: [gloryOffer]}}), "glory", "Glory-priced shop");
        expect(NpcMarkers.kind({type: 22, props: {npc: {unit: "WanderingMerchant"}, shop: [gloryOffer]}}),
            "glory", "Currency identifies role even with a reused merchant model");
        expect(NpcMarkers.kind({type: 33, props: {shop: [gloryOffer]}}), "infusion", "Station type takes precedence");
        expect(NpcMarkers.kind({type: 22, props: {shop: [
            {item: "Other", cost: []},
            {item: "Reward", cost: [{kind: "Gold", amount: 10}, {kind: "BadgeOfGlory", amount: 5}]}
        ]}}), "glory", "Search all offers and all currencies");
        expect(NpcMarkers.kind({type: 22, props: {shop: [{item: "BadgeOfGlory", cost: [{kind: "Gold", amount: 1}]}]}}),
            "npc", "Selling tokens does not identify a Glory merchant");
        expect(NpcMarkers.kind({type: 22, props: {npc: {npcTitle: "Glory Merchant"}, shop: [{item: "Reward"}]}}),
            "glory", "Service title works when the NPC does not expose Glory-priced offers");
        expect(NpcMarkers.kind({type: 22, texts: {type: "Glory Merchant"}}), "glory", "Native popup service label");
        expect(NpcMarkers.kind({type: 22, props: {npc: {npcTitle: " Glory Merchant ", unit: "WanderingMerchant"}}}),
            "glory", "Service title takes precedence over a reused merchant model");
        expect(NpcMarkers.kind({type: 22, texts: {name: "Glory Merchant", desc: "Glory Merchant"},
            props: {npc: {npcTitle: "Merchant of Glory Stories"}}}), "npc", "Incidental words and personal names are not a service title");
        expect(NpcMarkers.kind({type: 22, props: {shopList: [{lootTable: "BadgeOfGlory"}]}}),
            "npc", "Shop lists do not set a custom price");
        expect(NpcMarkers.isNpc("glory"), true, "Glory uses NPC visibility and priority");
        expect(NpcMarkers.isNpc("infusion"), true, "Crucible uses NPC visibility and priority");
        expect(NpcMarkers.isNpc("soulWell"), true, "Soul Well uses station visibility and priority");
        expect(NpcMarkers.isNpc("riftPortal"), false, "Rifts keep their own category");
        expect(NpcMarkers.availableDefinition(null), false, "Missing NPC definition");
        expect(NpcMarkers.availableDefinition({type: 22}), true, "Ordinary distant NPC stays visible without a loaded entity");
        expect(NpcMarkers.availableDefinition({props: {releaseStatus: 3}}), true, "Released NPC stays visible");
        for (status in [0, 1, 2]) expect(NpcMarkers.availableDefinition({props: {releaseStatus: status}}),
            false, "Unreleased or preview-only NPC is hidden on Live: " + status);
        expect(NpcMarkers.availableDefinition({props: {enabled: false}}), false, "Disabled prefab has no fallback marker");
        expect(NpcMarkers.availableDefinition({props: {enabled: true}}), true, "Enabled prefab is retained");
        expect(NpcMarkers.availableDefinition({props: {interactible: {hidden: true}}}), false, "Hidden interactible has no fallback marker");
        var access = new minimap.WorldEventAccess();
        var events = {disabled: "PreviewMerchant"};
        var eventNpc = {id: "PreviewMerchant", props: {event: "PreviewEvent"}};
        expect(NpcMarkers.eventVisible(eventNpc, events, access), false, "Disabled event merchant is hidden");
        events.disabled = "OtherMerchant";
        expect(NpcMarkers.eventVisible(eventNpc, events, access), true, "Event activation restores a cached marker");
        expect(NpcMarkers.eventVisible(eventNpc, null, access), false, "Event prefab waits for authoritative event status");
        var reads = G.eventStatusCalls;
        expect(NpcMarkers.eventVisible({id: "RegularMerchant", props: {}}, null, access), true, "Ordinary NPC does not need an event manager");
        expect(G.eventStatusCalls, reads, "Ordinary NPC markers do not query events");
        Sys.println('NPC marker checks passed ($checks)');
    }
}
