package groupfinder;

import groupfinder.GroupTypes;

/** Title budgets count Unicode code points, matching Fareverly's validator. */
class GroupTitle {
    public static function clip(value:String,limit=GroupRules.MAX_TITLE_LENGTH):String {
        var offset=0,count=0;
        for(code in new haxe.iterators.StringIteratorUnicode(value)) {
            if(count>=limit)break;
            offset+=#if utf16 (code>=0x10000?2:1) #else 1 #end;
            count++;
        }
        return value.substr(0,offset);
    }
    /** Selection offsets have already been converted by native getTextPos. */
    public static function insertion(current:String,start:Int,end:Int,value:String):String {
        var selected=current.substring(start,end);
        return clip(value,Std.int(Math.max(0,GroupRules.MAX_TITLE_LENGTH-GroupRules.count(current)+GroupRules.count(selected))));
    }
}
