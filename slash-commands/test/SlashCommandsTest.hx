import slashcommands.LayerCommand;
import slashcommands.LayerCommand.LayerAction;
import slashcommands.LayerQuery;

class SlashCommandsTest {
    static function check(condition:Bool, message:String):Void {
        if (!condition)
            throw message;
    }

    static function main():Void {
        for (text in [null, "", "hello", "!group hello", "/layercake", "/layersfoo", "//layer", "/other command", "say /layer"])
            check(LayerCommand.parse(text) == null, "Must preserve unrelated chat: " + text);

        for (text in ["/layer", "  /LaYeR  ", "\t/layer\t"])
            check(LayerCommand.parse(text) == Show, "Must recognize current-layer command: " + text);

        for (text in ["/layers", "  /LaYeRs\t"])
            check(LayerCommand.parse(text) == QueryLayers, "Must recognize the server query: " + text);
        for (text in ["/layers help", "/layers S123", "/layers all"])
            check(LayerCommand.parse(text) == LayersUsage, "Keep invalid query arguments local: " + text);

        for (text in ["/layer help", "/layer 2", "/layer id extra", "/layer <id>", "/layer S123\x00"])
            check(LayerCommand.parse(text) == Usage, "Malformed command must not transfer: " + text);

        var id = "Wexample.invalid:443S:AbC123";
        switch LayerCommand.parse(" /LAYER\t" + id + " ") {
            case Transfer(value): check(value == id, "Keep the complete ID and its case");
            default: throw "Expected transfer";
        }
        check(!LayerCommand.isLayerID(StringTools.lpad("S", "S", 513)), "Reject oversized IDs");

        // Above the precise integer range of JSON/Float; don't convert to a
        // string or round the hero ID while preparing the destination.
        var heroID = haxe.Int64.parseString("9007199254740993");
        var config:Dynamic = {mapId: "test-map", activityID: null, difficulty: null};
        var group:Dynamic = {id: heroID, lobbyId: "lobby"};
        var location:Dynamic = {x: 1.25, y: 3.5};
        var source:Dynamic = {
            group: group, heroID: heroID,
            instanceInfo: {config: config, serverID: "S12345678901234567"},
            pseed: 42, worldLocation: location
        };
        var target:Dynamic = LayerCommand.destination(source, id);
        check(target != source && target.instanceInfo != source.instanceInfo, "Copy session containers");
        check(source.instanceInfo.serverID == "S12345678901234567", "Leave the live session untouched");
        check(target.instanceInfo.serverID == id, "Set the requested destination");
        check(haxe.Int64.compare(target.heroID, heroID) == 0, "Preserve all hero ID bits");
        check(target.group == group && target.worldLocation == location, "Preserve group and location values");
        check(target.instanceInfo.config == config && target.pseed == 42, "Preserve map config and seed");
        source.group = null;
        source.pseed = null;
        source.worldLocation = null;
        target = LayerCommand.destination(source, id);
        check(target.group == null && target.pseed == null && target.worldLocation == null, "Preserve absent optional values");

        var realmConfig:Dynamic = {
            id: "Srealm", load: "Snot-a-layer", meta: {serverID: "Smetadata"},
            layout: [{sid: "world", id: "Slogical", mapId: "Smap", config: {serverID: "Sconfig"}}]
        };
        check(LayerQuery.serverIDs(realmConfig).length == 0, "Realm config is not a layer directory");
        var directory:Dynamic = {
            id: "Srealm",
            layout: [{instances: [{serverID: "S123"}, {serverID: "S456"}, {serverID: "S123"}]}],
            servers: ([{serverID: "S789"}, {serverID: "123"}, {serverID: "<bad>"}, {serverID: 123}]:Array<Dynamic>),
            layers: ["Snot-an-explicit-record"],
            meta: {serverID: "Smetadata", secret: "do-not-log"}
        };
        check(LayerQuery.serverIDs(directory).join(",") == "S123,S456,S789", "Return distinct explicit server IDs only");
        check(LayerQuery.serverIDs(null).length == 0, "Handle an empty response");
        var diagnostic = LayerQuery.shape(directory);
        check(diagnostic.indexOf("do-not-log") < 0 && diagnostic.indexOf("S123") < 0, "Schema diagnostics must omit values");
        check(LayerQuery.shape({layout: []}).indexOf("layout entries=0") >= 0, "Handle an empty layout");
        Sys.println("Slash Commands checks passed.");
    }
}
