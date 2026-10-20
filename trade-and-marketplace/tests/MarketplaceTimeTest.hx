import marketplace.MarketText;
/** Run in separate processes: HashLink reads the operating-system timezone at startup. */
class MarketplaceTimeTest {
 static function main():Void {
  var inputs=["2026-08-10T21:26:00.000Z","2027-01-01T00:05:59Z","2026-03-08T09:59:00Z","2026-03-08T10:01:00Z","2026-11-01T08:59:00Z","2026-11-01T09:01:00Z","2028-02-29T12:00:00Z"];
  var expected=switch(Sys.getEnv("TZ")) {
   case "UTC":["Aug. 10, 2026 - 21:26","Jan. 1, 2027 - 00:05","Mar. 8, 2026 - 09:59","Mar. 8, 2026 - 10:01","Nov. 1, 2026 - 08:59","Nov. 1, 2026 - 09:01","Feb. 29, 2028 - 12:00"];
   case "America/Vancouver":["Aug. 10, 2026 - 14:26","Dec. 31, 2026 - 16:05","Mar. 8, 2026 - 01:59","Mar. 8, 2026 - 03:01","Nov. 1, 2026 - 01:59","Nov. 1, 2026 - 01:01","Feb. 29, 2028 - 04:00"];
   case "Asia/Kathmandu":["Aug. 11, 2026 - 03:11","Jan. 1, 2027 - 05:50","Mar. 8, 2026 - 15:44","Mar. 8, 2026 - 15:46","Nov. 1, 2026 - 14:44","Nov. 1, 2026 - 14:46","Feb. 29, 2028 - 17:45"];
   default:throw "Set TZ to a supported test timezone";
  };
  for(i in 0...inputs.length) {
   var result=MarketText.expiry(inputs[i]);
   if(result!=expected[i]+" (local)")throw inputs[i]+": "+result+" != "+expected[i];
  }
  Sys.println("Marketplace local expiry checks passed: "+inputs.length+" ("+Sys.getEnv("TZ")+")");
 }
}
