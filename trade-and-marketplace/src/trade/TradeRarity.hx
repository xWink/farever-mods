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
    /**
     * Approximate the native Inventory/Bank item's rounded vignette: dark
     * edges and a gently illuminated centre. The shapes are painted once on
     * icon construction, without native shader or layout mutations.
     */
    public static function shade(color:Int,factor:Float):Int {
        var r=Std.int(Math.max(0,Math.min(255,((color>>16)&255)*factor)));
        var g=Std.int(Math.max(0,Math.min(255,((color>>8)&255)*factor)));
        var b=Std.int(Math.max(0,Math.min(255,(color&255)*factor)));
        return (r<<16)|(g<<8)|b;
    }

    public static function gradient(color:Int,width:Float,height:Float,radius:Float)
        :Array<{x:Float,y:Float,width:Float,height:Float,radius:Float,color:Int}> {
        var layers:Array<{x:Float,y:Float,width:Float,height:Float,radius:Float,color:Int}>=[];
        if(width<=0||height<=0)return layers;
        var span=Math.min(width,height);
        var count=Std.int(Math.max(12,Math.ceil(span/2.4))),extent=span*0.17;
        for(i in 1...(count+1)) {
            var t=i/count,inset=extent*t;
            layers.push({x:inset,y:inset,width:width-2*inset,height:height-2*inset,
                radius:Math.max(1,radius-inset*0.35),
                color:shade(color,0.82+0.5*t)});
        }
        return layers;
    }

    /** Use the original rarity tint for foreign-localized trade-only previews. */
    public static function fromTint(tint:Int):Int {
        if(tint<=0)return fill("Common");
        var r=(tint>>16)&255,g=(tint>>8)&255,b=tint&255;
        return (Std.int(r*0.58)<<16)|(Std.int(g*0.58)<<8)|Std.int(b*0.58);
    }
}
