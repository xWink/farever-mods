package moresettings;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

/** Character database IDs, never names or list positions. Separate from BMS config. */
class CharacterLockStore {
    var path:String;
    var locks:Map<String, Bool> = [];
    var loaded = false;
    var loadError:Dynamic;
    public function new(path:String) this.path = path;

    public static function valid(id:String):Bool
        return id != null && ~/^[1-9][0-9]*$/.match(id);

    function load():Void {
        if (loadError != null) throw loadError;
        if (loaded) return;
        try {
            var source = FileSystem.exists(path) ? path : path + ".bak";
            if (FileSystem.exists(source)) {
                var data:Dynamic = haxe.Json.parse(File.getContent(source));
                if (data == null || data.version != 1 || !Std.isOfType(data.characters, Array))
                    throw "Invalid character locks file; existing file has been preserved.";
                var rows:Array<Dynamic> = data.characters;
                var next:Map<String, Bool> = [];
                for (id in rows) {
                    if (!Std.isOfType(id, String) || !valid(id)) throw "Invalid saved character ID.";
                    next[id] = true;
                }
                locks = next;
            }
            loaded = true;
        } catch (error:Dynamic) {
            loadError = error;
            throw error;
        }
    }

    public function locked(id:String):Bool {
        load();
        if (!valid(id)) throw "Character ID is unavailable.";
        return locks.exists(id);
    }

    public function set(id:String, locked:Bool):Void {
        var previous = this.locked(id);
        if (previous == locked) return;
        // Copy across module string identities before serializing JSON.
        var copy = new StringBuf(); copy.add(id); id = copy.toString();
        if (locked) locks[id] = true; else locks.remove(id);
        try {
            var rows = [for (id in locks.keys()) id];
            rows.sort(Reflect.compare);
            FileSystem.createDirectory(Path.directory(path));
            File.saveContent(path + ".tmp", haxe.Json.stringify({version: 1, characters: rows}, null, "  "));
            var previousFile = FileSystem.exists(path);
            if (previousFile) {
                if (FileSystem.exists(path + ".bak")) FileSystem.deleteFile(path + ".bak");
                FileSystem.rename(path, path + ".bak");
            }
            try FileSystem.rename(path + ".tmp", path) catch (error:Dynamic) {
                if (previousFile) FileSystem.rename(path + ".bak", path);
                throw error;
            }
        } catch (error:Dynamic) {
            if (previous) locks[id] = true; else locks.remove(id);
            throw error;
        }
    }
}
