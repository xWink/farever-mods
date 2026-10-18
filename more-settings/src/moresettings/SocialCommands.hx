package moresettings;

typedef SocialCommand = {
    var command:String;
    var player:String;
    var message:String;
    var error:String;
}

/** Parse additional chat commands without performing game actions. */
class SocialCommands {
    public static function parse(command:String, args:String):Null<SocialCommand> {
        command = command.toLowerCase();
        if (command != "invite" && command != "leave" && command != "w" && command != "box") return null;
        args = StringTools.trim(args);
        var result:SocialCommand = {command: command, player: "", message: "", error: ""};
        if (command == "leave" || command == "box") {
            if (args != "") result.error = "Usage: /" + command;
            return result;
        }
        var end = 0;
        if (StringTools.startsWith(args, '"')) {
            end = args.indexOf('"', 1);
            if (end < 0 || (end + 1 < args.length && !space(args.charCodeAt(end + 1)))) {
                result.error = "Close the quoted player name before entering a message.";
                return result;
            }
            result.player = args.substring(1, end);
            end++;
        } else {
            while (end < args.length && !space(args.charCodeAt(end))) end++;
            result.player = args.substring(0, end);
        }
        result.player = StringTools.trim(result.player);
        result.message = StringTools.trim(args.substring(end));
        if (result.player == "" || (command == "invite" && result.message != ""))
            result.error = command == "invite" ? 'Usage: /invite <player> (quote names containing spaces)'
                : 'Usage: /w <player> [message] (quote names containing spaces)';
        return result;
    }

    static function space(c:Int):Bool return c == 32 || c == 9 || c == 10 || c == 13;
    public static function connectionMessage(id:String):Bool
        return id == "PlayerConnected" || id == "PlayerDisconnected";
}
