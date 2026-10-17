package minimap;

typedef MapPoint = {
    var x:Float;
    var y:Float;
    var z:Float;
    var kind:String;
    var ?activityIcon:String;
    var ?elevation:Int;
    var ?heading:Float;
    var ?sparkling:Bool;
    var ?partyMember:Bool;
    var ?friend:Bool;
    var ?respawnUnlocked:Bool;
    var ?eventElement:String;
    var ?entity:Dynamic;
    var ?inf:Dynamic;
    var ?name:String;
    var ?hasMarker:Bool;
}
