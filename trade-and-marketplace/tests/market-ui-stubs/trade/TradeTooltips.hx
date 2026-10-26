package trade;
class TradeTooltips {
 public static function create(item:Dynamic,inv:Dynamic):Dynamic return {item:item,inventory:inv};
 public static var previewAvailable=true;
 public static function previewItem(item:Dynamic):Dynamic {
  if(!previewAvailable)return null;
  var definition=TradeInventory.definition(item.kind),p=item.preview;
  return {inf:{nativeRarityId:p==null?"Common":p.rarity,valid:true},
   nativeType:GameAccess.field(definition,"gear")==true?"st.item.Gear":null,
   infusion:p==null?null:p.infusion,infusionBonusStat:p==null?null:p.bonus};
 }
}
