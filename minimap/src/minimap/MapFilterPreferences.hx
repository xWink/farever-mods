package minimap;

interface MapFilterPreferences {
    public var revision(default, null):Int;
    public function enabled(category:String, ?item:String):Bool;
    public function setEnabled(category:String, item:Null<String>, value:Bool):Void;
}
