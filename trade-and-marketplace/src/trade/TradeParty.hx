package trade;
import trade.GameAccess as G;

/** Native party setup runs only after the recipient accepts this trade request. */
class TradeParty {
    var player:Dynamic;
    var session:TradeSession;
    var left = false;
    var soloSent = false;
    var peerSolo = false;
    var peerJoined = false;
    var invited = false;
    var accepted = false;
    var error = "";
    var oldNotifies:Array<Dynamic>;
    public var joined(default,null) = false;
    public var ready(default,null) = false;
    public function new(player:Dynamic,session:TradeSession) {
        this.player = player; this.session = session;
        oldNotifies = G.array(G.field(player,"netNotifies"),true).copy();
    }
    public function receive(op:String):Void {
        if (op == "party-ready" && session.leader) peerSolo = true;
        if (op == "party-joined" && !session.leader) peerJoined = true;
    }
    function failed(ok:Bool,reason:String):Void {
        if (!ok && session.phase == "joining") error = reason;
    }
    public function update(peer:Dynamic,sameParty:Bool):String {
        if (session.phase != "joining") return "";
        if (error != "") return error;
        if (sameParty) {
            if (!joined) { joined = true; if (session.leader) session.emit("party-joined"); }
            ready = session.leader || peerJoined;
            return "";
        }
        if (joined) return "Your party changed.";
        var group = G.field(player,"group");
        if (group == null) return ""; // Wait for the replicated solo group after leaving.
        var solo = G.call("st.Group","get_isSolo",group) == true;
        if (!solo) {
            if (!left) {
                left = true;
                G.call("st.Group","requestLeave",group,[(ok:Bool)->failed(ok,"Could not leave your current party.")]);
            }
            return error;
        }
        if (!soloSent) { soloSent = true; if (!session.leader) session.emit("party-ready"); }
        if (session.leader) {
            if (peerSolo && !invited) {
                if (peer == null || G.field(peer,"__uid") == null) return "The other player is no longer nearby.";
                invited = true;
                // Pass the native I64 directly; the chat/account ID is a different ID.
                G.call("st.Group","invitePlayer",group,[G.field(peer,"__uid"),(ok:Bool)->failed(ok,"Could not send the trade party invite.")]);
            }
        } else if (!accepted) {
            for (notice in G.array(G.field(player,"netNotifies"),true)) {
                if (oldNotifies.indexOf(notice) >= 0 || G.field(notice,"removed") == true
                    || G.field(notice,"targetPlayer") != player || G.field(notice,"kind") != "PlayerGroupInvited"
                    || G.text(G.field(G.field(notice,"fromPlayer"),"uid")) != session.peer) continue;
                accepted = true;
                G.call("st.player.NetNotify","select",notice,[true,(ok:Bool)->failed(ok,"Could not join the trade party.")]);
                break;
            }
        }
        return error;
    }
}
