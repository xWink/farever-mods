package minimap;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;

@:build(hlx.runtime.Mod.build())
class MinimapMod {
    @:hlx.config
    static var config:MinimapSettings = {
        mainMapEnabled: null, minimapEnabled: null, mainMapHiddenFilters: ["activities:completed", "companions:collected", "enemies:mastered"], transparency: 0, zoom: 30, size: 250, markerScale: 100, rotateMap: true, followCamera: true,
        circular: true, leftCorner: false, showNorthIndicator: true, xOffset: 0, yOffset: 0,
        mainMapMarkerScale: 100, mainMapMovement: false, useSameMapFilters: true,
        clockTimerMode: null, showRiftTimer: true, riftAlerts: true,
        showPlayers: true, showPlants: true, showOre: true, showEnemies: true,
        hideCompletedCodexEnemies: false, hideMasteredCodexEnemies: false, hideTargetDummies: false,
        showCompanions: true, hideCollectedCompanions: true, sparklingCompanionAlerts: true,
        showRespawnPoints: true, showObelisks: true, showSoulstoneCircles: true, showNpcs: true,
        showChests: true, showSecretOrbs: true, showActivities: true,
        hideVerticallyDistantMarkers: false, verticallyDistantThreshold: 15,
        hideCompletedActivities: true, hideAscensions: false, hideDungeons: false, hideInactiveRifts: false,
        hideCopper: false, hideIron: false, hideTin: false, hideTungstene: false,
        hideMadrigold: false, hideLavendula: false, hideAncientThyme: false, hideZealotus: false
    };
    static var view:MinimapView;
    static var bigMap:BigMapView;
    static var mapControls = new MainMapControls();
    static var retryAt:Float = 0;
    static var reportedError:Bool = false;
    static var saveZoomAt:Float = 0;

    static function main():Void {
        normalize();
        config.save();
        view = new MinimapView(() -> config.save());
        bigMap = new BigMapView(() -> config.save());
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            normalize();
            config.save();
            saveZoomAt = 0;
            retryAt = 0;
        });
    }

    static function normalize():Void {
        MapVisibility.migrate(config);
        MainMapFilters.prepare(config);
        // A null initial default lets old false preferences migrate to None.
        config.clockTimerMode = ClockTimer.mode(Reflect.field(config, "clockTimerMode"), config.showRiftTimer);
        config.transparency = Std.int(Math.max(0, Math.min(100, config.transparency)));
        config.zoom = Math.isFinite(config.zoom) ? Math.max(10, Math.min(300, config.zoom)) : 30;
        config.size = Std.int(Math.max(160, Math.min(400, config.size)));
        config.markerScale = Math.isFinite(config.markerScale) ? Math.max(50, Math.min(200, config.markerScale)) : 100;
        var mainScale = config.mainMapMarkerScale;
        config.mainMapMarkerScale = mainScale != null && Math.isFinite(mainScale) ? Math.max(50, Math.min(200, mainScale)) : 100;
        config.verticallyDistantThreshold = MarkerDetails.threshold(config.verticallyDistantThreshold);
        MinimapPosition.migrateCorner(config);
        config.xOffset = MinimapPosition.percent(config.xOffset);
        config.yOffset = MinimapPosition.percent(config.yOffset);
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

    @:hlx.prefix(GameApp.update)
    static function beginFrame(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        // Never carry the scoped map-input interception into a later frame,
        // including after an exception in the native map input handler.
        mapControls.endInputs();
        return Continue;
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

    @:hlx.postfix(ui.GameUI.blockAttackClick)
    static function blockMinimapCloseClick(instance:Dynamic, result:Bool):Bool {
        return result || config.minimapEnabled != false && view != null && view.blocksAttackClick();
    }

    @:hlx.postfix(ui.win.MapWindow.update)
    static function updateBigMap(instance:Dynamic, dt:Float, result:Void):Void {
        if (bigMap != null) bigMap.update(instance, config);
    }

    @:hlx.prefix(ui.win.MapWindow.init)
    static function initMapControls(instance:Dynamic):HlxPrefixResult<Void> {
        mapControls.update(instance, config);
        return Continue;
    }

    @:hlx.prefix(ui.win.MapWindow.update)
    static function updateMapControls(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        mapControls.endInputs();
        mapControls.update(instance, config);
        return Continue;
    }

    @:hlx.prefix(ui.win.MapWindow.updateInputs)
    static function beginMapInputs(instance:Dynamic):HlxPrefixResult<Void> {
        mapControls.beginInputs(instance);
        return Continue;
    }
    @:hlx.postfix(ui.win.MapWindow.updateInputs)
    static function endMapInputs(instance:Dynamic, result:Void):Void mapControls.endInputs();

    @:hlx.postfix(lib.Input.getMove)
    // The native optional Bool is a reference, not a Dynamic object. Using
    // Dynamic here misreads its pointer and interrupts MapWindow.updateInputs
    // before the window applies its smooth panning and zoom.
    static function mapMoveInput(point:Dynamic, normalize:hl.Ref<Bool>, result:Dynamic):Dynamic
        return mapControls.filterMove(result);

    @:hlx.prefix(ui.win.MapWindow.clampTargetZoom)
    static function beginMapZoom(instance:Dynamic):HlxPrefixResult<Void> {
        mapControls.beforeClamp(instance, config);
        return Continue;
    }
    @:hlx.postfix(ui.win.MapWindow.clampTargetZoom)
    static function endMapZoom(instance:Dynamic, result:Void):Void mapControls.afterClamp(instance);

    @:hlx.postfix(ui.win.MapWindow.refreshVisuals)
    static function refreshBigMap(instance:Dynamic, result:Void):Void {
        if (bigMap != null) bigMap.refreshNative(instance);
    }

    @:hlx.prefix(ui.win.MapWindow.onRemove)
    static function removeBigMap(instance:Dynamic):HlxPrefixResult<Void> {
        mapControls.remove(instance);
        if (bigMap != null) bigMap.remove(instance);
        return Continue;
    }

    @:hlx.prefix(ui.win.MapWindow.buildMap)
    static function rebuildBigMap(instance:Dynamic):HlxPrefixResult<Void> {
        if (bigMap != null) bigMap.remove(instance);
        return Continue;
    }

    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {
        saveZoom();
        mapControls.dispose();
        if (bigMap != null) bigMap.release();
        if (view != null) try view.dispose() catch (_:Dynamic) {}
        retryAt = 0;
        return Continue;
    }
}
