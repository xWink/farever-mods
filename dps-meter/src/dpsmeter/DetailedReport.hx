package dpsmeter;

import dpsmeter.CombatTimeline;
import dpsmeter.FightHistory;

/** Pure worker-side filtering, paging, graph bins, and observed status intervals. */
class DetailedReport {
    public static inline var PAGE_SIZE = 6;
    public static inline var MAX_PAGE_SIZE = 16;
    public static inline var ROW_HEIGHT = 54;
    public static inline var ROW_GAP = 3;
    public static function pageCapacity(height:Int):Int
        return Std.int(Math.max(1, Math.min(MAX_PAGE_SIZE, Math.floor((height + ROW_GAP) / (ROW_HEIGHT + ROW_GAP)))));
    /** One expanded card replaces up to three adjacent rows, preserving the rest of the page. */
    public static function expansionRange(count:Int, selected:Int):{first:Int, last:Int} {
        if (count <= 0 || selected < 0 || selected >= count) return {first:-1, last:-1};
        var span = Std.int(Math.min(3, count));
        var first = Std.int(Math.min(selected, count - span));
        return {first:first, last:first + span - 1};
    }
    public static function statusCategory(e:TimelineEvent, ?metadata:Map<String, {kind:String, hidden:Bool}>):String {
        var info = metadata == null ? null : metadata[e.skill];
        if (e.hiddenStatus == true || (e.hiddenStatus == null && info != null && info.hidden)) return "";
        return e.statusType != null ? e.statusType : info == null ? "" : info.kind;
    }
    public static function displayedAmount(e:TimelineEvent, me:String):Null<Float> {
        if (e.amount == null) return null;
        return e.target == me && (e.kind == "damage" || e.kind == "health_loss") ? -Math.abs(e.amount) : e.amount;
    }
    public static function outcome(e:TimelineEvent):String return switch (text(e.outcome)) {
        case "Server charge increase; reset/correction cause unavailable": "Charge increase";
        case "Observed HP loss; cause unconfirmed": "Health lost";
        case "Removed (reason unavailable)": "Removed";
        case "Shield reduced (absorption/removal not distinguished)": "Shield reduced";
        case "Healing amount unavailable": "";
        default: text(e.outcome);
    };
    public static function isUse(e:TimelineEvent):Bool return ["skill_use", "dodge_use", "block_use"].indexOf(e.kind) >= 0;
    /** Attach lifecycle observations to their use row without changing recorded order/data. */
    static function attachUses(events:Array<TimelineEvent>):Array<TimelineEvent> {
        var result:Array<TimelineEvent> = [];
        var bySeq:Map<Int, TimelineEvent> = [];
        var active:Map<String, Array<TimelineEvent>> = [];
        for (original in events) {
            var e:TimelineEvent = Reflect.copy(original);
            if (e.kind == "recording_gap" || e.kind == "recording_stopped" || e.kind == "recording_started") { active = []; bySeq = []; }
            if (isUse(e)) {
                bySeq[e.seq] = e;
                var key = e.source + ":" + text(e.instance) + ":" + e.skill;
                if (!active.exists(key)) active[key] = [];
                active[key].push(e);
            }
            if (e.kind == "skill_context" || e.kind == "skill_end") {
                var use = e.related == null ? null : bySeq[e.related];
                var key = e.source + ":" + text(e.instance) + ":" + e.skill;
                var queue = active[key];
                // Compatibility with pre-link recordings; never pair across gaps.
                if (use == null && e.related == null && queue != null && queue.length > 0)
                    use = e.outcome == "Start" ? queue[0] : queue[queue.length - 1];
                if (use != null) {
                    if (e.kind == "skill_context" && e.target != "") { use.target = e.target; use.targetName = e.targetName; }
                    if (e.kind == "skill_context" && text(use.item) == "" && text(e.item) != "") {
                        use.item = e.item; use.itemName = e.itemName;
                    }
                    if (e.kind == "skill_end") {
                        use.useDuration = e.useDuration != null ? e.useDuration : Math.max(0, e.time - use.time);
                        if (queue != null) queue.remove(use);
                    }
                }
                continue;
            }
            result.push(e);
        }
        return result;
    }
    static function text(v:Dynamic):String return v == null ? "" : Std.string(v);
    public static function matches(e:TimelineEvent, me:String, filter:String, ?metadata:Map<String, {kind:String, hidden:Bool}>):Bool {
        // Samples are internal state, not player actions or combat outcomes.
        // Retain them in saved recordings without cluttering any event view.
        if (e.kind == "health_sample") return false;
        return switch filter {
        case "outgoing": e.kind == "damage" && e.source == me;
        case "incoming": e.kind == "damage" && e.target == me;
        case "actions": isUse(e);
        case "healing": e.kind == "heal";
        case "shield": StringTools.startsWith(e.kind, "shield_");
        case "buffs": StringTools.startsWith(e.kind, "status_") && statusCategory(e, metadata) == "buff";
        case "debuffs": StringTools.startsWith(e.kind, "status_") && statusCategory(e, metadata) == "debuff";
        case "statuses": StringTools.startsWith(e.kind, "status_");
        case "procs": StringTools.startsWith(e.kind, "proc_") || e.kind == "charge_update";
        case "defense": ["avoided", "dodge_use", "block_use", "block_success"].indexOf(e.kind) >= 0 || e.outcome == "Blocked";
        case "health": e.kind == "health_loss" || e.kind == "death";
        default: true;
        };
    }
    public static function query(data:Dynamic, request:HistoryRequest):Dynamic {
        var me = text(data.me);
        var events:Array<TimelineEvent> = cast data.events;
        var initial:Array<TimelineEvent> = cast data.initial;
        var all = initial.concat(events);
        all.sort(TimelineStore.compare);
        var visible = attachUses(all);
        var pageSize = request.eventPageSize == null ? PAGE_SIZE : Std.int(Math.max(1, Math.min(MAX_PAGE_SIZE, request.eventPageSize)));
        var skill = text(request.eventSkill), filter = text(request.eventFilter);
        var search = StringTools.trim(text(request.eventSearch)).toLowerCase();
        var filtered:Array<TimelineEvent> = [];
        var incomplete = false;
        for (e in visible) {
            // Work on detached presentation copies, including older reports
            // whose flask events inherited a movement buff's name.
            if (request.skillNames != null && request.skillNames.exists(e.skill)) e.skillName = request.skillNames[e.skill];
            if (e.kind == "recording_gap" || e.kind == "recording_stopped" || (e.kind == "recording_started" && e.time > 0)) incomplete = true;
            if (!matches(e, me, filter, request.statusMetadata) || (skill != "" && e.skill != skill && e.origin != skill)) continue;
            if (search != "" && (e.skill + " " + text(e.skillName) + " " + text(e.sourceName) + " " + text(e.targetName)
                + " " + text(e.item) + " " + text(e.itemName) + " " + e.kind + " " + text(e.outcome)).toLowerCase().indexOf(search) < 0) continue;
            filtered.push(e);
        }
        var page = request.page;
        if (request.jumpTime != null) {
            var i = 0;
            while (i < filtered.length - 1 && filtered[i].time < request.jumpTime) i++;
            page = Std.int(i / pageSize);
        }
        page = Std.int(Math.max(0, Math.min(page, Math.max(0, Math.ceil(filtered.length / pageSize) - 1))));
        var duration:Float = Math.max(.001, data.duration);
        var response:Dynamic = {version:1, me:me, count:events.length, total:filtered.length, page:page,
            pages:Std.int(Math.max(1, Math.ceil(filtered.length / pageSize))),
            rows:filtered.slice(page * pageSize, (page + 1) * pageSize), pageSize:pageSize,
            duration:duration, incomplete:incomplete};
        // Page/filter/search changes leave the full-fight graph untouched.
        if (request.includeGraph == false) return response;
        var end = duration;
        var width = Math.max(1, Math.ceil(end / 120));
        var bins:Array<Float> = [for (i in 0...Std.int(Math.ceil(end / width))) 0.0];
        var metric = text(request.graphMetric); if (metric == "") metric = "outgoing";
        var hasHp = false;
        var knownHp:Array<Bool> = [for (_ in bins) false];
        for (e in all) {
            if (metric != "health" && skill != "" && e.skill != skill && e.origin != skill) continue;
            var pos = Std.int(Math.max(0, Math.min(bins.length - 1, Math.floor(e.time / width))));
            if (metric == "health") {
                if ((e.kind == "health_loss" || e.kind == "health_sample") && e.after != null) {
                    hasHp = true;
                    for (i in pos...bins.length) { bins[i] = e.after; knownHp[i] = true; }
                }
                continue;
            }
            if (e.time < 0 || e.amount == null) continue;
            var include = switch metric {
                case "healing": e.kind == "heal" && e.source == me;
                case "incoming": e.kind == "damage" && e.target == me;
                case "shield": e.kind == "shield_applied" && e.source == me;
                default: e.kind == "damage" && e.source == me;
            };
            if (include) bins[pos] += e.amount / Math.max(.001, Math.min(width, end - pos * width));
        }
        var maximum = 0.0; for (v in bins) maximum = Math.max(maximum, v);
        response.graph = {metric:metric, bins:bins, step:width, end:end, max:maximum, hasHp:hasHp, knownHp:knownHp};
        response.lanes = lanes(all, end, me, skill, metric, request.statusMetadata);
        return response;
    }
    static function lanes(events:Array<TimelineEvent>, end:Float, me:String, skill:String, metric:String, ?metadata:Map<String, {kind:String, hidden:Bool}>):Array<Dynamic> {
        var active:Map<String, TimelineEvent> = [];
        var grouped:Map<String, Dynamic> = [];
        function interval(e:TimelineEvent, stop:Float):Void {
            if (e.skill == "" || (skill != "" && e.skill != skill && e.origin != skill)) return;
            if ((metric == "buffs" || metric == "debuffs") && statusCategory(e, metadata) != (metric == "buffs" ? "buff" : "debuff")) return;
            var key = e.skill + ":" + e.target;
            if (!grouped.exists(key)) grouped[key] = {skill:e.skill, name:text(e.skillName) != "" ? e.skillName : e.skill,
                target:e.target == me ? "You" : text(e.targetName), intervals:[]};
            var intervals:Array<Dynamic> = grouped[key].intervals;
            if (stop > Math.max(0, e.time)) intervals.push({start:Math.max(0, e.time), end:Math.min(end, stop)});
        }
        for (e in events) {
            if (e.kind == "recording_stopped" || e.kind == "recording_gap" || e.kind == "recording_started") {
                for (status in active) interval(status, e.time);
                active = []; continue;
            }
            if (!StringTools.startsWith(e.kind, "status_") || e.instance == null) continue;
            if (e.kind == "status_removed") {
                if (active.exists(e.instance)) { interval(active[e.instance], e.time); active.remove(e.instance); }
            } else if (!active.exists(e.instance)) active[e.instance] = e;
        }
        for (e in active) interval(e, end);
        var result = [for (lane in grouped) lane];
        result.sort((a,b) -> Reflect.compare(a.name, b.name));
        return result;
    }
    public static function timestamp(time:Float):String {
        var millis = Std.int(Math.round(Math.abs(time) * 1000));
        return (time < 0 ? "−" : "") + StringTools.lpad(Std.string(Std.int(millis / 60000)), "0", 2)
            + ":" + StringTools.lpad(Std.string(Std.int(millis / 1000) % 60), "0", 2)
            + "." + StringTools.lpad(Std.string(millis % 1000), "0", 3);
    }
    public static function label(e:TimelineEvent):String return switch e.kind {
        case "skill_use": e.skill == "ConsumeItem" ? "ITEM USED" : "SKILL USED"; case "skill_end": "SKILL ENDED";
        case "dodge_use": "DODGE USED"; case "block_use": "BLOCK USED"; case "block_success": "BLOCK SUCCESS";
        case "damage": e.critical == true ? "CRITICAL HIT" : "DAMAGE"; case "avoided": "AVOIDED";
        case "heal": e.critical == true ? "CRITICAL HEAL" : "HEAL";
        case "health_loss": "HP LOST"; case "health_sample": "HP OBSERVED";
        case "shield_applied": "SHIELD ADDED"; case "shield_changed": "SHIELD CHANGED"; case "shield_present": "SHIELD ACTIVE";
        case "status_applied": "APPLIED"; case "status_present": "ALREADY ACTIVE";
        case "status_stacks": "STACKS"; case "status_refreshed": "REFRESHED";
        case "status_duration": "DURATION UPDATED"; case "status_removed": "REMOVED";
        case "proc_available": "PROC READY"; case "proc_present": "PROC ACTIVE";
        case "proc_used": "PROC USED"; case "proc_ended": "PROC ENDED";
        case "proc_reset": "COOLDOWN RESET"; case "charge_update": "CHARGE INCREASE";
        case "death": "DEATH"; case "recording_started": "RECORDING STARTED";
        case "recording_stopped": "RECORDING PAUSED"; case "recording_gap": "RECORDING GAP";
        default: e.kind;
    }
}
