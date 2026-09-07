package slashcommands;

enum LayerAction {
    Show;
    Transfer(serverID:String);
    Usage;
    QueryLayers;
    LayersUsage;
}

class LayerCommand {
    // Null means this message belongs to the game or another mod.
    public static function parse(text:String):Null<LayerAction> {
        if (text == null)
            return null;
        var tokens = ~/\s+/g.split(StringTools.trim(text));
        if (tokens[0].toLowerCase() == "/layers")
            return tokens.length == 1 ? QueryLayers : LayersUsage;
        if (tokens[0].toLowerCase() != "/layer")
            return null;
        if (tokens.length == 1)
            return Show;
        if (tokens.length != 2 || !isLayerID(tokens[1]))
            return Usage;
        if (tokens[1].toLowerCase() == "help")
            return Usage;
        return Transfer(tokens[1]);
    }

    public static function isLayerID(value:String):Bool {
        // Native mpman IDs have a platform prefix. Keep the remainder opaque:
        // IDs can include punctuation and are case-sensitive, not layer numbers.
        return value != null && value.length <= 512
            && ~/^[A-Za-z][\x21-\x7e]+$/.match(value)
            && !~/[<>"']/.match(value);
    }

    public static function destination(info:Dynamic, serverID:String):Dynamic {
        // Preserve native values (especially the 64-bit hero ID). Serializing
        // through JSON would change their types. Don't mutate the live session.
        var instanceInfo:Dynamic = Reflect.field(info, "instanceInfo");
        return {
            group: Reflect.field(info, "group"),
            heroID: Reflect.field(info, "heroID"),
            instanceInfo: {
                config: Reflect.field(instanceInfo, "config"),
                serverID: serverID
            },
            pseed: Reflect.field(info, "pseed"),
            worldLocation: Reflect.field(info, "worldLocation")
        };
    }
}
