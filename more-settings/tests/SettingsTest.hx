import moresettings.SettingsData;
import moresettings.HideUiBinding;
import moresettings.BossHealth;
import moresettings.EffectPolicy;
import moresettings.SkillClassifier;
import moresettings.NativeSkillFacts;
import moresettings.AllyEffects;
import moresettings.GameAccess as G;

class SettingsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function main():Void {
        bossHealth(); hideUiBinding(); policy(); classification(); presentation();
        Sys.println('More Settings: $checks checks passed.');
    }

    static function bossHealth():Void {
        eq(SettingsData.defaults().showBossHealth, false, "boss health is opt-in");
        eq(BossHealth.format("100%", 123456), "123,456 (100%)", "requested full-health format");
        eq(BossHealth.format("50%", 61728.9), "61,728 (50%)", "uses raw HP with native whole-number rounding");
        eq(BossHealth.format("1%", 0.4), "0 (1%)", "retains native minimum percentage");
        eq(BossHealth.format("0%", -10), "0 (0%)", "negative HP displays zero");
        eq(BossHealth.format("100%", 3000000000.0), "3,000,000,000 (100%)", "large HP avoids Int overflow");
        eq(BossHealth.format("50% (+ 20%)", 500), "500 (50%) (+ 20%)", "shield stays outside health percentage");
        eq(BossHealth.format("50,5 %", 505), "505 (50,5 %)", "preserves localized percentage text");
        eq(BossHealth.format("123,456 (100%)", 123456), "123,456 (100%)", "does not decorate twice");
        eq(BossHealth.format("500 / 1000 (+ 200)", 500), "500 / 1000 (+ 200)", "Native numeric resource labels stay native");
        eq(BossHealth.format("100%", Math.NaN), "100%", "missing HP does not invent zero");
        eq(BossHealth.format("100%", Math.POSITIVE_INFINITY), "100%", "invalid HP is ignored");

        // Simulate the audited native callback order: HealthBar writes first,
        // then our callback decorates it. The bar owns both callbacks.
        var gauge = {usePercents: true, value: 123456.0};
        var label = {visible: true, text: "100%"};
        var nativeText = "100%";
        var callbacks:Array<Float->Void> = [(_:Float) -> { if (label.visible) label.text = nativeText; }];
        var bar:Dynamic = {parent: {parent: {types: ["ui.hud.BossInfo"]}}, txt: label, healthGauge: gauge, callbacks: callbacks};
        BossHealth.enabled = false;
        BossHealth.attach(bar);
        eq(callbacks.length, 2, "registers on an existing boss bar while disabled");
        eq(label.text, "100%", "disabled option keeps native label");
        BossHealth.enabled = true;
        for (callback in callbacks) callback(0.016);
        eq(label.text, "123,456 (100%)", "enabling takes effect on the next UI update");
        gauge.value = 61728.9; nativeText = "50% (+ 20%)";
        for (callback in callbacks) callback(0.016);
        eq(label.text, "61,728 (50%) (+ 20%)", "damage and shields update live");
        for (callback in callbacks) callback(0.016);
        eq(label.text, "61,728 (50%) (+ 20%)", "consecutive frames never accumulate HP prefixes");
        BossHealth.enabled = false;
        for (callback in callbacks) callback(0.016);
        eq(label.text, "50% (+ 20%)", "disabling restores native text without reopening HUD");
        BossHealth.enabled = true; label.visible = false; gauge.value = 50000;
        for (callback in callbacks) callback(0.016);
        eq(label.text, "50% (+ 20%)", "hidden labels are left untouched");
        label.visible = true; gauge.usePercents = false; nativeText = "50000 / 123456";
        for (callback in callbacks) callback(0.016);
        eq(label.text, nativeText, "numeric bars remain native");
        for (parent in [null, {types: ["ui.hud.UnitWidget"]}, {types: ["ui.hud.HeroInfo"]}]) {
            var other:Dynamic = {parent: parent, callbacks: []};
            BossHealth.attach(other);
            eq(other.callbacks.length, 0, "only boss HUD bars get a callback");
        }
        BossHealth.enabled = false;
    }

    static function hideUiBinding():Void {
        var config = SettingsData.defaults();
        eq(config.hideUiKey, 113, "new and migrated configs default to F2");
        for (invalid in [-1, 27, 512, 999]) {
            config.hideUiKey = invalid; SettingsData.normalize(config);
            eq(config.hideUiKey, 113, "invalid or reserved shortcut falls back to F2");
        }
        for (valid in [0, 65, 113, 123, 511]) {
            config.hideUiKey = valid; SettingsData.normalize(config);
            eq(config.hideUiKey, valid, "valid shortcut survives normalization");
        }
        var binding = new HideUiBinding();
        var original:Dynamic = {code: 113, mode: null, modifier: null, padCode: null};
        var pad:Dynamic = {code: null, mode: 2, modifier: 1, padCode: {button: 12}};
        var disabled:Dynamic = {code: null, mode: null, modifier: null, padCode: null};
        var native:Dynamic = {length: 3, items: [original, pad, disabled]};
        G.inputArrayCalls = 0;
        eq(binding.bindings("Interact", native), native, "other actions keep native array");
        eq(G.inputArrayCalls, 0, "other actions do no array lookups or writes");
        eq(binding.bindings("ToggleUITrailer", native), native, "trailer action unaffected");
        eq(binding.bindings("ToggleUI", null), null, "missing binding fails safely");
        binding.bindings("ToggleUI", native);
        eq(native.items[0].code, 113, "default binding is native F2");
        binding.configure(123);
        native.items[0] = original; binding.bindings("ToggleUI", native);
        eq(native.items[0].code, 123, "new shortcut replaces F2 in native checks");
        eq(original.code, 113, "native default and saved binding objects never mutated");
        eq(native.items[1], pad, "gamepad binding identity preserved");
        eq(native.items[2], disabled, "disabled binding stays disabled");
        var replacement = native.items[0];
        for (_ in 0...1000) {
            native.items[0] = original;
            binding.bindings("ToggleUI", native);
        }
        eq(native.items[0], replacement, "stable frames reuse the replacement record");
        binding.configure(123); native.items[0] = original; binding.bindings("ToggleUI", native);
        eq(native.items[0], replacement, "unrelated config changes keep cached binding");
        binding.configure(0); native.items[0] = original; binding.bindings("ToggleUI", native);
        eq(native.items[0].code, null, "unassigned shortcut removes keyboard activation");
        eq(native.items[1], pad, "unassigning keyboard preserves gamepad");
        binding.configure(113);
        var user:Dynamic = {code: 120, mode: 3, modifier: 1, padCode: null};
        native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0].code, 113, "returning to F2 replaces saved game override");
        eq(native.items[0].mode, 3, "native input-mode restriction preserved");
        eq(native.items[0].modifier, null, "single-key preference has no old modifier requirement");
        eq(user.code, 120, "saved game code unchanged");
        eq(user.modifier, 1, "saved game modifier unchanged");
        config.hideUiKey = haxe.Json.parse('{"code":113,"modifier":0}');
        SettingsData.normalize(config);
        binding.configure(config.hideUiKey);
        native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0].code, 113, "modified UI binding retains main key");
        eq(native.items[0].modifier, 0, "native UI action receives Ctrl modifier");
        eq(native.items[0].mode, 3, "modified UI binding retains native mode");
        var modified = native.items[0];
        binding.configure({code:113,modifier:0});
        native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0], modified, "equivalent reloaded combination reuses cache");
        binding.configure({code:113,modifier:1});
        native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0].modifier, 1, "modifier-only edits invalidate binding cache");
        binding.configure({code:0,modifier:2});
        native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0].code, 0, "modified left click is not disabled as unbound");
        eq(native.items[0].modifier, 2, "modified left click reaches native input");
        user.mode = 4; native.items[0] = user; binding.bindings("ToggleUI", native);
        eq(native.items[0].mode, 4, "changed input-mode restriction is honored");
        G.data = {current: {textInput: {allocated: true}}};
        eq(binding.pressed("ToggleUI", true), false, "typing never hides the UI");
        eq(binding.pressed("ToggleUI", false), false, "blocked native input stays blocked");
        eq(binding.pressed("Interact", true), true, "typing guard affects only Hide UI");
        G.data = {current: {textInput: null}};
        eq(binding.pressed("ToggleUI", true), true, "native press toggles UI when not typing");
        G.data = null;
    }

    static function policy():Void {
        var c = SettingsData.defaults();
        for (region in ["rift", "dungeon", "overworld", ""]) {
            var f = EffectPolicy.filters(c, region);
            eq(f.attacks || f.buffs || f.models, false, "visibility defaults off");
        }
        c.riftHideAllyAttacks = true; c.dungeonHideAllyBuffs = true; c.overworldHideAllies = true;
        eq(EffectPolicy.region(true, true, true), "rift", "rift takes precedence over dungeon");
        eq(EffectPolicy.region(false, true, true), "dungeon", "dungeon takes precedence over world map");
        eq(EffectPolicy.region(false, false, false), "", "unknown locations fail visible");
        for (own in [false, true]) for (ally in [false, true]) for (benefit in [false, true]) {
            eq(EffectPolicy.hideEffect(own, ally, benefit, EffectPolicy.filters(c, "rift")),
                !own && ally && !benefit, "rift attack filter excludes self, enemies and buffs");
            eq(EffectPolicy.hideEffect(own, ally, benefit, EffectPolicy.filters(c, "dungeon")),
                !own && ally && benefit, "dungeon buff filter excludes self, enemies and attacks");
            eq(EffectPolicy.hideEffect(own, ally, benefit, EffectPolicy.filters(c, "overworld")), false,
                "model-only setting leaves every ability visible");
        }
    }

    static function classification():Void {
        var damage = facts(true, false, false, []);
        var heal = facts(false, true, false, []);
        var debuff = facts(false, false, true, []);
        var graph = ["damage" => damage, "heal" => heal, "debuff" => debuff];
        eq(SkillClassifier.beneficial(damage, graph.get), false, "pure damage is an attack");
        eq(SkillClassifier.beneficial(debuff, graph.get), false, "harmful status is an attack");
        eq(SkillClassifier.beneficial(facts(true, false, false, ["heal"]), graph.get), true, "mixed damage and healing is beneficial");
        graph["a"] = facts(false, false, false, ["b"]); graph["b"] = facts(false, false, false, ["a", "damage"]);
        eq(SkillClassifier.beneficial(graph["a"], graph.get), false, "cyclic subskills terminate and retain damage");
        eq(SkillClassifier.beneficial(facts(false, false, false, ["missing"]), graph.get), true, "unknown utility stays out of attack filter");
        G.data = {skill: {byId: {regen: {id: "regen", props: {status: {types: [{type: "Regeneration"}]}}}}},
            statusType: {byId: {Regeneration: {flags: 8, parent: "Buff"}, Buff: {flags: 0}}}};
        NativeSkillFacts.clear();
        eq(NativeSkillFacts.beneficial({inf: {id: "mixed", props: {}, steps: [{effects: [{effect: 0}, {effect: 4, status: "regen"}]}]}}), true,
            "native-style referenced status inheritance classifies mixed skill as buff");
        eq(NativeSkillFacts.beneficial({inf: {id: "damage", props: {}, steps: [{effects: [{effect: 0}]}]}}), false,
            "native-style damage data");
    }
    static function facts(damage:Bool, benefit:Bool, debuff:Bool, refs:Array<String>):SkillFacts
        return {damage: damage, beneficial: benefit, offensiveStatus: debuff, references: refs};

    static function presentation():Void {
        var c = SettingsData.defaults(); c.riftHideAllyAttacks = true; c.riftHideAllies = true;
        var layer:Dynamic = {isRift: true, config: {mapId: "World/Test"}, units: [], areas: [], entities: []};
        var self = player(layer, true); var friend = player(layer, false); var enemy = player(layer, false); enemy.enemy = true;
        layer.units = [self, friend, enemy];
        AllyEffects.dispose(); AllyEffects.configure(c); AllyEffects.update({hero: self});
        var damage:Dynamic = {props: {}, steps: [{effects: [{effect: 0}]}]};
        var heal:Dynamic = {props: {}, steps: [{effects: [{effect: 1}]}]};
        var allyAttack:Dynamic = {owner: friend, inf: damage};
        var allyBuff:Dynamic = {owner: friend, inf: heal};
        checkFx(allyAttack, true, "ally attack hidden in rift");
        checkFx(allyBuff, false, "ally buff visible with attack-only filter");
        checkFx({owner: self, inf: damage}, false, "own attack always visible");
        checkFx({owner: enemy, inf: damage}, false, "PvP enemy attack visible");
        checkFx({owner: {types: ["ent.Foe"]}, inf: damage}, false, "monster attack visible");
        checkFx({owner: {summonOwner: self}, inf: damage}, false, "own summon attack visible");
        checkFx({owner: {summonOwner: friend}, sourceSkill: allyAttack, inf: damage}, true, "ally summon source preserved");
        checkFx({owner: friend, instigator: self, inf: heal}, false, "own buff on another player stays visible");
        c.riftHideAllyBuffs = true; AllyEffects.configure(c);
        checkFx({owner: self, instigator: friend, sourceSkill: allyBuff, inf: heal}, true, "ally buff on local recipient tracks caster");
        checkFx({owner: friend, instigator: self, inf: heal}, false, "buff hiding still protects own buffs");

        eq(AllyEffects.hideMesh(friend.unitView.children[0]), true, "ally model hidden");
        eq(AllyEffects.hideMesh(self.unitView.children[0]), false, "local model visible");
        eq(AllyEffects.hideMesh(enemy.unitView.children[0]), false, "enemy model visible");
        eq(AllyEffects.hideMesh(friend.unitView.children[1].children[0]), false, "attached ability mesh independent from model");

        var fx:Dynamic = {flags: 2, subFXs: [], effects: []};
        AllyEffects.pushSkill(allyAttack); AllyEffects.bindCreated(fx); AllyEffects.pop();
        var node:Dynamic = {types: ["shiro.audio.SoundObject3D"], fx: fx, active: true};
        var sound:Dynamic = {follow: node, entity: self, inst: {}, playing: true};
        AllyEffects.updateSound(sound); eq(sound.playing, false, "mid-flight ally sound stops despite local recipient");
        eq(node.active, false, "native sound node can restart when made visible");
        AllyEffects.updateSound(sound); eq(sound.stops, 1, "stopped sounds are not repeatedly stopped");
        eq(AllyEffects.beforeSound(sound), true, "hidden effect does not start audio");

        friend.anim = {currentDef: {skillSource: allyAttack}};
        AllyEffects.pushSoundEntity(friend);
        eq(AllyEffects.beforeSound({}), true, "entity SFX is suppressed before native source assignment");
        AllyEffects.pop();
        AllyEffects.pushSkill({owner: self, inf: heal}); AllyEffects.pushSoundEntity(friend);
        eq(AllyEffects.beforeSound({}), false, "local skill scope protects sound played through another entity");
        AllyEffects.pop(); AllyEffects.pop();

        var ownSound:Dynamic = {entity: self, inst: {}, playing: true};
        eq(AllyEffects.beforeSound(ownSound), false, "local audio always starts");
        AllyEffects.updateSound(ownSound); eq(ownSound.playing, true, "local audio never stopped");

        var screenEffect:Dynamic = {enabled: true};
        var alreadyOff:Dynamic = {enabled: false};
        var screenFx:Dynamic = {flags: 2, effects: [{instance: screenEffect}, {instance: alreadyOff}], subFXs: []};
        AllyEffects.pushSkill(allyAttack); AllyEffects.bindCreated(screenFx); AllyEffects.pop();
        AllyEffects.beforeRenderer(); eq(screenEffect.enabled, false, "hidden ability fullscreen effect suppressed");
        AllyEffects.beforeRenderer(); // More than one render pass must retain the original state.
        AllyEffects.afterRender(); eq(screenEffect.enabled, true, "fullscreen effect state restored after render");
        eq(alreadyOff.enabled, false, "natively disabled fullscreen effect stays disabled");
        AllyEffects.forget(screenFx);

        var parent:Dynamic = {flags: 2, effects: [], subFXs: []};
        var child:Dynamic = {flags: 2, effects: [], subFXs: [], parentFX: parent};
        AllyEffects.pushSkill(allyAttack); AllyEffects.bindCreated(parent); AllyEffects.pop();
        var nestedCtx:Dynamic = {visibleFlag: true};
        AllyEffects.beforeFxSync(parent, nestedCtx); AllyEffects.beforeFxSync(child, nestedCtx);
        AllyEffects.afterFxSync(child); eq(nestedCtx.visibleFlag, false, "child sync retains parent suppression");
        AllyEffects.afterFxSync(parent); eq(nestedCtx.visibleFlag, true, "parent sync restores outer context");
        eq(parent.flags & 2, 0, "parent still culled during draw"); eq(child.flags & 2, 0, "detached sub-FX retains original caster");
        AllyEffects.afterRender(); eq(parent.flags & 2, 2, "parent restored after draw"); eq(child.flags & 2, 2, "child restored after draw");
        var detached:Dynamic = {flags: 2, effects: [], subFXs: [], parentFX: {parentFX: parent}};
        AllyEffects.beforeDetach(detached); detached.parentFX = null;
        checkExistingFx(detached, true, "sub-FX detached before first sync keeps caster");
        AllyEffects.forget(parent); AllyEffects.forget(child); AllyEffects.forget(detached);

        // Same layer may acquire its main activity after creation.
        layer.isRift = false; layer.mainActivity = {types: ["st.activity.Dungeon"]};
        AllyEffects.update({hero: self}); checkFx(allyAttack, false, "dungeon settings do not inherit rift filters");
        eq(AllyEffects.hideMesh(friend.unitView.children[0]), false, "location change restores model");
        c.dungeonHideAllyAttacks = true; AllyEffects.configure(c);
        checkExistingFx(fx, true, "existing effect responds to new region toggle");
        AllyEffects.pushSkill({owner: self, inf: damage}); AllyEffects.bindCreated(fx); AllyEffects.pop();
        checkExistingFx(fx, false, "pool reuse never hides new local caster");
        AllyEffects.dispose(); checkExistingFx(fx, false, "scene disposal clears visibility state");
    }
    static function player(layer:Dynamic, own:Bool):Dynamic return {
        types: ["ent.Hero"], layer: layer, ownerPlayer: {isMe: own}, player: {},
        skills: [], statuses: {array: []}, unitView: {children: [
            {types: ["h3d.scene.Skin", "h3d.scene.Mesh"], children: []},
            {types: ["hrt.prefab.fx.FXAnimation"], children: [{types: ["h3d.scene.Mesh"], children: []}]}
        ]}
    };
    static function checkFx(skill:Dynamic, hidden:Bool, message:String):Void {
        var fx:Dynamic = {flags: 2, subFXs: [], effects: []};
        AllyEffects.pushSkill(skill); AllyEffects.bindCreated(fx); AllyEffects.pop();
        checkExistingFx(fx, hidden, message); AllyEffects.forget(fx);
    }
    static function checkExistingFx(fx:Dynamic, hidden:Bool, message:String):Void {
        var ctx:Dynamic = {visibleFlag: true};
        AllyEffects.beforeFxSync(fx, ctx);
        eq(ctx.visibleFlag, !hidden, message);
        if (hidden) {
            eq(fx.flags & 2, 0, "camera shake sees invisible flag");
            eq(fx.flags & (64 | 32768), 64 | 32768, "hidden effect retains native clock/sync updates");
        }
        // Native changes to other flags must survive our restoration.
        fx.flags |= 4096; AllyEffects.afterFxSync(fx);
        eq(ctx.visibleFlag, true, "sibling render context restored");
        eq(fx.flags, (hidden ? 0 : 2) | 4096, "FX remains hidden through native emission and drawing");
        AllyEffects.afterRender();
        eq(fx.flags, 2 | 4096, "render end restores visibility and preserves native flag changes");
    }
}
