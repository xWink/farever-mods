package trade;

import trade.TradeTypes;

typedef DraftItemAtom = {code:Int, token:String, offer:TradeItem};

/** One private character per item: native caret, selection, delete and undo stay atomic. */
class ItemLinkDraftModel {
    public var atoms(default,null):Map<Int,DraftItemAtom> = [];
    var tokens:Map<String,Int> = [];
    var nextCode = 0xe000;

    public function new() {}

    public function collapse(text:String, resolve:String->TradeItem):String {
        if (text == null || text.indexOf(ItemLinkCodec.PREFIX) < 0) return text;
        for (token in ItemLinkCodec.tokens(text)) {
            var code = tokens.get(token);
            if (code == null) {
                if (nextCode > 0xf8ff) continue;
                var offer = resolve(token);
                if (offer == null) continue;
                code = nextCode++;
                tokens.set(token,code);
                atoms.set(code,{code:code,token:token,offer:offer});
            }
            text = StringTools.replace(text,token,String.fromCharCode(code));
        }
        return text;
    }

    public function expand(text:String):String {
        if (text == null) return null;
        var out = new StringBuf();
        for (i in 0...text.length) {
            var atom = atoms.get(text.charCodeAt(i));
            out.add(atom == null ? text.charAt(i) : atom.token);
        }
        return out.toString();
    }

    public function fits(text:String, limit = ItemLinkCodec.MAX_MESSAGE):Bool
        return text != null && expand(text).length <= limit;

    /** Native positions are converted to string offsets before calling this. */
    public function replace(text:String,start:Int,end:Int,insert:String):String
        return text.substring(0,start)+insert+text.substring(end);

    public function visible(text:String):Array<{index:Int,atom:DraftItemAtom}> {
        var result = [];
        if (text != null) for (i in 0...text.length) {
            var atom = atoms.get(text.charCodeAt(i));
            if (atom != null) result.push({index:i,atom:atom});
        }
        return result;
    }
}
