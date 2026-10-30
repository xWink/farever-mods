package dpsmeter;

/** Presets change only when a graph is selected; event dropdowns remain independently editable. */
class ReportGraphFilters {
    public static inline var YOU = "@me";
    public static function preset(metric:String):{filter:String, source:String, target:String} return switch(metric) {
        case "incoming": {filter:"incoming", source:"", target:YOU};
        case "healing": {filter:"healing", source:YOU, target:""};
        case "shield": {filter:"shield", source:YOU, target:""};
        case "buffs": {filter:"buffs", source:"", target:YOU};
        case "debuffs": {filter:"debuffs", source:"", target:""};
        default: {filter:"outgoing", source:YOU, target:""};
    };
    public static function actor(value:String, me:String):String return value == YOU && me != "" ? me : value;
    public static function choices(values:Array<{value:String, name:String}>, me:String):Array<{value:String, name:String}> {
        var result = [for (choice in values) {value:me != "" && choice.value == me ? YOU : choice.value,
            name:me != "" && choice.value == me ? "You" : choice.name}];
        if (!Lambda.exists(result, choice -> choice.value == YOU)) result.insert(1, {value:YOU, name:"You"});
        return result;
    }
}
