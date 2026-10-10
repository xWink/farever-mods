package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

class SocialHooks {
    static var hideConnections = false;
    static var reported:Map<String, Bool> = [];
    static var interact = new SocialInteract();

    // HLX recovers game types after mod main() returns. At startup only store
    // preferences; UI creation/input hooks apply them once the game is ready.
    // Live settings changes still refresh existing cards and clear held inputs.
    public static function configure(config:MoreSettingsConfig, refreshExisting:Bool = true):Void {
        hideConnections = config.hideFriendConnectionNotifications;
        SocialChat.commandsEnabled = config.enableMissingSlashCommands;
        SocialChat.closeAfterSend = config.sendingMessageClosesChat;
        try SelfChatBubbles.configure(config.showSelfChatBubbles) catch (e:Dynamic) report(e);
        try interact.configure(config.rebindSocialInteract, config.socialInteractKey, refreshExisting) catch (e:Dynamic) report(e);
        try FriendNotes.configure(config.enableFriendNotes, refreshExisting) catch (e:Dynamic) report(e);
    }
    public static function dispose():Void {
        SocialChat.clear(); FriendNotes.dispose(); interact.dispose(); SelfChatBubbles.dispose();
    }
    public static function report(error:Dynamic):Void {
        var message = Std.string(error);
        if (reported.exists(message)) return;
        reported[message] = true;
        trace("[More Settings] Social: " + message);
    }

    @:hlx.prefix(client.PlayerController.tryInteractHero)
    static function socialInteract(instance:Dynamic):HlxPrefixResult<Void> {
        if (interact.inHeroCheck || !interact.usesHotkey()) return Continue;
        try interact.checkHero(instance) catch (e:Dynamic) report(e);
        return Skip;
    }

    @:hlx.prefix(lib.Input.isLongPressed)
    static function socialHold(key:String):HlxPrefixResult<Bool> {
        if (key != "Interact" || !interact.inHeroCheck) return Continue;
        try return SkipWith(interact.longPressed()) catch (e:Dynamic) report(e);
        return SkipWith(false);
    }

    @:hlx.prefix(lib.Input.checkInput)
    static function socialInput(key:String, keyboard:Dynamic, pad:Dynamic):HlxPrefixResult<Bool> {
        if (key != SocialInteract.ACTION) return Continue;
        try return SkipWith(interact.checkInput(keyboard, pad)) catch (e:Dynamic) report(e);
        return SkipWith(false);
    }

    @:hlx.prefix(lib.Input.getBindings)
    static function socialBindings(key:String):HlxPrefixResult<Dynamic> {
        if (key != SocialInteract.ACTION) return Continue;
        return SkipWith(interact.getBindings());
    }

    @:hlx.postfix(lib.Input.getBindings)
    static function socialBindingRead(key:String, result:Dynamic):Dynamic {
        return key == "Interact" && interact.inBindingCheck ? interact.bindings(result) : result;
    }

    @:hlx.postfix(ui.comp.LongInputKey.init)
    static function socialHint(instance:Dynamic, result:Void):Void {
        try interact.attachHint(instance) catch (e:Dynamic) report(e);
    }

    @:hlx.postfix(lib.Input.isPressed)
    static function noteChatPressed(key:String, result:Bool):Bool {
        try return FriendNotes.chatPressed(key, result) catch (e:Dynamic) report(e);
        return result;
    }

    @:hlx.prefix(ui.hud.ChatBox.receiveMessage)
    static function filterConnectionMessage(instance:Dynamic, message:Dynamic):HlxPrefixResult<Void> {
        // sendSystemMessage is a server-only stub in the client. Server RPCs
        // enter ChatClient history directly, then the UI polls that history.
        // Filter the structured notification ID before creating a chat row;
        // never suppress friend state updates or match arbitrary player text.
        if (hideConnections && SocialCommands.connectionMessage(G.text(G.field(message, "notify")))) return Skip;
        return Continue;
    }

    @:hlx.prefix(ui.hud.ChatBox.handleCommand)
    static function command(instance:Dynamic, command:String, args:Dynamic):HlxPrefixResult<String> {
        if (!SocialChat.commandsEnabled) return Continue;
        var parsed = SocialCommands.parse(command, [for (value in G.array(args)) G.text(value)].join(" "));
        if (parsed == null) return Continue;
        try return SkipWith(SocialChat.run(instance, parsed)) catch (e:Dynamic) {
            report(e);
            try SocialChat.error(instance, "Could not complete this chat command.") catch (_:Dynamic) {}
            return SkipWith(null); // Never leak a failed private command into public chat.
        }
    }

    @:hlx.prefix(ui.hud.ChatBox.processMessage)
    static function beforeSend(instance:Dynamic, text:String):HlxPrefixResult<Void> {
        SocialChat.begin(instance);
        return Continue;
    }
    @:hlx.postfix(ui.hud.ChatBox.processMessage)
    static function afterSend(instance:Dynamic, text:String, result:Void):Void {
        try SocialChat.finish(instance) catch (e:Dynamic) report(e);
    }
    @:hlx.postfix(st.player.ChatClient.sendMessage)
    static function sent(instance:Dynamic, message:Dynamic, result:Void):Void SocialChat.sent(instance, message);
    @:hlx.postfix(st.player.ChatClient.localReceiveMessage)
    static function whisperEcho(instance:Dynamic, message:Dynamic, result:Void):Void SocialChat.sent(instance, message);

    @:hlx.postfix(ui.hud.ChatBox.receiveMessage)
    static function received(instance:Dynamic, message:Dynamic, result:Void):Void {
        try SocialChat.remember(message) catch (e:Dynamic) report(e);
    }
    @:hlx.prefix(ui.win.PlayerCard.init)
    static function beforeCardInit(instance:Dynamic):HlxPrefixResult<Void> {
        FriendNotes.detach(instance);
        return Continue;
    }
    @:hlx.prefix(ui.UIElement.onRemove)
    static function removed(instance:Dynamic):HlxPrefixResult<Void> {
        FriendNotes.detach(instance);
        return Continue;
    }
    @:hlx.postfix(ui.win.PlayerCard.init)
    static function friendCard(instance:Dynamic, result:Void):Void {
        try FriendNotes.attach(instance) catch (e:Dynamic) report(e);
    }
}
