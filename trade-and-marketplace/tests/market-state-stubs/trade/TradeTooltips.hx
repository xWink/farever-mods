package trade;
class TradeTooltips {
 public static var previewAvailable=true;
 public static function previewItem(item:Dynamic):Dynamic
  return previewAvailable?{kind:item.kind,inf:{rarity:item.preview.rarity},testPreview:TradePreview.copy(item.preview)}:null;
}
