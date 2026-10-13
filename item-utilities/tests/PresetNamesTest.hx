import haxe.Json;
import itemutilities.PresetNames as Names;
import itemutilities.CharacterResetStore;
import itemutilities.CharacterResetStore.CharacterResetKind;

class PresetNamesTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        check(Names.labels(null, "db:1").join(",") == "Preset 1,Preset 2,Preset 3,Preset 4,Preset 5", "Old configurations keep all default labels");
        check(Names.clean("  Raid build  ") == "Raid build", "Saved names trim outer whitespace");
        check(Names.limit("Raid ") == "Raid ", "Typing a space does not join words");
        check(Names.clean("123456789012345678") == "123456789012345", "ASCII length limit");
        check(Names.clean("é火😀1234567890123") == "é火😀123456789012", "Unicode characters count once and remain intact");
        check(Names.clean("Raid\nset\t1") == "Raid set 1", "Pasted controls cannot create multiline labels");
        check(Names.clean(" \n\t ") == "", "Blank restores the default");

        var values:Dynamic = {weaponPresets:[{characterId:"db:1",preset:0,weapons:[{uid:"item"}]}]};
        var kinds:Array<CharacterResetKind> = [Equipment, Talent, Skill, Appearance];
        var keys = ["weaponPresetNames", "talentPresetNames", "skillPresetNames", "appearancePresetNames"];
        for (k in 0...keys.length) {
            var records:Array<Dynamic> = [{characterId:"db:10",preset:0,name:"Other character"}];
            for (slot in 0...5) records=Names.renamed(records,"db:1",slot,"Build " + k + " / " + slot);
            Reflect.setField(values,keys[k],records);
        }
        var original=Json.stringify(values);
        values=Json.parse(original);
        for (k in 0...keys.length) {
            var records:Array<Dynamic>=Reflect.field(values,keys[k]);
            for (slot in 0...5) check(Names.labels(records,"db:1")[slot]=="Build " + k + " / " + slot,
                "Every slot/category survives a JSON round trip");
            check(Names.labels(records,"db:10")[0]=="Other character", "Characters never share names");
            check(Names.labels(records,null)[0]=="Preset 1", "Logged out defaults");
            var changed=Names.renamed(records,"db:1",4,"New name");
            check(Names.labels(changed,"db:1")[4]=="New name" && Names.labels(records,"db:1")[4]!="New name",
                "Rename copies records before committing");
            changed=Names.renamed(changed,"db:1",4,"");
            check(Names.labels(changed,"db:1")[4]=="Preset 5", "Empty name removes only its own override");
            var reset=CharacterResetStore.cleared(values,"db:1",kinds[k]);
            check(Names.labels(Reflect.field(reset,keys[k]),"db:1").join(",")==Names.labels(null,"db:1").join(","),
                "Red reset restores all five names even for unsaved slots");
            check(Names.labels(Reflect.field(reset,keys[k]),"db:10")[0]=="Other character", "Reset preserves other characters' names");
            for (other in 0...keys.length) if (other != k)
                check(Json.stringify(Reflect.field(reset,keys[other]))==Json.stringify(Reflect.field(values,keys[other])),
                    "Reset preserves other preset categories' names");
        }
        check(Json.stringify(values)==original, "Renaming/reset preparation leaves saved setups and source records unchanged");
        for (input in [{id:null,slot:0},{id:"",slot:0},{id:"db:1",slot:-1},{id:"db:1",slot:5}]) {
            var rejected=false;
            try Names.renamed([],input.id,input.slot,"Build") catch (_:Dynamic) rejected=true;
            check(rejected,"Invalid identity/slot cannot create a name record");
        }
        trace('Preset names: $checks checks passed');
    }
}
