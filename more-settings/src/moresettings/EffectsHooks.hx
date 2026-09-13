package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;

/** Presentation scopes keep native FX creation, callbacks and skills intact. */
class EffectsHooks {
    @:hlx.prefix(st.skill.SkillStep.playVisuals)
    static function stepBefore(instance:Dynamic, force:hl.Ref<Bool>):HlxPrefixResult<Void> {
        AllyEffects.pushSkill(G.field(instance, "baseSkill")); return Continue;
    }
    @:hlx.postfix(st.skill.SkillStep.playVisuals)
    static function stepAfter(instance:Dynamic, force:hl.Ref<Bool>, result:Void):Void AllyEffects.pop();

    @:hlx.prefix(ent.GameObject.playSkillFx)
    static function skillBefore(instance:Dynamic, fxInf:Dynamic, skill:Dynamic):HlxPrefixResult<Dynamic> {
        AllyEffects.pushSkill(skill); return Continue;
    }
    @:hlx.postfix(ent.GameObject.playSkillFx)
    static function skillAfter(instance:Dynamic, fxInf:Dynamic, skill:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindSkill(skill, result); AllyEffects.pop(); return result;
    }

    @:hlx.prefix(ent.Projectile.playVisuals)
    static function projectileBefore(instance:Dynamic, type:Int):HlxPrefixResult<Dynamic> {
        AllyEffects.pushEntity(instance); return Continue;
    }
    @:hlx.postfix(ent.Projectile.playVisuals)
    static function projectileAfter(instance:Dynamic, type:Int, result:Dynamic):Dynamic {
        AllyEffects.bindEntity(instance, result); AllyEffects.pop(); return result;
    }

    @:hlx.prefix(st.skill.SkillArea.playAreaFx)
    @:hlx.prefix(st.skill.SkillArea.initVisual)
    @:hlx.prefix(ent.Projectile.initVisual)
    static function areaBefore(instance:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.pushEntity(instance); return Continue;
    }
    @:hlx.postfix(st.skill.SkillArea.playAreaFx)
    @:hlx.postfix(st.skill.SkillArea.initVisual)
    @:hlx.postfix(ent.Projectile.initVisual)
    static function areaAfter(instance:Dynamic, result:Void):Void AllyEffects.pop();

    @:hlx.prefix(script.SkillScript.playFXSetAtPos)
    static function scriptBefore(instance:Dynamic, fxSet:String, pos:Dynamic):HlxPrefixResult<Dynamic> {
        AllyEffects.pushSkill(G.field(instance, "skill")); return Continue;
    }
    @:hlx.postfix(script.SkillScript.playFXSetAtPos)
    static function scriptAfter(instance:Dynamic, fxSet:String, pos:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindSkill(G.field(instance, "skill"), result); AllyEffects.pop(); return result;
    }

    @:hlx.prefix(ent.Entity.playAnimFX)
    static function animBefore(instance:Dynamic, path:String, def:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.pushSkill(G.field(def, "skillSource")); return Continue;
    }
    @:hlx.postfix(ent.Entity.playAnimFX)
    static function animAfter(instance:Dynamic, path:String, def:Dynamic, result:Void):Void {
        AllyEffects.bindSkill(G.field(def, "skillSource"), G.field(instance, "crtAnimFx")); AllyEffects.pop();
    }

    @:hlx.prefix(ent.Unit.playHitDmgFX)
    static function damageBefore(instance:Dynamic, source:Dynamic, hitData:Dynamic):HlxPrefixResult<Dynamic> {
        AllyEffects.pushSkill(G.field(hitData, "baseSkill")); return Continue;
    }
    @:hlx.postfix(ent.Unit.playHitDmgFX)
    static function damageAfter(instance:Dynamic, source:Dynamic, hitData:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindSkill(G.field(hitData, "baseSkill"), result); AllyEffects.pop(); return result;
    }
    @:hlx.prefix(ent.Unit.playHitHealFX)
    static function healBefore(instance:Dynamic, hitData:Dynamic):HlxPrefixResult<Dynamic> {
        AllyEffects.pushSkill(G.field(hitData, "baseSkill")); return Continue;
    }
    @:hlx.postfix(ent.Unit.playHitHealFX)
    static function healAfter(instance:Dynamic, hitData:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindSkill(G.field(hitData, "baseSkill"), result); AllyEffects.pop(); return result;
    }

    @:hlx.prefix(ent.Unit.playBlock)
    static function blockBefore(instance:Dynamic, source:Dynamic, damageResult:Dynamic):HlxPrefixResult<Dynamic> {
        // Blocking belongs to the defender, never the attacker being blocked.
        AllyEffects.pushEntity(instance); return Continue;
    }
    @:hlx.postfix(ent.Unit.playBlock)
    static function blockAfter(instance:Dynamic, source:Dynamic, damageResult:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindEntity(instance, result); AllyEffects.pop(); return result;
    }

    @:hlx.prefix(ent.Projectile.playHitSfx)
    static function hitSoundBefore(instance:Dynamic, target:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.pushEntity(instance); return Continue;
    }
    @:hlx.postfix(ent.Projectile.playHitSfx)
    static function hitSoundAfter(instance:Dynamic, target:Dynamic, result:Void):Void AllyEffects.pop();

    @:hlx.postfix(ent.Entity.bindFX)
    static function bound(instance:Dynamic, fx:Dynamic, result:Void):Void AllyEffects.bindEntity(instance, fx);

    @:hlx.postfix(world.World.playFX)
    static function created(instance:Dynamic, resource:Dynamic, path:String, parent:Dynamic, onEnd:Dynamic,
            ctx:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.bindCreated(result); return result;
    }

    @:hlx.prefix(prefab.FXAnimationBase.syncRec)
    static function fxBefore(instance:Dynamic, ctx:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.beforeFxSync(instance, ctx); return Continue;
    }
    @:hlx.postfix(prefab.FXAnimationBase.syncRec)
    static function fxAfter(instance:Dynamic, ctx:Dynamic, result:Void):Void AllyEffects.afterFxSync(instance);
    @:hlx.prefix(prefab.FXAnimationBase.detachFromParent)
    static function detachBefore(instance:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.beforeDetach(instance); return Continue;
    }
    @:hlx.prefix(prefab.FXAnimationBase.reset)
    static function resetBefore(instance:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.forget(instance); return Continue;
    }
    @:hlx.postfix(prefab.FXAnimationBase.onRemove)
    static function removed(instance:Dynamic, result:Void):Void AllyEffects.forget(instance);

    @:hlx.prefix(ent.Entity.sfx)
    static function entitySoundBefore(instance:Dynamic, key:String, params:Dynamic, follow:Dynamic):HlxPrefixResult<Dynamic> {
        AllyEffects.pushSoundEntity(instance); return Continue;
    }
    @:hlx.postfix(ent.Entity.sfx)
    static function entitySoundAfter(instance:Dynamic, key:String, params:Dynamic, follow:Dynamic, result:Dynamic):Dynamic {
        AllyEffects.pop(); return result;
    }

    @:hlx.prefix(shiro.audio.SoundObject.play)
    static function soundBefore(instance:Dynamic, key:String):HlxPrefixResult<Void>
        return AllyEffects.beforeSound(instance) ? Skip : Continue;
    @:hlx.prefix(shiro.audio.SoundObject.update)
    static function soundUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        AllyEffects.updateSound(instance); return Continue;
    }
    @:hlx.postfix(fmod.Event.remove)
    static function soundRemoved(instance:Dynamic, result:Void):Void AllyEffects.forgetSound(instance);

    @:hlx.prefix(h3d.scene.Renderer.startEffects)
    static function rendererBefore(instance:Dynamic):HlxPrefixResult<Void> {
        AllyEffects.beforeRenderer(); return Continue;
    }

    @:hlx.postfix(App.render)
    static function renderAfter(instance:Dynamic, engine:Dynamic, result:Void):Void AllyEffects.afterRender();

    // Draw hooks retain skeleton/joint synchronization and all attached effects.
    @:hlx.prefix(h3d.scene.Mesh.draw)
    @:hlx.prefix(h3d.scene.MultiMaterial.draw)
    @:hlx.prefix(h3d.scene.Skin.draw)
    static function modelDraw(instance:Dynamic, ctx:Dynamic):HlxPrefixResult<Void>
        return AllyEffects.hideMesh(instance) ? Skip : Continue;
}
