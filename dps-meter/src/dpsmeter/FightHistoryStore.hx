package dpsmeter;

import dpsmeter.FightHistory;
import dpsmeter.HistoryCatalog;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** Worker-owned archive. Only compact summaries stay in memory; charts load on demand. */
class FightHistoryStore {
    public var timeline:TimelineStore;
    final root:String;
    final folder:String;
    final log:String->Void;
    final recycle:String->Void;
    final entries:Map<String, HistoryEntry> = [];
    final paths:Map<String, String> = [];
    var initialized:Bool = false;
    var indexed:Bool = false;
    var catalog:HistoryCatalog = {activities: [], names: [], bosses: [], bossCategories: []};
    var currentActivities:Map<String, String> = [];
    final learned:Map<String, HistoryEntry> = [];
    final learnedBosses:Map<String, String> = [];
    var legacyMetadata:Map<String, Dynamic>;
    var detailedId:String = "";
    var detailedData:Dynamic;
    public function new(root:String, log:String->Void, ?recycle:String->Void) {
        this.root = root; this.folder = root + "/history"; this.log = log;
        timeline = new TimelineStore(root);
        this.recycle = recycle == null ? DesktopActions.recycle : recycle;
    }
    public function initialize():Void {
        if (initialized) return;
        indexFiles();
        // Do this before the uploader writes new reports. Stable imported IDs
        // make retries safe if the process exits before committing the marker.
        var marker = folder + "/legacy-imported";
        if (!FileSystem.exists(marker)) {
            for (source in [root + "/logs", root + "/logs/sent", root + "/logs/rejected"])
                if (FileSystem.exists(source)) for (name in FileSystem.readDirectory(source)) {
                    if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".json")) continue;
                    var path = source + "/" + name;
                    if (FileSystem.isDirectory(path)) continue;
                    var record:Dynamic;
                    try {
                        var report:Dynamic = Json.parse(File.getContent(path));
                        var key = FightHistory.text(report.session_id);
                        if (key == "") key = name;
                        var timestamp = FileSystem.stat(path).mtime.getTime();
                        var date = ~/^run_([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})/;
                        if (date.match(name)) timestamp = Date.fromString(date.matched(1) + "-" + date.matched(2) + "-"
                            + date.matched(3) + " " + date.matched(4) + ":" + date.matched(5) + ":" + date.matched(6)).getTime();
                        record = FightHistory.legacy(report, timestamp, "legacy_" + haxe.crypto.Md5.encode(key));
                        FightHistory.validate(record);
                    } catch (e:Dynamic) { log("Could not import " + name + ": " + Std.string(e)); continue; }
                    // A disk failure must not mark unfinished migration complete.
                    save(record);
                }
            File.saveContent(marker, "1\n");
        }
        initialized = true;
    }
    public function save(record:Dynamic):Void {
        var summary = FightHistory.entry(record);
        if (!HistoryCategory.canArchive(summary, catalog)) return;
        indexFiles();
        // IDs remain stable through migration, localization and save retries.
        if (paths.exists(summary.id)) return;
        var path = recordPath(summary);
        FileSystem.createDirectory(Path.directory(path));
        if (FileSystem.exists(path)) throw "A file already exists at " + path;
        var temp = path + ".tmp";
        timeline.archive(record, path);
        Reflect.deleteField(record, "_timeline");
        File.saveContent(temp, Json.stringify(record));
        FileSystem.rename(temp, path);
        paths[summary.id] = path;
        entries[summary.id] = summary;
        learn(summary);
    }
    function learn(entry:HistoryEntry):Void {
        if (entry.categoryVersion != HistoryCategory.VERSION
            || (entry.category != HistoryCategory.BOSS && entry.category != HistoryCategory.DUNGEON)) return;
        HistoryCategory.observeBoss(learnedBosses, entry.bossKind, entry.category);
        HistoryCategory.observeBoss(catalog.bossCategories, entry.bossKind, entry.category);
        if (entry.activityId == "") return;
        var previous = learned[entry.activityId];
        if (previous == null || previous.startedAt < entry.startedAt) learned[entry.activityId] = entry;
        if (!currentActivities.exists(entry.activityId) || currentActivities[entry.activityId] == HistoryCategory.OTHER)
            catalog.activities[entry.activityId] = learned[entry.activityId].category;
    }
    /** Preload compact summaries on the worker before the first kill needs them. */
    public function warm():Void index();
    function index():Void initialize();
    function indexFiles():Void {
        if (indexed) return;
        FileSystem.createDirectory(folder);
        for (path in archiveFiles()) if (StringTools.endsWith(path, ".json.timeline.tmp")) {
            try {
                TimelineStore.readFile(path); // Validate before recovering a partial write or deletion backup.
                var committed = path.substr(0, path.length - 4);
                if (!FileSystem.exists(committed)) FileSystem.rename(path, committed);
                else if (File.getContent(path) == File.getContent(committed)) FileSystem.deleteFile(path);
            } catch (e:Dynamic) log("Could not recover " + path + ": " + Std.string(e));
        }
        // Both interrupted saves and deletion backups recover beside their
        // original file before indexing, including the old flat layout.
        for (path in archiveFiles()) if (StringTools.endsWith(path, ".json.tmp")) {
            try {
                var record:Dynamic = Json.parse(File.getContent(path));
                FightHistory.validate(record);
                if (Path.withoutDirectory(path) != filename(record.id) + ".tmp") throw "Draft filename does not match its ID.";
                var committed = path.substr(0, path.length - 4);
                if (!FileSystem.exists(committed)) FileSystem.rename(path, committed);
                else if (!FileSystem.isDirectory(committed) && File.getContent(path) == File.getContent(committed))
                    FileSystem.deleteFile(path); // An identical, already-committed recovery copy.
            } catch (e:Dynamic) log("Could not recover " + path + ": " + Std.string(e));
        }
        for (path in archiveFiles()) {
            if (!StringTools.endsWith(path, ".json")) continue;
            try {
                var record:Dynamic = Json.parse(File.getContent(path));
                restoreLegacyMetadata(record);
                var entry = FightHistory.entry(record);
                if (Path.withoutDirectory(path) != filename(entry.id)) throw "History filename does not match its ID.";
                if (paths.exists(entry.id)) throw "Duplicate history ID; both files have been retained.";
                paths[entry.id] = migrate(path, entry);
                entries[entry.id] = entry;
                learn(entry);
            } catch (e:Dynamic) log("Could not read " + path + ": " + Std.string(e));
        }
        indexed = true;
        legacyMetadata = null;
    }
    public function query(request:HistoryRequest):HistoryResponse {
        if (request.catalog != null) {
            // Detach the snapshot before enriching it on this worker.
            currentActivities = request.catalog.activities;
            catalog = {activities: request.catalog.activities.copy(), names: request.catalog.names, bosses: request.catalog.bosses,
                difficulties: request.catalog.difficulties,
                bossCategories: request.catalog.bossCategories == null ? [] : request.catalog.bossCategories.copy()};
            for (boss => category in learnedBosses) {
                if (category == HistoryCategory.OTHER) catalog.bossCategories[boss] = category;
                else HistoryCategory.observeBoss(catalog.bossCategories, boss, category);
            }
            for (activity => entry in learned) if (!catalog.activities.exists(activity)
                || catalog.activities[activity] == HistoryCategory.OTHER) catalog.activities[activity] = entry.category;
        }
        index();
        var response:HistoryResponse = {id: request.id, page: 0, total: 0, groups: [], entries: [], record: null, error: ""};
        if (request.action == "delete") {
            if (!entries.exists(request.fightId)) throw "This fight log could not be found.";
            var path = paths[request.fightId];
            if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) throw "This fight log could not be found.";
            // The existing .json.tmp recovery handles a crash during the shell
            // operation too. Keep this backup until recycling is confirmed.
            // Even an unexpected OS permanent-delete fallback cannot lose the log.
            var backup = path + ".tmp";
            File.copy(path, backup);
            var sidecar = path + ".timeline";
            var hasDetail = FileSystem.exists(sidecar);
            if (hasDetail) File.copy(sidecar, sidecar + ".tmp");
            try {
                recycle(FileSystem.fullPath(path));
                if (FileSystem.exists(path)) throw "The log is still in the history folder; it was not removed from the list.";
                if (hasDetail) {
                    recycle(FileSystem.fullPath(sidecar));
                    if (FileSystem.exists(sidecar)) throw "The detailed report was not recycled; the fight was restored.";
                    FileSystem.deleteFile(sidecar + ".tmp");
                }
                FileSystem.deleteFile(backup); // Only the confirmed-recycled backup.
            } catch (error:Dynamic) {
                if (!FileSystem.exists(path)) FileSystem.rename(backup, path);
                else if (FileSystem.exists(backup)) FileSystem.deleteFile(backup);
                if (hasDetail && FileSystem.exists(sidecar + ".tmp")) {
                    if (!FileSystem.exists(sidecar)) FileSystem.rename(sidecar + ".tmp", sidecar);
                    else FileSystem.deleteFile(sidecar + ".tmp");
                }
                throw error;
            }
            if (detailedId == request.fightId) { detailedId = ""; detailedData = null; }
            entries.remove(request.fightId);
            paths.remove(request.fightId);
        } else if (request.action == "detailed") {
            if (!entries.exists(request.fightId)) throw "This fight log could not be found.";
            if (detailedId != request.fightId) {
                detailedData = TimelineStore.read(paths[request.fightId]); detailedId = request.fightId;
            }
            if (detailedData == null) response.error = "Detailed recording is unavailable for this fight.";
            else response.record = DetailedReport.query(detailedData, request);
        } else if (request.action == "chart") {
            if (!entries.exists(request.fightId)) throw "This fight log could not be found.";
            response.record = Json.parse(File.getContent(paths[request.fightId]));
            FightHistory.validate(response.record);
            // The index may have recovered metadata from a surviving export.
            // Apply it to this detached read too, without rewriting the log.
            var summary = entries[request.fightId];
            if (!RiftRecapHistory.isRecap(response.record)) {
                response.record.difficulty = summary.difficulty;
                response.record.partySize = summary.partySize;
            }
        } else if (request.action == "categories") {
            var counts:Map<String, Int> = [];
            for (entry in entries) {
                var category = HistoryCategory.resolve(entry, catalog);
                counts[category] = counts.exists(category) ? counts[category] + 1 : 1;
            }
            response.groups = [for (name in HistoryCategory.all()) {name: name, count: counts.exists(name) ? counts[name] : 0}];
            response.total = response.groups.length;
            // Use the existing summary index: opening the home page never
            // reads full reports or inherits filters from an encounter folder.
            var recent = [for (entry in entries) entry];
            recent.sort((a, b) -> HistoryOptions.compare(a, b, "date", false));
            response.recent = [for (entry in recent.slice(0, FightHistory.RECENT_COUNT)) {
                entry: entry, category: HistoryCategory.resolve(entry, catalog), group: HistoryCategory.encounterName(entry, catalog)
            }];
        } else if (request.action == "groups") {
            var counts:Map<String, Int> = [];
            for (entry in entries) if (matches(entry, request.category)) {
                var name = HistoryCategory.encounterName(entry, catalog);
                counts[name] = counts.exists(name) ? counts[name] + 1 : 1;
            }
            var groups = [for (name => count in counts) {name: name, count: count}];
            groups.sort((a, b) -> Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
            response.total = groups.length;
            response.page = page(request.page, response.total);
            response.groups = groups.slice(response.page * FightHistory.PAGE_SIZE, (response.page + 1) * FightHistory.PAGE_SIZE);
        } else if (request.action == "fights") {
            response.characters = HistoryOptions.characters(entries.iterator());
            var fights = [for (entry in entries) if (matches(entry, request.category)
                && HistoryCategory.encounterName(entry, catalog) == request.group
                && HistoryOptions.matches(entry, request.character, request.outcome)) entry];
            fights.sort((a, b) -> HistoryOptions.compare(a, b, request.sortBy, request.ascending == true));
            response.total = fights.length;
            response.page = page(request.page, response.total);
            response.entries = fights.slice(response.page * FightHistory.PAGE_SIZE, (response.page + 1) * FightHistory.PAGE_SIZE);
        } else throw "Unknown history action.";
        return response;
    }
    public function bossRecord(request:BossRecords.BossRecordRequest):BossRecords.BossRecordResponse {
        // Unknown identity/difficulty cannot establish a same-character,
        // same-difficulty record. Never guess using the displayed boss name.
        if (request.bossKind == "" || request.playerName == "" || request.playerClass == ""
            || request.difficulty < 0 || !Math.isFinite(request.before) || request.before <= 0)
            return {id: request.id, best: null, error: "Missing encounter identity or difficulty."};
        index();
        return {id: request.id, best: BossRecords.best(entries.iterator(), request), error: ""};
    }
    function matches(entry:HistoryEntry, category:Null<String>):Bool
        return category == null || category == "" || HistoryCategory.resolve(entry, catalog) == category;
    function restoreLegacyMetadata(record:Dynamic):Void {
        var id = FightHistory.text(record.id);
        if (!StringTools.startsWith(id, "legacy_") || (FightHistory.text(record.activityId) != "" && record.difficulty != null)) return;
        if (legacyMetadata == null) {
            legacyMetadata = [];
            // The original history release omitted these fields. Its stable
            // legacy ID lets us recover exact metadata from retained reports,
            // without matching by time/name or rewriting any user's log.
            for (source in [root + "/logs", root + "/logs/sent", root + "/logs/rejected"])
                if (FileSystem.exists(source)) for (name in FileSystem.readDirectory(source)) {
                    if (!StringTools.startsWith(name, "run_") || !StringTools.endsWith(name, ".json")) continue;
                    var path = source + "/" + name;
                    if (FileSystem.isDirectory(path)) continue;
                    try {
                        var report:Dynamic = Json.parse(File.getContent(path));
                        var key = FightHistory.text(report.session_id);
                        if (key == "") key = name;
                        legacyMetadata["legacy_" + haxe.crypto.Md5.encode(key)] = {
                            activityId: FightHistory.text(report.activity_id), bossKind: FightHistory.text(report.boss_kind),
                            phase: FightHistory.text(report.phase), difficulty: FightHistory.difficulty(report.difficulty),
                            partySize: Std.int(FightHistory.number(report.party_size))
                        };
                    } catch (_:Dynamic) {}
                }
        }
        var metadata = legacyMetadata[id];
        if (metadata != null) for (field in ["activityId", "bossKind", "phase", "difficulty", "partySize"])
            if (Reflect.field(record, field) == null || Reflect.field(record, field) == "")
                Reflect.setField(record, field, Reflect.field(metadata, field));
    }
    static function page(requested:Int, total:Int):Int return Std.int(Math.max(0,
        Math.min(requested, Math.max(0, Math.ceil(total / FightHistory.PAGE_SIZE) - 1))));
    /** The supported layout is history/<encounter>/<id>.json, plus old flat logs.
        Do not recursively traverse unrelated folders or directory-link cycles. */
    function archiveFiles():Array<String> {
        var grouped:Array<String> = [], flat:Array<String> = [];
        var names = FileSystem.readDirectory(folder);
        names.sort(Reflect.compare);
        for (name in names) {
            var path = folder + "/" + name;
            if (!FileSystem.isDirectory(path)) flat.push(path);
            else {
                try {
                    var children = FileSystem.readDirectory(path);
                    children.sort(Reflect.compare);
                    for (child in children) {
                        var file = path + "/" + child;
                        if (!FileSystem.isDirectory(file)) grouped.push(file);
                    }
                } catch (e:Dynamic) log("Could not read history folder " + path + ": " + Std.string(e));
            }
        }
        return grouped.concat(flat);
    }
    function migrate(path:String, entry:HistoryEntry):String {
        if (Path.directory(path) != folder) return path;
        var target = recordPath(entry);
        try {
            // Do not strand a different/invalid recovery draft in the old
            // location where it might resurrect the moved log on next launch.
            if (FileSystem.exists(path + ".tmp")) throw "An unresolved recovery draft remains beside this log.";
            FileSystem.createDirectory(Path.directory(target));
            if (FileSystem.exists(target)) throw "Destination already exists.";
            // Rename preserves the original bytes and is restart-safe. Failed
            // moves remain browsable at their old path and retry next launch.
            var movedDetail = false;
            if (FileSystem.exists(path + ".timeline")) {
                if (FileSystem.exists(target + ".timeline")) throw "Detailed report destination already exists.";
                FileSystem.rename(path + ".timeline", target + ".timeline"); movedDetail = true;
            }
            try FileSystem.rename(path, target) catch (e:Dynamic) {
                if (movedDetail) FileSystem.rename(target + ".timeline", path + ".timeline");
                throw e;
            }
            return target;
        } catch (e:Dynamic) log("Could not organize " + path + ": " + Std.string(e));
        return path;
    }
    function recordPath(entry:HistoryEntry):String
        return folder + "/" + HistoryCategory.folderName(entry, catalog) + "/" + filename(entry.id);
    static function filename(id:String):String {
        if (!~/^[A-Za-z0-9_-]+$/.match(id)) throw "Invalid fight log ID.";
        return id + ".json";
    }
}
