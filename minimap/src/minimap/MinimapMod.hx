package minimap;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;

typedef MinimapSettings = {
    var enabled:Bool;
    var transparency:Int;
    var zoom:Float;
    var size:Int;
    var rotateMap:Bool;
    var followCamera:Bool;
    var circular:Bool;
    var leftCorner:Bool;
    var showPlayers:Bool;
    var showPlants:Bool;
    var showOre:Bool;
    var showEnemies:Bool;
    var hideCompletedCodexEnemies:Bool;
    var hideNonCodexEnemies:Bool;
    var showCompanions:Bool;
    var hideCollectedCompanions:Bool;
    var sparklingCompanionAlerts:Bool;
    var showRespawnPoints:Bool;
    var showObelisks:Bool;
    var showNpcs:Bool;
    var showChests:Bool;
    var showSecretOrbs:Bool;
    var showActivities:Bool;
    var hideCopper:Bool;
    var hideIron:Bool;
    var hideTin:Bool;
    var hideTungstene:Bool;
    var hideMadrigold:Bool;
    var hideLavendula:Bool;
    var hideAncientThyme:Bool;
    var hideZealotus:Bool;
}

@:build(hlx.runtime.Mod.build())
class MinimapMod {
    @:hlx.config
    static var config:MinimapSettings = {
        enabled: true, transparency: 0, zoom: 100, size: 240, rotateMap: false, followCamera: false,
        circular: false, leftCorner: false,
        showPlayers: true, showPlants: true, showOre: true, showEnemies: true,
        hideCompletedCodexEnemies: false, hideNonCodexEnemies: false,
        showCompanions: true, hideCollectedCompanions: false, sparklingCompanionAlerts: true,
        showRespawnPoints: true, showObelisks: true, showNpcs: true,
        showChests: true, showSecretOrbs: true, showActivities: true,
        hideCopper: false, hideIron: false, hideTin: false, hideTungstene: false,
        hideMadrigold: false, hideLavendula: false, hideAncientThyme: false, hideZealotus: false
    };
    static var view:MinimapView;
    static var retryAt:Float = 0;
    static var reportedError:Bool = false;
    static var saveZoomAt:Float = 0;

    static function main():Void {
        normalize();
        config.save();
        view = new MinimapView();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            normalize();
            saveZoomAt = 0;
            retryAt = 0;
        });
    }

    static function normalize():Void {
        config.transparency = Std.int(Math.max(0, Math.min(100, config.transparency)));
        config.zoom = Math.isFinite(config.zoom) ? Math.max(10, Math.min(300, config.zoom)) : 100;
        config.size = Std.int(Math.max(160, Math.min(400, config.size)));
    }

    public static function adjustZoom(wheelDelta:Float):Void {
        if (wheelDelta == 0) return;
        var zoom = Math.max(10, Math.min(300, config.zoom + (wheelDelta < 0 ? 10 : -10)));
        if (zoom == config.zoom) return;
        config.zoom = zoom;
        // Coalesce a burst of wheel events into one native config save.
        saveZoomAt = haxe.Timer.stamp() + 0.35;
    }

    static function saveZoom():Void {
        if (saveZoomAt == 0) return;
        config.save();
        saveZoomAt = 0;
    }

    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        if (saveZoomAt != 0 && haxe.Timer.stamp() >= saveZoomAt) saveZoom();
        if (view == null || haxe.Timer.stamp() < retryAt) return;
        try view.update(instance, config) catch (error:Dynamic) {
            // Avoid repeated resource work or log spam if a game update changes the UI.
            retryAt = haxe.Timer.stamp() + 10;
            try view.dispose() catch (_:Dynamic) {}
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] " + Std.string(error));
            }
        }
    }

    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {
        saveZoom();
        if (view != null) try view.dispose() catch (_:Dynamic) {}
        retryAt = 0;
        return Continue;
    }
}
