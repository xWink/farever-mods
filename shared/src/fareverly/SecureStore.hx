package fareverly;
import fareverly.Protocol.Credential;
import sys.FileSystem;
import sys.io.File;

/** The sole credential file, shared by mods. Never copy it into ordinary mod configs. */
class SecureStore {
    public static inline var RELATIVE_PATH = "hlx/config/fareverly/account.json";
    public static function path():String return haxe.io.Path.join([Sys.getCwd(), RELATIVE_PATH]);
    public static function read(?file:String):Credential {
        if (file == null) file = path();
        if (!FileSystem.exists(file)) return Protocol.empty();
        if (FileSystem.stat(file).size > 4096) throw "Fareverly account settings could not be read.";
        var value:Credential;
        try value = haxe.Json.parse(File.getContent(file)) catch (_:Dynamic) throw "Fareverly account settings could not be read.";
        if (value == null || !Std.isOfType(value.accessToken, String) || (value.accessToken != "" && !Protocol.validKey(value.accessToken))
            || !Std.isOfType(value.accountId, String) || !Std.isOfType(value.steamId, String) || !Std.isOfType(value.expiresAt, String))
            throw "Fareverly account settings could not be read.";
        return value;
    }
    public static function save(value:Credential):Void {
        var file = path();
        FileSystem.createDirectory(haxe.io.Path.directory(file));
        NativeAccount.write(file, haxe.Json.stringify(value));
    }
}
