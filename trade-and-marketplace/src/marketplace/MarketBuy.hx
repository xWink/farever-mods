package marketplace;

import trade.GameAccess as G;
import trade.TradeInventory;
import trade.TradeTypes;

typedef CatalogItem = {
    var kind:String;
    var name:String;
    var category:String;
    var subcategory:String;
    var classes:Array<String>;
    var rarity:String;
    var level:Int;
    var gear:Bool;
    var weapon:Bool;
    var infusable:Bool;
    var offer:TradeItem;
};

/** Local catalog and order draft; the controller owns submission. */
class MarketBuy {
    static var excludedKinds=["Hide_Gear","TPRiftStone","TPRiftStone_Perma","SparkCube","TeleportationStone","RefillableFlask"];
    static var excludedTypes=["Currency","Mastery","Prospecting","GearTool"];
    static var weaponRarities=["Common","Uncommon","Rare","Epic","Legendary"];
    public var filters:Map<String,String>=["search"=>"","category"=>"","subcategory"=>"","rarity"=>"","classes"=>""];
    public var expanded=false;
    public var items:Array<CatalogItem>=[];
    public var visible:Array<CatalogItem>=[];
    public var selected:CatalogItem;
    public var scroll={offset:0.0};
    public var level=0;
    public var maxLevel=1;
    public var anyLevel=false;
    public var rarity="";
    public var bonus="";
    public var bonuses:Array<{id:String,name:String}>=[];
    public var prismatic=false;
    public var quantity="1";
    public var trays="1";
    public var offers=false;
    public var preview:TradeItem;
    public var nativePreview:Dynamic;
    var loaded=false;

    public function new() {}
    public function draftKey():String return haxe.Json.stringify([selected==null?"":selected.kind,level,anyLevel,rarity,bonus,prismatic,quantity,trays,offers]);
    public function clearSelection():Void {
        selected=null;preview=null;nativePreview=null;level=0;anyLevel=false;rarity="";bonus="";bonuses=[];prismatic=false;quantity="1";
    }
    public function rarityOptions():Array<String> return selected==null?[]:selected.weapon?weaponRarities.copy():[selected.rarity];
    public function setRarity(value:String):Void {if(rarityOptions().indexOf(value)<0)return;rarity=value;updatePreview();}
    public function setAnyLevel(value:Bool):Void {anyLevel=value&&selected!=null&&selected.gear;updatePreview();}
    static function allowed(definition:Dynamic,kind:String):Bool {
        if(excludedKinds.indexOf(kind)>=0)return false;
        // Native inheritance includes every crafting/gathering tool and keeps
        // catalog eligibility independent of the player's language.
        for(type in excludedTypes)if(G.staticCall("HItem","isType",[definition,type])==true)return false;
        return true;
    }
    public function load(force=false):Void {
        if(loaded&&!force)return;
        var definitions=G.array(G.field(G.current("Data","item"),"all"));
        if(definitions.length==0)return;
        var previous=selected==null?"":selected.kind,seen:Map<String,Bool>=[];
        items=[];maxLevel=G.integer(G.field(G.current("Const","Hero"),"MaxLevel"),1);
        for(definition in definitions) {
            var kind=G.text(G.field(definition,"id"));
            if(kind==""||seen.exists(kind))continue;
            seen[kind]=true;
            if(!allowed(definition,kind))continue;
            // Resolve native type/rarity fallback icons too; a missing item-level
            // gfx field alone does not mean the item has no usable artwork.
            if(G.staticCall("HItem","getGfx",[definition])==null)continue;
            var meta=MarketCategory.item(kind),rarity=G.text(G.field(G.staticCall("HItem","getRarity",[definition]),"id"));
            var name=MarketText.itemName(kind,TradeInventory.itemName(kind),TradeInventory.itemName),level=G.integer(G.field(definition,"level"),1);
            if(StringTools.trim(name)=="")name=kind;
            maxLevel=Std.int(Math.max(maxLevel,level));
            var offer:TradeItem={uid:"catalog:"+kind,kind:kind,name:name,count:1,detail:"",color:trade.TradeRarity.fill(rarity),fingerprint:"",preview:{
                flags:0,level:0,upgrade:0,rarity:"",infusion:"",bonus:"",mastery:"",slots:[],effects:[]
            }};
            items.push({kind:kind,name:name,category:meta.category,subcategory:meta.subcategory,classes:meta.classes,
                rarity:rarity,level:level,gear:G.staticCall("HItem","isType",[definition,"Gear"])==true,
                weapon:G.staticCall("HItem","isType",[definition,"Weapon"])==true,
                infusable:G.staticCall("HInfusion","canBeInfused",[definition])==true,offer:offer});
        }
        items.sort((a,b)->{var order=Reflect.compare(a.name.toLowerCase(),b.name.toLowerCase());return order==0?Reflect.compare(a.kind,b.kind):order;});
        loaded=true;
        if(previous!="") {
            selected=null;
            for(entry in items)if(entry.kind==previous){selected=entry;break;}
            if(selected==null){preview=null;nativePreview=null;}else updatePreview();
        }
        applyFilters();
    }
    public function setFilter(key:String,value:String):Void {
        filters[key]=value;
        if(key=="category") {filters["subcategory"]="";if(!MarketCategory.supportsClasses(value))filters["classes"]="";}
        applyFilters();
    }
    public function clearFilters():Void {for(key in filters.keys())filters[key]="";applyFilters();}
    public function applyFilters():Void {
        var query=StringTools.trim(filters["search"]).toLowerCase(),classes=filters["classes"].split(",").filter(s->s!="");
        visible=items.filter(item->(query==""||item.name.toLowerCase().indexOf(query)>=0)
            &&(filters["category"]==""||item.category==filters["category"])
            &&(filters["subcategory"]==""||item.subcategory==filters["subcategory"])
            &&(filters["rarity"]==""||(filters["rarity"]=="Epic (Prismatic)"?(item.rarity=="Epic"||item.weapon)&&item.infusable:item.rarity==filters["rarity"]||item.weapon&&weaponRarities.indexOf(filters["rarity"])>=0))
            &&(classes.length==0||classes.filter(c->item.classes.indexOf(c)>=0).length>0));
        scroll={offset:0.0};
    }
    public function select(item:CatalogItem,playerLevel=1):Void {
        if(selected==item)return;
        selected=item;level=item.gear?Std.int(Math.max(1,Math.min(maxLevel,playerLevel))):0;anyLevel=false;
        rarity=item.weapon&&weaponRarities.indexOf(filters["rarity"])>=0?filters["rarity"]:item.rarity;
        if(item.weapon&&filters["rarity"]=="Epic (Prismatic)")rarity="Epic";
        bonus="";prismatic=false;quantity="1";bonuses=[];
        if(item.infusable) {
            var definition=TradeInventory.definition(item.kind);
            var excluded:Map<String,Bool>=[];
            for(scaling in G.array(G.staticCall("HItem","getItemExpectedScalings",[definition])))
                if(G.integer(G.field(scaling,"statGroup"))==3)excluded[G.text(G.field(scaling,"endAtb"))]=true;
            for(value in G.array(G.current("ent.UnitAttributes","infusionBonusAttributes"))) {
                var id=G.text(value);
                if(id==""||excluded.exists(id))continue;
                var row=G.call("haxe.ds.StringMap","get",G.field(G.current("Data","attribute"),"byId"),[id]);
                bonuses.push({id:id,name:G.text(G.field(row,"name"),id)});
            }
        }
        prismatic=filters["rarity"]=="Epic (Prismatic)"&&item.infusable&&bonuses.length>0;
        updatePreview();
    }
    public function setLevel(value:String):Void {
        if(value.toLowerCase()=="any"){setAnyLevel(true);return;}
        if(!~/^-?[0-9]+$/.match(value))return;
        level=selected!=null&&selected.gear?Std.int(Math.max(1,Math.min(maxLevel,Std.parseFloat(value)))):0;anyLevel=false;updatePreview();
    }
    public function setBonus(value:String):Void {bonus=bonuses.filter(b->b.id==value).length>0?value:"";updatePreview();}
    public function setPrismatic(value:Bool):Void {prismatic=value&&selected!=null&&selected.infusable&&bonuses.length>0;updatePreview();}
    public function updatePreview():Void {
        if(selected==null)return;
        level=selected.gear?Std.int(Math.max(1,Math.min(maxLevel,level))):0;
        if(!selected.gear)anyLevel=false;
        if(rarityOptions().indexOf(rarity)<0)rarity=selected.rarity;
        var base=selected.offer;
        preview={uid:base.uid,kind:base.kind,name:base.name,count:1,detail:"",color:base.color,fingerprint:"",preview:trade.TradePreview.copy(base.preview)};
        preview.preview.level=anyLevel?0:level;preview.preview.bonus=bonus;preview.preview.flags=prismatic?2:0;
        if(selected.weapon)preview.preview.rarity=rarity;
        nativePreview=null;
        try {
            nativePreview=trade.TradeTooltips.previewItem(preview);
            if(nativePreview!=null) {
                var description=TradeInventory.describe(nativePreview,1);
                preview.detail=description.detail;
            }
        }catch(_:Dynamic){} // Catalog entries without an instance still have their name, icon and definition.
    }
    public function metadata():Dynamic return selected==null?null:{category:selected.category,subcategory:selected.subcategory,
        classes:selected.classes,rarity:rarity,requiredLevel:selected.gear&&!anyLevel?level:0,anyLevel:anyLevel,prismatic:prismatic};
}
