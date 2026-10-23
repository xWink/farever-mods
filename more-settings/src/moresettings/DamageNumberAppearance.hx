package moresettings;

import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

/** Native floaters are styled independently of fancy colours.
    Scale and opacity belong to the text itself, preserving parent fade. */
class DamageNumberAppearance {
    public static function apply(display:Dynamic,config:MoreSettingsConfig):Void {
        if(config.damageNumberLimit==0 || display==null)return;
        applyText(G.field(display,"counter"),config);
    }
    static function applyText(counter:Dynamic,config:MoreSettingsConfig):Void {
        if(counter==null)return;
        if(config.damageNumberScale!=100)
            G.call("h2d.Object","setScale",counter,[config.damageNumberScale/100.0]);
        if(config.damageNumberOpacity!=100)
            G.set(counter,"alpha",config.damageNumberOpacity/100.0);
    }
    /** HUD feed rows are independent of the native floating damage components. */
    public static function healingFeed(feed:Dynamic,damage:Dynamic,config:MoreSettingsConfig):Void {
        if(config.damageNumberLimit==0||damage==null
            || (config.damageNumberScale==100&&config.damageNumberOpacity==100))return;
        var row=HealingFeed.lastAddedRow(feed,damage);
        if(row!=null)applyRow(row,config);
    }
    public static function damageFeed(feed:Dynamic,damage:Dynamic,config:MoreSettingsConfig):Void {
        if(config.damageNumberLimit==0||damage==null
            || (config.damageNumberScale==100&&config.damageNumberOpacity==100))return;
        var lines=G.field(feed,"activeLines");
        var count=G.integer(G.field(lines,"length"));
        if(count<=0)return;
        var row=G.field(G.call("hl.types.ArrayObj","getDyn",lines,[count-1]),"elt");
        var dom=G.field(row,"dom");
        if(dom==null||G.call("domkit.Properties","hasClass",dom,["damage"])!=true)return;
        applyRow(row,config);
    }
    static function applyRow(row:Dynamic,config:MoreSettingsConfig):Void {
        var count=G.integer(G.call("h2d.Object","get_numChildren",row));
        for(i in 0...count) {
            var child=G.call("h2d.Object","getChildAt",row,[i]);
            if(G.isA(child,"ui.comp.FmtText"))applyText(child,config);
        }
    }
}
