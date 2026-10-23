package moresettings;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;
import modconfig.ConfigMigration;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

@:build(hlx.runtime.Mod.build())
class MoreSettingsMod {
    @:hlx.config
    static var config:MoreSettingsConfig = SettingsData.defaults();
    static var hideUi = new HideUiBinding();
    static var reportedInputError:Bool = false;
    static var reportedDamageNumberError:Bool = false;

    static function main():Void {
        var imported = ConfigMigration.importLegacy("more-audio-settings");
        if (!imported) imported = ConfigMigration.importLegacy("mute-unfocused");
        if (!imported) imported = ConfigMigration.importLegacy();
        if (imported) config = ModConfig.load(HlxRuntime.moduleName(), config);
        var previous = ModConfig.load(HlxRuntime.moduleName(), {
            disableProfanityFilter: (null:Null<Bool>)
        });
        if (previous.disableProfanityFilter == null) {
            // Preserve the standalone mod's preference when combining installs.
            config.disableProfanityFilter = previousProfanityPreference();
        }
        SettingsData.normalize(config);
        BossHealth.enabled = config.showBossHealth;
        PerformanceHooks.enabled = config.performanceOptimization;
        BeeEffects.enabled = config.performanceOptimization;
        BombletEffects.enabled = config.performanceOptimization;
        PerformanceDamageNumbers.enabled = config.performanceOptimization;
        InputComfort.configure(config.preventCtrlFFullscreen,config.holdSkillRepeat);
        StallMetrics.configure(config.performanceDiagnostics);
        DungeonPartyGuard.enabled = config.waitForParty;
        DungeonLeaveButton.enabled = config.leaveDungeonButton;
        DungeonLeaveButton.riftEnabled = config.leaveRiftButton;
        CrabgantuaWarnings.configure(config.crabgantuaRockfallWarnings);
        MinionHealthBars.configure(config.hideAlliedMinionHealthBars);
        ObviousSkillProcs.configure(config.obviousSkillProcs, config.skillProcAlertSize, config.skillProcAlertPosition);
        BuffStackOutlines.configure(config.buffStackNumberOutline);
        SocialHooks.configure(config, false);
        hideUi.configure(config.hideUiKey);
        config.save();
        AllyEffects.configure(config);
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            SettingsData.normalize(config);
            BossHealth.enabled = config.showBossHealth;
            var changedPerformance=PerformanceHooks.enabled!=config.performanceOptimization;
            PerformanceHooks.enabled = config.performanceOptimization;
            if(changedPerformance) {
                BeeEffects.reset();
                BombletEffects.reset();
                PerformanceDamageNumbers.reset();
            }
            BeeEffects.enabled = config.performanceOptimization;
            BombletEffects.enabled = config.performanceOptimization;
            PerformanceDamageNumbers.enabled = config.performanceOptimization;
            InputComfort.configure(config.preventCtrlFFullscreen,config.holdSkillRepeat);
            StallMetrics.configure(config.performanceDiagnostics);
            DungeonPartyGuard.enabled = config.waitForParty;
            DungeonLeaveButton.enabled = config.leaveDungeonButton;
            DungeonLeaveButton.riftEnabled = config.leaveRiftButton;
            CrabgantuaWarnings.configure(config.crabgantuaRockfallWarnings);
            MinionHealthBars.configure(config.hideAlliedMinionHealthBars);
            ObviousSkillProcs.configure(config.obviousSkillProcs, config.skillProcAlertSize, config.skillProcAlertPosition);
            BuffStackOutlines.configure(config.buffStackNumberOutline);
            SocialHooks.configure(config);
            hideUi.configure(config.hideUiKey);
            AllyEffects.configure(config);
        });
    }

    @:hlx.postfix(client.GameCamera.getTargetFov)
    static function adjustFieldOfView(instance:Dynamic, result:Float):Float {
        // Explicit cinematic/ability overrides keep their native framing.
        return CameraFov.adjust(result, G.number(G.field(instance, "overrideFov")), config.fieldOfView);
    }

    @:hlx.prefix(HText.cleanPlayerText)
    static function cleanPlayerText(text:String):HlxPrefixResult<String> {
        return config.disableProfanityFilter ? SkipWith(StringTools.htmlEscape(text)) : Continue;
    }

    @:hlx.postfix(ui.comp.HealthBar.init)
    static function afterHealthBarInit(instance:Dynamic, result:Void):Void {
        try BossHealth.attach(instance) catch (e:Dynamic) BossHealth.reportError(e);
        try MinionHealthBars.attach(instance) catch (e:Dynamic) MinionHealthBars.report(e);
    }

    @:hlx.postfix(ui.comp.AttributeBar.init)
    static function afterAttributeBarInit(instance:Dynamic, result:Void):Void {
        try MinionHealthBars.attachLifetime(instance) catch (e:Dynamic) MinionHealthBars.report(e);
    }

    @:hlx.prefix(ui.comp.DamageDisplay.display)
    static function beforeDamageNumber(damage:Dynamic, position:Dynamic):HlxPrefixResult<Dynamic> {
        return config.disableDamageNumbers || PerformanceDamageNumbers.suppress() ? SkipWith(null) : Continue;
    }

    @:hlx.postfix(ui.comp.DamageDisplay.display)
    static function afterFloatingDamage(damage:Dynamic,position:Dynamic,result:Dynamic):Dynamic {
        if(!config.disableDamageNumbers) PerformanceDamageNumbers.created(result);
        return result;
    }

    @:hlx.prefix(ui.comp.HealDisplay.display)
    static function beforeHealingNumber(damage:Dynamic, position:Dynamic):HlxPrefixResult<Dynamic>
        return config.disableDamageNumbers ? SkipWith(null) : Continue;

    @:hlx.prefix(ui.hud.EffectsFeed.displayDamage)
    static function beforeIncomingDamageNumber(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void>
        return config.disableDamageNumbers ? Skip : Continue;

    @:hlx.prefix(ui.hud.EffectsFeed.displayHeal)
    static function beforeIncomingHealingNumber(instance:Dynamic, damage:Dynamic):HlxPrefixResult<Void>
        return config.disableDamageNumbers ? Skip : Continue;

    @:hlx.postfix(ui.win.GearAppearance.init)
    static function afterGearAppearanceInit(instance:Dynamic, result:Void):Void {
        try BarbershopButton.attach(instance) catch (error:Dynamic) AppearanceEditor.report(error);
    }

    @:hlx.postfix(ui.BaseElement.onRemove)
    static function afterElementRemoved(instance:Dynamic, result:Void):Void {
        MinionHealthBars.forget(instance);
        BarbershopButton.forget(instance);
        ObviousSkillProcs.forget(instance);
        BuffStackOutlines.forget(instance);
    }

    @:hlx.postfix(ui.hud.StatusDisplay.init)
    static function afterStatusDisplayInit(instance:Dynamic, result:Void):Void {
        try BuffStackOutlines.attach(instance) catch (error:Dynamic) BuffStackOutlines.report(error);
    }

    @:hlx.postfix(h2d.Object.set_filter)
    static function afterStackLabelFilter(instance:Dynamic, filter:Dynamic, result:Dynamic):Dynamic {
        try BuffStackOutlines.afterFilter(instance) catch (error:Dynamic) BuffStackOutlines.report(error);
        return result;
    }

    @:hlx.postfix(ui.hud.SkillButton.init)
    static function afterSkillButtonInit(instance:Dynamic, result:Void):Void {
        ObviousSkillProcs.attach(instance);
    }

    @:hlx.postfix(ent.Hero.onSkillUse)
    static function afterHeroSkillUse(instance:Dynamic, skill:Dynamic, result:Void):Void {
        try ObviousSkillProcs.onUse(instance, skill) catch (error:Dynamic) ObviousSkillProcs.report(error);
    }

    @:hlx.postfix(ui.comp.DamageDisplay.init)
    static function afterDamageDisplayInit(instance:Dynamic, result:Void):Void {
        // HealDisplay calls this base initializer, then changes its component.
        // Style healing once, after the complete subclass initialization.
        if (G.isA(instance, "ui.comp.HealDisplay")) return;
        try DamageSkillIcons.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
        try FancyDamageNumbers.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
        try DamageNumberAppearance.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(ui.comp.HealDisplay.init)
    static function afterHealDisplayInit(instance:Dynamic, result:Void):Void {
        try DamageSkillIcons.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
        try FancyDamageNumbers.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
        try DamageNumberAppearance.apply(instance, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(ui.hud.EffectsFeed.displayDamage)
    static function afterReceivedDamage(instance:Dynamic,damage:Dynamic,result:Void):Void {
        try DamageNumberAppearance.damageFeed(instance,damage,config)
        catch(error:Dynamic)damageNumberError(error);
    }

    @:hlx.postfix(ui.hud.EffectsFeed.displayHeal)
    static function afterReceivedHeal(instance:Dynamic, damage:Dynamic, result:Void):Void {
        try DamageSkillIcons.applyHealingFeed(instance, damage, config) catch (error:Dynamic) damageNumberError(error);
        try FancyDamageNumbers.applyHealingFeed(instance, damage, config) catch (error:Dynamic) damageNumberError(error);
        try DamageNumberAppearance.healingFeed(instance, damage, config) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(h2d.filter.Filter.bind)
    static function afterDamageFilterBind(instance:Dynamic, s:Dynamic, result:Void):Void {
        try FancyDamageNumbers.bindGradient(instance, s) catch (error:Dynamic) damageNumberError(error);
    }

    @:hlx.postfix(h2d.filter.Filter.unbind)
    static function afterDamageFilterUnbind(instance:Dynamic, s:Dynamic, result:Void):Void {
        FancyDamageNumbers.unbindGradient(instance);
    }

    @:hlx.prefix(h2d.filter.Shader.draw)
    static function beforeDamageGradientDraw(instance:Dynamic, ctx:Dynamic, input:Dynamic):HlxPrefixResult<Dynamic> {
        try FancyDamageNumbers.syncGradient(instance, ctx, input) catch (error:Dynamic) damageNumberError(error);
        return Continue;
    }

    static function damageNumberError(error:Dynamic):Void {
        if (!reportedDamageNumberError) {
            reportedDamageNumberError = true;
            trace("[More Settings] Damage numbers: " + Std.string(error));
        }
    }

    @:hlx.postfix(lib.Input.getBindings)
    static function hideUiBindings(key:String, result:Dynamic):Dynamic {
        try return hideUi.bindings(key, result) catch (e:Dynamic) inputError(e);
        return result;
    }

    @:hlx.postfix(ui.win.element.InstanceSelectScreen.init)
    static function afterInstanceSelectInit(instance:Dynamic, result:Void):Void {
        try DungeonPartyGuard.update(instance) catch (e:Dynamic) DungeonPartyGuard.reportError(e);
    }

    @:hlx.postfix(ui.hud.ActivitiesInfo.init)
    static function afterActivitiesInfoInit(instance:Dynamic, result:Void):Void {
        try DungeonLeaveButton.attach(instance) catch (e:Dynamic) DungeonLeaveButton.reportError(e);
    }

    @:hlx.prefix(ui.UIElement.set_visible)
    static function beforeUiVisibility(instance:Dynamic, value:Bool):HlxPrefixResult<Bool> {
        try {
            if (MinionHealthBars.intercept(instance, value)) return SkipWith(false);
        } catch (error:Dynamic) MinionHealthBars.report(error);
        try {
            var visible = DungeonLeaveButton.visibility(instance, value);
            if (visible != value) {
                // Re-enter with the final value: this prefix then continues to
                // the native setter. Unchanged frames never hide then reshow
                // the button, avoiding repeated layout invalidation.
                if (G.field(instance, "visible") != visible)
                    G.call("ui.UIElement", "set_visible", instance, [visible]);
                return SkipWith(visible);
            }
        } catch (e:Dynamic) DungeonLeaveButton.reportError(e);
        return Continue;
    }

    @:hlx.postfix(ui.win.element.InstanceSelectScreen.update)
    static function afterInstanceSelectUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        try DungeonPartyGuard.update(instance) catch (e:Dynamic) DungeonPartyGuard.reportError(e);
    }

    @:hlx.prefix(ui.win.element.InstanceSelectScreen.startAction)
    static function beforeInstanceStart(instance:Dynamic):HlxPrefixResult<Void> {
        // Check again at activation, including keyboard/controller actions and
        // party changes since the last UI update. Ready and Cancel stay native.
        if (DungeonPartyGuard.waiting(instance)) return Skip;
        return Continue;
    }

    @:hlx.prefix(lib.Input.checkInput)
    static function suppressCtrlFFullscreen(action:String,checkKey:Dynamic,checkPad:Dynamic):HlxPrefixResult<Bool>
        return InputComfort.blockFullscreen(action) ? SkipWith(false) : Continue;

    @:hlx.prefix(client.UnitController.updateSkillInputs)
    static function beforeSkillInput(controller:Dynamic):HlxPrefixResult<Void> {
        InputComfort.begin(controller);
        return Continue;
    }

    @:hlx.postfix(client.UnitController.updateSkillInputs)
    static function afterSkillInput(controller:Dynamic,result:Void):Void InputComfort.end();

    @:hlx.postfix(lib.Input.isPressed)
    static function hideUiPressed(key:String, result:Bool):Bool {
        var pressed=InputComfort.pressed(key,result);
        try return hideUi.pressed(key,pressed) catch (e:Dynamic) inputError(e);
        return pressed;
    }

    @:hlx.prefix(GameApp.update)
    static function beforeUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        DiagnosticHooks.update(instance, config.performanceOptimization);
        PerformanceHooks.update(instance, dt);
        AppearanceEditor.update(instance);
        AllyEffects.update(instance);
        try SelfChatBubbles.update(instance) catch (error:Dynamic) SocialHooks.report(error);
        return Continue;
    }

    // Cosmetic FX suppression never touches skill damage, area-hit callbacks,
    // server simulation, or any object owned by the combat model.
    @:hlx.prefix(st.skill.SkillArea.playAreaFx)
    static function reduceBombletExplosions(area:Dynamic):HlxPrefixResult<Void>
        return BombletEffects.suppress(area)?Skip:Continue;

    @:hlx.prefix(world.World.playBellFx)
    static function reduceBombletTravel(world:Dynamic,inf:Dynamic,owner:Dynamic,
        from:Dynamic,to:Dynamic,duration:Float):HlxPrefixResult<Void>
        return BombletEffects.suppressTravel(inf,owner)?Skip:Continue;

    @:hlx.prefix(ent.GameObject.playSkillFx)
    static function reduceBeeAura(entity:Dynamic,fx:Dynamic,skill:Dynamic,
        force:hl.Ref<Bool>):HlxPrefixResult<Dynamic>
        return BeeEffects.suppressAura(entity,fx,skill)?SkipWith(null):Continue;

    @:hlx.prefix(st.skill.SkillArea.playTelegraph)
    static function reduceBeeOutlines(area:Dynamic,immediate:Bool):HlxPrefixResult<Void>
        return BeeEffects.suppressSkillFx(area)?Skip:Continue;

    @:hlx.prefix(st.skill.SkillStep.tryPlayShapeFx)
    static function reduceBeeAttackShapes(step:Dynamic,shape:Dynamic,fx:Dynamic):HlxPrefixResult<Void>
        return BeeEffects.suppressSkillFx(step)?Skip:Continue;

    @:hlx.postfix(ent.Unit.clientUpdate)
    static function reduceBeeModels(unit:Dynamic,dt:Float,result:Void):Void
        BeeEffects.update(unit);

    @:hlx.prefix(ent.Unit.removeVisual)
    static function restoreBeeOnRemove(unit:Dynamic):HlxPrefixResult<Void> {
        BeeEffects.release(unit);
        return Continue;
    }

    @:hlx.prefix(ent.Projectile.playVisuals)
    static function reduceBeeProjectileFx(projectile:Dynamic,mode:Int):HlxPrefixResult<Dynamic>
        return BeeEffects.suppressProjectile(projectile)?SkipWith(null):Continue;

    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {
        StallMetrics.suspend();
        PerformanceHooks.dispose();
        BeeEffects.reset();BombletEffects.reset();PerformanceDamageNumbers.reset();
        InputComfort.reset();
        DungeonLeaveButton.clear();
        try FancyDamageNumbers.dispose() catch (error:Dynamic) damageNumberError(error);
        DamageSkillIcons.clear();
        ObviousSkillProcs.clear();
        BuffStackOutlines.clear();
        AppearanceEditor.close();
        BarbershopButton.clear();
        MinionHealthBars.clear();
        AllyEffects.dispose();
        CrabgantuaWarnings.dispose();
        SocialHooks.dispose();
        return Continue;
    }

    @:hlx.postfix(GameApp.update)
    static function afterUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        try ObviousSkillProcs.update(instance, dt) catch (error:Dynamic) ObviousSkillProcs.report(error);
    }

    static function previousProfanityPreference():Bool {
        for (path in ["hlx/config/disable-profanity-filter/config.json", "hlx/mods/disable-profanity-filter/config.json"]) {
            if (!sys.FileSystem.exists(path)) continue;
            try {
                var old:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
                var value = Reflect.field(old, "disableProfanityFilter");
                if (Std.isOfType(value, Bool)) return value;
            } catch (_:Dynamic) {}
        }
        return true;
    }

    static function inputError(error:Dynamic):Void {
        if (!reportedInputError) {
            reportedInputError = true;
            trace("[More Settings] Hide UI binding: " + Std.string(error));
        }
    }
}
