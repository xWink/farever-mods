package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;
import moresettings.EffectPolicy.RegionFilters;

private typedef EffectOrigin = { var source:Dynamic; var beneficial:Bool; }
private typedef SyncFrame = { var fx:Dynamic; var ctx:Dynamic; var visible:Bool; var flags:Int; }

/** Only presentation objects are filtered; skills, hits and RPCs still run. */
class AllyEffects {
    static var config:MoreSettingsConfig;
    static var hero:Dynamic;
    static var layer:Dynamic;
    static var region:String = "";
    static var filters:RegionFilters = {attacks: false, buffs: false, models: false};
    static var origins:ObjectMap<Dynamic, EffectOrigin> = new ObjectMap();
    static var soundOrigins:ObjectMap<Dynamic, EffectOrigin> = new ObjectMap();
    static var friends:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var rendererOrigins:ObjectMap<Dynamic, {fx:Dynamic, origin:EffectOrigin}> = new ObjectMap();
    static var visibilityRestore:ObjectMap<Dynamic, Int> = new ObjectMap();
    static var rendererRestore:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var hiddenMeshes:ObjectMap<Dynamic, Bool> = new ObjectMap();
    static var scopes = new sys.thread.Tls<Array<EffectOrigin>>();
    static var syncFrames = new sys.thread.Tls<Array<SyncFrame>>();
    static var nextRefresh:Float = 0;
    static var reported:Bool = false;
    public static var active(default, null):Bool = false;

    public static function configure(value:MoreSettingsConfig):Void {
        config = value;
        filters = EffectPolicy.filters(config, region);
        active = filters.attacks || filters.buffs;
        if (!filters.models) hiddenMeshes = new ObjectMap();
        nextRefresh = 0;
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
                active = filters.attacks || filters.buffs;
                hiddenMeshes = new ObjectMap(); nextRefresh = 0;
            }
            // Recover an abandoned presentation scope if the game threw while
            // creating an effect. Scope storage is per-thread for visual jobs.
            if (scopes.value != null && scopes.value.length > 0) scopes.value = [];
            var now = haxe.Timer.stamp();
            if (hero == null || (!active && !filters.models) || now < nextRefresh) return;
            nextRefresh = now + 0.2;
            hiddenMeshes = new ObjectMap();
            for (unit in G.array(G.field(layer, "units"))) {
                if (filters.models && isA(unit, "ent.Hero") && ally(unit)) collectMeshes(G.field(unit, "unitView"));
                if (!active) continue;
                // This also adopts already-running buffs when a filter is
                // enabled, and keeps effects on recipients attributed correctly.
                if (ally(unit)) for (skill in G.array(G.field(unit, "skills"))) adoptSkill(skill);
                for (status in G.array(G.field(unit, "statuses"), true)) adoptSkill(status);
                bindEntity(unit, G.field(unit, "crtAnimFx"));
            }
            if (active) {
                for (area in G.array(G.field(layer, "areas"))) adoptEntity(area);
                for (entity in G.array(G.field(layer, "entities")))
                    if (isA(entity, "ent.Projectile")) adoptEntity(entity);
                var expired:Array<Dynamic> = [];
                for (fx in origins.keys()) if (G.field(fx, "removed") == true) expired.push(fx);
                for (fx in expired) forget(fx);
                var ended:Array<Dynamic> = [];
                for (sound in soundOrigins.keys()) if (G.field(sound, "added") != true) ended.push(sound);
                for (sound in ended) soundOrigins.remove(sound);
            }
        } catch (e:Dynamic) fail(e);
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
        if (!ally(source)) return null;
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
        // existing hit/skill scope (including a local player's null scope).
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

    public static function bindCreated(fx:Dynamic):Void {
        if (fx == null) return;
        // Pool reuse must not retain the previous caster's visibility rule.
        forget(fx);
        if (active) try remember(fx, current()) catch (e:Dynamic) fail(e);
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
        if (!active || fx == null) return;
        try remember(fx, origin(skill)) catch (e:Dynamic) fail(e);
    }

    static function remember(fx:Dynamic, value:EffectOrigin):Void {
        if (fx == null || value == null) return;
        var first = !origins.exists(fx);
        origins.set(fx, value);
        if (first) for (effect in G.array(G.field(fx, "effects"))) {
            var instance = G.field(effect, "instance");
            if (instance != null) rendererOrigins.set(instance, {fx: fx, origin: value});
        }
        // Detached sub-effects retain the same original caster.
        for (child in G.array(G.field(fx, "subFXs"))) remember(child, value);
    }

    static function adoptSkill(skill:Dynamic):Void {
        if (skill == null) return;
        var value = origin(skill);
        if (value == null) return;
        for (step in G.array(G.field(skill, "steps"))) {
            for (fx in G.array(G.field(step, "fxs"))) remember(fx, value);
            for (fx in G.array(G.field(step, "otherFxs"))) remember(fx, value);
            for (link in G.array(G.field(step, "linkFxs"))) remember(G.field(link, "fx"), value);
        }
    }

    static function adoptEntity(entity:Dynamic):Void {
        var value = origin(entitySkill(entity));
        if (value == null) return;
        for (name in ["telegraphFx", "projFX", "groundFX"]) remember(G.field(entity, name), value);
        for (fx in G.array(G.field(entity, "fxs"))) remember(fx, value);
    }

    static function hidden(value:EffectOrigin):Bool {
        if (!active || value == null) return false;
        return EffectPolicy.hideEffect(value.source == hero, ally(value.source), value.beneficial, filters);
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
        if (!active || fx == null) return;
        try remember(fx, fxOrigin(fx)) catch (e:Dynamic) fail(e);
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
        try for (instance => record in rendererOrigins) {
            if (!hidden(record.origin) || G.field(record.fx, "removed") == true) continue;
            if (!rendererRestore.exists(instance)) rendererRestore.set(instance, G.field(instance, "enabled") == true);
            G.set(instance, "enabled", false);
        } catch (e:Dynamic) fail(e);
    }

    static function restoreRenderer():Void {
        for (instance => enabled in rendererRestore) try G.set(instance, "enabled", enabled) catch (e:Dynamic) fail(e);
        rendererRestore = new ObjectMap();
    }

    static function collectMeshes(root:Dynamic):Void {
        if (root == null) return;
        var pending = [root];
        while (pending.length > 0) {
            var node = pending.pop();
            // Model hiding must not hide any abilities attached to that model.
            if (isA(node, "hrt.prefab.fx.FXAnimation")) continue;
            if (isA(node, "h3d.scene.Mesh")) hiddenMeshes.set(node, true);
            for (child in G.array(G.field(node, "children"))) pending.push(child);
        }
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
        var expired:Array<Dynamic> = [];
        for (instance => record in rendererOrigins) if (record.fx == fx) expired.push(instance);
        for (instance in expired) {
            if (rendererRestore.exists(instance)) G.set(instance, "enabled", rendererRestore.get(instance));
            rendererRestore.remove(instance); rendererOrigins.remove(instance);
        }
    }

    public static function dispose():Void {
        if (syncFrames.value != null) while (syncFrames.value.length > 0) restoreFrame(syncFrames.value.pop());
        afterRender();
        soundOrigins = new ObjectMap(); friends = new ObjectMap(); rendererOrigins = new ObjectMap();
        origins = new ObjectMap(); hiddenMeshes = new ObjectMap();
        scopes.value = []; syncFrames.value = [];
        hero = null; layer = null; region = ""; active = false;
        filters = {attacks: false, buffs: false, models: false};
        NativeSkillFacts.clear(); nextRefresh = 0;
    }

    static function fail(error:Dynamic):Void {
        if (!reported) { reported = true; trace("[More Settings] Ally effects: " + Std.string(error)); }
    }
}
