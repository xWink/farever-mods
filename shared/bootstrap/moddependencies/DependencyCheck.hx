package moddependencies;

import sys.FileSystem;
import sys.io.File;

/** The entry module uses no mod or game code before this check passes. */
class DependencyCheck {
    public static function title(id:String):String {
        return switch (id) {
            case "dps-meter": "DPS Meter";
            case "minimap": "Minimap";
            case "item-utilities": "Item Utilities";
            case "more-settings": "More Settings";
            case "fix-target-lock": "Fix Target Lock";
            default: throw "Unknown dependency-checked mod: " + id;
        };
    }

    public static function missing(settingsInstalled:Bool, updateAlertsInstalled:Bool):Array<String> {
        var result = [];
        if (!settingsInstalled) result.push("Better Mod Settings");
        if (!updateAlertsInstalled) result.push("Mod Update Alerts");
        return result;
    }

    public static function message(id:String, missing:Array<String>):String {
        return title(id) + " cannot start. Missing critical dependencies:\n\n"
            + [for (name in missing) "- " + name].join("\n")
            + "\n\nInstall or enable these dependencies, deploy them in Vortex "
            + "(or extract their complete archives into the Farever game folder), then restart Farever."
            + (missing.indexOf("Better Mod Settings") < 0 ? ""
                : "\n\nBetter Mod Settings: https://www.nexusmods.com/farever/mods/10")
            + (missing.indexOf("Mod Update Alerts") < 0 ? ""
                : "\n\nMod Update Alerts: https://www.nexusmods.com/farever/mods/17")
            + "\n\nFarever will close when you dismiss this message.";
    }

    public static function isBytecode(path:String):Bool {
        // Read through Vortex's symbolic link to the actual binary. Windows
        // _wstat can report a valid link as zero bytes, so metadata size is not
        // a reliable prerequisite. Require the magic AND a version byte;
        // missing files, directories, broken links and short reads still fail.
        try {
            if (FileSystem.isDirectory(path)) return false;
            var file = File.read(path, true);
            var header = try file.read(4) catch (e:Dynamic) {
                file.close();
                return false;
            };
            file.close();
            return header.get(0) == 0x48 && header.get(1) == 0x4C && header.get(2) == 0x42;
        } catch (_:Dynamic) return false;
    }

    public static function matchesImplementation(path:String, hash:String):Bool {
        try return isBytecode(path) && haxe.crypto.Sha256.make(File.getBytes(path)).toHex() == hash
        catch (_:Dynamic) return false;
    }
}
