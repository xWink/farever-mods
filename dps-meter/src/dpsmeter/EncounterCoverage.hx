package dpsmeter;

typedef CoverageEvidence = {complete:Bool, start:Float};
typedef CoverageHit = {attempt:EncounterCoverage, serial:Int};

/** Evidence for one attempt, independent of combat UI/timer boundaries.
    Only an observed ready state can arm a start. Later phases cannot repair
    missing evidence, and seeing damage is different from recording it. */
class EncounterCoverage {
    var armed:Bool = false;
    var begun:Bool = false;
    var observedStart:Bool = false;
    var firstDamage:Float = -1;
    var firstRecorded:Bool = false;
    var serial:Int = 0;
    public function new() {}
    public function ready():Void { if (!begun) armed = true; }
    public function begin():Void {
        if (begun) return;
        begun = true; observedStart = armed; armed = false;
    }
    public function interrupt():Void {
        begun = true; armed = false; observedStart = false;
    }
    public function damage(now:Float):CoverageHit {
        begin();
        if (firstDamage < 0) firstDamage = now;
        return {attempt:this, serial:++serial};
    }
    public function record(hit:CoverageHit):CoverageEvidence {
        if (hit.serial == 1) firstRecorded = true;
        return {complete:complete(), start:firstDamage};
    }
    public function complete():Bool return observedStart && firstRecorded;
}
