package modconfig;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** Shared top-level settings. Never imports a mod's private configuration. */
class CommonSettings {
    public static inline var PATH = "hlx/config/common/config.json";
    public static inline var CHANGED_TOPIC = "better-mod-settings/config-changed/common";

    public static function isCommon(definition:Dynamic):Bool {
        if (Reflect.field(definition, "isCommon") != true) return false;
        return switch (Reflect.field(definition, "type")) {
            case "checkbox", "slider", "text", "dropdown", "keybinding": true;
            default: false;
        };
    }

    public static function read(?path:String):Dynamic {
        if (path == null) path = PATH;
        if (!FileSystem.exists(path)) return {};
        var values:Dynamic;
        try values = Json.parse(File.getContent(path))
        catch (_:Dynamic) throw "Common settings could not be read.";
        if (values == null || !Reflect.isObject(values) || Std.isOfType(values, Array)
            || Std.isOfType(values, String)) throw "Common settings must be a JSON object.";
        return values;
    }

    /** Merge into the UI snapshot only, including removing absent common keys. */
    public static function overlay(values:Dynamic, definitions:Array<Dynamic>, common:Dynamic):Void {
        for (definition in definitions) if (isCommon(definition)) {
            var key:String = Reflect.field(definition, "key");
            if (key == null || key == "") continue;
            if (Reflect.hasField(common, key)) Reflect.setField(values, key, Reflect.field(common, key));
            else Reflect.deleteField(values, key);
        }
    }

    /** Read immediately before writing so other mods' fields are preserved. */
    public static function write(key:String, value:Dynamic, ?path:String):Void {
        if (path == null) path = PATH;
        var values = read(path);
        Reflect.setField(values, key, value);
        FileSystem.createDirectory(Path.directory(path));
        File.saveContent(path, Json.stringify(values, null, "  "));
    }
}
