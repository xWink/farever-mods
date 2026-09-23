package itemutilities;

import haxe.io.Input;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** Startup capability check, before HLX recovers the live game's reflection data. */
class InspectSupport {
    static inline var MENU_METHOD = "openPlayerInteractionMenu";
    static inline var MAX_TABLE = 32 * 1024 * 1024;

    public static function clientPath():String {
        // The bytecode normally lives beside the game executable. HL may report
        // the module path instead; the loader also requires the game's working
        // directory, so keep that as the fallback.
        var besideProgram = Path.join([Path.directory(Sys.programPath()), "hlboot.dat"]);
        for (path in [besideProgram, "hlboot.dat"])
            if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path;
        throw "Could not locate hlboot.dat for the Inspect compatibility check";
    }

    public static function registerForClient(path:String, register:Void->Void):Bool {
        var input = File.read(path, true);
        var supported:Bool;
        try supported = hasSocialMenu(input)
        catch (error:Dynamic) { input.close(); throw error; }
        input.close();
        if (supported) register();
        return supported;
    }

    public static function hasSocialMenu(input:Input):Bool {
        input.bigEndian = false;
        if (input.readString(3) != "HLB") throw "Invalid game bytecode header";
        var version = input.readByte();
        if (version < 4 || version > 6) throw "Unsupported game bytecode version: " + version;
        index(input); // flags
        var ints = index(input), floats = index(input), strings = index(input);
        if (version >= 5) index(input); // byte-constant count
        for (_ in 0...6) index(input); // types, globals, natives, functions, constants, entrypoint
        if (ints > MAX_TABLE / 4 || floats > MAX_TABLE / 8 || strings > MAX_TABLE)
            throw "Invalid game bytecode table size";
        var remaining = ints * 4 + floats * 8;
        if (remaining > MAX_TABLE) throw "Invalid game bytecode constant size";
        while (remaining > 0) {
            var amount = Std.int(Math.min(4096, remaining));
            input.read(amount);
            remaining -= amount;
        }
        var size = input.readInt32();
        if (size < 0 || size > MAX_TABLE || strings > size) throw "Invalid game bytecode string table";
        var table = input.read(size);
        if (table.length != size) throw "Truncated game bytecode string table";
        var offset = 0, found = false, gameUI = false;
        // The table stores UTF-8 strings, then one length per string. Match whole
        // metadata names, not a bytecode-version guess or a substring in a label.
        for (_ in 0...strings) {
            var length = index(input);
            if (length >= size - offset || table.get(offset + length) != 0)
                throw "Invalid game bytecode string length";
            if (length == MENU_METHOD.length && table.getString(offset, length) == MENU_METHOD) found = true;
            if (length == 9 && table.getString(offset, length) == "ui.GameUI") gameUI = true;
            offset += length + 1;
        }
        if (offset != size) throw "Invalid game bytecode string count";
        return found && gameUI;
    }

    static function index(input:Input):Int {
        var first = input.readByte();
        if (first < 0x80) return first;
        if ((first & 0x20) != 0) throw "Negative game bytecode index";
        if (first < 0xC0) return ((first & 0x1F) << 8) | input.readByte();
        var value = (first & 0x1F) << 24;
        value |= input.readByte() << 16;
        value |= input.readByte() << 8;
        return value | input.readByte();
    }
}
