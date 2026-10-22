package trade;

/** Native Inventory/Bank rarity-slot colours. */
class TradeRarity {
    public static function fill(rarity:String):Int return switch(rarity) {
        case "Common":0x665E57;
        case "Uncommon":0x2B7732;
        case "Rare":0x236581;
        case "Epic":0x662883;
        case "Legendary":0x937829;
        default:0x665E57;
    };
    public static function border(rarity:String,prismatic=false):Int return switch(rarity) {
        case "Common":0xB89A82;
        case "Uncommon":0x17D62D;
        case "Rare":0x218FDD;
        case "Epic":prismatic?0xD7A7F2:0xA043BD;
        case "Legendary":0xE4B647;
        default:0xB89A82;
    };
    /** Use the original rarity tint for foreign-localized trade-only previews. */
    public static function fromTint(tint:Int):Int {
        if(tint<=0)return fill("Common");
        var r=(tint>>16)&255,g=(tint>>8)&255,b=tint&255;
        return (Std.int(r*0.58)<<16)|(Std.int(g*0.58)<<8)|Std.int(b*0.58);
    }
}
