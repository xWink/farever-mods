package slashcommands;

import haxe.Json;
import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixControl;
import hlx.runtime.ResolvedMember;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class SlashCommandsMod {
    static inline var CONFIG_PATH = "hlx/mods/slash-commands/config.json";
    static inline var USAGE = "Use /layer for your layer, /layer <full layer ID> to join, or /layers to query the server.";

    static var enabled = true;
    static var transferring = false;
    static var getApp:ResolvedMember;
    static var disconnect:ResolvedMember;
    static var connectTo:ResolvedMember;
    static var delay:ResolvedMember;
    static var chatError:ResolvedMember;
    static var lineType:hl.Bytes;
    static var setText:ResolvedMember;
    static var queryRealm:ResolvedMember;
    static var printJSON:ResolvedMember;
    static var querying = false;
    static var querySerial = 0;

    static function main():Void {
        loadConfig();
        if (!FileSystem.exists(CONFIG_PATH)) {
            try File.saveContent(CONFIG_PATH, Json.stringify({enabled: enabled}, null, "  "))
            catch (error:Dynamic) trace("[SlashCommands] Could not save config: " + Std.string(error));
        }
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), function(_:Dynamic) {
            loadConfig();
        });
    }

    @:hlx.prefix(ui.hud.ChatBox.processMessage)
    static function beforeProcessMessage(instance:Dynamic, text:String):HlxPrefixControl {
        var action = LayerCommand.parse(text);
        if (action == null)
            return Continue;

        // Even disabled or invalid recognized commands stay local, so a layer
        // ID isn't accidentally posted to the currently selected chat channel.
        try {
            if (!enabled) {
                reply(instance, "Slash Commands is disabled.");
                return Skip;
            }
            switch action {
                case Usage:
                    reply(instance, USAGE);
                case Show:
                    var info = connectionInfo(currentApp());
                    var id = layerID(info);
                    reply(instance, id == null ? "Your current layer ID is unavailable." : "Current layer: " + id);
                case Transfer(id):
                    requestTransfer(instance, id);
                case QueryLayers:
                    requestLayers(instance);
                case LayersUsage:
                    reply(instance, "Use /layers with no arguments to query the current realm for layer IDs.");
            }
        } catch (error:Dynamic) {
            reportError(instance, error);
        }
        return Skip;
    }

    static function requestLayers(chat:Dynamic):Void {
        if (querying) {
            reply(chat, "A layer query is already in progress.");
            return;
        }
        var app = currentApp();
        var info = connectionInfo(app);
        var network = HlxRuntime.resolveType("lib.Network");
        var realm:Dynamic = network == null ? null : HlxRuntime.resolveStaticField(network, "realmId");
        if (info == null || realm == null || field(app, "host") == null) {
            reply(chat, "The current realm is unavailable. Wait until your character has loaded.");
            return;
        }
        if (queryRealm == null)
            queryRealm = resolve("mpman.Realms", "loadRealmDetails", true);
        if (printJSON == null)
            printJSON = resolve("haxe.format.JsonPrinter", "print", true);
        if (delay == null)
            delay = resolve("haxe.Timer", "delay", true);
        if (queryRealm == null || printJSON == null || delay == null) {
            reply(chat, "The realm query is unavailable in this game build.");
            return;
        }

        var serial = ++querySerial;
        querying = true;
        reply(chat, "Requesting layer IDs from the current realm...");
        try {
            schedule(function() {
                if (!querying || querySerial != serial)
                    return;
                querying = false;
                querySerial++;
                if (enabled && currentApp() == app && connectionInfo(app) == info)
                    reply(chat, "The layer query timed out. Try /layers again.");
            }, 15000);
            // Verified in mpman/Realms.hx: loadRealmDetails sends the real
            // authenticated `realm/query` request with {realm: realmId}.
            // It does not resolve/matchmake a destination or join any lobby.
            HlxRuntime.callResolved(queryRealm, [realm, function(response:Dynamic) {
                if (!querying || querySerial != serial)
                    return;
                querying = false;
                if (!enabled || currentApp() != app || connectionInfo(app) != info)
                    return;
                try {
                    if (response == null) {
                        reply(chat, "The server did not return realm details. The query may be unavailable or rejected.");
                        return;
                    }
                    // Serialize with the game's printer so native ArrayObj /
                    // ArrayDyn values are handled by their own module. Parse
                    // locally only for read-only inspection, never reconnects.
                    var json:Dynamic = HlxRuntime.callResolved(printJSON, [response, null, null]);
                    if (json == null || !Std.isOfType(json, String))
                        throw "Could not read the realm query response.";
                    var data:Dynamic = Json.parse(json);
                    var ids = LayerQuery.serverIDs(data);
                    trace("[SlashCommands] realm/query " + LayerQuery.shape(data));
                    if (ids.length == 0) {
                        reply(chat, "The server response supplied no layer IDs. It does not provide a complete layer list.");
                        return;
                    }
                    reply(chat, "Server-reported IDs for this realm (completeness and availability unconfirmed):");
                    var currentID = layerID(info);
                    for (id in ids)
                        reply(chat, id + (id == currentID ? " (current layer)" : ""));
                } catch (error:Dynamic) {
                    reportError(chat, error);
                }
            }]);
        } catch (error:Dynamic) {
            querying = false;
            querySerial++;
            reportError(chat, error);
        }
    }

    static function requestTransfer(chat:Dynamic, id:String):Void {
        if (transferring) {
            reply(chat, "A layer transfer is already starting.");
            return;
        }
        var app = currentApp();
        var info = connectionInfo(app);
        var currentID = layerID(info);
        if (currentID == null || field(app, "host") == null || field(app, "layer") == null) {
            reply(chat, "Wait until your character has loaded before changing layers.");
            return;
        }
        if (id == currentID) {
            reply(chat, "You are already on that layer.");
            return;
        }
        if (!resolveTransferMethods()) {
            reply(chat, "Layer switching is unavailable in this game build.");
            return;
        }

        var destination = LayerCommand.destination(info, id);
        var host = field(app, "host");
        transferring = true;
        reply(chat, "Joining layer " + id + "...");
        try {
            // Use Farever's timer, not a separate timer loop in the mod. Wait
            // until the chat callback returns before disposing its game layer.
            schedule(function() {
                try {
                    if (!enabled || currentApp() != app || connectionInfo(app) != info || field(app, "host") != host) {
                        transferring = false;
                        return;
                    }
                    HlxRuntime.callResolved(disconnect, [app]);
                    if (field(app, "host") != null)
                        throw "The game did not disconnect the current session.";
                    // Mirrors EscapeMenu's "Go to layer" callback in the
                    // September 3, 2026 build. connectTo owns the loading UI,
                    // normal authentication, retries and connection errors.
                    schedule(function() {
                        try {
                            // Don't resurrect a session the player has left.
                            if (currentApp() == app && connectionInfo(app) == info && field(app, "host") == null)
                                HlxRuntime.callResolved(connectTo, [app, destination]);
                        } catch (error:Dynamic) {
                            recover(app, info, error);
                        }
                        transferring = false;
                    }, 100);
                } catch (error:Dynamic) {
                    transferring = false;
                    recover(app, info, error);
                }
            }, 0);
        } catch (error:Dynamic) {
            transferring = false;
            reportError(chat, error);
        }
    }

    static function schedule(callback:Void->Void, milliseconds:Int):Void {
        if (HlxRuntime.callResolved(delay, [callback, milliseconds]) == null)
            throw "Could not schedule the layer transfer.";
    }

    static function recover(app:Dynamic, originalInfo:Dynamic, error:Dynamic):Void {
        trace("[SlashCommands] Could not start layer transfer: " + Std.string(error));
        // Only recover a synchronous setup failure. Ordinary server rejection
        // and connection retry behavior belong to GameApp.
        try {
            if (currentApp() == app && field(app, "host") == null)
                HlxRuntime.callResolved(connectTo, [app, originalInfo]);
        } catch (recoveryError:Dynamic) {
            trace("[SlashCommands] Could not reconnect: " + Std.string(recoveryError));
        }
    }

    static function currentApp():Dynamic {
        if (getApp == null)
            getApp = resolve("App", "get", true);
        return getApp == null ? null : HlxRuntime.callResolved(getApp, []);
    }

    static function connectionInfo(app:Dynamic):Dynamic {
        return field(app, "connectionInfo");
    }

    static function layerID(info:Dynamic):String {
        var id:Dynamic = field(field(info, "instanceInfo"), "serverID");
        return id == null || !Std.isOfType(id, String) || id.length == 0 ? null : cast id;
    }

    static function field(object:Dynamic, name:String):Dynamic {
        return object == null ? null : HlxRuntime.resolveField(object, name);
    }

    static function resolve(typeName:String, name:String, isStatic = false):ResolvedMember {
        var type = HlxRuntime.resolveType(typeName);
        if (type == null)
            return null;
        return isStatic ? HlxRuntime.resolveStaticMember(type, name) : HlxRuntime.resolveMember(type, name);
    }

    static function resolveTransferMethods():Bool {
        if (disconnect == null)
            disconnect = resolve("GameApp", "disconnect");
        if (connectTo == null)
            connectTo = resolve("GameApp", "connectTo");
        if (delay == null)
            delay = resolve("haxe.Timer", "delay", true);
        return disconnect != null && connectTo != null && delay != null;
    }

    static function reply(chat:Dynamic, message:String):Void {
        var text = StringTools.htmlEscape("[Slash Commands] " + message);
        try {
            if (lineType == null)
                lineType = HlxRuntime.resolveType("ui.hud.ChatBoxLine");
            if (setText == null)
                setText = resolve("ui.comp.FmtText", "set_text");
            var messages = field(chat, "messages");
            if (lineType != null && setText != null && messages != null) {
                var line = HlxRuntime.constructInstanceByName(lineType, 1, [messages]);
                var label = field(line, "msgText");
                if (label != null) {
                    HlxRuntime.callResolved(setText, [label, text]);
                    return;
                }
            }
        } catch (_:Dynamic) {}
        try {
            if (chatError == null)
                chatError = resolve("ui.hud.ChatBox", "chatError");
            if (chatError != null && chat != null) {
                HlxRuntime.callResolved(chatError, [chat, text]);
                return;
            }
        } catch (_:Dynamic) {}
        trace("[SlashCommands] " + message);
    }

    static function reportError(chat:Dynamic, error:Dynamic):Void {
        trace("[SlashCommands] " + Std.string(error));
        reply(chat, "Could not run the command. See the HLX log for details.");
    }

    static function loadConfig():Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH))
                return;
            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            var value:Dynamic = Reflect.field(data, "enabled");
            if (Std.isOfType(value, Bool))
                enabled = value;
        } catch (error:Dynamic) {
            trace("[SlashCommands] Could not load config: " + Std.string(error));
        }
    }
}
