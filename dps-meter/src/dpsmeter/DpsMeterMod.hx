package dpsmeter;

import modinput.NativeHotkey;

import dpsmeter.MeterConfig.MeterSettings;
import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;
import dpsmeter.GameAccess as G;

@:build(hlx.runtime.Mod.build())
class DpsMeterMod {
    @:hlx.config
    static var config:MeterSettings = MeterConfig.defaults();
    static var collector:Collector;
    static var view:NativeMeterWindow;
    static var recapView:NativeRiftRecapWindow;
    static var historyView:NativeHistoryWindow;
    static var kills:KillNotifications;
    static var writer:RunWriter;
    static function main():Void {
        if (ConfigMigration.importLegacy()) reloadConfig();
        else if (!ConfigMigration.hasNative()) MeterConfig.importLegacy(config);
        MeterConfig.normalize(config);
        saveConfig();
        historyView = new NativeHistoryWindow(config);
        view = new NativeMeterWindow(config, () -> historyView.open());
        recapView = new NativeRiftRecapWindow();
        kills = new KillNotifications(config);
        writer = new RunWriter();
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> reloadConfig());
    }
    static function reloadConfig():Void {
        var loaded = ModConfig.load(HlxRuntime.moduleName(), config);
        // The collector and UI share this object; keep their reference live.
        for (key in Reflect.fields(loaded))
            Reflect.setField(config, key, Reflect.field(loaded, key));
        MeterConfig.normalize(config);
    }

    public static function saveConfig():Void {
        try config.save() catch (_:Dynamic) {}
    }

    @:hlx.postfix(GameApp.onQuit)
    static function finishUploads(instance:Dynamic, result:Bool):Void {
        if (result) finishHistory();
    }

    static function flushFights():Void {
        writer.archiveHistory(collector.model);
        while (collector.model.completed.length > 0 && collector.model.completed[0].pendingHealing == 0) {
            if (config.sendLogs) writer.enqueue(collector.model.completed[0]);
            collector.model.completed.shift();
        }
    }
    static function finishHistory():Void {
        try {
            if (collector != null && writer != null) {
                collector.healingCapture.flush(haxe.Timer.stamp(), true);
                collector.model.reset(haxe.Timer.stamp());
                flushFights();
            }
        } catch (e:Dynamic) trace("[DPS Meter] Could not finalize fight history: " + Std.string(e));
        if (writer != null) writer.stop();
    }

    @:hlx.prefix(GameApp.dispose)
    static function stopUploads(instance:Dynamic):HlxPrefixResult<Void> {
        finishHistory();
        if (historyView != null) historyView.dispose();
        // A later GameApp (for example after reconnecting) starts a new worker.
        writer = new RunWriter();
        return Continue;
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMeterAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return NativeMeterWindow.constructing || NativeRiftRecapWindow.constructing || NativeHistoryWindow.constructing ? Skip : Continue;
    }
    @:hlx.prefix(ui.BaseUI.closeFirstClosableUI)
    static function closeHistoryOnEscape(instance:Dynamic, onlyEscapeClosable:Null<Bool>):HlxPrefixResult<Bool> {
        // Participate in the native Escape/back route and consume this close
        // action so it cannot also open EscapeMenu or close another window.
        return historyView != null && historyView.closeFromEscape(instance) ? SkipWith(true) : Continue;
    }
    @:hlx.prefix(ui.notify.NotifyManager.queue)
    static function positionKillPopup(instance:Dynamic, notification:Dynamic):HlxPrefixResult<Void> {
        // These native text components have their own screen placement/lifetime.
        return NativeKillPopups.constructing ? Skip : Continue;
    }
    @:hlx.prefix(st.Player.onUnitKilledIncremented__impl)
    static function replaceCodexKillPopup(instance:Dynamic, unitId:String, completed:Bool):HlxPrefixResult<Void> {
        // Keep the native reward notification; replace only its recurring count.
        return config != null && config.enabled && !completed && G.field(instance, "isMe") == true ? Skip : Continue;
    }
    @:hlx.postfix(st.player.Progress.networkSync)
    static function onProgressSync(instance:Dynamic, context:Dynamic, result:Void):Void {
        if (kills != null) kills.synced(instance);
    }
    @:hlx.prefix(ent.Unit.rpcDisplayHeal__impl)
    static function collectHealing(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void> {
        if (collector != null) try collector.healing(instance, damage, haxe.Timer.stamp()) catch (_:Dynamic) {}
        return Continue;
    }
    @:hlx.prefix(ent.UnitAttributes.set_health)
    static function observeHealth(instance:Dynamic, value:Float):HlxPrefixResult<Float> {
        if (collector != null) try collector.healthChanged(instance, value) catch (_:Dynamic) {}
        return Continue;
    }
    @:hlx.prefix(ent.Unit.playHitHealFX)
    static function collectHealingFX(instance:Dynamic, hitData:Dynamic):HlxPrefixResult<Dynamic> {
        if (collector != null) try collector.healingFX(instance, hitData, haxe.Timer.stamp()) catch (_:Dynamic) {}
        return Continue;
    }

    @:hlx.prefix(ent.Unit.rpcReceiveDamage__impl)
    static function onDamage(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void> {
        // Healing has one canonical collection route, even if a game effect
        // sends both a generic damage notification and a heal notification.
        if (collector != null && G.integer(G.field(damage, "effect")) != 1)
            try collector.damage(instance, damage, haxe.Timer.stamp()) catch (_:Dynamic) {}
        return Continue;
    }
    @:hlx.postfix(ent.Hero.onEnterCombat)
    static function onCombatEnter(instance:Dynamic, result:Void):Void {
        if (collector != null && config.enabled) try collector.combatEnter(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(ent.GameObject.rpcDie__impl)
    static function onTargetDeath(instance:Dynamic, result:Void):Void {
        if (collector != null && config.enabled) try collector.model.onTargetDeath(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(ent.Hero.onLeaveCombat)
    static function onCombatExit(instance:Dynamic, result:Void):Void {
        // This callback runs before set_isInCombat stores false. Observe the
        // actual exit event; the collector excludes this hero when checking
        // whether the rest of the party is still fighting.
        if (collector != null && config.enabled) try collector.combatExit(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic, dt:Float, result:Void):Void {
        // HLX recovers the game's module only AFTER every mod's main() runs.
        // Collector reads Config.getVersion(), so construct it here once the
        // native functions and game statics are available, before any fights.
        if (collector == null) collector = new Collector(config);
        var now = haxe.Timer.stamp();
        try {
            if (NativeHotkey.isPressed(config.toggleHotkey)) {
                config.visible = !config.visible; saveConfig();
            }
            if (NativeHotkey.isPressed(config.unlockHotkey)) {
                config.unlocked = !config.unlocked; saveConfig();
            }
            // Read the same shared key state as the other hotkeys; BMS consumes
            // assignment input centrally. Zero is unbound, not a mouse binding.
            if (config.enabled && G.field(instance, "hero") != null) {
                var historyPressed = NativeHotkey.isPressed(config.historyHotkey);
                var modePressed = NativeHotkey.isPressed(config.modeHotkey);
                if (historyPressed || modePressed) {
                    var ui = G.current("ui.BaseUI", "current");
                    if (ui != null && G.call("ui.BaseUI", "getFocusedTextInput", ui) == null) {
                        if (historyPressed) historyView.toggle();
                        if (modePressed) { view.toggleMode(); historyView.toggleMode(); recapView.toggleMode(); }
                    }
                }
            }
            if (config.enabled) collector.update(instance, now);
            else collector.healingCapture.flush(now, true);
            flushFights();
            writer.update(now);
        } catch (_:Dynamic) {}
        // A UI failure must never stop the collector or discard a finished report.
        try view.update(collector.model, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
        try recapView.update(collector.model, config.enabled && config.showRiftRecaps, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
        try historyView.update(writer, config.enabled && G.field(instance, "hero") != null, now)
        catch (e:Dynamic) { historyView.dispose(); trace("[DPS Meter] Could not display history: " + Std.string(e)); }
        try kills.update(instance, collector.model, writer, now) catch (_:Dynamic) {}
    }
}
