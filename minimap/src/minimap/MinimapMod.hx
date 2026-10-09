package minimap;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;
import minimap.GameAccess as G;

typedef MinimapSettings = {
    var enabled:Bool;
    var transparency:Int;
    var zoom:Float;
    var size:Int;
    var markerScale:Float;
    var rotateMap:Bool;
    var followCamera:Bool;
    var circular:Bool;
    var leftCorner:Bool;
    var showNorthIndicator:Bool;
    var showCategoryButtons:Bool;
    var clockTimerMode:String;
    // Retained only to import older configs; no longer exposed as a setting.
    var showRiftTimer:Bool;
    var riftAlerts:Bool;
    var xOffset:Float;
    var yOffset:Float;
    var expandHotkey:Int;
    var showPlayers:Bool;
    var hideNonPartyPlayers:Bool;
    var partyDirectionArrows:Bool;
    var showPlants:Bool;
    var showOre:Bool;
    var showEnemies:Bool;
    var alwaysShowEliteEnemies:Bool;
    var hideCompletedCodexEnemies:Bool;
    var hideMasteredCodexEnemies:Bool;
    var hideTargetDummies:Bool;
    var showCompanions:Bool;
    var hideCollectedCompanions:Bool;
    var sparklingCompanionAlerts:Bool;
    var showRespawnPoints:Bool;
    var showObelisks:Bool;
    var showSoulstoneCircles:Bool;
    var showNpcs:Bool;
    var showChests:Bool;
    var showSecretOrbs:Bool;
    var hideVerticallyDistantMarkers:Bool;
    var verticallyDistantThreshold:Float;
    var showActivities:Bool;
    var hideCompletedActivities:Bool;
    var hideAscensions:Bool;
    var hideDungeons:Bool;
    var hideInactiveRifts:Bool;
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
        enabled: true, transparency: 0, zoom: 30, size: 250, markerScale: 100, rotateMap: true, followCamera: true,
        circular: true, leftCorner: false, showNorthIndicator: true, showCategoryButtons: true, xOffset: 0, yOffset: 0,
        expandHotkey: 0,
        clockTimerMode: null, showRiftTimer: true, riftAlerts: true,
        showPlayers: true, hideNonPartyPlayers: false, partyDirectionArrows: true,
        showPlants: true, showOre: true, showEnemies: true, alwaysShowEliteEnemies: true,
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
        // A null initial default lets old false preferences migrate to None.
        config.clockTimerMode = ClockTimer.mode(Reflect.field(config, "clockTimerMode"), config.showRiftTimer);
        config.transparency = Std.int(Math.max(0, Math.min(100, config.transparency)));
        config.zoom = Math.isFinite(config.zoom) ? Math.max(10, Math.min(300, config.zoom)) : 30;
        config.size = Std.int(Math.max(160, Math.min(400, config.size)));
        config.markerScale = Math.isFinite(config.markerScale) ? Math.max(50, Math.min(200, config.markerScale)) : 100;
        config.verticallyDistantThreshold = MarkerDetails.threshold(config.verticallyDistantThreshold);
        config.xOffset = MinimapPosition.percent(config.xOffset);
        config.yOffset = MinimapPosition.percent(config.yOffset);
        config.expandHotkey = Std.int(Math.max(0, config.expandHotkey));
    }

    public static function setToggles(values:Map<String, Bool>):Void {
        var changed = false;
        for (key in values.keys()) {
            if (!Reflect.hasField(config, key) || Reflect.field(config, key) == values[key]) continue;
            Reflect.setField(config, key, values[key]);
            changed = true;
        }
        if (changed) config.save();
    }

    public static function adjustZoom(wheelDelta:Float):Void {
        if (wheelDelta == 0) return;
        var zoom = Math.max(10, Math.min(300, config.zoom + (wheelDelta < 0 ? 10 : -10)));
        if (zoom == config.zoom) return;
        config.zoom = zoom;
        // Coalesce a burst of wheel events into one native config save.
        saveZoomAt = haxe.Timer.stamp() + 0.35;
    }

    static inline var SHIFT = 16;
    static inline var CTRL = 17;
    static inline var ALT = 18;
    static inline var LOC_LEFT = 256;
    static inline var LOC_RIGHT = 512;
    static inline var ESCAPE = 27;
    static var closedByEscape:Bool = false;

    static function expandPressed(app:Dynamic):Bool {
        if (config.expandHotkey <= 0) return false;
        if (G.staticCall("hxd.Key", "isPressed", [config.expandHotkey]) != true) return false;
        // M is still down during Shift+M. A plain binding must not fire while a modifier is held.
        if (modifierHeld()) return false;
        try {
            var ui = G.current("ui.BaseUI", "current");
            if (ui != null && G.call("ui.BaseUI", "getFocusedTextInput", ui) != null) return false;
        } catch (_:Dynamic) {}
        return true;
    }

    static function modifierHeld():Bool {
        for (code in [
            SHIFT, CTRL, ALT,
            SHIFT | LOC_LEFT, SHIFT | LOC_RIGHT,
            CTRL | LOC_LEFT, CTRL | LOC_RIGHT,
            ALT | LOC_LEFT, ALT | LOC_RIGHT
        ]) {
            if (code == config.expandHotkey) continue;
            try {
                if (G.staticCall("hxd.Key", "isDown", [code]) == true) return true;
            } catch (_:Dynamic) return false;
        }
        return false;
    }

    static function saveZoom():Void {
        if (saveZoomAt == 0) return;
        config.save();
        saveZoomAt = 0;
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMapWindowAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        // TitleWindow displays itself. Skip that so the expanded map stays a HUD window.
        return MapWindow.constructing ? Skip : Continue;
    }

    @:hlx.prefix(GameApp.update)
    static function beforeUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        // Run before the game handles Escape, so the pause menu does not open as well.
        if (view != null && haxe.Timer.stamp() >= retryAt && escapePressed() && view.dismissExpanded()) {
            closedByEscape = true;
            swallowEscape();
        }
        return Continue;
    }

    static function escapePressed():Bool {
        try return G.staticCall("hxd.Key", "isPressed", [ESCAPE]) == true catch (_:Dynamic) return false;
    }

    static function swallowEscape():Void {
        try {
            var keyType = HlxRuntime.resolveType("hxd.Key");
            var state = HlxRuntime.resolveStaticField(keyType, "keyPressed");
            if (state == null) return;
            var arrayType = hl.Type.getDynamic(state).getTypeName();
            var setter = HlxRuntime.resolveMember(HlxRuntime.resolveType(arrayType), "set");
            if (setter == null) setter = HlxRuntime.resolveMember(HlxRuntime.resolveType(arrayType), "setDyn");
            if (setter != null) HlxRuntime.callResolved(setter, [state, ESCAPE, 0]);
        } catch (_:Dynamic) {}
    }

    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        if (saveZoomAt != 0 && haxe.Timer.stamp() >= saveZoomAt) saveZoom();
        if (view == null || haxe.Timer.stamp() < retryAt) return;
        try {
            if (closedByEscape) closedByEscape = false;
            else if (expandPressed(instance)) view.toggleExpanded(instance);
            view.update(instance, config);
        } catch (error:Dynamic) {
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
