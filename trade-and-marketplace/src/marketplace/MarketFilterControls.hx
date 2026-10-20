package marketplace;
import trade.GameAccess as G;

/** Keep filter interactives attached while results/layout are refreshed. */
class MarketFilterControls {
    public var active=false;
    var objects:Map<String,Dynamic>=[];
    var used:Map<String,Bool>=[];
    public function new(){}
    public function begin():Void {active=false;used=[];}
    public function contains(object:Dynamic):Bool {
        for(value in objects)if(value==object)return true;
        return false;
    }
    public function get(key:String,create:Void->Dynamic):Dynamic {
        if(!active)return create();
        used[key]=true;
        if(!objects.exists(key))objects[key]=create();
        return objects[key];
    }
    public function finish():Void {
        active=false;
        for(key in [for(key in objects.keys())if(!used.exists(key))key]) {
            G.call("h2d.Object","remove",objects[key]);objects.remove(key);
        }
    }
    public function clear():Void {active=false;objects=[];used=[];}
}
