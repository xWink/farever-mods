package marketplace;

/** Time-based, reversible slide; layout remains idle once its destination is reached. */
class MarketDrawer {
    public var value(default,null)=0.0;
    public var target(default,null)=0.0;
    var from=0.0;
    var started=0.0;
    public function new() {}
    public function set(open:Bool,now:Float,snap=false):Void {
        var next=open?1.0:0.0;
        if(snap){value=target=from=next;started=now;return;}
        if(next==target)return;
        update(now);from=value;target=next;started=now;
    }
    public function update(now:Float):Void {
        if(value==target)return;
        var t=Math.max(0,Math.min(1,(now-started)/0.24));
        var eased=1-Math.pow(1-t,3);
        value=t==1?target:from+(target-from)*eased;
    }
}
