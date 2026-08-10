package venworks.cui
{
   import Shared.AS3.Data.BSUIDataManager;
   import Shared.AS3.Data.FromClientDataEvent;
   import flash.events.Event;
   import flash.events.EventDispatcher;

   public final class CUIPlayerHudDataContext extends EventDispatcher
   {
      private var values:Object;

      public function CUIPlayerHudDataContext()
      {
         super();
         values = {};
         BSUIDataManager.Subscribe("LocalEnvironmentData",this.onLocalEnvironmentData);
         BSUIDataManager.Subscribe("LocalEnvData_Frequent",this.onLocalEnvironmentFrequentData);
         BSUIDataManager.Subscribe("PlayerFrequentData",this.onPlayerFrequentData);
         BSUIDataManager.Subscribe("WeaponData",this.onWeaponData);
         BSUIDataManager.Subscribe("HUDStarbornPowersData",this.onStarbornPowersData);
      }

      public static function normalizeSource(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var source:String = normalizeSource(param1);
         if(source == "location.name" || source == "power.key")
         {
            return "string";
         }
         if(source == "power.hasspell" || source == "weapon.displayammo" || source == "weapon.ammoaspercent")
         {
            return "boolean";
         }
         if(source == "environment.oxygenpercentage" || source == "environment.temperature" ||
            source == "environment.gravity" || source == "environment.localtime" ||
            source == "player.health" || source == "player.maxhealth" ||
            source == "player.healthpercentage" || source == "player.oxygen" ||
            source == "player.maxoxygen" || source == "player.oxygenpercentage" ||
            source == "player.carbondioxide" || source == "power.current" ||
            source == "power.maximum" || source == "power.percentage" ||
            source == "power.cost" || source == "power.cooldown" ||
            source == "weapon.clipammo" || source == "weapon.totalammo" ||
            source == "weapon.reserveammo")
         {
            return "number";
         }
         return "unknown";
      }

      public function getValue(param1:String) : Object
      {
         var source:String = normalizeSource(param1);
         if(values[source] == null)
         {
            return { known:false, value:null };
         }
         return values[source];
      }

      private function onLocalEnvironmentData(param1:FromClientDataEvent) : void
      {
         this.setText("location.name",param1.data.sLocationName);
         this.setFinite("environment.oxygenpercentage",param1.data.fOxygenPercent);
         this.setFinite("environment.temperature",param1.data.fTemperature);
         this.setFinite("environment.gravity",param1.data.fGravity);
         this.notifyChanged();
      }

      private function onLocalEnvironmentFrequentData(param1:FromClientDataEvent) : void
      {
         this.setFinite("environment.localtime",param1.data.fLocalPlanetTime);
         this.notifyChanged();
      }

      private function onPlayerFrequentData(param1:FromClientDataEvent) : void
      {
         this.setFinite("player.health",param1.data.fHealth);
         this.setFinite("player.maxhealth",param1.data.fMaxHealth);
         this.setRatio("player.healthpercentage",param1.data.fHealth,param1.data.fMaxHealth);
         this.setFinite("player.oxygen",param1.data.fOxygen);
         this.setFinite("player.maxoxygen",param1.data.fMaxO2CO2);
         this.setRatio("player.oxygenpercentage",param1.data.fOxygen,param1.data.fMaxO2CO2);
         this.setFinite("player.carbondioxide",param1.data.fCarbonDioxide);
         this.setFinite("power.current",param1.data.fStarPower);
         this.setFinite("power.maximum",param1.data.fMaxStarPower);
         this.setRatio("power.percentage",param1.data.fStarPower,param1.data.fMaxStarPower);
         this.notifyChanged();
      }

      private function onWeaponData(param1:FromClientDataEvent) : void
      {
         var clip:Number = Number(param1.data.uClipAmmo);
         var total:Number = Number(param1.data.uTotalAmmo);
         this.setFinite("weapon.clipammo",clip);
         this.setFinite("weapon.totalammo",total);
         if(!isNaN(clip) && isFinite(clip) && !isNaN(total) && isFinite(total))
         {
            this.setFinite("weapon.reserveammo",Math.max(0,total - clip));
         }
         this.setBoolean("weapon.displayammo",param1.data.bDisplayAmmo);
         this.setBoolean("weapon.ammoaspercent",param1.data.bShowAmmoAsPercent);
         this.notifyChanged();
      }

      private function onStarbornPowersData(param1:FromClientDataEvent) : void
      {
         this.setText("power.key",param1.data.sKey);
         this.setBoolean("power.hasspell",param1.data.bHasSpell);
         this.setFinite("power.cost",param1.data.fCost);
         this.setFinite("power.cooldown",param1.data.uCooldown);
         this.notifyChanged();
      }

      private function setText(param1:String, param2:Object) : void
      {
         if(param2 !== undefined && param2 !== null)
         {
            values[normalizeSource(param1)] = { known:true, value:String(param2) };
         }
      }

      private function setBoolean(param1:String, param2:Object) : void
      {
         if(param2 !== undefined && param2 !== null)
         {
            values[normalizeSource(param1)] = { known:true, value:Boolean(param2) };
         }
      }

      private function setFinite(param1:String, param2:Object) : void
      {
         var value:Number = Number(param2);
         if(!isNaN(value) && isFinite(value))
         {
            values[normalizeSource(param1)] = { known:true, value:value };
         }
      }

      private function setRatio(param1:String, param2:Object, param3:Object) : void
      {
         var value:Number = Number(param2);
         var maximum:Number = Number(param3);
         if(!isNaN(value) && isFinite(value) && !isNaN(maximum) && isFinite(maximum) && maximum > 0)
         {
            this.setFinite(param1,Math.max(0,Math.min(100,value / maximum * 100)));
         }
      }

      private function notifyChanged() : void
      {
         dispatchEvent(new Event(Event.CHANGE));
      }
   }
}
