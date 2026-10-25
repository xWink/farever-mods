package trade;

import haxe.crypto.Base64;
import haxe.io.Bytes;
import trade.TradeTypes;

/** One self-contained, versioned chat token. No remote IDs, HTML or network objects. */
class ItemLinkCodec {
    public static inline var PREFIX = "~i1:";
    public static inline var MAX_MESSAGE = 250;
    static inline var MAX_JSON = 2048;

    public static function encode(item:TradeItem):String {
        if (item == null || !id(item.kind, false) || !TradePreview.integer(item.count, 1, 1000000000)
            || item.preview == null || !validPreview(item.preview)) return null;
        var p = item.preview;
        var data:Array<Dynamic> = [item.kind, item.count, p.flags, p.level, p.upgrade,
            p.rarity, p.infusion, p.bonus, p.mastery, p.slots, [for (e in p.effects) e.skill]];
        var bytes = Bytes.ofString(haxe.Json.stringify(data));
        if (bytes.length > MAX_JSON) return null;
        var token = PREFIX + Base64.urlEncode(haxe.zip.Compress.run(bytes, 9)) + "~";
        return token.length <= MAX_MESSAGE ? token : null;
    }

    public static function decode(token:String):TradeItem {
        if (token == null || token.length > MAX_MESSAGE || !~/^~i1:[A-Za-z0-9_-]+~$/.match(token)) return null;
        var packed = token.substring(PREFIX.length, token.length - 1);
        if (packed.length % 4 == 1) return null;
        var inflater:haxe.zip.Uncompress = null;
        try {
            var source = Base64.urlDecode(packed);
            if (Base64.urlEncode(source) != packed) return null;
            // A fixed destination prevents a short hostile token from expanding without bound.
            inflater = new haxe.zip.Uncompress();
            var target = Bytes.alloc(MAX_JSON + 1);
            var result = inflater.execute(source, 0, target, 0);
            inflater.close(); inflater = null;
            if (!result.done || result.read != source.length || result.write > MAX_JSON) return null;
            var raw:Dynamic = haxe.Json.parse(target.getString(0, result.write));
            if (!Std.isOfType(raw, Array)) return null;
            var data:Array<Dynamic> = raw;
            if (data.length != 11 || !id(data[0], false) || !TradePreview.integer(data[1], 1, 1000000000)
                || !Std.isOfType(data[10], Array)) return null;
            var effects:Array<Dynamic> = data[10];
            if (effects.length > 8) return null;
            for (effect in effects) if (!id(effect, false)) return null;
            var p:Dynamic = {flags:data[2], level:data[3], upgrade:data[4], rarity:data[5],
                infusion:data[6], bonus:data[7], mastery:data[8], slots:data[9],
                effects:[for (effect in effects) {skill:effect, source:"RoguePoison"}]};
            if (!validPreview(p)) return null;
            return {uid:"", kind:data[0], count:data[1], name:"", detail:"", color:0,
                fingerprint:"", preview:p};
        } catch (_:Dynamic) {
            if (inflater != null) try inflater.close() catch (_:Dynamic) {}
            return null;
        }
    }

    static function id(value:Dynamic, empty = true):Bool return Std.isOfType(value, String)
        && (empty && value == "" || ~/^[A-Za-z0-9_]{1,120}$/.match(value));
    static function validPreview(p:Dynamic):Bool {
        if (!TradePreview.valid(p)) return false;
        var preview:TradeItemPreview = p;
        for (value in [preview.rarity, preview.infusion, preview.bonus, preview.mastery]) if (!id(value)) return false;
        for (value in preview.slots) if (!id(value)) return false;
        for (effect in preview.effects) if (!id(effect.skill, false)) return false;
        return true;
    }

    public static function tokens(text:String):Array<String> {
        var result:Array<String> = [];
        if (text == null || text.length > MAX_MESSAGE) return result;
        var pattern = ~/~i1:[A-Za-z0-9_-]+~/g;
        pattern.map(text, match -> {
            var token = match.matched(0);
            if (result.indexOf(token) < 0) result.push(token);
            return token;
        });
        return result;
    }

    /** Append without replacing a selection, truncating a token or sending the draft. */
    public static function append(draft:String, token:String, limit:Int):String {
        if (token == null || limit <= 0) return null;
        if (draft == null) draft = "";
        var next = draft + (draft == "" || ~/\s$/.match(draft) ? "" : " ") + token;
        limit = Std.int(Math.min(limit, MAX_MESSAGE));
        if (next.length > limit) return null;
        return next.length < limit ? next + " " : next;
    }

    public static function markup(name:String, color:Int, index:Int):String
        return '<a href="wink-item:' + index + '">' + nameMarkup(name,color) + '</a>';

    public static function nameMarkup(name:String, color:Int):String
        return '<font color="#' + StringTools.hex(color & 0xffffff, 6)
            + '"><b>' + StringTools.htmlEscape(name) + '</b></font>';
}
