import minimap.MainMapFilters;
import minimap.MinimapSettings;

class MainMapFiltersTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected $b, got $a';
    }
    static function main():Void {
        var config:MinimapSettings = cast {markerScale:100., showPlayers:false, showObelisks:false,
            showRespawnPoints:false, showSoulstoneCircles:false, hideVerticallyDistantMarkers:true,
            showOre:false, showPlants:false, showEnemies:false, showCompanions:false,
            showActivities:false, showNpcs:false, showChests:false, showSecretOrbs:false, hideCopper:true};
        var saves = 0, filters = new MainMapFilters(() -> saves++);
        filters.bind(config);
        var derived = filters.settings();
        eq(derived == filters.settings(), true, 'Repeated frames reuse derived config');
        for (key in ['showPlayers', 'showObelisks', 'showRespawnPoints', 'showSoulstoneCircles']) {
            eq(Reflect.field(derived, key), true, 'Always-visible main-map category ' + key);
            eq(Reflect.field(config, key), false, 'Minimap preference preserved ' + key);
        }
        eq(derived.hideVerticallyDistantMarkers, false, 'Main map never filters by height');
        eq(config.hideVerticallyDistantMarkers, true, 'Minimap height preference preserved');
        eq(derived.hideCopper, false, 'Independent resource default');
        eq(filters.enabled('activities', 'completed'), false, 'Completed activities default hidden');
        eq(filters.enabled('companions', 'collected'), false, 'Collected companions default hidden');
        eq(derived.hideMasteredCodexEnemies, true, 'Codex mastery completed enemies default hidden');
        var defaults = ['activities:completed', 'companions:collected', 'enemies:mastered'];
        eq(config.mainMapHiddenFilters.join(','), defaults.join(','), 'Exactly the requested three default exclusions');
        var categoryFields = ['showOre', 'showPlants', 'showEnemies', 'showCompanions', 'showActivities', 'showNpcs', 'showChests', 'showSecretOrbs'];
        for (i in 0...MainMapFilters.CATEGORIES.length) {
            var category = MainMapFilters.CATEGORIES[i];
            for (item in category.items)
                eq(filters.enabled(category.key, item.key), defaults.indexOf(category.key + ':' + item.key) < 0,
                    'Exact default for ' + category.key + ':' + item.key);
            eq(Reflect.field(filters.settings(), categoryFields[i]), true, category.label + ' default on');
            filters.setEnabled(category.key, null, false);
            eq(Reflect.field(filters.settings(), categoryFields[i]), false, category.label + ' category off');
            filters.setEnabled(category.key, null, true);
            for (item in category.items) {
                filters.setEnabled(category.key, item.key, false);
                eq(filters.enabled(category.key, item.key), false, 'Disable ' + category.key + ':' + item.key);
                filters.setEnabled(category.key, item.key, true);
            }
        }
        var resources = ['copper', 'iron', 'tin', 'tungstene', 'madrigold', 'lavendula', 'ancientThyme', 'zealotus'];
        for (i in 0...resources.length) {
            var key = resources[i], category = i < 4 ? 'ore' : 'plants';
            var flag = 'hide' + key.charAt(0).toUpperCase() + key.substr(1);
            filters.setEnabled(category, key, false);
            eq(Reflect.field(filters.settings(), flag), true, 'Collector receives resource exclusion ' + key);
            filters.setEnabled(category, key, true);
        }
        var subtypes = [
            {category:'enemies', key:'regular', kinds:['enemy']},
            {category:'enemies', key:'boss', kinds:['boss']},
            {category:'enemies', key:'targetDummy', kinds:['targetDummy']},
            {category:'companions', key:'regular', kinds:['companion']},
            {category:'activities', key:'activity', kinds:['activity']},
            {category:'activities', key:'ascension', kinds:['ascension']},
            {category:'activities', key:'dungeon', kinds:['dungeon']},
            {category:'activities', key:'rifts', kinds:['inactiveRift', 'nextRift', 'upcomingRift', 'riftPortal']}
        ];
        for (subtype in subtypes) {
            filters.setEnabled(subtype.category, subtype.key, false);
            for (kind in subtype.kinds) eq(filters.accepts({kind:kind, x:0, y:0, z:0}), false, 'Subtype actually hides ' + kind);
            for (kind in ['player', 'obelisk', 'respawn', 'soulstone'])
                eq(filters.accepts({kind:kind, x:0, y:0, z:500}), true, 'Subtype never hides protected ' + kind);
            filters.setEnabled(subtype.category, subtype.key, true);
        }
        filters.setEnabled('companions', 'sparkling', false);
        eq(filters.accepts({kind:'companion', sparkling:true, x:0, y:0, z:0}), false, 'Sparkling companion subfilter');
        eq(filters.accepts({kind:'companion', sparkling:false, x:0, y:0, z:0}), true, 'Normal companions remain visible');
        filters.setEnabled('secretOrbs', 'uncollected', false);
        eq(filters.settings().showSecretOrbs, true, 'Retired orb preference cannot silently hide markers');
        for (kind in ['chest', 'vaultChest', 'recipeChest']) {
            filters.setEnabled('chests', kind, false);
            eq(filters.accepts({kind:kind, x:0, y:0, z:0}), true, 'Retired chest preference cannot hide ' + kind);
        }
        for (kind in minimap.NpcMarkers.KINDS) {
            filters.setEnabled('npcs', kind, false);
            eq(filters.accepts({kind:kind, x:0, y:0, z:0}), true, 'Retired NPC preference cannot hide ' + kind);
        }
        eq(filters.settings().showNpcs, true, 'All NPC services share the enabled category');
        filters.setEnabled('npcs', null, false);
        eq(filters.settings().showNpcs, false, 'NPC category can still hide all NPC services');
        filters.setEnabled('npcs', null, true);
        for (category in MainMapFilters.CATEGORIES) if (['npcs', 'chests', 'secretOrbs'].indexOf(category.key) >= 0)
            eq(category.items.length, 0, category.label + ' has no subfilters');
        filters.setEnabled('ore', 'copper', false);
        filters.setEnabled('ore', null, false);
        var reloaded:MinimapSettings = haxe.Json.parse(haxe.Json.stringify(config));
        var reopened = new MainMapFilters(); reopened.bind(reloaded);
        eq(reopened.settings().showOre, false, 'Category survives serialized config reload');
        reopened.setEnabled('ore', null, true);
        eq(reopened.settings().hideCopper, true, 'Subfilter survives category cycling and reload');
        eq(reloaded.showOre, false, 'Minimap state independently survives reload');
        eq(reopened.settings().hideMasteredCodexEnemies, false, 'Explicit saved mastery preference is preserved on reload');
        eq(reopened.settings().showSecretOrbs, true, 'Old orb exclusion stays retired after reload');
        for (kind in ['chest', 'vaultChest', 'recipeChest'])
            eq(reopened.accepts({kind:kind, x:0, y:0, z:0}), true, 'Old chest exclusion stays retired after reload: ' + kind);
        for (kind in minimap.NpcMarkers.KINDS)
            eq(reopened.accepts({kind:kind, x:0, y:0, z:0}), true, 'Old NPC exclusion stays retired after reload: ' + kind);
        var oldSettings = reopened.settings();
        reloaded.markerScale = 150;
        eq(reopened.settings().markerScale, 150., 'Marker scale changes invalidate derived settings');
        eq(reopened.settings() != oldSettings, true, 'Collector receives new config for rescaling');
        var before = saves;
        filters.setEnabled('ore', 'copper', false);
        eq(saves, before, 'No-op changes do not save again');
        Sys.println('Main map filters: $checks checks passed.');
    }
}
