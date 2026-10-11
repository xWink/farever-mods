import moresettings.SocialCommands;
import moresettings.SocialChat;
import moresettings.FriendNotes;
import moresettings.FriendNotesStore;
import moresettings.SettingsData;
import moresettings.GameAccess as G;
import moresettings.SocialHooks;
import hlx.runtime.HlxPrefixResult;

class SocialTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function main():Void {
        parse(); notifications(); notes(); chat(); menu();
        Sys.println('Social: $checks checks passed.');
    }
    static function parse():Void {
        eq(SocialCommands.parse("party", "Hello"), null, "existing command remains native");
        var parsed = SocialCommands.parse("W", '  "Friend With Spaces"   Hello there! ');
        eq(parsed.player, "Friend With Spaces", "quoted names");
        eq(parsed.message, "Hello there!", "whisper body");
        eq(parsed.error, "", "case-insensitive command");
        eq(SocialCommands.parse("w", "Thorcules").message, "", "open whisper without message");
        for (args in ["", '"unfinished', '"quoted"suffix', "Name unexpected"]) {
            eq(SocialCommands.parse("invite", args).error != "", true, "invalid invite has usage error");
        }
        eq(SocialCommands.parse("leave", "extra").error != "", true, "leave validates arguments");
        eq(SocialCommands.parse("invite", "Magé").player, "Magé", "accented name unchanged");
        eq(SocialCommands.connectionMessage("PlayerConnected"), true, "connected hidden");
        eq(SocialCommands.connectionMessage("PlayerDisconnected"), true, "disconnected hidden");
        for (id in ["PlayerFriendAdded", "PlayerGroup_AlreadyIn", "ErrorDefault"])
            eq(SocialCommands.connectionMessage(id), false, "other notifications unchanged");
        eq(SettingsData.defaults().enableMissingSlashCommands, true, "slash commands enabled by default");
        eq(SettingsData.defaults().sendingMessageClosesChat, true, "sending closes chat by default");
        eq(SettingsData.defaults().enableFriendNotes, true, "friend notes enabled by default");
        eq(SettingsData.defaults().hideFriendConnectionNotifications, false, "connection notifications remain visible by default");
    }
    static function notifications():Void {
        var config = SettingsData.defaults();
        var history:Array<Dynamic> = [
            {notify:"PlayerConnected", args:{player:"Magé"}},
            {notify:"PlayerDisconnected", args:{player:"Magé"}},
            {notify:"PlayerFriendAdded", args:{player:"Magé"}},
            {notify:null, text:"PlayerConnected"},
            {text:"Magé is connected."},
            {localTextId:"PlayerDisconnected", text:"ordinary player message"},
            {notify:"ErrorDefault"}
        ];
        // Model the audited client path: server RPC -> localReceiveMessage ->
        // history -> UI poll -> receiveMessage. sendSystemMessage never runs.
        config.hideFriendConnectionNotifications = true; SocialHooks.configure(config);
        var displayed = [];
        for (message in history) {
            var result = @:privateAccess SocialHooks.filterConnectionMessage({}, message);
            if (result == Continue) displayed.push(message);
        }
        eq(history.length, 7, "filter does not mutate network/chat history");
        eq(displayed.length, 5, "both received connection notifications hidden");
        eq(displayed[0], history[2], "friend-added notification retained");
        eq(displayed[1], history[3], "notification name in player text remains visible");
        eq(displayed[2], history[4], "localized-looking player text remains visible");
        eq(displayed[3], history[5], "localTextId is a text fingerprint, not a notification ID");
        eq(displayed[4], history[6], "unrelated system errors retained");
        config.hideFriendConnectionNotifications = false; SocialHooks.configure(config);
        for (message in history)
            eq(@:privateAccess SocialHooks.filterConnectionMessage({}, message), Continue, "disabled setting preserves received messages");
        eq(@:privateAccess SocialHooks.filterConnectionMessage({}, null), Continue, "missing notification metadata ignored");
    }
    static function notes():Void {
        eq(FriendNotesStore.clean("  Friend from Discord  "), "Friend from Discord", "trim saved note");
        eq(FriendNotesStore.clean("a\nb\tc"), "a b c", "single-line notes");
        eq(FriendNotesStore.clean("123456789012345678901234567890EXTRA"), "123456789012345678901234567890", "30-character limit");
        eq(FriendNotesStore.clean("Magé <3 [party] $gold"), "Magé <3 [party] $gold", "literal special characters saved");
        var emoji = [for (_ in 0...31) "😀"].join("");
        eq([for (c in new haxe.iterators.StringIteratorUnicode(FriendNotesStore.clean(emoji))) c].length, 30, "Unicode character limit");
        var dir = 'tests/social-tmp-${Std.random(1000000000)}';
        var path = dir + "/notes.json";
        var store = new FriendNotesStore(path);
        eq(store.get("me", "friend"), "", "new store empty");
        store.set("me", "friend", "Discord");
        store.set("other", "friend", "Raid");
        store = new FriendNotesStore(path);
        eq(store.get("me", "friend"), "Discord", "survives restart");
        eq(store.get("other", "friend"), "Raid", "isolated by local account");
        eq(store.get("me", "other-friend"), "", "uses friend UID, not name");
        store.set("me", "friend", "   ");
        eq(new FriendNotesStore(path).get("me", "friend"), "", "empty save deletes note");
        sys.io.File.saveContent(path, "broken JSON");
        var failed = false;
        try new FriendNotesStore(path).set("me", "friend", "new") catch (_:Dynamic) failed = true;
        eq(failed, true, "corrupt file cannot silently lose existing notes");
        eq(sys.io.File.getContent(path), "broken JSON", "corrupt original preserved");
        for (p in sys.FileSystem.readDirectory(dir)) sys.FileSystem.deleteFile(dir + "/" + p);
        sys.FileSystem.deleteDirectory(dir);
    }
    static function player(uid:String, name:String):Dynamic return {uid:uid,__uid:uid+"-network",name:name,removed:false};
    static function chat():Void {
        var me:Dynamic = player("me", "My Name");
        var local:Dynamic = player("local", "Thorcules");
        me.layer = {players:{array:[me,local]}};
        me.group = {players:{array:[me]}};
        me.whispers = {};
        me.friendList = {friends:[{uid:"remote",metadata:{heroName:"Magé",connected:true}},
            {uid:"offline",metadata:{heroName:"Offline",connected:false}}]};
        G.me = me;
        var box:Dynamic = {chatClient:{},errors:[],focused:true,channel:"public",messageInput:{input:{}}};
        SocialChat.clear(); SocialChat.closeAfterSend = true;
        SocialChat.begin(box);
        eq(SocialChat.run(box,SocialCommands.parse("w", "Magé")), null, "bare whisper consumes command");
        eq(box.channel.args[0], "remote", "native whisper uses UID");
        SocialChat.finish(box);
        eq(box.focused, true, "bare whisper keeps focus");
        G.calls = [];
        SocialChat.begin(box);
        eq(SocialChat.run(box,SocialCommands.parse("w", "Magé Hello")), "Hello", "only message sent through native path");
        SocialChat.sent(box.chatClient,{text:"Hello"}); SocialChat.finish(box);
        eq(box.focused, false, "whisper submission closes editor");
        eq(G.calls.filter(c -> c.name == "focus").length, 0, "sent whisper cannot queue a next-frame refocus");
        box.focused = true;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"ordinary message"}); SocialChat.finish(box);
        eq(box.focused,false,"normal sends close editor");
        box.focused = true; box.mouseOverChat = true; box.inspectFocused = true;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"mouse over chat"}); SocialChat.finish(box);
        eq(box.focused, false, "explicit close releases keyboard focus even under the mouse");
        eq(box.inspectFocused, false, "explicit close also releases native controller focus");
        var blur:Dynamic = {cancel:true};
        @:privateAccess SocialHooks.chatFocusLost(box.messageInput.input, blur);
        eq(blur.cancel, true, "ordinary clicks inside chat still preserve its focus");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "submission Enter cannot reopen chat");
        G.keyFrame++;
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "buffered submission cannot reopen on next frame");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "repeated input polls cannot consume guard early");
        eq(@:privateAccess SocialHooks.noteChatPressed("Interact", true), true, "movement and other actions remain available");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", false), false, "does not invent chat presses");
        G.keyFrame++;
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "fresh Enter opens chat again");
        G.failChatBlur = true;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"failure"});
        var failed = false;
        try SocialChat.finish(box) catch (_:Dynamic) failed = true;
        eq(failed, true, "native failure surfaced"); G.failChatBlur = false;
        blur.cancel = true; @:privateAccess SocialHooks.chatFocusLost(box.messageInput.input, blur);
        eq(blur.cancel, true, "native failure cannot leave forced blur enabled");
        SocialChat.clear();
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "session reset clears submission guard");
        box.focused=true; SocialChat.closeAfterSend=false;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"ordinary message"}); SocialChat.finish(box);
        eq(box.focused,true,"disabled preserves native focus");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "disabled close does not suppress Enter");
        SocialChat.sent(box.chatClient,{text:"automatic ready check message"}); SocialChat.finish(box);
        eq(box.focused, true, "automatic sends outside textbox submission do not alter focus");
        SocialChat.closeAfterSend=true;
        for (args in ["Missing", "Offline"]) {
            SocialChat.begin(box); var channel = box.channel;
            eq(SocialChat.run(box,SocialCommands.parse("w",args+" private text")),null,"failed whisper consumed");
            eq(box.channel,channel,"failed whisper does not change channel");
            SocialChat.finish(box); eq(box.focused,true,"failed command retains typing focus");
        }
        G.calls=[]; SocialChat.begin(box);
        SocialChat.run(box,SocialCommands.parse("invite","Thorcules")); SocialChat.finish(box);
        var invites=G.calls.filter(c -> c.name=="invitePlayer");
        eq(invites.length,1,"one native local invite");
        eq(invites[0].args[0],"local-network","native network ID for local player");
        G.calls=[]; SocialChat.begin(box);
        SocialChat.run(box,SocialCommands.parse("invite","Magé")); SocialChat.finish(box);
        eq(G.calls.filter(c -> c.name=="sendInviteGroup")[0].args[0],"remote","cross-area friend invite via whispers");
        G.reason="NotAllowed"; G.calls=[];
        SocialChat.run(box,SocialCommands.parse("invite","Thorcules"));
        eq(G.calls.filter(c -> c.name=="invitePlayer").length,0,"party permissions preserved"); G.reason="Ok";
        G.calls=[]; SocialChat.run(box,SocialCommands.parse("leave",""));
        eq(G.calls.filter(c -> c.name=="requestLeave").length,0,"solo leave rejected");
        me.group.players.array.push(local); SocialChat.run(box,SocialCommands.parse("leave",""));
        eq(G.calls.filter(c -> c.name=="requestLeave").length,1,"native party leave");
        SocialChat.remember({sender:{uid:"chat-only",name:"Someone"}});
        eq(SocialChat.run(box,SocialCommands.parse("w","Someone")),null,"chat sender recognized");
        eq(box.channel.args[0],"chat-only","recent chat resolves UID");
        SocialChat.remember({sender:{uid:"duplicate",name:"Someone"}});
        var channel=box.channel;
        SocialChat.run(box,SocialCommands.parse("w","Someone secret"));
        eq(box.channel,channel,"ambiguous name never guesses recipient");
        SocialChat.clear(); G.calls=[];
        SocialChat.run(box,SocialCommands.parse("w","Someone secret"));
        eq(G.calls.filter(c -> c.name=="setChannel").length,0,"session change clears cached identities");
    }
    static function node(type:String, parent:Dynamic, classes:Array<String>):Dynamic {
        var n:Dynamic={type:type,parent:parent,dom:{classes:classes},children:[],rebuilds:0};
        if (parent!=null) parent.children.push(n); return n;
    }
    static function menu():Void {
        var root=node("root",null,[]); G.ui={root:root};
        var view=node("ui.win.FriendView",root,[]);
        var card=node("ui.win.PlayerCard",view,[]);
        card.pInfo={uid:"friend",player:null,name:"Lionsden"}; card.settingsBtn={boundActions:[
            {name:"Send message"},{name:"Invite to party"},{name:"Remove friend"}]};
        var dir = 'tests/social-menu-tmp-${Std.random(1000000000)}';
        var path = dir + "/notes.json";
        @:privateAccess FriendNotes.store = new FriendNotesStore(path);
        FriendNotes.configure(false); view.rebuilds = 0; FriendNotes.attach(card);
        eq(card.settingsBtn.boundActions.length,3,"disabled menu unchanged");
        FriendNotes.configure(true); FriendNotes.attach(card);
        eq(card.settingsBtn.boundActions.length,4,"one note action added");
        eq(card.settingsBtn.boundActions[1].name,"Add note","inserted after Send message");
        eq(card.settingsBtn.boundActions[2].name,"Invite to party","native order preserved");
        var action:Dynamic = card.settingsBtn.boundActions[1]; action.action();
        eq(G.dialog.input.input.maxCharacters,30,"editor limit configured");
        eq(G.dialog.buttons[0].text,"Save","save explicit");
        eq(G.dialog.buttons[1].text,"Cancel","cancel available");
        eq(sys.FileSystem.exists(path), false, "opening/canceling editor does not save");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "opening/canceling notes does not swallow chat input");
        G.dialog.input.input.text = "Friend from Discord";
        G.dialog.input.input.onEnter();
        eq(G.dialog.closed, true, "Enter still calls native confirmation and closes note dialog");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "note submission cannot open chat in the event frame");
        eq(@:privateAccess SocialHooks.noteChatPressed("DialogConfirm", true), true, "other actions unchanged");
        G.keyFrame++;
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "buffered Enter cannot open chat on the next frame");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), false, "multiple polls cannot consume the protection early");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", false), false, "never invent a key press");
        G.keyFrame++;
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "a subsequent Enter can open chat normally");
        eq(new FriendNotesStore(path).get("me", "friend"), "Friend from Discord", "dialog save persists note");
        var rebuilt = node("ui.win.PlayerCard", view, []);
        rebuilt.pInfo = card.pInfo; rebuilt.settingsBtn = {boundActions:[{name:"Send message"},{name:"Invite to party"},{name:"Remove friend"}]};
        rebuilt.calculatedWidth = 340; rebuilt.x = 0.0;
        var header = node("flow", rebuilt, ["header"]); header.x = 25.0;
        var name = node("ui.comp.FmtText", header, ["name"]); name.text = "Lionsden";
        var desc = node("flow", rebuilt, ["desc"]);
        var detail = node("ui.comp.FmtText", desc, []); detail.font = {}; detail.scaleX = 1.0;
        var nativeReflows = 0;
        var original = () -> nativeReflows++;
        rebuilt.onAfterReflow = original;
        G.calls = []; FriendNotes.attach(rebuilt);
        eq(G.field(rebuilt,"textTip"),null,"notes do not add a tooltip");
        eq(G.calls.filter(c -> c.name=="set_textTip" || c.name=="set_interactive" || c.name=="get_interactive").length,0,"notes do not enable row hover feedback");
        var actions:Array<Dynamic> = rebuilt.settingsBtn.boundActions;
        eq(actions[1].name,"Edit note","existing note can be edited");
        rebuilt.onAfterReflow();
        var label:Dynamic = header.children[header.children.length-1];
        eq(label.text," - Friend from Discord","hyphen and note after name");
        eq(label.scaleX,0.75,"note smaller than detail text");
        eq(label.x,56.0,"note follows rendered name");
        G.calls=[]; rebuilt.onAfterReflow();
        eq(G.calls.filter(c -> c.name=="set_text" || c.name=="set_font" || c.name=="setScale" || c.name=="set_maxWidthText").length,0,"stable layout does not invalidate itself");
        rebuilt.calculatedWidth=105; rebuilt.onAfterReflow();
        var displayed:String = label.text;
        eq(displayed.indexOf("…")>=0 || displayed=="",true,"narrow rows truncate note instead of covering gear");
        rebuilt.calculatedWidth = 380;
        var leader = node("ui.comp.FmtText", header, ["player-status"]);
        leader.text = "(Leader)"; leader.scaleX = 1.0;
        var right = node("flow", rebuilt, ["right-cont"]); right.calculatedWidth = 80; right.x = 290.0; right.y = 0.0;
        leader.x = 61.0; rebuilt.onAfterReflow();
        eq(label.x,117.0,"note starts after the party leader label");
        eq(label.text," - Friend from Discord","leader leaves the note legible");
        eq(G.number(label.x) + Std.string(label.text).length * 7 * 0.75 <= 260,true,"note stays before party controls");
        rebuilt.calculatedWidth = 320; right.x = 230;
        rebuilt.onAfterReflow();
        leader.x = G.number(G.field(name,"maxWidthText")) + 5; rebuilt.onAfterReflow();
        eq(G.number(label.x) >= G.number(leader.x) + 56,true,"narrow cards keep note after the leader label");
        eq(G.number(label.x) + Std.string(label.text).length * 7 * 0.75 <= 200,true,"narrow party row fits before controls");
        leader.visible = false; rebuilt.calculatedWidth = 230; right.x = 140; right.y = 30;
        // Simulate native truncation, then give the header room above its buttons.
        name.text = "Lion..."; rebuilt.onAfterReflow();
        eq(name.text,"Lionsden","wider rows restore the original name after native ellipsis");
        eq(label.x,56.0,"hidden party label leaves no note-position gap");
        eq(label.text," - Friend from Discord","full note fits above controls instead of needless ellipsis");
        eq(G.number(G.field(name,"maxWidthText")) >= 56,true,"full name has enough width above the controls");
        right.y = 0; rebuilt.onAfterReflow();
        eq(G.number(label.x) + Std.string(label.text).length * 7 * 0.75 <= 110,true,"buttons sharing the header still reserve their real space");
        FriendNotes.detach(rebuilt);
        eq(rebuilt.onAfterReflow,original,"rebuild/removal restores original callback");
        actions[1].action(); eq(G.dialog.input.input.text,"Friend from Discord","editor prefills existing note");
        G.saved(""); eq(new FriendNotesStore(path).get("me","friend"),"","saving empty removes note");
        eq(@:privateAccess SocialHooks.noteChatPressed("OpenChat", true), true, "mouse save does not suppress the next chat key");
        FriendNotes.configure(false);
        eq(view.rebuilds,4,"toggles and saves refresh existing list");
        eq(@:privateAccess [for (_ in SocialHooks.reported.keys()) true].length,0,"no UI adapter errors");
        for (p in sys.FileSystem.readDirectory(dir)) sys.FileSystem.deleteFile(dir+"/"+p);
        sys.FileSystem.deleteDirectory(dir);
    }
}
