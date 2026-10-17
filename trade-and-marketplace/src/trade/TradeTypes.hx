package trade;
typedef TradeItemPreview = {flags:Int, level:Int, upgrade:Int, rarity:String, infusion:String, bonus:String, mastery:String, slots:Array<String>, effects:Array<{skill:String, source:String}>};
typedef TradeItem = {uid:String, kind:String, count:Int, name:String, detail:String, color:Int, fingerprint:String, preview:TradeItemPreview};
