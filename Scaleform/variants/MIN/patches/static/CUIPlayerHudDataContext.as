package venworks.cui
{
   public final class CUIPlayerHudDataContext
   {
      public function CUIPlayerHudDataContext()
      {
         super();
      }

      public function start() : void
      {
      }

      public function get lastDisposalError() : String
      {
         return "";
      }

      public static function normalizeSource(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var source:String = normalizeSource(param1);
         if(/^favorite\.(0[1-9]|1[0-2])\.(name|detail|hotkey)$/.test(source))
         {
            return "string";
         }
         if(source == "location.name" || source == "environment.solartransitioncountdown" ||
            source == "player.serial" ||
            source == "power.key" || source == "power.name" ||
            source == "quest.objective" ||
            source == "weapon.name" || source == "weapon.icon" || source == "weapon.ammotype" ||
            source == "weapon.explosivelabel" ||
            source == "diagnostic.inventoryprovider" || source == "diagnostic.powernameprovider" ||
            source == "environment.protectionstatus" ||
            source == "environment.hazard.airwaterstatus" || source == "environment.hazard.thermalstatus" ||
            source == "environment.hazard.corrosivestatus" || source == "environment.hazard.radiationstatus" ||
            source == "environment.hazard.airwatershortstatus" || source == "environment.hazard.thermalshortstatus" ||
            source == "environment.hazard.corrosiveshortstatus" || source == "environment.hazard.radiationshortstatus" ||
            source == "diagnostic.environmentprovider" || source == "diagnostic.environmentfields" ||
            source == "diagnostic.environmentcandidates" || source == "diagnostic.localenvironmentfields" ||
            source == "diagnostic.activityoxygen" || source == "diagnostic.activityenvelope" ||
            source == "diagnostic.activityprotection" || source == "diagnostic.activityloads" ||
            source == "diagnostic.playerfields" || source == "diagnostic.playertargets" ||
            source == "diagnostic.playeridentifiers" || source == "diagnostic.playertimeinventory" ||
            source == "diagnostic.effect0" || source == "diagnostic.effect1" ||
            source == "diagnostic.effect2" || source == "diagnostic.effect3" ||
            source == "diagnostic.armorresistance" || source == "diagnostic.starmapprovider")
         {
            return "string";
         }
         if(source == "power.hasspell" || source == "weapon.displayammo" || source == "weapon.ammoaspercent" ||
            source == "environment.fullsoakalertcandidate")
         {
            return "boolean";
         }
         if(source == "environment.oxygenpercentage" || source == "environment.temperature" ||
            source == "environment.gravity" || source == "environment.localtime" ||
            source == "player.universaltime" || source == "player.level" ||
            source == "player.levelxp" || source == "player.nextlevelxp" ||
            source == "player.xppercentage" || source == "player.health" || source == "player.maxhealth" ||
            source == "player.healthpercentage" || source == "player.oxygen" ||
            source == "player.maxoxygen" || source == "player.oxygenpercentage" ||
            source == "player.carbondioxide" || source == "player.carbondioxidepercentage" ||
            source == "player.digipicks" || source == "power.current" ||
            source == "power.maximum" || source == "power.percentage" ||
            source == "power.cost" || source == "power.cooldown" ||
            source == "carry.current" || source == "carry.maximum" || source == "carry.percentage" ||
            source == "credits" ||
            source == "weapon.clipammo" || source == "weapon.totalammo" ||
            source == "weapon.reserveammo" || source == "weapon.explosivecount" ||
            source == "weapon.explosivetype" || source == "boost.charge" ||
            source == "boost.percentage" ||
            source == "environment.hazard.effectcount" || source == "environment.hazard.airwaterlevel" ||
            source == "environment.hazard.thermallevel" || source == "environment.hazard.corrosivelevel" ||
            source == "environment.hazard.radiationlevel" ||
            source == "environment.hazard.airwaterexposurelevel" ||
            source == "environment.hazard.thermalexposurelevel" ||
            source == "environment.hazard.corrosiveexposurelevel" ||
            source == "environment.hazard.radiationexposurelevel" || source == "environment.soakcandidate" ||
            source == "environment.protectionlevel" || source == "environment.protectionpercentage")
         {
            return "number";
         }
         return "unknown";
      }

      public function get currentCompassData() : Object
      {
         return null;
      }

      public function get currentTacticalAwarenessData() : Object
      {
         return null;
      }

      public function getValue(param1:String) : Object
      {
         return { known:false, value:null };
      }

      public function dispose() : void
      {
      }
   }
}
