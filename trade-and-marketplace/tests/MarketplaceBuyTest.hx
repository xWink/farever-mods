import marketplace.MarketController;
import marketplace.MarketWindow;
import marketplace.MarketBuy;
import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeFrame;
@:access(marketplace.MarketWindow)
class MarketplaceBuyTest {
    static var checks=0;
    static function check(value:Bool):Void {checks++;if(!value)throw "Marketplace buy assertion "+checks;}
    static function node(prefix:String):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),prefix))[0];
    static function slots():Array<Dynamic> return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketBuySlot"));
    static function button(text:String):Dynamic return G.buttons.filter(b->b.text==text)[0];
    static function dropdown(y:Int):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketSelect")&&n.x==754&&n.y==y)[0];
    static function levelInput(y:Int):Dynamic return G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput")&&n.x==754&&n.y==y)[0];
    static function reflow(view:MarketWindow):Dynamic {var viewport=node("marketBuyViewport");viewport.onAfterReflow();view.update();return viewport;}
    public static function run(example:Dynamic):Void {
        var oldDefinitions=TradeInventory.definitions,oldNames=TradeInventory.localizedNames;
        TradeInventory.definitions=[];TradeInventory.localizedNames=[];
        var armor:Dynamic={id:"CatalogArmor",type:"Chest",nativeRarityId:"Epic",level:30,gear:true,infusable:true,aptitudes:["Wizard"],scalings:[{statGroup:3,endAtb:"Strength"}]};
        var bow:Dynamic={id:"CatalogBow",type:"Bow",nativeRarityId:"Rare",level:20,gear:true,infusable:false};
        var potion:Dynamic={id:"CatalogPotion",type:"Potion",nativeRarityId:"Common",gear:false,infusable:false};
        var definitions:Array<Dynamic>=[armor,bow,potion];
        for(i in 0...250)definitions.push({id:"CatalogMaterial"+i,type:"CraftingComponent",nativeRarityId:"Common",gear:false,infusable:false});
        for(id in ["ActivityLoot","RecipeGenerator","Soulstone","SoulstoneLegendary","WorldLoot"])
            definitions.push({id:id,type:"Misc",nativeRarityId:"Common",valid:false});
        var excluded:Map<String,String>=["RefillableFlask"=>"HealthPotion","Experience"=>"Currency","Gold"=>"Currency","BadgeOfGlory"=>"Currency","CraftPoint"=>"Currency",
            "DemonicSoul"=>"Currency","Nightblood"=>"Currency","ShopCurrency"=>"Currency","Hide_Gear"=>"Gear",
            "TPRiftStone"=>"Consumable","TPRiftStone_Perma"=>"Usable","Mastery"=>"Mastery","SparkCube"=>"Usable","TeleportationStone"=>"Usable",
            "CopperProspecting"=>"Prospecting","TinProspecting"=>"Prospecting","TungsteneProspecting"=>"Prospecting",
            "Hammer"=>"ToolBlacksmith","Mortar"=>"ToolAlchemist","Scissors"=>"ToolOutfitter","Pliers"=>"ToolJeweller",
            "Knife"=>"ToolCook","Wand"=>"ToolEnchanter","Sickle"=>"GearSickle","Pickaxe"=>"GearPickaxe"];
        for(id=>type in excluded)definitions.push({id:id,type:type,nativeRarityId:"Common"});
        for(d in definitions){TradeInventory.definitions[d.id]=d;TradeInventory.localizedNames[d.id]=d.id;}
        TradeInventory.localizedNames[armor.id]="Armure étoilée";TradeInventory.localizedNames[bow.id]="Arc";TradeInventory.localizedNames[potion.id]="Potion";
        var types:Map<String,Dynamic>=["Chest"=>{inherit:"Armor"},"Armor"=>{inherit:"Gear"},"Bow"=>{inherit:"Weapon"},"Weapon"=>{inherit:"Gear"},"Potion"=>{inherit:"Consumable"}];
        types["GearTool"]={inherit:"Gear"};types["JobTool"]={inherit:"GearTool"};types["Mastery"]={inherit:"Consumable"};
        for(type in ["ToolBlacksmith","ToolAlchemist","ToolOutfitter","ToolJeweller","ToolCook","ToolEnchanter"])types[type]={inherit:"JobTool"};
        for(type in ["GearSickle","GearPickaxe"])types[type]={inherit:"GearTool"};
        var attributes:Map<String,Dynamic>=["Strength"=>{name:"Strength"},"Vitality"=>{name:"Vitality"},"FervorRating"=>{name:"Fervor"}];
        G.dataFields=["Data.item"=>{all:definitions.concat([armor])},"Data.itemType"=>{byId:types},"Const.Hero"=>{MaxLevel:30},
            "Data.attribute"=>{byId:attributes},"ent.UnitAttributes.infusionBonusAttributes"=>["Strength","Vitality","FervorRating"]];
        var b=new MarketBuy();b.load();check(b.items.length==253&&b.visible.length==253&&b.maxLevel==30);
        check(marketplace.MarketCategory.subcategories("Miscellaneous").indexOf("Currency")<0
            &&marketplace.MarketCategory.subcategories("Miscellaneous").indexOf("Prospecting")<0);
        b.setFilter("category","Armor");check(b.visible.length==1&&b.visible[0].kind==armor.id&&b.visible[0].subcategory=="Chest");
        b.setFilter("classes","Mage");check(b.visible.length==1);
        b.setFilter("classes","Rogue");check(b.visible.length==0);
        b.clearFilters();b.setFilter("search","ÉTOILÉE");check(b.visible.length==1&&b.visible[0].name=="Armure étoilée");
        b.clearFilters();b.setFilter("rarity","Epic (Prismatic)");check(b.visible.length==1);
        b.select(b.visible[0],17);check(b.bonuses.length==2&&b.bonuses[0].id=="Vitality"&&b.prismatic&&b.level==17);
        b.setBonus("Strength");check(b.bonus=="");b.setBonus("Vitality");b.setLevel("20");
        check(b.preview.preview.bonus=="Vitality"&&b.preview.preview.level==20&&b.preview.preview.flags==2);
        b.setLevel("99");check(b.level==30);b.setLevel("-1");check(b.level==1);
        b.setPrismatic(false);check(b.preview.preview.flags==0&&b.metadata().prismatic==false);
        b.clearFilters();b.select(b.items.filter(i->i.kind==potion.id)[0]);b.setLevel("20");b.setBonus("Vitality");b.setPrismatic(true);
        check(b.level==0&&b.bonus==""&&!b.prismatic&&b.bonuses.length==0);
        check(Reflect.field(armor,"__host")==null&&Reflect.field(armor,"__uid")==null&&armor.level==30);

        var c=new MarketController();c.tab="Buy";c.buy.load();c.ready=false;c.connectionIssue=true;c.busy=true;
        c.player={hero:{_level:17}};
        c.filters["search"]="sword";c.filters["online"]="true";c.hideMine=true;c.chosen=marketplace.MarketExport.offer(example);
        var chosen=c.chosen,dialogs=G.dialogs;
        var view=new MarketWindow(c);c.view=view;view.quantity="7";view.open();view.update();var viewport=reflow(view);
        check(G.dialogs==dialogs&&slots().length>0&&slots().length<=110&&viewport.contentHeight==26*64);
        check(button("Sell").x<button("Buy").x&&button("Buy").x<button("My listings").x);
        check(viewport.y+viewport.height==794&&viewport.scrollBar.visible);
        viewport.scrollPosY=640;view.update();check(slots()[0].y==576&&slots().length<=120);
        button("Show filters").action();view.update();viewport=reflow(view);check(c.buy.expanded&&viewport.scrollPosY==640);
        check(G.nodes.filter(n->n.fmtText.text=="Hide mine"||n.fmtText.text=="Online only").length==0);
        var search=node("marketInput");search.input.text="Armure";search.onChange();view.update();viewport=reflow(view);
        check(c.buy.visible.length==1&&slots().length==1&&viewport.scrollPosY==0&&node("marketInput")==search);
        slots()[0].action();view.update();reflow(view);
        check(c.buy.selected.kind==armor.id&&levelInput(438)!=null&&dropdown(438)==null&&dropdown(508)!=null);
        var level=levelInput(438);check(level.input.text=="17"&&c.buy.preview.preview.level==17);
        level.input.text="999";level.onChange();view.update();reflow(view);check(c.buy.level==30&&level.input.text=="30");
        level.input.text="";level.onChange();view.update();check(level.input.text==""&&c.buy.level==30);
        level.input.text="20";level.onChange();view.update();reflow(view);
        var bonus=dropdown(508);bonus.selectedIndex=1;bonus.onSelectOption(null);view.update();reflow(view);
        var prism=G.nodes.filter(n->n.fmtText.text=="Prismatic")[0];prism.onValueChange(true);view.update();reflow(view);
        check(c.buy.level==20&&c.buy.bonus=="Vitality"&&c.buy.prismatic&&c.buy.preview.preview.flags==2);
        check(G.labels.filter(l->~/<[^>]*>/g.replace(Std.string(l.text),"")=="Prismatic").length==1);
        var quantity=G.nodes.filter(n->StringTools.startsWith(Std.string(n.id),"marketInput")&&n.x==918&&n.y==438)[0];
        quantity.input.text="12";quantity.onChange();check(c.buy.quantity=="12");
        button("Open to offers").action();view.update();reflow(view);check(c.buy.offers);
        button("Any").action();view.update();reflow(view);
        check(c.buy.anyLevel&&levelInput(438).input.text=="Any"&&c.buy.preview.preview.level==0);
        check(G.labels.filter(l->l.text=="Any level").length==1);
        button("Any").action();view.update();reflow(view);check(!c.buy.anyLevel&&c.buy.level==20);
        level=levelInput(438);level.input.text="any";level.onChange();view.update();reflow(view);
        check(c.buy.anyLevel&&level.input.text=="Any");
        level.input.text="20";level.onChange();view.update();reflow(view);check(!c.buy.anyLevel&&c.buy.level==20);
        var count=c.refreshes;button("Place buy order").action();
        check(c.refreshes==count&&c.buySubmissions==0&&c.buy.selected.kind==armor.id&&c.buy.quantity=="12"&&c.message=="");
        c.ready=true;c.busy=false;c.atSellLimit=true;view.dirty=true;view.update();reflow(view);button("Place buy order").action();
        check(c.buySubmissions==1);
        c.atBuyLimit=true;view.dirty=true;view.update();reflow(view);button("Place buy order").action();
        check(c.buySubmissions==1&&G.labels.filter(l->l.text==MarketController.error("listing_limit","buy")).length==1);
        c.atBuyLimit=false;c.atSellLimit=false;view.dirty=true;view.update();reflow(view);
        check(c.chosen==chosen&&view.quantity=="7"&&c.filters["search"]=="sword"&&c.filters["online"]=="true"&&c.hideMine);
        button("Clear filters").action();view.update();reflow(view);
        check(c.buy.visible.length==253&&c.buy.selected.kind==armor.id&&c.filters["search"]=="sword");
        button("Browse").action();view.dirty=true;view.update();
        check(node("marketBuyViewport")==null&&node("marketListingViewport")!=null);
        button("Buy").action();view.dirty=true;view.update();reflow(view);
        check(c.buy.selected.kind==armor.id&&c.buy.quantity=="12"&&c.buy.offers&&c.buy.prismatic);
        view.close();view.open();view.update();reflow(view);check(c.buy.quantity=="12"&&c.buy.level==20);
        search=node("marketInput");search.input.text="Potion";search.onChange();view.update();reflow(view);slots()[0].action();view.update();reflow(view);
        check(c.buy.selected.kind==potion.id&&c.buy.quantity=="1"&&dropdown(534)==null&&dropdown(508)==null);
        check(G.nodes.filter(n->n.fmtText.text=="Prismatic").length==0&&button("Place buy order")!=null);
        search.input.text="Arc";search.onChange();view.update();reflow(view);slots()[0].action();view.update();reflow(view);
        var rarity=dropdown(464);check(c.buy.selected.weapon&&rarity!=null&&rarity.selectText.text=="Rare");
        rarity.selectedIndex=3;rarity.onSelectOption(null);view.update();reflow(view);
        check(c.buy.rarity=="Epic"&&c.buy.preview.preview.rarity=="Epic"&&c.buy.metadata().rarity=="Epic");
        check(node("marketDetailViewport").y+node("marketDetailViewport").height<rarity.y-28);
        view.close();check(TradeFrame.active==0);
        var amulet:Dynamic=haxe.Json.parse(haxe.Json.stringify(b.items.filter(i->i.kind==armor.id)[0]));
        amulet.kind="Necklace_Z1_Mp";b.select(amulet,30);check(b.level==30&&b.maxLevel==30);
        b.setLevel("999999999999999999");check(b.level==30);
        b.setLevel("1");check(b.level==1);b.setAnyLevel(true);check(b.anyLevel&&b.preview.preview.level==0);
        b.select(b.items.filter(i->i.kind==bow.id)[0],30);check(!b.anyLevel&&b.level==30&&b.maxLevel==30);
        b.setRarity("Legendary");check(b.rarity=="Legendary"&&b.preview.preview.rarity=="Legendary");
        b.setRarity("Invalid");check(b.rarity=="Legendary");
        b.setFilter("rarity","Legendary");check(b.visible.length==1&&b.visible[0].kind==bow.id);
        TradeInventory.definitions=oldDefinitions;TradeInventory.localizedNames=oldNames;G.dataFields=[];
        Sys.println("Marketplace buy checks passed: "+checks);
    }
}
