package venworks.cui
{
   import Shared.AS3.Data.BSUIDataManager;
   import Shared.AS3.Data.FromClientDataEvent;
   import Shared.AS3.Events.CustomEvent;
   import flash.events.EventDispatcher;

   public final class CUIConditionContext extends EventDispatcher
   {
      public static const CONDITION_CHANGE:String = "cuiConditionChange";
      public static const PROVIDER_ERROR:String = "cuiConditionProviderError";

      private static const FAVORITE_SLOT_COUNT:int = 12;
      private static const CRITICAL_HEALTH_PERCENTAGE:Number = 35;
      private static const MAX_INVENTORY_ITEMS:int = 256;
      private static const DIGIPICK_FORM_ID:Number = 10;

      private var values:Object;
      private var changedConditions:Object;
      private var changedConditionCount:int = 0;
      private var favoriteNames:Array;
      private var favoritePowers:Array;
      private var favoriteWeapons:Array;
      private var activeWeaponName:String = "";
      private var activePowerName:String = "";
      private var providerSubscriptions:Array;
      private var started:Boolean = false;
      private var disposed:Boolean = false;
      private var faulted:Boolean = false;
      private var disposalErrorMessage:String = "";

      public function CUIConditionContext()
      {
         super();
         values = {};
         changedConditions = {};
         favoriteNames = [];
         favoritePowers = [];
         favoriteWeapons = [];
         providerSubscriptions = [];
         this.setValue("criticalhealth",false);
         this.resetFavoriteConditions();
         this.resetChangedConditions();
      }

      public function start() : void
      {
         if(this.disposed)
         {
            throw new Error("CUI-EVT-LIFECYCLE|Condition providers cannot start after disposal.");
         }
         if(this.started)
         {
            return;
         }
         this.started = true;
         try
         {
            this.subscribeProvider("HudCrosshairData",this.onCrosshairData);
            this.subscribeProvider("HUDStealthData",this.onStealthData);
            this.subscribeProvider("HudCompassData",this.onCompassData);
            this.subscribeProvider("HUDVehicleData",this.onVehicleData);
            this.subscribeProvider("HUDOpacityData",this.onOpacityData);
            this.subscribeProvider("WeaponData",this.onWeaponData);
            this.subscribeProvider("HUDStarbornPowersData",this.onStarbornPowersData);
            this.subscribeProvider("FavoritesData",this.onFavoritesData);
            this.subscribeProvider("HudJetpackData",this.onJetpackData);
            this.subscribeProvider("PlayerInventoryData",this.onPlayerInventoryData);
         }
         catch(param1:Error)
         {
            this.faulted = true;
            this.dispose();
            throw param1;
         }
         this.resetChangedConditions();
      }

      public function get lastDisposalError() : String
      {
         return this.disposalErrorMessage;
      }

      public function dispose() : void
      {
         var subscription:Object = null;
         var failure:Error = null;
         if(this.disposed)
         {
            return;
         }
         this.disposed = true;
         this.faulted = true;
         while(this.providerSubscriptions.length != 0)
         {
            subscription = this.providerSubscriptions.pop();
            if(String(subscription.state) == "active")
            {
               try
               {
                  BSUIDataManager.Unsubscribe(String(subscription.provider),subscription.callback as Function);
               }
               catch(param1:Error)
               {
                  if(failure == null)
                  {
                     failure = param1;
                     this.disposalErrorMessage = "CUI-EVT-UNSUBSCRIBE | CONDITION | " +
                        String(subscription.provider) + " | " + param1.toString();
                  }
               }
            }
            subscription.state = "disposed";
         }
         if(failure != null)
         {
            trace(this.disposalErrorMessage);
         }
      }

      private function subscribeProvider(param1:String, param2:Function) : void
      {
         var existing:Object = null;
         var context:CUIConditionContext = this;
         var subscription:Object = null;
         var callback:Function = null;
         if(this.disposed || this.faulted)
         {
            throw new Error("CUI-EVT-LIFECYCLE|Condition provider registration stopped after a fault.");
         }
         for each(existing in this.providerSubscriptions)
         {
            if(String(existing.provider) == param1 && existing.handler === param2)
            {
               throw new Error("CUI-EVT-LIFECYCLE|Condition provider is already registered: " + param1);
            }
         }
         subscription = {
            provider:param1,
            handler:param2,
            callback:null,
            state:"pending",
            handling:false
         };
         callback = function(param3:FromClientDataEvent):void
         {
            context.handleProviderEvent(subscription,param3);
         };
         subscription.callback = callback;
         this.providerSubscriptions.push(subscription);
         try
         {
            BSUIDataManager.Subscribe(param1,callback);
            subscription.state = "active";
         }
         catch(param3:Error)
         {
            throw new Error("CUI-EVT-SUBSCRIBE|CONDITION | " + param1 + " | " + param3.toString(),param3.errorID);
         }
      }

      private function handleProviderEvent(param1:Object, param2:FromClientDataEvent) : void
      {
         var handler:Function = null;
         if(this.disposed || this.faulted)
         {
            return;
         }
         if(Boolean(param1.handling))
         {
            this.failProvider(param1,"CUI-EVT-REENTRANT",new Error("Provider callback re-entered before returning."));
            return;
         }
         if(param2 == null || param2.data == null)
         {
            this.failProvider(param1,"CUI-EVT-PAYLOAD",new Error("Provider callback did not contain data."));
            return;
         }
         param1.handling = true;
         try
         {
            handler = param1.handler as Function;
            handler(param2);
         }
         catch(param3:Error)
         {
            this.failProvider(param1,"CUI-EVT-CALLBACK",param3);
         }
         finally
         {
            param1.handling = false;
         }
      }

      private function failProvider(param1:Object, param2:String, param3:Error) : void
      {
         var details:Object = null;
         if(this.disposed || this.faulted)
         {
            return;
         }
         this.faulted = true;
         details = {
            code:param2,
            consumer:"CONDITION",
            provider:String(param1.provider),
            message:param3.toString(),
            errorID:param3.errorID,
            stack:param3.getStackTrace()
         };
         try
         {
            dispatchEvent(new CustomEvent(PROVIDER_ERROR,details));
         }
         catch(param4:Error)
         {
            trace(param2 + " | CONDITION | " + String(param1.provider) + " | " + param3.toString());
         }
      }

      public static function normalizeName(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var name:String = normalizeName(param1);
         if(/^favorite(0[1-9]|1[0-2])(active|populated|power|weapon|item)$/.test(name))
         {
            return "boolean";
         }
         if(name == "always" || name == "never" || name == "firstperson" || name == "thirdperson" ||
            name == "incombat" || name == "inscanner" || name == "issneaking" ||
            name == "weaponaiming" || name == "weaponhasammo" || name == "weaponhasexplosive" ||
            name == "weaponexplosiveismine" || name == "boostactive" || name == "invehicle" ||
            name == "digipicksavailable" || name == "hudvisible" || name == "criticalhealth")
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

      public function updateCriticalHealth(param1:Object) : void
      {
         var percentage:Number = NaN;
         var critical:Boolean = false;
         if(param1 != null && Boolean(param1.known))
         {
            percentage = Number(param1.value);
            critical = !isNaN(percentage) && isFinite(percentage) &&
               percentage < CRITICAL_HEALTH_PERCENTAGE;
         }
         this.setValue("criticalhealth",critical);
         this.notifyChanged();
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
         var data:Object = param1 == null ? null : param1.data;
         this.setValue("inscanner",data != null && Boolean(data.bIsHandscannerOpen));
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
         this.activeWeaponName = this.cleanName(param1.data.sWeaponName);
         this.setValue("weaponhasammo",Boolean(param1.data.bDisplayAmmo));
         this.setValue("weaponhasexplosive",Number(param1.data.uExplosiveCount) > 0);
         this.setValue("weaponexplosiveismine",Number(param1.data.uExplosiveIndicatorType) != 0);
         this.updateFavoriteActiveConditions();
         this.notifyChanged();
      }

      private function onStarbornPowersData(param1:FromClientDataEvent) : void
      {
         this.activePowerName = Boolean(param1.data.bHasSpell) ?
            this.resolvePowerName(param1.data.sKey) : "";
         this.updateFavoriteActiveConditions();
         this.notifyChanged();
      }

      private function onFavoritesData(param1:FromClientDataEvent) : void
      {
         var favorites:Array = param1 == null || param1.data == null ? null :
            param1.data.aFavoriteItems as Array;
         var item:Object = null;
         var index:int = 0;
         var limit:int = 0;
         var slotLabel:String = null;
         var populated:Boolean = false;
         var isPower:Boolean = false;
         var isWeapon:Boolean = false;
         this.resetFavoriteConditions();
         if(favorites != null)
         {
            limit = Math.min(favorites.length,FAVORITE_SLOT_COUNT);
            while(index < limit)
            {
               item = favorites[index];
               slotLabel = this.formatFavoriteSlot(index + 1);
               populated = item != null;
               isPower = populated && Boolean(item.bIsPower);
               isWeapon = populated && !isPower && this.cleanName(item.sAmmoName).length != 0;
               favoriteNames[index] = populated ? this.cleanName(item.sName) : "";
               favoritePowers[index] = isPower;
               favoriteWeapons[index] = isWeapon;
               this.setValue("favorite" + slotLabel + "populated",populated);
               this.setValue("favorite" + slotLabel + "power",isPower);
               this.setValue("favorite" + slotLabel + "weapon",isWeapon);
               this.setValue("favorite" + slotLabel + "item",populated && !isPower && !isWeapon);
               ++index;
            }
         }
         this.updateFavoriteActiveConditions();
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

      private function onPlayerInventoryData(param1:FromClientDataEvent) : void
      {
         this.setValue("digipicksavailable",this.hasDigipicks(param1));
         this.notifyChanged();
      }

      private function hasDigipicks(param1:FromClientDataEvent) : Boolean
      {
         var items:Array = param1 == null || param1.data == null ? null :
            param1.data.aItems as Array;
         var item:Object = null;
         var formId:Number = NaN;
         var editorId:String = "";
         var name:String = "";
         var count:Number = NaN;
         var index:int = 0;
         var limit:int = 0;
         if(items == null)
         {
            return false;
         }
         limit = Math.min(items.length,MAX_INVENTORY_ITEMS);
         while(index < limit)
         {
            item = items[index];
            if(item != null)
            {
               formId = Number(item.uFormID);
               editorId = item.sEditorID !== undefined && item.sEditorID !== null ? String(item.sEditorID) :
                  (item.EditorID !== undefined && item.EditorID !== null ? String(item.EditorID) : "");
               name = item.sName !== undefined && item.sName !== null ? String(item.sName) : "";
               if((!isNaN(formId) && isFinite(formId) && formId == DIGIPICK_FORM_ID) ||
                  editorId.toLowerCase() == "digipick" || name.toLowerCase() == "digipick")
               {
                  count = Number(item.uCount);
                  if(!isNaN(count) && isFinite(count) && count > 0)
                  {
                     return true;
                  }
               }
            }
            ++index;
         }
         return false;
      }

      private function resetFavoriteConditions() : void
      {
         var index:int = 0;
         var slotLabel:String = null;
         while(index < FAVORITE_SLOT_COUNT)
         {
            slotLabel = this.formatFavoriteSlot(index + 1);
            favoriteNames[index] = "";
            favoritePowers[index] = false;
            favoriteWeapons[index] = false;
            this.setValue("favorite" + slotLabel + "active",false);
            this.setValue("favorite" + slotLabel + "populated",false);
            this.setValue("favorite" + slotLabel + "power",false);
            this.setValue("favorite" + slotLabel + "weapon",false);
            this.setValue("favorite" + slotLabel + "item",false);
            ++index;
         }
      }

      private function updateFavoriteActiveConditions() : void
      {
         var index:int = 0;
         var slotLabel:String = null;
         var name:String = null;
         var populatedValue:Object = null;
         var populated:Boolean = false;
         var weaponMatch:Boolean = false;
         var effectiveWeapon:Boolean = false;
         var active:Boolean = false;
         while(index < FAVORITE_SLOT_COUNT)
         {
            slotLabel = this.formatFavoriteSlot(index + 1);
            name = String(favoriteNames[index]);
            populatedValue = values["favorite" + slotLabel + "populated"];
            populated = populatedValue != null && Boolean(populatedValue.known) && Boolean(populatedValue.value);
            weaponMatch = populated && !Boolean(favoritePowers[index]) && activeWeaponName.length != 0 && name == activeWeaponName;
            effectiveWeapon = Boolean(favoriteWeapons[index]) || weaponMatch;
            this.setValue("favorite" + slotLabel + "weapon",effectiveWeapon);
            this.setValue("favorite" + slotLabel + "item",populated && !Boolean(favoritePowers[index]) && !effectiveWeapon);
            active = name.length != 0 &&
               ((Boolean(favoritePowers[index]) && activePowerName.length != 0 && name == activePowerName) ||
                weaponMatch);
            this.setValue("favorite" + slotLabel + "active",active);
            ++index;
         }
      }

      private function formatFavoriteSlot(param1:int) : String
      {
         return (param1 < 10 ? "0" : "") + param1.toString();
      }

      private function cleanName(param1:Object) : String
      {
         if(param1 === undefined || param1 === null)
         {
            return "";
         }
         return String(param1).replace(/[\r\n\t]+/g," ").replace(/^\s+|\s+$/g,"").toLowerCase();
      }

      private function resolvePowerName(param1:Object) : String
      {
         var key:String = param1 === undefined || param1 === null ? "" : String(param1);
         switch(key)
         {
            case "ArtifactPower_AlienReanim": return "alien reanimation";
            case "ArtifactPower_AntiGravityField": return "anti-gravity field";
            case "ArtifactPower_CreateVacuum": return "create vacuum";
            case "ArtifactPower_CreatorsPeace": return "creators' peace";
            case "ArtifactPower_Earthbound": return "earthbound";
            case "ArtifactPower_ElementalBlast": return "elemental pull";
            case "ArtifactPower_EternalHarvest": return "eternal harvest";
            case "ArtifactPower_GravDash": return "grav dash";
            case "ArtifactPower_GravWave": return "gravity wave";
            case "ArtifactPower_GravWell": return "gravity well";
            case "ArtifactPower_InnerDemon": return "inner demon";
            case "ArtifactPower_LifeForced": return "life forced";
            case "ArtifactPower_MoonForm": return "moon form";
            case "ArtifactPower_ParallelSelf": return "parallel self";
            case "ArtifactPower_ParticleBeam": return "particle beam";
            case "ArtifactPower_PersonalAtmo": return "personal atmosphere";
            case "ArtifactPower_PhasedTime": return "phased time";
            case "ArtifactPower_Precognition": return "precognition";
            case "ArtifactPower_ReactiveShield": return "reactive shield";
            case "ArtifactPower_SenseStarStuff": return "sense star stuff";
            case "ArtifactPower_SolarFlare": return "solar flare";
            case "ArtifactPower_SunlessSpace": return "sunless space";
            case "ArtifactPower_Supernova": return "supernova";
            case "ArtifactPower_VoidForm": return "void form";
         }
         return "";
      }

      private function setValue(param1:String, param2:Object) : void
      {
         var name:String = normalizeName(param1);
         var current:Object = values[name];
         if(current != null && Boolean(current.known) && current.value === param2)
         {
            return;
         }
         values[name] = { known:true, value:param2 };
         if(changedConditions[name] !== true)
         {
            changedConditions[name] = true;
            ++changedConditionCount;
         }
      }

      private function notifyChanged() : void
      {
         var conditions:Object = null;
         if(changedConditionCount == 0)
         {
            return;
         }
         conditions = changedConditions;
         this.resetChangedConditions();
         dispatchEvent(new CustomEvent(CONDITION_CHANGE,conditions));
      }

      private function resetChangedConditions() : void
      {
         changedConditions = {};
         changedConditionCount = 0;
      }
   }
}
