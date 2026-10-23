package dpsmeter;

import modinput.NativeHotkey;

import dpsmeter.MeterConfig.MeterSettings;
import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import modconfig.CommonSettings;
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
    static var readyCheck:ReadyCheckController;
    static var writer:RunWriter;
    static var fareverlyAccount:NativeFareverlyAccount;
    static var timeline:NativeTimeline;
    static final reportMode = new ReportMode();
    static function main():Void {
        if (ConfigMigration.importLegacy()) reloadConfig();
        else if (!ConfigMigration.hasNative()) MeterConfig.importLegacy(config);
        MeterConfig.normalize(config);
        saveConfig();
        historyView = new NativeHistoryWindow(config, reportMode);
        view = new NativeMeterWindow(config, () -> historyView.open(), reportMode);
        recapView = new NativeRiftRecapWindow(reportMode);
        kills = new KillNotifications(config);
        readyCheck = new ReadyCheckController(config);
        writer = new RunWriter();
        fareverlyAccount = new NativeFareverlyAccount(saveFareverlyCredential);
        Bus.subscribe(CommonSettings.CHANGED_TOPIC, (_:Dynamic) -> fareverlyAccount.settingsChanged());
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> reloadConfig());
    }
    static function reloadConfig():Void {
        var loaded = ModConfig.load(HlxRuntime.moduleName(), config);
        // The collector and UI share this object; keep their reference live.
        for (key in Reflect.fields(loaded))
            Reflect.setField(config, key, Reflect.field(loaded, key));
        MeterConfig.normalize(config);
        if (fareverlyAccount != null) fareverlyAccount.settingsChanged();
    }

    static function saveFareverlyCredential(value:fareverly.Protocol.Credential, expectedKey:String):Bool {
        try {
            if (!FareverlyConfig.save(value, expectedKey)) return false;
        } catch (_:Dynamic) return false;
        Bus.publish(CommonSettings.CHANGED_TOPIC, null);
        return true;
    }

    public static function saveConfig():Void {
        try config.save() catch (_:Dynamic) {}
    }

    @:hlx.postfix(GameApp.onQuit)
    static function finishUploads(instance:Dynamic, result:Bool):Void {
        if (result) finishHistory();
    }

    static function flushFights():Void {
        // Gate both the background worker (including queued retries) and new
        // submissions by the currently running game's verified branch.
        // Local history is still recorded on PTR and unknown branches.
        var submit=GameBranch.sessionMayUpload(config.sendLogs,collector.model.gameBranch);
        writer.setUploadsEnabled(submit);
        writer.setRetention(config.autoDeleteLogs, config.logRetentionMonths);
        writer.archiveHistory(collector.model, submit);
        while (collector.model.completed.length > 0 && collector.model.completed[0].pendingHealing == 0) {
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
        if (fareverlyAccount != null) fareverlyAccount.disconnect();
        if (historyView != null) historyView.dispose();
        if (readyCheck != null) readyCheck.dispose();
        // A later GameApp (for example after reconnecting) starts a new worker.
        writer = new RunWriter();
        collector = null; timeline = null;
        return Continue;
    }

    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressMeterAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> {
        return NativeMeterWindow.constructing || NativeRiftRecapWindow.constructing || NativeHistoryWindow.constructing
            || NativeReadyCheckWindow.constructing ? Skip : Continue;
    }
    @:hlx.prefix(st.player.ChatClient.sendMessage)
    static function routeReadyCheck(instance:Dynamic, message:Dynamic):HlxPrefixResult<Void> {
        if (readyCheck != null) try readyCheck.outgoing(instance, message, haxe.Timer.stamp())
        catch (error:Dynamic) readyCheck.report(error);
        return Continue;
    }
    @:hlx.postfix(st.player.ChatClient.localReceiveMessage)
    static function receiveReadyCheck(instance:Dynamic, message:Dynamic, result:Void):Void {
        // Both remote RPCs and the sender's server echo enter here exactly once.
        // Do not poll ChatBox history: rebuilding chat would replay old commands.
        if (readyCheck != null) try readyCheck.received(instance, message, haxe.Timer.stamp())
        catch (error:Dynamic) readyCheck.report(error);
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
        if (timeline != null) try timeline.health(instance, value) catch (error:Dynamic) timeline.report(error);
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
        if (G.integer(G.field(damage, "effect")) != 1) {
            var now = haxe.Timer.stamp();
            if (timeline != null) try timeline.damage(instance, damage, now) catch (error:Dynamic) timeline.report(error);
            if (collector != null) try collector.damage(instance, damage, now) catch (_:Dynamic) {}
        }
        return Continue;
    }
    @:hlx.postfix(ent.Foe.set_summonSourceSkill)
    static function recordSummonSource(instance:Dynamic, skill:Dynamic, result:Dynamic):Dynamic {
        // Used by both initial replication and later source-skill updates.
        if (collector != null) try collector.summonCreated(instance)
            catch (error:Dynamic) trace("[DPS Meter] Summon cast capture: " + Std.string(error));
        return result;
    }
    @:hlx.postfix(ent.Foe.init)
    static function recordSummonInit(instance:Dynamic, result:Void):Void {
        // Retry after initialization if the source/player was not ready when
        // its network fields were read. The collector deduplicates by unit UID.
        if (collector != null) try collector.summonCreated(instance)
            catch (error:Dynamic) trace("[DPS Meter] Summon cast capture: " + Std.string(error));
    }
    @:hlx.prefix(st.skill.Skill.start)
    static function recordSkillUse(instance:Dynamic, duration:Dynamic, target:Dynamic, sourceContext:Dynamic,
        startConfig:Dynamic):HlxPrefixResult<Dynamic> {
        // The accepted start boundary also covers automatically started skills,
        // and precedes instant effects that run before Hero.onSkillUse.
        if (collector != null) try collector.skillUse(instance, sourceContext)
            catch (error:Dynamic) trace("[DPS Meter] Cast capture: " + Std.string(error));
        if (timeline != null) try timeline.use(G.field(instance, "owner"), instance, target) catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.postfix(st.skill.Skill.start)
    static function recordSkillStarted(instance:Dynamic, duration:Dynamic, target:Dynamic, sourceContext:Dynamic,
        startConfig:Dynamic, result:Dynamic):Dynamic {
        if (timeline != null) try timeline.started(instance, result) catch (error:Dynamic) timeline.report(error);
        return result;
    }
    @:hlx.postfix(st.skill.BaseSkill.clientsPlayStep__impl)
    static function recordPassiveProcStep(instance:Dynamic, step:String, rank:Dynamic,
        variation:String, target:Dynamic, result:Void):Void {
        // The shipped client receives skill steps here. Passive procs can
        // execute without Skill.start; AoE hits and DoT ticks arrive later.
        if (collector != null) try collector.procStep(instance, haxe.Timer.stamp())
            catch (error:Dynamic) trace("[DPS Meter] Proc cast capture: " + Std.string(error));
    }
    @:hlx.prefix(st.skill.Skill.doStop)
    static function recordSkillStop(instance:Dynamic, reason:Dynamic):HlxPrefixResult<Void> {
        if (timeline != null) try timeline.stopped(instance, reason) catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.postfix(st.skill.Block.onBlock__impl)
    static function recordBlock(instance:Dynamic, wellTimed:Bool, result:Void):Void {
        if (timeline != null) try timeline.block(instance, wellTimed) catch (error:Dynamic) timeline.report(error);
    }
    @:hlx.postfix(st.skill.Skill.shouldHighlight)
    static function recordHighlight(instance:Dynamic, result:Bool):Bool {
        if (timeline != null) try timeline.highlight(instance, result) catch (error:Dynamic) timeline.report(error);
        return result;
    }
    @:hlx.prefix(st.skill.Skill.doUpdateCharges__impl)
    static function recordChargeChange(instance:Dynamic, value:Float):HlxPrefixResult<Void> {
        if (timeline != null) try timeline.charges(instance, value) catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.postfix(st.skill.SkillArea.initData)
    static function recordBombletArea(instance:Dynamic, result:Void):Void {
        // The client receives each Bomblet/GoldenBomblet area with its
        // baseSkill and stepIndex already initialized. No game mutation and
        // no hit-based cast inference.
        if (collector != null) try collector.bombletArea(instance, haxe.Timer.stamp())
            catch (error:Dynamic) trace("[DPS Meter] Bomblet cast capture: " + Std.string(error));
    }
    @:hlx.postfix(st.skill.Status.postInit)
    static function recordStatusInit(instance:Dynamic, result:Bool):Bool {
        if (result && collector != null) try collector.statusApplied(instance)
            catch (error:Dynamic) trace("[DPS Meter] Status cast capture: " + Std.string(error));
        if (result && timeline != null) try timeline.statusChanged(instance, "status_applied") catch (error:Dynamic) timeline.report(error);
        return result;
    }
    @:hlx.postfix(st.skill.Status.clientRefresh__impl)
    static function recordStatusRefresh(instance:Dynamic, result:Void):Void {
        if (collector != null) try collector.statusApplied(instance, true)
            catch (error:Dynamic) trace("[DPS Meter] Status cast capture: " + Std.string(error));
        if (timeline != null) try timeline.statusChanged(instance, "status_refreshed") catch (error:Dynamic) timeline.report(error);
    }
    @:hlx.postfix(st.skill.Status.setDuration__impl)
    static function recordStatusDuration(instance:Dynamic, duration:Float, result:Void):Void {
        if (timeline != null) try timeline.statusChanged(instance, "status_duration") catch (error:Dynamic) timeline.report(error);
    }
    @:hlx.postfix(st.skill.Status.networkRPC)
    static function recordStatusRpc(instance:Dynamic, serializer:Dynamic, rpcId:Int, client:Dynamic, result:Bool):Bool {
        // rpcExtendDuration__impl is only an add/store/return; its JIT body is
        // too short for MinHook on the shipped client. Observe the completed
        // dispatch instead, without depending on version-specific RPC numbers.
        if (result && timeline != null) try timeline.statusRpc(instance) catch (error:Dynamic) timeline.report(error);
        return result;
    }
    @:hlx.postfix(st.skill.Status.set_stacks)
    static function recordStatusStacks(instance:Dynamic, value:Int, result:Int):Int {
        if (timeline != null) try timeline.statusChanged(instance, "status_stacks") catch (error:Dynamic) timeline.report(error);
        return result;
    }
    @:hlx.prefix(st.skill.Status.doStop)
    static function recordStatusStop(instance:Dynamic, reason:Dynamic):HlxPrefixResult<Void> {
        if (timeline != null) try timeline.statusRemoved(instance, reason) catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.prefix(st.skill.Status.onRemove)
    static function recordStatusRemove(instance:Dynamic):HlxPrefixResult<Void> {
        if (collector != null) collector.statusRemoved(instance);
        if (timeline != null) try timeline.statusRemoved(instance) catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.prefix(st.skill.Status.set_shieldAmount)
    static function recordShield(instance:Dynamic, value:Float):HlxPrefixResult<Float> {
        if (timeline != null) try timeline.shieldChanged(instance, G.number(G.field(instance, "shieldAmount")), value)
            catch (error:Dynamic) timeline.report(error);
        return Continue;
    }
    @:hlx.postfix(ent.Hero.onEnterCombat)
    static function onCombatEnter(instance:Dynamic, result:Void):Void {
        if (collector != null && config.enabled) try collector.combatEnter(G.uid(instance), haxe.Timer.stamp())
        catch (_:Dynamic) {}
    }
    @:hlx.postfix(ent.GameObject.rpcDie__impl)
    static function onTargetDeath(instance:Dynamic, result:Void):Void {
        if (timeline != null) try timeline.death(instance) catch (error:Dynamic) timeline.report(error);
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
        if (collector == null) {
            var epoch = haxe.Timer.stamp();
            writer.timeline = new CombatTimeline("trace_" + DateTools.format(Date.now(), "%Y%m%d_%H%M%S") + "_" + Std.random(0x3fffffff), epoch, writer.recordTimeline);
            timeline = new NativeTimeline(config, writer.timeline);
            collector = new Collector(config, timeline);
        }
        var now = haxe.Timer.stamp();
        try {
            fareverlyAccount.update(G.field(instance, "hero"));
            var authMessage = writer.receiveAuthMessage();
            while (authMessage != null) { fareverlyAccount.uploadMessage(authMessage); authMessage = writer.receiveAuthMessage(); }
        } catch (_:Dynamic) {}
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
                        if (modePressed) reportMode.toggle();
                    }
                }
            }
            if (config.enabled) collector.update(instance, now);
            else { collector.healingCapture.flush(now, true); timeline.update(G.field(instance, "hero"), now); }
            flushFights();
            writer.update(now);
        } catch (_:Dynamic) {}
        // A UI failure must never stop the collector or discard a finished report.
        try view.update(collector.model, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
        try recapView.update(collector.model, config.enabled && config.showRiftRecaps, G.field(instance, "hero") != null, now) catch (_:Dynamic) {}
        try historyView.update(writer, config.enabled && G.field(instance, "hero") != null, now)
        catch (e:Dynamic) { historyView.dispose(); trace("[DPS Meter] Could not display history: " + Std.string(e)); }
        try kills.update(instance, collector.model, writer, now) catch (_:Dynamic) {}
        try readyCheck.update(instance, now) catch (error:Dynamic) readyCheck.report(error);
    }
}
