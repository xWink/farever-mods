import trade.*;
class InfusionNamesTest {
    static var checks=0;
    static function check(ok:Bool,message:String):Void {checks++;if(!ok)throw message;}
    public static function main():Void {
        GameAccess.skills={byId:{get:function(id:String):Dynamic return switch(id){
            case "Infusion_Manfish_DPS": {texts:{name:"Overwhelming Tides"}};
            case "Infusion_Ref": {texts:{name:"::ref_skill::",refs:{ref:"Infusion_Manfish_DPS"}}};
            case "Infusion_Loop": {texts:{refs:{ref:"Infusion_Loop"}}};
            default:null;
        }}};
        check(TradeInventory.skillName("Infusion_Manfish_DPS")=="Overwhelming Tides","Infusions use native skill display names");
        check(TradeInventory.skillName("Infusion_Ref")=="Overwhelming Tides","Infusion name references resolve");
        check(TradeInventory.skillName("Infusion_Loop")=="Infusion_Loop","Cyclic references are bounded");
        var named:Dynamic={__uid:"x",kind:"Sword",inf:{},infusion:"Infusion_Manfish_DPS",getName:()->"Sword"};
        check(TradeInventory.describe(named,1).detail.indexOf("Infusion: Overwhelming Tides")>=0,"New exports contain infusion display names");
        Sys.println("Infusion name checks passed: "+checks);
    }
}
