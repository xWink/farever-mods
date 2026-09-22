import modupdatealerts.AlertSession;
import modupdatealerts.UpdateModel;
import modupdatealerts.UpdateModel.AvailableUpdate;
import modupdatealerts.UpdateWorker;
import modupdatealerts.UpdateWorker.CheckResult;

@:access(modupdatealerts.UpdateWorker)
class ProgressiveAlertTest {
    static var checks=0;
    static function eq(actual:Dynamic,expected:Dynamic):Void {
        checks++;
        if(actual!=expected) throw 'Expected $expected, got $actual';
    }
    static function u(id:Int):AvailableUpdate
        return {name:'Mod $id',domain:"farever",modId:id,current:"1",latest:"2"};
    static function result(updates:Array<AvailableUpdate>,complete:Bool=false):CheckResult
        return {updates:updates,dismissed:["farever/1"=>"2"],notes:[],complete:complete};
    public static function run():Int {
        checks=0;
        var session=new AlertSession();
        eq(session.shouldShow(),false);
        session.accept(result([u(1)]));
        eq(session.shouldShow(),false); // Suppressed partial results aren't final.
        session.accept(result([u(1),u(2)]));
        eq(session.shouldShow(),true); // Show immediately, before scan completion.
        var saved=session.select(true);
        eq(saved.get("farever/2"),"2");eq(session.shouldShow(),false);
        session.accept(result([u(1),u(2)]));
        eq(session.selected,true);eq(session.dismissed.get("farever/2"),"2");
        session.accept(result([u(1),u(2),u(3)]));
        eq(session.selected,false);eq(session.shouldShow(),true);
        eq(session.dismissed.get("farever/2"),"2");
        eq(session.dismissed.exists("farever/3"),false);
        saved=session.select(true);eq(saved.get("farever/3"),"2");
        saved=session.select(false);eq(saved.exists("farever/3"),false);
        eq(saved.get("farever/2"),"2");
        session.close();eq(session.shouldShow(),false);
        session.accept(result([u(1),u(2),u(3),u(4)],true));
        eq(session.shouldShow(),false); // Never reopen after X/Escape this launch.
        eq(UpdateModel.needsReminder(session.updates,saved),true); // Next launch still reminds.

        var initial=new AlertSession();
        initial.accept(result([]));initial.accept(result([u(2)],true));
        eq(initial.shouldShow(),true);

        // Exercise the actual worker handoff: later discoveries must not mutate
        // an earlier snapshot while the game thread is using it.
        var worker=new UpdateWorker("unused"),scan=result([u(2)]);
        worker.publish(scan,false);
        var first=worker.results.pop(false);
        eq(first.complete,false);eq(first.updates.length,1);
        scan.updates.push(u(1));scan.notes.push("final diagnostic");
        scan.dismissed.set("farever/9","2");
        worker.publish(scan,true);
        var last=worker.results.pop(false);
        eq(first.updates.length,1);eq(first.dismissed.exists("farever/9"),false);
        eq(first.notes.length,0);eq(last.updates[0].modId,1);
        eq(last.complete,true);eq(last.notes[0],"final diagnostic");
        eq(worker.results.pop(false),null);
        return checks;
    }
}
