import moresettings.SettingsData;
import moresettings.VolumeState;
import moresettings.AudioControl;
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
    static function close(actual:Float, expected:Float, message:String):Void
        eq(Math.abs(actual - expected) < 0.000001, true, message);

    static function main():Void {
        volume(); policy(); classification(); presentation();
        Sys.println('More Settings: $checks checks passed.');
    }

    static function volume():Void {
        var config = SettingsData.defaults();
        config.backgroundVolume = 20; config.adjustFastTravelVolume = true; config.fastTravelVolume = 40;
        for (travelFirst in [false, true]) {
            var state = new VolumeState();
            close(state.apply(0.8, travelFirst ? 0.4 : 0.2), travelFirst ? 0.4 : 0.2, "first limit");
            close(state.apply(0.2, VolumeState.target(config, false, true)), 0.2, "overlap uses quieter limit");
            close(state.apply(0.2, travelFirst ? 0.2 : 0.4), travelFirst ? 0.2 : 0.4, "one condition ends");
            close(state.apply(0.2, null), 0.8, "overlap restores original only at end");
        }
        var state = new VolumeState();
        close(state.apply(0.1, 0.4), 0.1, "temporary control never boosts master");
        state.masterChanged(0.6);
        close(state.apply(0.6, 0.4), 0.4, "master change while temporarily limited");
        close(state.apply(0.4, null), 0.6, "restore updated master");
        config.backgroundVolume = Math.NaN; config.fastTravelVolume = 150;
        SettingsData.normalize(config);
        close(config.backgroundVolume, 0, "invalid percent"); close(config.fastTravelVolume, 100, "clamped percent");

        config.backgroundVolume = 20; config.fastTravelVolume = 40;
        G.master = 0.8; G.focused = true; G.writes = 0;
        var audio = new AudioControl(config);
        var hero:Dynamic = {flying: false};
        audio.update(hero); eq(G.writes, 0, "focused idle does not write FMOD");
        audio.startTravel(); close(G.master, 0.4, "departure sound is limited immediately");
        hero.flying = true; G.focused = false; audio.update(hero); close(G.master, 0.2, "travel plus unfocus");
        var writes = G.writes;
        for (_ in 0...1000) audio.update(hero);
        eq(G.writes, writes, "unchanged frames never write FMOD");
        hero.flying = false; audio.update(hero); close(G.master, 0.2, "landing while unfocused stays quiet");
        G.master = 0.7; audio.masterChanged(); close(G.master, 0.2, "options apply preserves temporary limit");
        G.focused = true; audio.update(hero); close(G.master, 0.7, "focus restores new master");
        audio.startTravel(); config.adjustFastTravelVolume = false; audio.configure(config);
        close(G.master, 0.7, "disabling travel limit restores volume immediately");
        G.focused = false; audio.update(hero); audio.dispose(); close(G.master, 0.7, "dispose restores volume");
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
