package modui;

/** Resolve native flags by name so renamed or missing variants cannot break a window. */
class WindowFlags {
    static function read(name:String, lookup:String->Dynamic):Dynamic {
        try return lookup(name) catch (_:Dynamic) return null;
    }

    public static function resolve(names:Array<String>, lookup:String->Dynamic)
        :{mask:Int, found:Int, missing:Array<String>} {
        var mask = 0, found = 0, missing:Array<String> = [];
        for (name in names) {
            var flag = read(name, lookup);
            // The October 28 client renamed NeedLayer to NeedGameLayer.
            // Keep older Live/PTR clients on their native variant as well.
            if (flag == null && name == "NeedLayer") flag = read("NeedGameLayer", lookup);
            var index = -1;
            if (flag != null) try index = Type.enumIndex(flag) catch (_:Dynamic) {}
            if (index < 0 || index >= 31) { missing.push(name); continue; }
            mask |= 1 << index;
            found++;
        }
        return {mask:mask, found:found, missing:missing};
    }
}
