package venworks.cui
{
   import Shared.AS3.Data.BSUIDataManager;
   import Shared.AS3.Data.FromClientDataEvent;
   import flash.events.Event;
   import flash.events.EventDispatcher;

   public final class CUIConditionContext extends EventDispatcher
   {
      private var values:Object;

      public function CUIConditionContext()
      {
         super();
         values = {};
         BSUIDataManager.Subscribe("HudCrosshairData",this.onCrosshairData);
         BSUIDataManager.Subscribe("HUDStealthData",this.onStealthData);
         BSUIDataManager.Subscribe("HudCompassData",this.onCompassData);
         BSUIDataManager.Subscribe("HUDVehicleData",this.onVehicleData);
         BSUIDataManager.Subscribe("HUDOpacityData",this.onOpacityData);
         BSUIDataManager.Subscribe("WeaponData",this.onWeaponData);
         BSUIDataManager.Subscribe("HudJetpackData",this.onJetpackData);
      }

      public static function normalizeName(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var name:String = normalizeName(param1);
         if(name == "always" || name == "never" || name == "firstperson" || name == "thirdperson" ||
            name == "incombat" || name == "inscanner" || name == "issneaking" ||
            name == "weaponaiming" || name == "weaponhasammo" || name == "weaponhasexplosive" ||
            name == "weaponexplosiveismine" || name == "boostactive" || name == "invehicle" || name == "hudvisible")
         {
            return "boolean";
         }
         if(name == "hudopacitypercentage")
         {
            return "number";
         }
         if(name == "hascombateffect" || name == "hasenvironmenteffect")
         {
            return "unavailable-function";
         }
         return "unknown";
      }

      public function getValue(param1:String) : Object
      {
         var name:String = normalizeName(param1);
         if(name == "always")
         {
            return { known:true, value:true };
         }
         if(name == "never")
         {
            return { known:true, value:false };
         }
         return values[name];
      }

      public function get hudOpacity() : Number
      {
         var value:Object = values["hudopacitypercentage"];
         if(value == null || !Boolean(value.known))
         {
            return NaN;
         }
         return Number(value.value) / 100;
      }

      private function onCrosshairData(param1:FromClientDataEvent) : void
      {
         this.setValue("thirdperson",Boolean(param1.data.bIn3rdPerson));
         this.setValue("firstperson",!Boolean(param1.data.bIn3rdPerson));
         this.setValue("weaponaiming",Boolean(param1.data.bIronSights));
         this.notifyChanged();
      }

      private function onStealthData(param1:FromClientDataEvent) : void
      {
         this.setValue("incombat",Boolean(param1.data.bIsInCombat));
         this.setValue("issneaking",Boolean(param1.data.bSneaking));
         this.notifyChanged();
      }

      private function onCompassData(param1:FromClientDataEvent) : void
      {
         this.setValue("inscanner",Boolean(param1.data.bIsHandscannerOpen));
         this.notifyChanged();
      }

      private function onVehicleData(param1:FromClientDataEvent) : void
      {
         this.setValue("invehicle",Boolean(param1.data.bInVehicle));
         this.notifyChanged();
      }

      private function onOpacityData(param1:FromClientDataEvent) : void
      {
         var opacity:Number = Number(param1.data.fHUDOpacity);
         if(isNaN(opacity) || !isFinite(opacity))
         {
            return;
         }
         opacity = Math.max(0,Math.min(1,opacity));
         this.setValue("hudopacitypercentage",opacity * 100);
         this.setValue("hudvisible",opacity > 0);
         this.notifyChanged();
      }

      private function onWeaponData(param1:FromClientDataEvent) : void
      {
         this.setValue("weaponhasammo",Boolean(param1.data.bDisplayAmmo));
         this.setValue("weaponhasexplosive",Number(param1.data.uExplosiveCount) > 0);
         this.setValue("weaponexplosiveismine",Number(param1.data.uExplosiveIndicatorType) != 0);
         this.notifyChanged();
      }

      private function onJetpackData(param1:FromClientDataEvent) : void
      {
         var charge:Number = Number(param1.data.fJetpackCharge);
         if(isNaN(charge) || !isFinite(charge))
         {
            return;
         }
         this.setValue("boostactive",charge > 0 && charge < 1);
         this.notifyChanged();
      }

      private function setValue(param1:String, param2:Object) : void
      {
         values[param1] = { known:true, value:param2 };
      }

      private function notifyChanged() : void
      {
         dispatchEvent(new Event(Event.CHANGE));
      }
   }
}
