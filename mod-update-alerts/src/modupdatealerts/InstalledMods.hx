package modupdatealerts;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import modupdatealerts.UpdateModel.InstalledMod;

typedef DeployedMod = {
    var source:String;
    var files:Array<String>;
    var metadata:Null<InstalledMod>;
}

/** Read-only discovery. Deployment files select installed mods, never the whole staging library. */
class InstalledMods {
    public var diagnostics:Array<String> = [];
    public var manual:Array<InstalledMod> = [];
    public var deployed:Array<DeployedMod> = [];
    public var retryable:Bool = false;
    public function new() {}

    public static function text(value:Dynamic, key:String):String {
        var field:Dynamic = value == null ? null : Reflect.field(value, key);
        return Std.isOfType(field, String) ? StringTools.trim(field) : "";
    }
    public static function id(value:Dynamic):Int {
        if (value == null || !~/^[1-9][0-9]{0,8}$/.match(Std.string(value))) return 0;
        return Std.parseInt(Std.string(value));
    }
    public static function safeRelative(value:String):Bool {
        if (value == null || value == "") return false;
        var path = StringTools.replace(value, "\\", "/");
        return !Path.isAbsolute(path) && path.indexOf(":") < 0
            && path.indexOf("\x00") < 0 && path.split("/").indexOf("..") < 0;
    }
    static function read(path:String, limit:Int):Dynamic {
        if (FileSystem.stat(path).size > limit) throw "Metadata file is too large";
        return haxe.Json.parse(File.getContent(path));
    }

    public function scan(root:String, ?vortexPath:String, ?progress:Void->Void):Void {
        if (progress == null) progress = function() {};
        diagnostics = []; manual = []; deployed = []; retryable = false;
        var readFailed = false;
        var records:Map<String,Dynamic> = [];
        if (vortexPath == null || vortexPath == "") {
            var appData = Sys.getEnv("APPDATA");
            if (appData != null) vortexPath = Path.join([appData, "Vortex"]);
        }
        if (vortexPath != null && vortexPath != "") {
            try records = VortexState.read(vortexPath, progress)
            catch (error:Dynamic) {
                readFailed = true; retryable = true;
                diagnostics.push("Could not read current Vortex mod records (" + Std.string(error)
                    + "); backup snapshots and archive folder versions are not used.");
            }
        }

        var groups:Map<String,DeployedMod> = [];
        var stale:Map<String,Bool> = [];
        // Vortex writes one deployment manifest per target directory/mod type.
        for (relative in ["", "hlx", "hlx/mods", "hlx/plugins"]) {
            var folder = Path.join([root,relative]);
            if (!FileSystem.exists(folder)) continue;
            for (name in FileSystem.readDirectory(folder)) {
                if (!StringTools.startsWith(name,"vortex.deployment.") || !StringTools.endsWith(name,".json")) continue;
                try {
                    var manifest = read(Path.join([folder,name]), 16 * 1024 * 1024);
                    if (text(manifest,"gameId") != "" && text(manifest,"gameId") != "farever") continue;
                    var files:Dynamic = Reflect.field(manifest,"files");
                    if (!Std.isOfType(files,Array)) continue;
                    var staging = text(manifest,"stagingPath");
                    for (file in (cast files:Array<Dynamic>)) {
                        progress();
                        var source = text(file,"source"), rel = text(file,"relPath"), target = text(file,"target");
                        if (!safeRelative(source) || !safeRelative(rel) || (target != "" && !safeRelative(target))) continue;
                        var extension=Path.extension(rel).toLowerCase();
                        if (["hl","dll","hdll","pak"].indexOf(extension)<0) continue;
                        var path = Path.join([folder,target,rel]);
                        if (!FileSystem.exists(path) || FileSystem.isDirectory(path)) {stale.set(source,true);continue;}
                        // Exclude purged/replaced files and stale deployment records.
                        var time:Dynamic = Reflect.field(file,"time");
                        var timestamp = Std.parseFloat(Std.string(time));
                        if (!Math.isFinite(timestamp) || Math.abs(FileSystem.stat(path).mtime.getTime() - timestamp) > 2100) {stale.set(source,true);continue;}
                        // Vortex can update in place and reuse an old archive's
                        // folder name. Bind the live record to deployed contents.
                        if (staging == "" || !Path.isAbsolute(staging)
                            || !sameContents(path, Path.join([staging,source,rel]))) {stale.set(source,true);continue;}
                        var entry = groups.get(source);
                        if (entry == null) {
                            entry = {source:source,files:[],metadata:fromVortex(records.get(source))};
                            groups.set(source,entry);
                        }
                        entry.files.push(path);
                    }
                } catch (_:Dynamic) diagnostics.push("Could not read deployment manifest " + name);
            }
        }
        for (entry in groups) if (!stale.exists(entry.source)) deployed.push(entry);
        for (source in stale.keys()) diagnostics.push("Deployed files changed, missing, or do not match current Vortex staging; cannot verify version: "+source);
        deployed.sort((a,b) -> Reflect.compare(a.source,b.source));
        // Detect installs/uninstalls that raced with binary verification. A
        // valid old read must not label newer files with the previous version.
        if (!readFailed && deployed.length > 0 && vortexPath != null && vortexPath != "") {
            var fresh:Map<String,Dynamic> = [];
            try fresh = VortexState.read(vortexPath, progress) catch (error:Dynamic) {
                readFailed = true; retryable = true;
                diagnostics.push("Could not recheck current Vortex mod records: " + Std.string(error));
            }
            for (entry in deployed) {
                var current = fromVortex(fresh[entry.source]);
                if (readFailed || haxe.Json.stringify(entry.metadata) != haxe.Json.stringify(current)) {
                    entry.metadata = null;
                    retryable = true;
                    if (!readFailed) diagnostics.push("Vortex mod record changed during verification; skipping: "+entry.source);
                }
            }
        }

        // Manual installs can opt in with metadata bound to an actual binary hash.
        var modRoot = Path.join([root,"hlx","mods"]);
        var manualPaths:Map<String,Bool> = [];
        if (FileSystem.exists(modRoot)) for (folder in FileSystem.readDirectory(modRoot)) {
            progress();
            var base = Path.join([modRoot,folder]), path = Path.join([base,"update-info.json"]);
            if (!FileSystem.exists(path)) continue;
            try {
                var info = read(path, 16384);
                var entry = fromInfo(info);
                var binary = text(info,"binary"), hash = text(info,"sha256").toLowerCase();
                if (entry == null || !safeRelative(binary) || !~/^[a-f0-9]{64}$/.match(hash)) continue;
                var binPath = Path.join([base,binary]);
                if (!FileSystem.exists(binPath) || FileSystem.stat(binPath).size > 64 * 1024 * 1024) continue;
                if (haxe.crypto.Sha256.make(File.getBytes(binPath)).toHex() != hash) continue;
                manual.push(entry);
                manualPaths[base] = true;
            } catch (_:Dynamic) diagnostics.push("Could not read update metadata for " + folder);
        }
        // Report unidentified HLX modules instead of pretending all were checked.
        if (FileSystem.exists(modRoot)) for (folder in FileSystem.readDirectory(modRoot)) {
            var base = Path.join([modRoot,folder]);
            if (!FileSystem.isDirectory(base)) continue;
            var binaries = [for (name in FileSystem.readDirectory(base)) if (StringTools.endsWith(name,".hl")) Path.join([base,name])];
            if (binaries.length == 0) continue;
            var found = manualPaths.exists(base);
            for (entry in deployed) for (binary in binaries) if (entry.files.indexOf(binary) >= 0) found = true;
            // Our test build has no Nexus identity until it is published.
            if (!found && folder!="mod-update-alerts") diagnostics.push("No installed-version metadata for " + folder);
        }
    }

    public static function fromVortex(record:Dynamic):Null<InstalledMod> {
        if (record == null || text(record,"state") != "installed") return null;
        var a = Reflect.field(record,"attributes");
        if (text(a,"source") != "nexus") return null;
        var domain = text(a,"downloadGame");
        if (domain == "") {
            var games:Dynamic = Reflect.field(a,"game");
            if (Std.isOfType(games,Array) && (cast games:Array<Dynamic>).length == 1) domain = Std.string(games[0]);
        }
        if (domain == "") domain = "farever";
        return fromInfo({name:text(a,"name"),version:text(a,"version"),domain:domain,modId:Reflect.field(a,"modId")});
    }
    public static function fromInfo(info:Dynamic):Null<InstalledMod> {
        var domain=text(info,"domain"), version=text(info,"version"), name=text(info,"name");
        var modId=id(info==null?null:Reflect.field(info,"modId"));
        if (modId==0 || !~/^[a-z0-9_-]{1,64}$/.match(domain) || version=="" || version.length>80) return null;
        return {name:name==""?domain+"/"+modId:name,domain:domain,modId:modId,version:version};
    }

    static function sameContents(a:String, b:String):Bool {
        try {
            if (!FileSystem.exists(b) || FileSystem.isDirectory(b)) return false;
            var size = FileSystem.stat(a).size;
            if (size > 64 * 1024 * 1024 || size != FileSystem.stat(b).size) return false;
            return haxe.crypto.Sha256.make(File.getBytes(a)).compare(haxe.crypto.Sha256.make(File.getBytes(b))) == 0;
        } catch (_:Dynamic) return false;
    }
}
