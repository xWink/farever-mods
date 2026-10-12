package moresettings;

import moresettings.GameAccess as G;

/** Expiry of the native condition that keeps a highlighted skill available. */
class ProcTiming {
    public static function remaining(skill:Dynamic):Null<Float> {
        var inf = G.field(skill, "inf");
        var id = G.text(G.field(inf, "id"));
        var owner = G.field(skill, "owner");
        var script = G.field(skill, "script");
        if (owner == null) return null;
        // These are the conditions in shouldHighlightSkill, not the active
        // skill's cast duration/cooldown. Read live state so refreshes, rank
        // changes and alerts enabled midway through a proc stay accurate.
        var status = switch (id) {
            case "Bow_Craft_Skill1", "Staff_Craft_S1": G.text(G.field(script, "Proc"));
            case "Mace_Benediction_Skill1": "Mace_Benediction_Skill1_Proc";
            case "DS_Bladeleaf_Skill1": G.text(G.field(script, "RECAST"));
            case "Daggers_Demondash_Skill2": G.text(G.field(script, "Counter"));
            case "GM_MassGrab_Skill2": "GM_MassGrab_Combo_Proc";
            case "Halos_Demon_Skill1": G.text(G.field(script, "Reblink"));
            case "Mage_Blink": "Mage_Blink_Mastery2_Position";
            case "Warrior_Rage_Strike": G.text(G.field(script, "SURGE"));
            case "Staff_Censer_Ultimate": "Staff_Censer_Ultimate_Proc";
            case "Infusion_Manfish_Support_Ultimate": "Infusion_Manfish_Support_Ultimate_Proc";
            case "Infusion_Manfish_DPS_Ultimate": "Infusion_Manfish_DPS_Ultimate_Proc";
            case "Infusion_Bee_Support_Ultimate": "Infusion_Bee_Support_Ultimate_Proc";
            default: "";
        };
        if (status != "") return ownStatus(owner, status);
        return switch (id) {
            case "DM_Multispin_Skill1":
                var stamp = G.field(script, "lastHitTime");
                var duration = G.field(G.field(inf, "vars"), "time");
                var time = G.call("st.State", "get_time", owner);
                var now = G.field(time, "serverNow");
                stamp == null || duration == null || now == null ? null
                    : finite(G.number(duration) - (G.number(now) - G.number(stamp)));
            case "Book_WaterOrbs_Skill2", "Book_WaterOrbs_Skill2_Recast":
                // Both the recast window and at least one orb must survive.
                earliest(ownStatus(owner, "Book_WaterOrbs_Skill2_Recast_Proc"),
                    ownStatus(owner, "Book_WaterOrbs_Orb_Charge"));
            case "Fists_LightMonk_Skill1", "Fists_LightMonk_Skill1_Recast":
                // These marks are on enemies, not the caster. Any surviving
                // mark keeps the recast available, so use the last expiry.
                var marks = G.call("script.SkillScript", "getInflictedStatuses", script,
                    ["Fists_LightMonk_Skill1_Status"]);
                latest(G.array(marks));
            default: null; // No guessed timers for an unknown/untimed highlight.
        };
    }

    static function ownStatus(owner:Dynamic, kind:String):Null<Float> {
        var matches = [];
        for (status in G.array(G.field(owner, "statuses"), true))
            if (G.text(G.field(status, "kind")) == kind && G.field(status, "removed") != true)
                matches.push(status);
        return latest(matches);
    }

    static function latest(statuses:Array<Dynamic>):Null<Float> {
        var result:Null<Float> = null;
        for (status in statuses) {
            if (status == null || G.field(status, "removed") == true) continue;
            // An infinite status means the condition has no known deadline.
            if (G.call("st.skill.Status", "canElapsedStop", status) != true) return null;
            var remaining = finite(G.number(G.call("st.skill.BaseSkill", "getDurationLeft", status)));
            if (remaining != null && (result == null || remaining > result)) result = remaining;
        }
        return result;
    }

    static function earliest(a:Null<Float>, b:Null<Float>):Null<Float>
        return a == null ? b : b == null ? a : Math.min(a, b);

    static function finite(value:Float):Null<Float>
        return Math.isFinite(value) && value > 0 ? value : null;

    public static function label(seconds:Null<Float>):String {
        if (seconds == null || !Math.isFinite(seconds) || seconds <= 0) return "";
        if (seconds < 3) {
            var tenths = Math.ceil(seconds * 10);
            return Std.int(tenths / 10) + "." + (tenths % 10);
        }
        var whole = Math.ceil(seconds);
        if (whole < 60) return Std.string(whole);
        return Std.int(whole / 60) + ":" + StringTools.lpad(Std.string(whole % 60), "0", 2);
    }
}
