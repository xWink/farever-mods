package modconfig;

import sys.FileSystem;
import sys.io.File;

/** One-time import from the old mod-local JSON files. Native files take priority. */
class ConfigMigration {
    public static function hasNative():Bool {
        return FileSystem.exists("hlx/config/" + HlxRuntime.moduleName() + "/config.json");
    }

    public static function importLegacy():Bool {
        var modName = HlxRuntime.moduleName();
        var legacyPath = "hlx/mods/" + modName + "/config.json";
        if (hasNative() || !FileSystem.exists(legacyPath)) return false;
        // Let HLX load the copied file and apply its usual defaults/recovery.
        // Leave the original file intact as a backup.
        var nativeDir = "hlx/config/" + modName;
        FileSystem.createDirectory(nativeDir);
        File.copy(legacyPath, nativeDir + "/config.json");
        return true;
    }
}
