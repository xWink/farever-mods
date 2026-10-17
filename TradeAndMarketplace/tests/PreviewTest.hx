import trade.*;
class PreviewTest {
 static var checks=0;
 static function check(b:Bool,s:String):Void { checks++; if(!b) throw s; }
 static function main() {
  GameAccess.app={me:{uid:"me",isMe:true,hero:{uid:"hero"}}};
  var c=new TradeController(); c.togglePreview();
  check(c.previewMode && c.open && c.state.phase=="offering","Preview opens without party");
  check(c.state.theirs.length==1 && c.state.theirs[0].count==3,"Read-only sample offer");
  c.receive(null,null,"!winktrade1:malicious");
  c.addSlot({},false); check(c.state.mine.length==1 && c.state.outbox.length==0,"Offer stays local");
  c.accept(); check(c.state.accepted && c.state.peerAccepted,"Acceptance preview");
  for(i in 0...10) c.update(GameAccess.app,1000000+i);
  check(c.state.phase=="offering" && c.view.updates==10,"No exchange or timeout in preview");
  check(!c.controlsLocked() && c.canAccept() && c.inventorySpaceReason()=="","No real movement or inventory gate");
  c.driveMovement({}); check(!c.blocksPickup({},"hero"),"No movement or pickup interception");
  c.remove("1"); check(c.state.mine.length==0 && !c.state.accepted && !c.state.peerAccepted,"Editing clears acceptance locally");
  c.togglePreview(); c.update(GameAccess.app,1000020);
  check(!c.previewMode && !c.open && c.state.outbox.length==0,"Closing sends no cancel packet");
  c.togglePreview(); TradeMod.on=false; c.update(GameAccess.app,1000030);
  check(!c.previewMode && !c.open,"Disable closes preview without sending");
  TradeMod.on=true; c.togglePreview(); GameAccess.app.me={}; c.update(GameAccess.app,1000040);
  check(c.state==null && !c.previewMode,"Player replacement cleans up preview");
  Sys.println("Preview checks passed: "+checks);
 }
}
