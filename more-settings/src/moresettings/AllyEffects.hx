package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;
import moresettings.EffectPolicy.RegionFilters;

private typedef EffectOrigin = { var source:Dynamic; var beneficial:Bool; var ?aiming:Bool; }
private typedef SyncFrame = { var fx:Dynamic; var ctx:Dynamic; var visible:Bool; var flags:Int; }
private enum abstract DiscoveryKind(Int) {
    var Unit; var Skill; var Step; var Fx; var LinkFx; var Entity; var Projectile;
    var ModelUnit; var Mesh; var ExpiredFx; var EndedSound;
}
private typedef DiscoveryWork = {var kind:DiscoveryKind; var items:Iterator<Dynamic>; var origin:EffectOrigin;}

/** Only presentation objects are filtered; skills, hits and RPCs still run. */
class AllyEffects {
    static var config:MoreSettingsConfig;
    static var hero:Dynamic;
    static var layer:Dynamic;
    static var region:String = "";
    static var filters:RegionFilters = {attacks: false, buffs: false, models: false, ownAttacks: false, ownBuffs: false};
    static var origins:ObjectMap<Dynamic, EffectOrigin> = new ObjectMap();
    static var soundOrigins:ObjectMap<Dynamic, EffectOrigin> = new ObjectMap();
    static var friends:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var rendererOrigins:ObjectMap<Dynamic, Dynamic> = new ObjectMap();
    static var renderersByFx:ObjectMap<Dynamic, Array<Dynamic>> = new ObjectMap();
    static var visibilityRestore:ObjectMap<Dynamic, Int> = new ObjectMap();
    static var rendererRestore:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var hiddenMeshes:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var scopes = new sys.thread.Tls<Array<EffectOrigin>>();
    static var aimingDepth = new sys.thread.Tls<Null<Int>>();
    static var aimingOrigin:EffectOrigin = {source:null, beneficial:false, aiming:true};
    static var syncFrames = new sys.thread.Tls<Array<SyncFrame>>();
    static var nextRefresh:Float = 0;
    static var nextAdoption:Float = 0;
    static var discovery:Array<DiscoveryWork>;
    static var modelDiscovery:Array<DiscoveryWork>;
    static var discoveryMeshes:ObjectMap<Dynamic, Bool>;
    static var discoveredSkills:ObjectMap<Dynamic, Bool>;
    static inline var DISCOVERY_BUDGET = 96;
    static inline var ADOPTION_INTERVAL = 1.0;
    static var reported:Bool = false;
    public static var active(default, null):Bool = false;

    public static function configure(value:MoreSettingsConfig):Void {
        config = value;
        filters = EffectPolicy.filters(config, region);
        active = EffectPolicy.effectsActive(filters);
        if (!filters.models) hiddenMeshes = new ObjectMap();
        restartDiscovery();
    }

    public static function update(app:Dynamic):Void {
        if (config == null) return;
        try {
            if (syncFrames.value != null) while (syncFrames.value.length > 0) restoreFrame(syncFrames.value.pop());
            afterRender();
            if (active || filters.models) friends = new ObjectMap();
            var nextHero = G.field(app, "hero");
            var nextLayer = G.field(nextHero, "layer");
            if (nextHero != hero || nextLayer != layer) {
                dispose(); hero = nextHero; layer = nextLayer;
            }
            var nextRegion = findRegion(layer);
            if (nextRegion != region) {
                region = nextRegion;
                filters = EffectPolicy.filters(config, region);
                active = EffectPolicy.effectsActive(filters);
                hiddenMeshes = new ObjectMap(); restartDiscovery();
            }
            // Recover an abandoned presentation scope if the game threw while
            // creating an effect. Scope storage is per-thread for visual jobs.
            if (scopes.value != null && scopes.value.length > 0) scopes.value = [];
            aimingDepth.value = 0;
            var now = haxe.Timer.stamp();
            if (hero == null || (!active && !filters.models)) return;
            if (active && discovery == null && now >= nextAdoption) beginDiscovery(now);
            if (filters.models && modelDiscovery == null && now >= nextRefresh) {
                nextRefresh = now + 0.2;
                modelDiscovery = [];
                discoveryMeshes = new ObjectMap();
                enqueue(ModelUnit, G.iterate(G.field(layer, "units")));
            }
            var deadline = haxe.Timer.stamp() + 0.001;
            var both = discovery != null && modelDiscovery != null;
            var budget = both ? DISCOVERY_BUDGET >> 1 : DISCOVERY_BUDGET;
            // Model refreshes retain their own cadence even during a long FX sweep.
            if (modelDiscovery != null) advanceDiscovery(true, budget, both ? deadline - 0.0005 : deadline);
            if (discovery != null) advanceDiscovery(false, budget, deadline);
        } catch (e:Dynamic) fail(e);
    }

    static function restartDiscovery():Void {
        discovery = null; modelDiscovery = null; discoveryMeshes = null; discoveredSkills = null;
        nextRefresh = 0; nextAdoption = 0;
    }

    static function enqueue(kind:DiscoveryKind, items:Iterator<Dynamic>, ?value:EffectOrigin):Void {
        var pending = kind == ModelUnit || kind == Mesh ? modelDiscovery : discovery;
        pending.push({kind:kind, items:items, origin:value});
    }

    static function beginDiscovery(now:Float):Void {
        discovery = [];
        discoveredSkills = new ObjectMap();
        nextAdoption = now + ADOPTION_INTERVAL;
        enqueue(EndedSound, soundOrigins.keys());
        enqueue(ExpiredFx, origins.keys());
        enqueue(Projectile, G.iterate(G.field(layer, "entities")));
        enqueue(Entity, G.iterate(G.field(layer, "areas")));
        enqueue(Unit, G.iterate(G.field(layer, "units")));
    }

    static function advanceDiscovery(models:Bool, budget:Int, deadline:Float):Void {
        // Creation/bind/detach hooks handle new effects immediately. This slower
        // reconciliation finds already-running effects, including buffs applied
        // to someone other than their caster. Lazy readers avoid scene snapshots.
        // Bound both entries and elapsed work; large arrays/mesh trees resume on
        // the next frame instead of being walked in one periodic burst.
        var pending = models ? modelDiscovery : discovery;
        for (_ in 0...budget) {
            if (pending.length == 0) {
                if (models) {
                    hiddenMeshes = discoveryMeshes;
                    modelDiscovery = null; discoveryMeshes = null;
                } else {
                    discovery = null; discoveredSkills = null;
                }
                return;
            }
            var work = pending[pending.length - 1];
            if (work.items.hasNext()) discover(work.kind, work.items.next(), work.origin);
            else pending.pop();
            if (haxe.Timer.stamp() >= deadline) return;
        }
    }

    static function discover(kind:DiscoveryKind, item:Dynamic, value:EffectOrigin):Void {
        if (item == null) return;
        switch kind {
            case Unit:
                if (G.field(item, "removed") == true) return;
                if (own(playerSource(item)) || ally(item)) enqueue(Skill, G.iterate(G.field(item, "skills")));
                enqueue(Skill, G.iterate(G.field(item, "statuses"), true));
                var animFx = G.field(item, "crtAnimFx");
                if (animFx != null && !origins.exists(animFx)) bindEntity(item, animFx);
            case Skill:
                if (G.field(item, "removed") == true || discoveredSkills.exists(item)) return;
                discoveredSkills.set(item, true);
                var source = origin(item);
                if (source != null) enqueue(Step, G.iterate(G.field(item, "steps")), source);
            case Step:
                enqueue(Fx, G.iterate(G.field(item, "fxs")), value);
                enqueue(Fx, G.iterate(G.field(item, "otherFxs")), value);
                enqueue(LinkFx, G.iterate(G.field(item, "linkFxs")), value);
            case Fx: adoptFx(item, value);
            case LinkFx: adoptFx(G.field(item, "fx"), value);
            case Projectile:
                if (isA(item, "ent.Projectile")) discover(Entity, item, null);
            case Entity:
                if (G.field(item, "removed") == true) return;
                var source = origin(entitySkill(item));
                if (source == null) return;
                adoptFx(G.field(item, "telegraphFx"), source);
                adoptFx(G.field(item, "projFX"), source);
                adoptFx(G.field(item, "groundFX"), source);
                enqueue(Fx, G.iterate(G.field(item, "fxs")), source);
                enqueue(LinkFx, G.iterate(G.field(item, "linkFxs")), source);
            case ModelUnit:
                if (G.field(item, "removed") != true && isA(item, "ent.Hero") && ally(item))
                    discover(Mesh, G.field(item, "unitView"), null);
            case Mesh:
                // Ability meshes attached to a model have their own filters.
                if (isA(item, "hrt.prefab.fx.FXAnimation")) return;
                if (isA(item, "h3d.scene.Mesh")) {
                    discoveryMeshes.set(item, true);
                    // Hide newly discovered meshes immediately; retain the old
                    // set until the sweep completes so existing models don't flash.
                    hiddenMeshes.set(item, true);
                }
                enqueue(Mesh, G.iterate(G.field(item, "children")));
            case ExpiredFx:
                if (G.field(item, "removed") == true) forget(item);
            case EndedSound:
                if (G.field(item, "added") != true) soundOrigins.remove(item);
        }
    }

    static function adoptFx(fx:Dynamic, value:EffectOrigin):Void {
        // A sweep may span a pool reset/rebind. Its earlier skill attribution
        // must never overwrite the newer caster captured by a lifecycle hook.
        if (fx != null && !origins.exists(fx)) remember(fx, value);
    }

    static function findRegion(layer:Dynamic):String {
        if (layer == null) return "";
        var activity = G.field(layer, "mainActivity");
        var map = G.text(G.field(G.field(layer, "config"), "mapId"));
        return EffectPolicy.region(G.field(layer, "isRift") == true || isA(activity, "st.activity.Rift"),
            isA(activity, "st.activity.Dungeon"), StringTools.startsWith(map, "World/"));
    }

    static function isA(object:Dynamic, base:String):Bool return G.isA(object, base);

    static function call(object:Dynamic, name:String):Dynamic return G.callInstance(object, name);

    static function playerSource(source:Dynamic):Dynamic {
        var seen:Array<Dynamic> = [];
        while (source != null && seen.indexOf(source) < 0 && seen.length < 32) {
            seen.push(source);
            var owner = G.field(source, "summonOwner");
            if (owner != null) { source = owner; continue; }
            var proxy = G.call("ent.GameObject", "resolveProxy", source);
            if (proxy != source) { source = proxy; continue; }
            return source;
        }
        return null;
    }

    static function own(source:Dynamic):Bool {
        return source != null && (source == hero || G.field(G.field(source, "ownerPlayer"), "isMe") == true
            || (G.field(source, "player") != null && G.field(source, "player") == G.field(hero, "player")));
    }

    static function ally(source:Dynamic):Bool {
        if (hero == null || source == null) return false;
        if (friends.exists(source)) return friends.get(source);
        source = playerSource(source);
        if (source == null) return false;
        if (friends.exists(source)) return friends.get(source);
        // Include friendly players outside your group, but never duel/PvP opponents.
        var result = isA(source, "ent.Hero") && !own(source) && G.field(source, "removed") != true
            && G.field(source, "layer") == layer
            && G.call("ent.GameObject", "isEnemy", hero, [source]) != true;
        friends.set(source, result);
        return result;
    }

    static function origin(skill:Dynamic):EffectOrigin {
        if (!active || skill == null || hero == null) return null;
        var root = call(skill, "getSourceSkill");
        var source = playerSource(call(root == null ? skill : root, "getSourceObject"));
        if (!own(source) && !ally(source)) return null;
        return {source: source, beneficial: NativeSkillFacts.beneficial(skill)
            || (root != null && root != skill && NativeSkillFacts.beneficial(root))};
    }

    static function entitySkill(entity:Dynamic):Dynamic {
        var skill = G.field(entity, "baseSkill");
        return skill != null ? skill : G.field(G.field(G.field(entity, "anim"), "currentDef"), "skillSource");
    }

    public static function pushSkill(skill:Dynamic):Void {
        if (!active) return;
        if (scopes.value == null) scopes.value = [];
        var value:EffectOrigin = null;
        try value = origin(skill) catch (e:Dynamic) fail(e);
        scopes.value.push(value);
    }

    public static function pushEntity(entity:Dynamic):Void {
        if (active) pushSkill(entitySkill(entity));
    }
    public static function pushSoundEntity(entity:Dynamic):Void {
        if (!active) return;
        // Entity.sfx assigns SoundObject.entity after calling play. Preserve an
        // existing hit/skill scope so the recipient cannot change the caster.
        var stack = scopes.value;
        if (stack != null && stack.length > 0) stack.push(stack[stack.length - 1]);
        else pushEntity(entity);
    }
    public static function pop():Void {
        if (scopes.value != null && scopes.value.length > 0) scopes.value.pop();
    }

    static function current():EffectOrigin {
        var stack = scopes.value;
        return stack == null || stack.length == 0 ? null : stack[stack.length - 1];
    }

    // Target-mode circles and lines share playSkillFx with actual attacks.
    // Mark the preview objects for their lifetime, not the skill being aimed.
    // Track them even with filtering off so enabling it mid-aim is safe.
    public static function beginAiming():Void
        aimingDepth.value = aimingDepth.value == null ? 1 : aimingDepth.value + 1;
    public static function endAiming():Void {
        if (aimingDepth.value > 0) aimingDepth.value--;
    }

    public static function bindCreated(fx:Dynamic):Void {
        if (fx == null) return;
        // Pool reuse must not retain the previous caster's visibility rule.
        forget(fx);
        if (aimingDepth.value > 0 || active) try
            remember(fx, aimingDepth.value > 0 ? aimingOrigin : current()) catch (e:Dynamic) fail(e);
    }

    public static function bindEntity(entity:Dynamic, fx:Dynamic):Void {
        if (!active || fx == null) return;
        try {
            var value = current();
            if (value == null) value = origin(entitySkill(entity));
            if (value != null) remember(fx, value);
        } catch (e:Dynamic) fail(e);
    }

    public static function bindSkill(skill:Dynamic, fx:Dynamic):Void {
        if (fx == null || (!active && !(aimingDepth.value > 0))) return;
        try remember(fx, aimingDepth.value > 0 ? aimingOrigin : origin(skill)) catch (e:Dynamic) fail(e);
    }

    static function remember(fx:Dynamic, value:EffectOrigin):Void {
        if (fx == null || G.field(fx, "removed") == true) return;
        var inherited = fxOrigin(fx);
        if (inherited != null && inherited.aiming == true) value = inherited;
        if (value == null) return;
        var previous = origins.get(fx);
        // Existing effects do not need their entire sub-FX tree rediscovered.
        // New descendants inherit through sync/detach hooks; pool reuse forgets
        // the old attribution before binding the new caster.
        if (previous != null && previous.source == value.source && previous.beneficial == value.beneficial
            && previous.aiming == value.aiming) return;
        origins.set(fx, value);
        if (previous == null) {
            var instances:Array<Dynamic> = [];
            for (effect in G.iterate(G.field(fx, "effects"))) {
                var instance = G.field(effect, "instance");
                if (instance == null || rendererOrigins.get(instance) == fx) continue;
                rendererOrigins.set(instance, fx);
                instances.push(instance);
            }
            if (instances.length > 0) renderersByFx.set(fx, instances);
        }
        // Detached sub-effects retain the same original caster.
        for (child in G.iterate(G.field(fx, "subFXs"))) remember(child, value);
    }

    static function hidden(value:EffectOrigin):Bool {
        if (!active || value == null || value.aiming == true) return false;
        return EffectPolicy.hideEffect(own(value.source), ally(value.source), value.beneficial, filters);
    }

    public static function beforeFxSync(fx:Dynamic, ctx:Dynamic):Void {
        if (!active || ctx == null) return;
        try {
            var value = fxOrigin(fx);
            if (!hidden(value)) return;
            if (!origins.exists(fx)) remember(fx, value);
            if (syncFrames.value == null) syncFrames.value = [];
            var frame:SyncFrame = {fx: fx, ctx: ctx, visible: G.field(ctx, "visibleFlag") == true,
                flags: G.integer(G.field(fx, "flags"))};
            syncFrames.value.push(frame);
            if (!visibilityRestore.exists(fx)) visibilityRestore.set(fx, frame.flags & 2);
            // Visible=2, AlwaysSyncAnimation=64, AlwaysSync=32768. Advance
            // timelines/callbacks while suppressing geometry and camera shake.
            G.set(fx, "flags", (frame.flags & ~2) | 64 | 32768);
            G.set(ctx, "visibleFlag", false);
        } catch (e:Dynamic) fail(e);
    }

    public static function afterFxSync(fx:Dynamic):Void {
        var stack = syncFrames.value;
        if (stack == null || stack.length == 0 || stack[stack.length - 1].fx != fx) return;
        restoreFrame(stack.pop());
    }

    static function restoreFrame(frame:SyncFrame):Void {
        try {
            G.set(frame.ctx, "visibleFlag", frame.visible);
            var flags = G.integer(G.field(frame.fx, "flags"));
            G.set(frame.fx, "flags", (flags & ~(64 | 32768)) | (frame.flags & (64 | 32768)));
        } catch (e:Dynamic) fail(e);
    }

    public static function afterRender():Void {
        // Scene synchronization precedes emission/drawing. Keep Visible cleared
        // until the whole App.render finishes, then restore the native state.
        for (fx => visible in visibilityRestore) try {
            if (G.field(fx, "removed") != true)
                G.set(fx, "flags", (G.integer(G.field(fx, "flags")) & ~2) | visible);
        } catch (e:Dynamic) fail(e);
        visibilityRestore = new ObjectMap();
        restoreRenderer();
    }

    static function fxOrigin(fx:Dynamic):EffectOrigin {
        // Sub-FX can be constructed and detached before their first scene sync.
        var depth = 0;
        while (fx != null && depth++ < 32) {
            var value = origins.get(fx);
            if (value != null) return value;
            fx = G.field(fx, "parentFX");
        }
        return null;
    }

    public static function beforeDetach(fx:Dynamic):Void {
        if (fx == null) return;
        try {
            var value = fxOrigin(fx);
            if (active || (value != null && value.aiming == true)) remember(fx, value);
        } catch (e:Dynamic) fail(e);
    }

    static function soundOrigin(sound:Dynamic):EffectOrigin {
        var value = fxOrigin(G.field(G.field(sound, "follow"), "fx"));
        if (value != null) return value;
        value = soundOrigins.get(sound);
        return value != null ? value : origin(entitySkill(G.field(sound, "entity")));
    }

    public static function beforeSound(sound:Dynamic):Bool {
        if (!active || sound == null) return false;
        try {
            soundOrigins.remove(sound); // Replayed sound objects can change caster.
            var value = current();
            if (value == null) value = soundOrigin(sound);
            if (value != null) soundOrigins.set(sound, value);
            if (!hidden(value)) return false;
            silence(sound);
            return true;
        } catch (e:Dynamic) { fail(e); return false; }
    }

    public static function updateSound(sound:Dynamic):Void {
        if (!active || sound == null) return;
        try {
            var value = soundOrigin(sound);
            if (hidden(value)) silence(sound);
        } catch (e:Dynamic) fail(e);
    }

    static function silence(sound:Dynamic):Void {
        // Do not cancel or dispose the FX. Native sound nodes may restart a
        // still-running loop if the user makes that effect visible again.
        if (G.field(sound, "inst") != null && G.call("fmod.Event", "isActive", sound) == true)
            G.call("fmod.Event", "stop", sound, [null]);
        var follow = G.field(sound, "follow");
        if (isA(follow, "shiro.audio.SoundObject3D")) G.set(follow, "active", false);
    }

    public static function forgetSound(sound:Dynamic):Void soundOrigins.remove(sound);

    public static function beforeRenderer():Void {
        if (!active) return;
        try for (instance => fx in rendererOrigins) {
            if (!hidden(origins.get(fx)) || G.field(fx, "removed") == true) continue;
            if (!rendererRestore.exists(instance)) rendererRestore.set(instance, G.field(instance, "enabled") == true);
            G.set(instance, "enabled", false);
        } catch (e:Dynamic) fail(e);
    }

    static function restoreRenderer():Void {
        for (instance => enabled in rendererRestore) try G.set(instance, "enabled", enabled) catch (e:Dynamic) fail(e);
        rendererRestore = new ObjectMap();
    }

    public static function hideMesh(mesh:Dynamic):Bool
        return filters.models && hiddenMeshes.exists(mesh);

    public static function forget(fx:Dynamic):Void {
        if (!origins.exists(fx) && !visibilityRestore.exists(fx)) return;
        origins.remove(fx);
        // Reused FX objects must not inherit a deferred visibility restoration.
        if (visibilityRestore.exists(fx)) {
            if (G.field(fx, "removed") != true)
                G.set(fx, "flags", (G.integer(G.field(fx, "flags")) & ~2) | visibilityRestore.get(fx));
            visibilityRestore.remove(fx);
        }
        var instances = renderersByFx.get(fx);
        renderersByFx.remove(fx);
        if (instances == null) return;
        for (instance in instances) {
            // A renderer instance can have been reassigned to another pooled FX.
            if (rendererOrigins.get(instance) != fx) continue;
            if (rendererRestore.exists(instance)) G.set(instance, "enabled", rendererRestore.get(instance));
            rendererRestore.remove(instance); rendererOrigins.remove(instance);
        }
    }

    public static function dispose():Void {
        if (syncFrames.value != null) while (syncFrames.value.length > 0) restoreFrame(syncFrames.value.pop());
        afterRender();
        soundOrigins = new ObjectMap(); friends = new ObjectMap(); rendererOrigins = new ObjectMap();
        renderersByFx = new ObjectMap();
        origins = new ObjectMap(); hiddenMeshes = new ObjectMap();
        scopes.value = []; syncFrames.value = []; aimingDepth.value = 0;
        hero = null; layer = null; region = ""; active = false;
        filters = {attacks: false, buffs: false, models: false, ownAttacks: false, ownBuffs: false};
        NativeSkillFacts.clear(); restartDiscovery();
    }

    static function fail(error:Dynamic):Void {
        if (!reported) { reported = true; trace("[More Settings] Ability effects: " + Std.string(error)); }
    }
}
