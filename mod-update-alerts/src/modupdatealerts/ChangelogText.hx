package modupdatealerts;

/** Nexus release notes are displayed as literal text, never executable UI markup. */
class ChangelogText {
    public static function plain(value:String):String {
        if (value==null) return "";
        value=value.substr(0,16000);
        value=~/<br\s*\/?\s*>|<\/(?:p|div|li)>/gi.replace(value,"\n");
        value=~/<[^>]*>/g.replace(value,"");
        value=~/\[\*\]/g.replace(value,"- ");
        value=~/\[\/?(?:b|i|u|s|list|size|color|url|font|quote|code)(?:=[^\]]*)?\]/gi.replace(value,"");
        value=~/&#(x[0-9a-f]+|[0-9]+);/gi.map(value,function(match) {
            var number=match.matched(1);
            var code=Std.parseInt(number.charAt(0).toLowerCase()=="x" ? "0x"+number.substr(1) : number);
            return code==null || code<32 || code>0x10FFFF || (code>=0xD800 && code<=0xDFFF)
                ? " " : String.fromCharCode(code);
        });
        for (pair in [["&lt;","<"],["&gt;",">"],["&quot;","\""],["&apos;","'"],["&nbsp;"," "]])
            value=StringTools.replace(value,pair[0],pair[1]);
        value=StringTools.replace(value,"&amp;","&");
        value=StringTools.replace(value,"\r\n","\n");
        value=~/[\x00-\x08\x0b-\x1f\x7f]/g.replace(value,"");
        return StringTools.trim(value);
    }
}
