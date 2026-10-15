import moresettings.ChatTimestamps;
import moresettings.SettingsData;
import moresettings.SocialHooks;
import moresettings.GameAccess as G;

private enum Channel {
    Local(id:Int);
    All;
    AllSystem;
    Player(uid:String, name:String);
    Group;
    System(name:String);
}

class ChatTimestampsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ": expected " + expected + ", got " + actual;
    }

    static function main():Void {
        var config = SettingsData.defaults();
        eq(config.addMessageTimestamps, false, "timestamps are opt-in");
        ChatTimestamps.dispose(); ChatTimestamps.configure(false);
        var wallTime = new Date(2026, 9, 15, 0, 1, 0).getTime();
        eq(ChatTimestamps.prefix(60, 180, wallTime), "[23:59] ", "receipt time crosses midnight");
        eq(ChatTimestamps.prefix(180, 180, wallTime), "[00:01] ", "local hours and minutes are padded");
        eq(ChatTimestamps.prefix(200, 180, wallTime), "[00:01] ", "future monotonic stamp is clamped");
        eq(ChatTimestamps.prefix(Math.NaN, 180, wallTime), "[00:01] ", "missing stamp uses display time");

        var rows:Array<Dynamic> = [];
        for (entry in [
            {channel:Local(7), colour:"Chat_Local"}, {channel:All, colour:"Chat_All"},
            {channel:Group, colour:"Chat_Group"}, {channel:Player("uid", "Alice"), colour:"Chat_Player"}
        ]) {
            var colour = G.chatColours.get(entry.colour);
            var markup = '<font color="' + colour + '"><a href="player">Alice</a>: &lt;hello&gt;</font>';
            var row = makeRow(entry.channel, markup);
            row.colour = colour;
            // Native formatted output can differ from the saved input markup.
            row.msgText.text = "native formatted output";
            ChatTimestamps.attach(row);
            eq(row.msgText.prevUnformatted, markup, "disabled attachment leaves native input alone");
            eq(row.msgText.text, "native formatted output", "disabled attachment never rewrites output");
            rows.push(row);
        }
        var systemRows = [makeRow(System("notice"), "[00:01] Notice"), makeRow(AllSystem, "[00:01] Welcome")];
        for (row in systemRows) ChatTimestamps.attach(row);

        config.addMessageTimestamps = true;
        SocialHooks.configure(config, false);
        var firstTexts:Array<String> = [];
        for (row in rows) {
            var rendered:String = row.msgText.prevUnformatted;
            var parts = splitTimestamp(rendered);
            eq(parts.colour, row.colour, "timestamp inherits the native colour for each player channel");
            eq(parts.body, row.original, "original links, colours and escaping are preserved");
            eq(row.message.text, "<hello>", "message and chat history payload stay untouched");
            var calls = G.calls.length;
            ChatTimestamps.attach(row);
            eq(row.msgText.prevUnformatted, rendered, "repeated attachment never doubles timestamp");
            eq(G.calls.length, calls, "unchanged row needs no extra text setter");
            firstTexts.push(rendered);
        }
        for (row in systemRows) eq(row.msgText.prevUnformatted, row.original, "native system timestamp stays single");
        ChatTimestamps.configure(false);
        for (row in rows) eq(row.msgText.prevUnformatted, row.original, "disabling restores exact original markup");
        ChatTimestamps.configure(true);
        for (i in 0...rows.length) eq(rows[i].msgText.prevUnformatted, firstTexts[i], "toggles retain receipt time");

        var pooled = rows[0];
        pooled.message = {channel: Group, text: "new message", localStamp: haxe.Timer.stamp()};
        pooled.msgText.prevUnformatted = "New native markup";
        ChatTimestamps.attach(pooled);
        eq(splitTimestamp(pooled.msgText.prevUnformatted).body, "New native markup", "rebuilt rows use the new message");
        eq(splitTimestamp(pooled.msgText.prevUnformatted).colour, G.chatColours.get("Chat_Group"), "rebuilt row follows its new channel colour");
        // Another display writer can replace the text without losing its change.
        pooled.msgText.prevUnformatted = "Updated by game";
        ChatTimestamps.configure(false);
        eq(pooled.msgText.prevUnformatted, "Updated by game", "toggle preserves a native replacement");
        ChatTimestamps.configure(true);
        eq(splitTimestamp(pooled.msgText.prevUnformatted).body, "Updated by game", "replacement can be timestamped again");

        // Use the game's current colour data, rather than a copied colour table.
        ChatTimestamps.configure(false);
        G.chatColours.set("Chat_Group", "#123456");
        ChatTimestamps.configure(true);
        eq(splitTimestamp(pooled.msgText.prevUnformatted).colour, "#123456", "native colour changes are respected");

        var removedText = pooled.msgText.prevUnformatted;
        @:privateAccess SocialHooks.removed(pooled);
        ChatTimestamps.configure(false);
        eq(pooled.msgText.prevUnformatted, removedText, "removed rows are no longer retained or rewritten");
        ChatTimestamps.dispose();
        var calls = G.calls.length;
        ChatTimestamps.configure(true);
        eq(G.calls.length, calls, "world disposal releases all old rows");
        for (call in G.calls) eq(call.name, "set_text", "timestamps only change displayed text");
        ChatTimestamps.configure(false);
        Sys.println('Chat timestamps: $checks checks passed.');
    }

    static function makeRow(channel:Channel, text:String):Dynamic return {
        original:text,
        message:{channel:channel, text:"<hello>", localStamp:haxe.Timer.stamp() - 120},
        msgText:{prevUnformatted:text, text:text}
    };

    static function splitTimestamp(rendered:String):{colour:String, body:String} {
        var pattern = ~/^<font color="([^"]+)">\[[0-9]{2}:[0-9]{2}\] <\/font>/;
        if (!pattern.match(rendered)) throw "Missing coloured timestamp: " + rendered;
        return {colour:pattern.matched(1), body:pattern.matchedRight()};
    }
}
