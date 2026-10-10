package hl;

/** Explicit interpreter stand-in for the native skill's virtual type. */
class Type {
    var name:String;
    function new(name:String) this.name = name;
    public static function getDynamic(value:Dynamic):Type {
        var name = Reflect.field(value, "__type");
        if (name == null) throw "Missing native type in test";
        return new Type(name);
    }
    public function getTypeName():String return name;
}
