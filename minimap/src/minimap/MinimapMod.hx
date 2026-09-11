package minimap;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;

typedef MinimapSettings = {
    var enabled:Bool;
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
    var showIncompleteCodexEnemies:Bool;
    var showCompletedCodexEnemies:Bool;
    var showNonCodexEnemies:Bool;
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
        enabled: true, zoom: 100, size: 240, rotateMap: false, followCamera: false,
        circular: false, leftCorner: false,
        showPlayers: true, showPlants: true, showOre: true, showEnemies: true,
        showIncompleteCodexEnemies: true, showCompletedCodexEnemies: true,
        showNonCodexEnemies: true, showRespawnPoints: true, showObelisks: true, showNpcs: true,
        showChests: true, showSecretOrbs: true, showActivities: true,
        hideCopper: false, hideIron: false, hideTin: false, hideTungstene: false,
        hideMadrigold: false, hideLavendula: false, hideAncientThyme: false, hideZealotus: false
    };
    static var view:MinimapView;
    static var retryAt:Float = 0;
    static var reportedError:Bool = false;

    static function main():Void {
        normalize();
        config.save();
        view = new MinimapView();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            normalize();
            retryAt = 0;
        });
    }

    static function normalize():Void {
        config.zoom = Math.isFinite(config.zoom) ? Math.max(10, Math.min(300, config.zoom)) : 100;
        config.size = Std.int(Math.max(160, Math.min(400, config.size)));
    }

    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
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
        if (view != null) try view.dispose() catch (_:Dynamic) {}
        retryAt = 0;
        return Continue;
    }
}
