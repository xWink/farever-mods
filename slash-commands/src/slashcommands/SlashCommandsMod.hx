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
    static inline var USAGE = "Use /layer to show your layer, or /layer <full layer ID> to join one.";

    static var enabled = true;
    static var transferring = false;
    static var getApp:ResolvedMember;
    static var disconnect:ResolvedMember;
    static var connectTo:ResolvedMember;
    static var delay:ResolvedMember;
    static var chatError:ResolvedMember;
    static var lineType:hl.Bytes;
    static var setText:ResolvedMember;

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
            }
        } catch (error:Dynamic) {
            reportError(instance, error);
        }
        return Skip;
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
