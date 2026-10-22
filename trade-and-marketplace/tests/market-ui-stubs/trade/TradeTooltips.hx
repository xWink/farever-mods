package trade;
class TradeTooltips {
 public static function create(item:Dynamic,inv:Dynamic):Dynamic return {item:item,inventory:inv};
 public static var previewAvailable=true;
 public static function previewItem(item:Dynamic):Dynamic
  return previewAvailable?{inf:{nativeRarityId:item.preview==null?"Common":item.preview.rarity,valid:true}}:null;
}
