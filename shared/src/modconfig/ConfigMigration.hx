package modconfig;

import sys.FileSystem;
import sys.io.File;

/** Import an old module's settings or mod-local JSON. Current native files take priority. */
class ConfigMigration {
    public static function hasNative():Bool {
        return FileSystem.exists("hlx/config/" + HlxRuntime.moduleName() + "/config.json");
    }

    public static function importLegacy(?previousModule:String):Bool {
        var modName = HlxRuntime.moduleName();
        var sourceName = previousModule == null ? modName : previousModule;
        var legacyPath = "hlx/mods/" + sourceName + "/config.json";
        if (previousModule != null) {
            var previousNativePath = "hlx/config/" + previousModule + "/config.json";
            if (FileSystem.exists(previousNativePath)) legacyPath = previousNativePath;
        }
        if (hasNative() || !FileSystem.exists(legacyPath)) return false;
        // Let HLX load the copied file and apply its usual defaults/recovery.
        // Leave the original file intact as a backup.
        var nativeDir = "hlx/config/" + modName;
        FileSystem.createDirectory(nativeDir);
        File.copy(legacyPath, nativeDir + "/config.json");
        return true;
    }
}
