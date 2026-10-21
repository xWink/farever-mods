import moresettings.AllyEffects;
import moresettings.GameAccess as G;
import moresettings.SettingsData;

class EffectDiscoveryTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ": expected " + expected + ", got " + actual;
    }
    static function fx():Dynamic return {flags:2, effects:[], subFXs:[], removed:false};
    static function player(layer:Dynamic, own:Bool):Dynamic return {
        types:["ent.Hero"], layer:layer, ownerPlayer:{isMe:own}, player:{},
        skills:[], statuses:{array:[]}, unitView:{children:[]}, removed:false
    };
    static function skill(owner:Dynamic, effects:Array<Dynamic>, beneficial = false):Dynamic return {
        owner:owner, inf:{props:{}, steps:[{effects:[{effect:beneficial ? 1 : 0}]}]},
        steps:[{fxs:effects, otherFxs:[], linkFxs:[]}], removed:false
    };
    static function drain(app:Dynamic):Void {
        var frames = 0;
        while ((@:privateAccess AllyEffects.discovery != null) || (@:privateAccess AllyEffects.modelDiscovery != null)) {
            if (++frames > 2000) throw "discovery did not finish";
            AllyEffects.update(app);
        }
    }
    static function sweep(app:Dynamic):Void {
        @:privateAccess AllyEffects.nextRefresh = 0;
        @:privateAccess AllyEffects.nextAdoption = 0;
        AllyEffects.update(app); drain(app);
    }
    static function hidden(effect:Dynamic):Bool {
        var ctx:Dynamic = {visibleFlag:true};
        AllyEffects.beforeFxSync(effect, ctx);
        var result = !ctx.visibleFlag;
        AllyEffects.afterFxSync(effect); AllyEffects.afterRender();
        return result;
    }
    static function bind(source:Dynamic, effect:Dynamic):Void {
        AllyEffects.pushSkill(source); AllyEffects.bindCreated(effect); AllyEffects.pop();
    }

    static function lazyArrays():Void {
        var array:Dynamic = {length:3, items:["a", "b", "c"]};
        G.discoveryReads = 0;
        var reader = G.iterate(array);
        eq(G.discoveryReads, 0, "constructing a reader does not copy the array");
        eq(reader.next(), "a", "reader preserves element identity/order");
        array.items.resize(1); array.length = 1;
        eq(reader.hasNext(), false, "array shrinking between frames never reads out of bounds");
        var growing:Dynamic = {length:1, items:["a"]};
        reader = G.iterate(growing);
        growing.items.push("b"); growing.length = 2;
        eq(reader.next(), "a", "initial entry remains available");
        eq(reader.hasNext(), false, "appends wait for the next bounded sweep");
        eq(G.iterate(null).hasNext(), false, "missing arrays are empty");
        eq(G.iterate({array:growing}, true).next(), "a", "array proxies use their backing array");
    }

    static function discoveryAndReuse():Void {
        var config = SettingsData.defaults(); config.riftHideOwnAttacks = true; config.riftHideOwnBuffs = true;
        var layer:Dynamic = {isRift:true, config:{mapId:"World/Test"}, units:[], areas:[], entities:[]};
        var self = player(layer, true), friend = player(layer, false);
        var effects = [for (_ in 0...1000) fx()];
        var attack = skill(self, effects);
        self.skills = [attack]; layer.units = [self, friend];
        var app:Dynamic = {hero:self};
        AllyEffects.dispose(); AllyEffects.configure(config);
        G.discoveryReads = 0;
        AllyEffects.update(app);
        eq(G.discoveryReads > 0 && G.discoveryReads <= 96, true, "a large effect list is visited incrementally");
        eq(@:privateAccess AllyEffects.discovery != null, true, "large discovery yields to the next frame");
        var last = effects[999];
        bind(skill(friend, []), last);
        var created = fx(); bind(attack, created);
        eq(hidden(created), true, "creation hooks filter immediately during a pending sweep");
        drain(app);
        eq(hidden(effects[0]), true, "already-running own effect adopted");
        eq(hidden(effects[998]), true, "end of large array eventually adopted");
        eq(hidden(last), false, "old sweep cannot overwrite a newly bound pooled caster");

        // Effects missed by creation hooks still get a reconciliation pass,
        // including statuses on recipients and projectile/area FX.
        var buffFx = fx(), areaFx = fx(), projectileFx = fx(), linkFx = fx(), projectileLinkFx = fx();
        friend.statuses.array.push(skill(self, [buffFx], true));
        layer.areas.push({baseSkill:attack, telegraphFx:areaFx, fxs:[]});
        layer.entities.push({types:["ent.Projectile"], baseSkill:attack, projFX:projectileFx,
            fxs:[], linkFxs:[{fx:projectileLinkFx}]});
        attack.steps[0].linkFxs.push({fx:linkFx});
        sweep(app);
        eq(hidden(buffFx), true, "buff on a different recipient retains its caster");
        eq(hidden(projectileLinkFx), true, "projectile-owned link effects retain their caster after the game update");
        eq(hidden(areaFx), true, "pre-existing area is adopted");
        eq(hidden(projectileFx), true, "pre-existing projectile is adopted");
        eq(hidden(linkFx), true, "linked skill effect is adopted");

        // Turning a filter off invalidates pending work and restores visibility.
        @:privateAccess AllyEffects.nextRefresh = 0;
        @:privateAccess AllyEffects.nextAdoption = 0;
        AllyEffects.update(app);
        config.riftHideOwnAttacks = false; config.riftHideOwnBuffs = false;
        AllyEffects.configure(config);
        eq(@:privateAccess AllyEffects.discovery == null, true, "config changes cancel an unfinished sweep");
        eq(hidden(created), false, "disabling restores existing effects");
        config.riftHideOwnAttacks = true; AllyEffects.configure(config);
        AllyEffects.update(app);
        var nextLayer:Dynamic = {isRift:false, config:{mapId:"World/New"}, units:[], areas:[], entities:[]};
        self.layer = nextLayer; AllyEffects.update(app);
        eq(@:privateAccess AllyEffects.discovery == null, true, "scene changes discard old array readers");
        eq(hidden(effects[0]), false, "old scene's pending work cannot reintroduce hidden effects");
        AllyEffects.dispose();
    }

    static function incrementalModels():Void {
        var config = SettingsData.defaults(); config.riftHideAllies = true;
        var layer:Dynamic = {isRift:true, config:{mapId:"World/Test"}, units:[], areas:[], entities:[]};
        var self = player(layer, true), friend = player(layer, false);
        var meshes:Array<Dynamic> = [for (_ in 0...1000) {types:["h3d.scene.Mesh"], children:[]}];
        var abilityMesh:Dynamic = {types:["h3d.scene.Mesh"], children:[]};
        friend.unitView.children = meshes.copy();
        friend.unitView.children.push({types:["hrt.prefab.fx.FXAnimation"], children:[abilityMesh]});
        layer.units = [self, friend]; var app:Dynamic = {hero:self};
        AllyEffects.dispose(); AllyEffects.configure(config);
        G.discoveryReads = 0; AllyEffects.update(app);
        eq(G.discoveryReads <= 96, true, "large model trees are also incremental");
        drain(app);
        eq(AllyEffects.hideMesh(meshes[999]), true, "entire allied model eventually hidden");
        eq(AllyEffects.hideMesh(abilityMesh), false, "attached ability meshes stay independent");
        @:privateAccess AllyEffects.nextRefresh = 0;
        AllyEffects.update(app);
        eq(AllyEffects.hideMesh(meshes[999]), true, "refresh never flashes previously hidden meshes");
        drain(app);
        friend.enemy = true; sweep(app);
        eq(AllyEffects.hideMesh(meshes[999]), false, "PvP ownership changes restore model visibility");
        friend.enemy = false; sweep(app);
        friend.unitView.children = []; sweep(app);
        eq(AllyEffects.hideMesh(meshes[0]), false, "removed model meshes are released after reconciliation");
        AllyEffects.dispose();
    }

    static function rendererCleanup():Void {
        var config = SettingsData.defaults(); config.riftHideOwnAttacks = true;
        var layer:Dynamic = {isRift:true, config:{mapId:"World/Test"}, units:[], areas:[], entities:[]};
        var self = player(layer, true), friend = player(layer, false);
        AllyEffects.dispose(); AllyEffects.configure(config); AllyEffects.update({hero:self});
        var own = skill(self, []), allied = skill(friend, []);
        var effects:Array<Dynamic> = [], renderers:Array<Dynamic> = [];
        for (_ in 0...300) {
            var renderer:Dynamic = {enabled:true};
            var effect = fx(); effect.effects = [{instance:renderer}];
            effects.push(effect); renderers.push(renderer); bind(own, effect);
        }
        AllyEffects.beforeRenderer();
        AllyEffects.forget(effects[0]);
        eq(renderers[0].enabled, true, "removing a hidden effect restores its renderer");
        eq(renderers[299].enabled, false, "removal leaves unrelated renderer suppression intact");
        AllyEffects.afterRender();
        eq(renderers[299].enabled, true, "remaining renderer state still restores normally");

        // Retagging an existing effect must update fullscreen filtering too.
        AllyEffects.bindSkill(allied, effects[1]);
        AllyEffects.beforeRenderer();
        eq(renderers[1].enabled, true, "renderer uses current effect attribution");
        AllyEffects.afterRender();
        var reused = fx(); reused.effects = [{instance:renderers[2]}]; bind(own, reused);
        AllyEffects.forget(effects[2]); AllyEffects.beforeRenderer();
        eq(renderers[2].enabled, false, "old FX cleanup cannot remove reassigned renderer entries");
        AllyEffects.forget(reused);
        eq(renderers[2].enabled, true, "new renderer owner still cleans up correctly");
        AllyEffects.dispose();
        eq(renderers[299].enabled, true, "scene disposal restores pending renderer state");
    }

    static function independentModelRefresh():Void {
        var config = SettingsData.defaults(); config.riftHideOwnAttacks = true; config.riftHideAllies = true;
        var layer:Dynamic = {isRift:true, config:{mapId:"World/Test"}, units:[], areas:[], entities:[]};
        var self = player(layer, true), friend = player(layer, false);
        var mesh:Dynamic = {types:["h3d.scene.Mesh"], children:[]};
        friend.unitView.children = [mesh];
        self.skills = [skill(self, [for (_ in 0...1000) fx()])];
        layer.units = [self, friend]; var app:Dynamic = {hero:self};
        AllyEffects.dispose(); AllyEffects.configure(config); AllyEffects.update(app);
        var frames = 0;
        while (@:privateAccess AllyEffects.modelDiscovery != null) {
            if (++frames > 100) throw "model pass did not finish";
            AllyEffects.update(app);
        }
        eq(@:privateAccess AllyEffects.discovery != null, true, "large FX pass remains pending");
        eq(AllyEffects.hideMesh(mesh), true, "model discovery finishes independently of FX discovery");
        friend.enemy = true;
        @:privateAccess AllyEffects.nextRefresh = 0;
        AllyEffects.update(app);
        while (@:privateAccess AllyEffects.modelDiscovery != null) {
            if (++frames > 200) throw "model refresh did not finish";
            AllyEffects.update(app);
        }
        eq(@:privateAccess AllyEffects.discovery != null, true, "model refresh does not require finishing FX pass");
        eq(AllyEffects.hideMesh(mesh), false, "new PvP opponent becomes visible while FX pass is pending");
        AllyEffects.dispose();
    }

    static function main():Void {
        lazyArrays(); discoveryAndReuse(); incrementalModels(); rendererCleanup(); independentModelRefresh();
        Sys.println('Incremental VFX discovery: $checks checks passed.');
    }
}
