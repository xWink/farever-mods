package slashcommands;

class LayerQuery {
    // The realm/query response has no documented active-instance list. Extract
    // only explicitly named serverID fields from server/layout records, never
    // realm IDs, logical sids, map names, lobby IDs or strings that just look
    // like connection addresses. This cannot establish completeness/liveness.
    public static function serverIDs(response:Dynamic):Array<String> {
        var result:Array<String> = [];
        if (response == null)
            return result;
        for (name in ["layout", "servers", "instances", "layers"])
            visit(Reflect.field(response, name), result, 0);
        return result;
    }

    static function visit(value:Dynamic, result:Array<String>, depth:Int):Void {
        if (value == null || depth > 32)
            return;
        if (Std.isOfType(value, Array)) {
            for (entry in (cast value:Array<Dynamic>))
                visit(entry, result, depth + 1);
        } else if (Reflect.isObject(value) && !Std.isOfType(value, String)) {
            var id:Dynamic = Reflect.field(value, "serverID");
            if (Std.isOfType(id, String) && LayerCommand.isLayerID(id) && result.indexOf(id) < 0)
                result.push(id);
            for (name in Reflect.fields(value)) {
                // Arbitrary metadata and connection configuration are not an
                // instance directory. In particular, don't echo credentials.
                if (name != "serverID" && name != "meta" && name != "config" && name != "userDefinedParams")
                    visit(Reflect.field(value, name), result, depth + 1);
            }
        }
    }

    public static function shape(response:Dynamic):String {
        // A small schema-only diagnostic helps identify an unsupported server
        // response without writing its contents or session data into the log.
        if (response == null)
            return "null";
        var fields = Reflect.fields(response);
        fields.sort(Reflect.compare);
        var layout:Dynamic = Reflect.field(response, "layout");
        var detail = "";
        if (Std.isOfType(layout, Array)) {
            var entries:Array<Dynamic> = cast layout;
            detail = "; layout entries=" + entries.length;
            if (entries.length > 0 && entries[0] != null && !Std.isOfType(entries[0], String))
                detail += "; first entry fields=" + Reflect.fields(entries[0]).join(",");
        }
        return "fields=" + fields.join(",") + detail;
    }
}
