import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import itemutilities.InspectSupport;

class InspectSupportTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function index(out:BytesOutput, value:Int):Void {
        if (value < 0x80) out.writeByte(value);
        else if (value < 0x2000) {
            out.writeByte(0x80 | (value >> 8)); out.writeByte(value & 255);
        } else {
            out.writeByte(0xC0 | (value >> 24)); out.writeByte((value >> 16) & 255);
            out.writeByte((value >> 8) & 255); out.writeByte(value & 255);
        }
    }
    static function fixture(version:Int, names:Array<String>):Bytes {
        var out = new BytesOutput();
        out.writeString("HLB"); out.writeByte(version);
        index(out, 1); index(out, 129); index(out, 2); index(out, names.length);
        if (version >= 5) index(out, 0);
        for (i in 0...6) index(out, i);
        out.write(Bytes.alloc(129 * 4 + 2 * 8));
        var strings = new BytesOutput(), lengths:Array<Int> = [];
        for (name in names) {
            var bytes = Bytes.ofString(name);
            strings.write(bytes); strings.writeByte(0); lengths.push(bytes.length);
        }
        var block = strings.getBytes();
        out.writeInt32(block.length); out.write(block);
        for (length in lengths) index(out, length);
        return out.getBytes();
    }
    static function rejects(bytes:Bytes):Bool {
        try { InspectSupport.hasSocialMenu(new BytesInput(bytes)); return false; }
        catch (_:Dynamic) return true;
    }
    static function main():Void {
        var menu = "openPlayerInteractionMenu";
        for (version in [4, 5, 6]) {
            check(!InspectSupport.hasSocialMenu(new BytesInput(fixture(version, ["ui.GameUI", "displayContextMenu"]))),
                "clients without the social method must not register its hook");
            check(InspectSupport.hasSocialMenu(new BytesInput(fixture(version, ["ui.GameUI", menu]))),
                "capability detection does not assume a particular bytecode version");
        }
        check(!InspectSupport.hasSocialMenu(new BytesInput(fixture(6, ["ui.GameUI", menu + "Tip"]))),
            "a substring in another name is not the menu method");
        check(!InspectSupport.hasSocialMenu(new BytesInput(fixture(6, [menu]))), "require the game UI metadata too");
        var longName = StringTools.lpad("", "x", 9000);
        var supported = fixture(6, ["", "日本語", longName, "ui.GameUI", menu]);
        check(InspectSupport.hasSocialMenu(new BytesInput(supported)), "UTF-8 byte lengths and four-byte indices are parsed correctly");
        for (cut in [0, 3, 12, 530, supported.length - 1])
            check(rejects(supported.sub(0, cut)), "truncated metadata cannot install a partial hook set");
        var corrupt = fixture(6, ["ui.GameUI", menu]);
        corrupt.set(0, 0);
        check(rejects(corrupt), "reject an invalid bytecode magic");
        corrupt = fixture(6, ["ui.GameUI", menu]); corrupt.set(3, 7);
        check(rejects(corrupt), "unknown bytecode layouts are reported rather than guessed");

        // Regression: install registration must work before ANY live reflection
        // exists. This path has no game/HLX dependency and performs registration
        // now, not after the loader has already installed its pending patches.
        var path = 'inspect-startup-test-${Std.random(0x3fffffff)}.tmp';
        var registrations = 0;
        try {
            sys.io.File.saveBytes(path, supported);
            check(InspectSupport.registerForClient(path, () -> registrations++), "PTR registration runs during mod initialization");
            check(registrations == 1, "register exactly once without any live type lookup");
            sys.io.File.saveBytes(path, fixture(4, ["ui.GameUI"]));
            check(!InspectSupport.registerForClient(path, () -> registrations++), "live client cleanly skips unsupported hook");
            sys.io.File.saveBytes(path, supported.sub(0, 12));
            var failed = false;
            try InspectSupport.registerForClient(path, () -> registrations++) catch (_:Dynamic) failed = true;
            check(failed && registrations == 1, "failed reads do not register hooks");
        } catch (error:Dynamic) {
            if (sys.FileSystem.exists(path)) sys.FileSystem.deleteFile(path);
            throw error;
        }
        sys.FileSystem.deleteFile(path);
        trace('Inspect startup: $checks checks passed');
    }
}
