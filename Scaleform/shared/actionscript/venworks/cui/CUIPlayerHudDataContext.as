package venworks.cui
{
   import Shared.AS3.Data.BSUIDataManager;
   import Shared.AS3.Data.FromClientDataEvent;
   import Shared.AS3.Events.CustomEvent;
   import Shared.Components.ButtonControls.Utils.ButtonKeyHelper;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.TimerEvent;
   import flash.utils.Timer;

   public final class CUIPlayerHudDataContext extends EventDispatcher
   {
      public static const VALUE_CHANGE:String = "cuiValueChange";
      public static const COMPASS_CHANGE:String = "cuiCompassChange";
      public static const TACTICAL_AWARENESS_CHANGE:String = "cuiTacticalAwarenessChange";

      private static const MAX_DIAGNOSTIC_FIELDS:int = 12;
      private static const MAX_PLAYER_DIAGNOSTIC_FIELDS:int = 32;
      private static const MAX_DIAGNOSTIC_EFFECTS:int = 4;
      private static const MAX_HAZARD_EFFECTS:int = 32;
      private static const MAX_DIAGNOSTIC_INVENTORY_ITEMS:int = 256;
      private static const MAX_FAVORITE_SLOTS:int = 12;
      private static const DIGIPICK_FORM_ID:Number = 10;
      private static const PLAYER_SERIAL_ALPHABET:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      private static const PLAYER_SERIAL_LENGTH:int = 18;
      private static const PLAYER_SERIAL_SEED_A:uint = 0x811C9DC5;
      private static const PLAYER_SERIAL_SEED_B:uint = 0x9E3779B9;
      private static const EXPOSURE_UPDATE_MS:int = 250;
      private static const EXPOSURE_LERP:Number = 0.18;
      private static const EXPOSURE_TARGET_MIN_TICKS:int = 6;
      private static const EXPOSURE_TARGET_TICK_RANGE:int = 11;
      private static const ACTIVITY_DRAIN_EPSILON:Number = 0.0005;
      private static const ACTIVITY_ATTACK_STEP:Number = 0.08;
      private static const ACTIVITY_RELEASE_STEP:Number = 0.10;
      private static const EXPOSURE_SOURCES:Array = [
         "environment.hazard.airwaterexposurelevel",
         "environment.hazard.thermalexposurelevel",
         "environment.hazard.corrosiveexposurelevel",
         "environment.hazard.radiationexposurelevel"
      ];

      private var values:Object;
      private var changedSources:Object;
      private var changedSourceCount:int = 0;
      private var exposureTimer:Timer;
      private var exposureActive:Array;
      private var exposureCurrent:Array;
      private var exposureTarget:Array;
      private var exposureTargetTicks:Array;
      private var exposureRandom:Array;
      private var currentProtection:Number = 1;
      private var protectionKnown:Boolean = false;
      private var currentFullSoak:Boolean = false;
      private var environmentalCritical:Boolean = false;
      private var currentOxygen:Number = NaN;
      private var previousOxygen:Number = NaN;
      private var oxygenDrainDetected:Boolean = false;
      private var oxygenActivity:Number = 0;
      private var favoriteNames:Array;
      private var favoriteDetails:Array;
      private var buttonKeyHelper:ButtonKeyHelper;
      private var universalTimeDiagnostic:String = "UT: LOCAL ENV FREQUENT DATA NOT RECEIVED";
      private var digipickDiagnostic:String = "DIGIPICK: PLAYER INVENTORY DATA NOT RECEIVED";
      private var compassData:Object;
      private var tacticalAwareness:CUITacticalAwarenessModel;
      private var providerSubscriptions:Array;
      private var disposed:Boolean = false;

      public function CUIPlayerHudDataContext()
      {
         super();
         values = {};
         changedSources = {};
         exposureActive = [false,false,false,false];
         exposureCurrent = [0,0,0,0];
         exposureTarget = [0,0,0,0];
         exposureTargetTicks = [0,0,0,0];
         exposureRandom = [0,0,0,0];
         favoriteNames = [];
         favoriteDetails = [];
         tacticalAwareness = new CUITacticalAwarenessModel();
         buttonKeyHelper = new ButtonKeyHelper();
         providerSubscriptions = [];
         exposureTimer = new Timer(EXPOSURE_UPDATE_MS);
         exposureTimer.addEventListener(TimerEvent.TIMER,this.onExposureTimer);
         this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA NOT RECEIVED");
         this.setText("diagnostic.powernameprovider","HUD POWER NAME FIELDS NOT RECEIVED");
         this.setText("diagnostic.environmentprovider","ENVIRONMENTEFFECTSDATA NOT RECEIVED");
         this.setText("diagnostic.environmentfields","ENVIRONMENT ROOT FIELDS UNAVAILABLE");
         this.setText("diagnostic.environmentcandidates","PULSE / AGGREGATE CANDIDATES UNAVAILABLE");
         this.setText("diagnostic.localenvironmentfields","LOCALENVIRONMENTDATA NOT RECEIVED");
         this.setText("diagnostic.armorresistance","EQUIPPED ARMOR RESISTANCE DATA NOT RECEIVED");
         this.setText("diagnostic.starmapprovider","STARMAP BODY PROVIDER NOT RECEIVED IN HUD");
         this.setText("diagnostic.activityoxygen","PLAYER O2 RESERVE: WAITING // DOWNWARD DRAIN: FALSE");
         this.setText("diagnostic.activityenvelope","O2 ACTIVITY ENVELOPE: 0%");
         this.setText("diagnostic.activityprotection","SUIT PROTECTION: WAITING // FULL-SOAK FLAG: FALSE // CRITICAL OVERRIDE: FALSE");
         this.setText("diagnostic.activityloads","LOADS: AIR/WATER 0% // THERMAL 0% // CORROSIVE 0% // RADIATION 0%");
         this.setText("diagnostic.playerfields","PLAYERDATA NOT RECEIVED");
         this.setText("diagnostic.playertargets","PLAYER TARGETS: WAITING");
         this.setText("diagnostic.playeridentifiers","DETERMINISTIC SERIAL: WAITING FOR PLAYERDATA");
         this.resetFavoriteHotkeys();
         this.resetFavoriteSlots();
         this.updatePlayerTimeInventoryDiagnostic();
         this.resetEnvironmentalHazards();
         this.setText("environment.protectionstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.airwaterstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.thermalstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.corrosivestatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.radiationstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.airwatershortstatus","WAITING");
         this.setText("environment.hazard.thermalshortstatus","WAITING");
         this.setText("environment.hazard.corrosiveshortstatus","WAITING");
         this.setText("environment.hazard.radiationshortstatus","WAITING");
         this.setText("quest.objective","");
         this.resetChangedSources();
         try
         {
            providerSubscriptions.push({ provider:"LocalEnvironmentData", callback:this.onLocalEnvironmentData });
            BSUIDataManager.Subscribe("LocalEnvironmentData",this.onLocalEnvironmentData);
            providerSubscriptions.push({ provider:"LocalEnvData_Frequent", callback:this.onLocalEnvironmentFrequentData });
            BSUIDataManager.Subscribe("LocalEnvData_Frequent",this.onLocalEnvironmentFrequentData);
            providerSubscriptions.push({ provider:"PlayerData", callback:this.onPlayerData });
            BSUIDataManager.Subscribe("PlayerData",this.onPlayerData);
            providerSubscriptions.push({ provider:"PlayerFrequentData", callback:this.onPlayerFrequentData });
            BSUIDataManager.Subscribe("PlayerFrequentData",this.onPlayerFrequentData);
            providerSubscriptions.push({ provider:"PlayerInventoryData", callback:this.onPlayerInventoryData });
            BSUIDataManager.Subscribe("PlayerInventoryData",this.onPlayerInventoryData);
            providerSubscriptions.push({ provider:"WeaponData", callback:this.onWeaponData });
            BSUIDataManager.Subscribe("WeaponData",this.onWeaponData);
            providerSubscriptions.push({ provider:"HudJetpackData", callback:this.onJetpackData });
            BSUIDataManager.Subscribe("HudJetpackData",this.onJetpackData);
            providerSubscriptions.push({ provider:"HUDStarbornPowersData", callback:this.onStarbornPowersData });
            BSUIDataManager.Subscribe("HUDStarbornPowersData",this.onStarbornPowersData);
            providerSubscriptions.push({ provider:"FavoritesData", callback:this.onFavoritesData });
            BSUIDataManager.Subscribe("FavoritesData",this.onFavoritesData);
            providerSubscriptions.push({ provider:"ControlMapData", callback:this.onControlMapData });
            BSUIDataManager.Subscribe("ControlMapData",this.onControlMapData);
            providerSubscriptions.push({ provider:"EnvironmentEffectsData", callback:this.onEnvironmentEffectsData });
            BSUIDataManager.Subscribe("EnvironmentEffectsData",this.onEnvironmentEffectsData);
            providerSubscriptions.push({ provider:"PersonalEffectsData", callback:this.onPersonalEffectsData });
            BSUIDataManager.Subscribe("PersonalEffectsData",this.onPersonalEffectsData);
            providerSubscriptions.push({ provider:"StarmapSystemBodyInfoProvider", callback:this.onStarmapSystemBodyInfoData });
            BSUIDataManager.Subscribe("StarmapSystemBodyInfoProvider",this.onStarmapSystemBodyInfoData);
            providerSubscriptions.push({ provider:"HudCompassData", callback:this.onRadarCompassData });
            BSUIDataManager.Subscribe("HudCompassData",this.onRadarCompassData);
         }
         catch(param1:Error)
         {
            this.dispose();
            throw param1;
         }
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
            source == "diagnostic.activityprotection" ||
            source == "diagnostic.activityloads" ||
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

      public static function resolveTrackedObjective(param1:Object) : String
      {
         var markers:Array = param1 == null ? null : param1.aMissionMarkers as Array;
         var marker:Object = null;
         var text:String = "";
         var fallback:String = "";
         var index:int = 0;
         if(markers == null)
         {
            return "";
         }
         while(index < markers.length)
         {
            marker = markers[index];
            if(marker != null && marker.strText !== undefined && marker.strText !== null)
            {
               text = String(marker.strText).replace(/^\s+|\s+$/g,"");
               if(text.length != 0)
               {
                  if(marker.bShouldShowText === true)
                  {
                     return text;
                  }
                  if(fallback.length == 0)
                  {
                     fallback = text;
                  }
               }
            }
            ++index;
         }
         return fallback;
      }

      public function get currentCompassData() : Object
      {
         return compassData;
      }

      public function get currentTacticalAwarenessData() : Object
      {
         return tacticalAwareness.snapshot;
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
         if(this.disposed)
         {
            return;
         }
         this.clearValue("environment.solartransitioncountdown");
         if(param1 == null || param1.data == null)
         {
            this.notifyChanged();
            return;
         }
         this.setText("location.name",param1.data.sLocationName);
         this.setFinite("environment.oxygenpercentage",param1.data.fOxygenPercent);
         this.setFinite("environment.temperature",param1.data.fTemperature);
         this.setFinite("environment.gravity",param1.data.fGravity);
         this.setText("diagnostic.localenvironmentfields","LOCAL ENV ROOT: " + this.listFieldNames(param1.data,MAX_DIAGNOSTIC_FIELDS));
         this.notifyChanged();
      }

      private function onEnvironmentEffectsData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var effects:Array = param1.data.aEnvironmentEffects as Array;
         var activeEffects:Array = [false,false,false,false];
         var effect:Object = null;
         var icon:String = "";
         var normalizedIcon:String = "";
         var soakProtection:Number = Number(param1.data.fSoakDamagePct);
         var normalizedProtection:Number = 0;
         var fullSoak:Boolean = param1.data.bShouldPlayAlertAtFullSoak !== undefined &&
            param1.data.bShouldPlayAlertAtFullSoak !== null &&
            Boolean(param1.data.bShouldPlayAlertAtFullSoak);
         var index:int = 0;
         var diagnosticIndex:int = 0;
         this.resetEnvironmentalHazards();
         this.clearValue("environment.soakcandidate");
         this.clearValue("environment.fullsoakalertcandidate");
         this.clearValue("environment.protectionlevel");
         this.clearValue("environment.protectionpercentage");
         this.setText("environment.protectionstatus","PROTECTION DATA UNAVAILABLE");
         this.setText("diagnostic.environmentprovider","ENVIRONMENTEFFECTSDATA RECEIVED");
         this.setText("diagnostic.environmentfields","ENVIRONMENT ROOT: " + this.listFieldNames(param1.data,MAX_DIAGNOSTIC_FIELDS));
         this.setText("diagnostic.environmentcandidates","PULSE / AGGREGATE CANDIDATES: " +
            this.listCandidateFields(param1.data,["pulse","speed","threat","severity","exposure","soak"],8));
         this.setFinite("environment.soakcandidate",param1.data.fSoakDamagePct);
         this.setBoolean("environment.fullsoakalertcandidate",param1.data.bShouldPlayAlertAtFullSoak);
         this.currentFullSoak = fullSoak;
         this.protectionKnown = false;
         if(!isNaN(soakProtection) && isFinite(soakProtection))
         {
            normalizedProtection = Math.max(0,Math.min(1,soakProtection));
            this.currentProtection = normalizedProtection;
            this.protectionKnown = true;
            this.setFinite("environment.protectionlevel",normalizedProtection);
            this.setFinite("environment.protectionpercentage",normalizedProtection * 100);
            if(fullSoak || normalizedProtection <= 0)
            {
               this.setText("environment.protectionstatus","PROTECTION DEPLETED");
            }
            else if(normalizedProtection >= 1)
            {
               this.setText("environment.protectionstatus","PROTECTION READY");
            }
            else
            {
               this.setText("environment.protectionstatus","PROTECTION PARTIAL");
            }
         }
         if(effects != null)
         {
            this.setFinite("environment.hazard.effectcount",effects.length);
            while(index < effects.length && index < MAX_HAZARD_EFFECTS)
            {
               effect = effects[index];
               if(effect != null)
               {
                  if(diagnosticIndex < MAX_DIAGNOSTIC_EFFECTS)
                  {
                     this.setText("diagnostic.effect" + diagnosticIndex.toString(),"EFFECT " +
                        diagnosticIndex.toString() + ": " + this.describeObject(effect,8));
                     ++diagnosticIndex;
                  }
                  if(effect.sEffectIcon !== undefined && effect.sEffectIcon !== null)
                  {
                     icon = String(effect.sEffectIcon);
                     normalizedIcon = icon.toLowerCase();
                     if(normalizedIcon.indexOf("airborne") >= 0)
                     {
                        activeEffects[0] = true;
                        this.setFinite("environment.hazard.airwaterlevel",1);
                        this.setText("environment.hazard.airwaterstatus","AIR / WATER DETECTED");
                        this.setText("environment.hazard.airwatershortstatus","DETECTED");
                     }
                     else if(normalizedIcon.indexOf("thermal") >= 0)
                     {
                        activeEffects[1] = true;
                        this.setFinite("environment.hazard.thermallevel",1);
                        this.setText("environment.hazard.thermalstatus","THERMAL EFFECT DETECTED");
                        this.setText("environment.hazard.thermalshortstatus","DETECTED");
                     }
                     else if(normalizedIcon.indexOf("corrosive") >= 0)
                     {
                        activeEffects[2] = true;
                        this.setFinite("environment.hazard.corrosivelevel",1);
                        this.setText("environment.hazard.corrosivestatus","CORROSIVE EFFECT DETECTED");
                        this.setText("environment.hazard.corrosiveshortstatus","DETECTED");
                     }
                     else if(normalizedIcon.indexOf("radiation") >= 0)
                     {
                        activeEffects[3] = true;
                        this.setFinite("environment.hazard.radiationlevel",1);
                        this.setText("environment.hazard.radiationstatus","RADIATION EFFECT DETECTED");
                        this.setText("environment.hazard.radiationshortstatus","DETECTED");
                     }
                  }
               }
               ++index;
            }
         }
         this.updateExposureActivity(activeEffects);
         tacticalAwareness.updateEnvironment(param1.data,exposureActive,exposureCurrent,environmentalCritical);
         dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
         this.notifyChanged();
      }

      private function onStarmapSystemBodyInfoData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         this.setText("diagnostic.starmapprovider","STARMAP BODY PROVIDER RECEIVED IN HUD: " +
            this.listCandidateFields(param1.data,["body","gravity","temp","atmosphere","magnetosphere","water"],8));
         this.notifyChanged();
      }

      private function onPersonalEffectsData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var data:Object = param1 == null ? null : param1.data;
         tacticalAwareness.updatePersonalEffects(data);
         dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
      }

      private function onRadarCompassData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         compassData = param1 == null ? null : param1.data;
         this.setText("quest.objective",resolveTrackedObjective(compassData));
         tacticalAwareness.updateCompass(compassData);
         dispatchEvent(new Event(COMPASS_CHANGE));
         dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
         this.notifyChanged();
      }

      private function onLocalEnvironmentFrequentData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         if(param1 == null || param1.data == null)
         {
            this.clearValue("environment.solartransitioncountdown");
            this.notifyChanged();
            return;
         }
         this.setFinite("environment.localtime",param1.data.fLocalPlanetTime);
         this.updateSolarTransitionCountdown(param1.data.fLocalPlanetTime,param1.data.fLocalPlanetHoursPerDay);
         this.setFinite("player.universaltime",param1.data.fGalacticStandardTime / 24);
         this.universalTimeDiagnostic = "UT: fGalacticStandardTime=" +
            this.formatDiagnosticValue(param1.data.fGalacticStandardTime) +
            " | fLocalPlanetTime=" + this.formatDiagnosticValue(param1.data.fLocalPlanetTime) +
            " | fLocalPlanetHoursPerDay=" + this.formatDiagnosticValue(param1.data.fLocalPlanetHoursPerDay);
         this.updatePlayerTimeInventoryDiagnostic();
         this.notifyChanged();
      }

      private function updateSolarTransitionCountdown(param1:Object, param2:Object) : void
      {
         if(param1 == null || param2 == null)
         {
            this.clearValue("environment.solartransitioncountdown");
            return;
         }
         var localTime:Number = Number(param1);
         var hoursPerDay:Number = Number(param2);
         if(isNaN(localTime) || !isFinite(localTime) || isNaN(hoursPerDay) || !isFinite(hoursPerDay) || hoursPerDay <= 0)
         {
            this.clearValue("environment.solartransitioncountdown");
            return;
         }
         this.setText("environment.solartransitioncountdown",this.formatSolarTransitionCountdown(localTime));
      }

      private function formatSolarTransitionCountdown(param1:Number) : String
      {
         var normalized:Number = param1 - Math.floor(param1);
         var currentMinute:int = 0;
         var remainingMinutes:int = 0;
         var transition:String = "";
         var hours:int = 0;
         var minutes:int = 0;
         var duration:String = "";
         if(normalized < 0)
         {
            normalized += 1;
         }
         currentMinute = int(Math.floor(normalized * 1440 + 0.5)) % 1440;
         if(currentMinute < 360)
         {
            transition = "SUNRISE";
            remainingMinutes = 360 - currentMinute;
         }
         else if(currentMinute < 1080)
         {
            transition = "SUNSET";
            remainingMinutes = 1080 - currentMinute;
         }
         else
         {
            transition = "SUNRISE";
            remainingMinutes = 1440 - currentMinute + 360;
         }
         hours = int(remainingMinutes / 60);
         minutes = remainingMinutes % 60;
         if(hours > 0)
         {
            duration = hours.toString() + "H";
            if(minutes > 0)
            {
               duration += " " + (minutes < 10 ? "0" : "") + minutes.toString() + "M";
            }
         }
         else
         {
            duration = minutes.toString() + "M";
         }
         return transition + " IN " + duration;
      }

      private function onPlayerData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         if(tacticalAwareness.updateCombatState(Boolean(param1.data.bIsInCombat)))
         {
            dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
         }
         this.setFinite("player.level",param1.data.uLevel);
         this.setFinite("player.levelxp",param1.data.fLevelXP);
         this.setFinite("player.nextlevelxp",param1.data.fNextLevelXP);
         this.setRatio("player.xppercentage",param1.data.fLevelXP,param1.data.fNextLevelXP);
         this.setText("diagnostic.playerfields","PLAYERDATA ROOT: " +
            this.listFieldNames(param1.data,MAX_PLAYER_DIAGNOSTIC_FIELDS));
         this.setText("diagnostic.playertargets","PLAYER TARGETS: sName=" +
            this.formatDiagnosticValue(param1.data.sName) + " | uLevel=" +
            this.formatDiagnosticValue(param1.data.uLevel) + " | fLevelXP=" +
            this.formatDiagnosticValue(param1.data.fLevelXP) + " | fNextLevelXP=" +
            this.formatDiagnosticValue(param1.data.fNextLevelXP) + " | VWKS_PlayerLevel=" +
            this.formatDiagnosticValue(param1.data["VWKS_PlayerLevel"]));
         this.updatePlayerSerialDiagnostic(param1.data.sName);
         this.notifyChanged();
      }

      private function onPlayerFrequentData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         this.setFinite("player.health",param1.data.fHealth);
         this.setFinite("player.maxhealth",param1.data.fMaxHealth);
         this.setRatio("player.healthpercentage",param1.data.fHealth,param1.data.fMaxHealth);
         this.setFinite("player.oxygen",param1.data.fOxygen);
         this.setFinite("player.maxoxygen",param1.data.fMaxO2CO2);
         this.setRatio("player.oxygenpercentage",param1.data.fOxygen,param1.data.fMaxO2CO2);
         this.setFinite("player.carbondioxide",param1.data.fCarbonDioxide);
         this.setRatio("player.carbondioxidepercentage",param1.data.fCarbonDioxide,param1.data.fMaxO2CO2);
         this.setFinite("power.current",param1.data.fStarPower);
         this.setFinite("power.maximum",param1.data.fMaxStarPower);
         this.setRatio("power.percentage",param1.data.fStarPower,param1.data.fMaxStarPower);
         this.captureOxygenActivity(param1.data.fOxygen,param1.data.fMaxO2CO2);
         this.updateActivityDiagnostic();
         this.notifyChanged();
      }

      private function onWeaponData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var clip:Number = Number(param1.data.uClipAmmo);
         var total:Number = Number(param1.data.uTotalAmmo);
         var explosiveCount:Number = Number(param1.data.uExplosiveCount);
         var explosiveType:Number = Number(param1.data.uExplosiveIndicatorType);
         this.setText("weapon.name",param1.data.sWeaponName);
         this.setText("weapon.icon",param1.data.sIconLinkageName);
         this.setFinite("weapon.clipammo",clip);
         this.setFinite("weapon.totalammo",total);
         if(!isNaN(clip) && isFinite(clip) && !isNaN(total) && isFinite(total))
         {
            this.setFinite("weapon.reserveammo",Math.max(0,total - clip));
         }
         this.setBoolean("weapon.displayammo",param1.data.bDisplayAmmo);
         this.setBoolean("weapon.ammoaspercent",param1.data.bShowAmmoAsPercent);
         this.setFinite("weapon.explosivecount",explosiveCount);
         this.setFinite("weapon.explosivetype",explosiveType);
         if(!isNaN(explosiveCount) && isFinite(explosiveCount) && explosiveCount > 0)
         {
            this.setText("weapon.explosivelabel",!isNaN(explosiveType) && isFinite(explosiveType) && explosiveType != 0 ? "MINE" : "GRENADE");
         }
         else
         {
            this.setText("weapon.explosivelabel","NO THROWABLE");
         }
         this.refreshFavoriteSlotText();
         this.notifyChanged();
      }

      private function onJetpackData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var charge:Number = Number(param1.data.fJetpackCharge);
         if(!isNaN(charge) && isFinite(charge))
         {
            charge = Math.max(0,Math.min(1,charge));
            this.setFinite("boost.charge",charge);
            this.setFinite("boost.percentage",charge * 100);
            this.notifyChanged();
            return;
         }
         this.notifyChanged();
      }

      private function onPlayerInventoryData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var items:Array = param1.data.aItems as Array;
         var item:Object = null;
         var weaponInfo:Object = null;
         var ammoType:String = "";
         var armorResistance:Array = [];
         var armorInfo:Object = null;
         var equippedWeaponCount:int = 0;
         var index:int = 0;
         this.clearValue("carry.current");
         this.clearValue("carry.maximum");
         this.clearValue("carry.percentage");
         this.clearValue("credits");
         this.setText("diagnostic.armorresistance","EQUIPPED ARMOR RESISTANCE FIELDS NOT PRESENT");
         this.setFinite("carry.current",param1.data.fEncumbrance);
         this.setFinite("carry.maximum",param1.data.fMaxEncumbrance);
         this.setRatio("carry.percentage",param1.data.fEncumbrance,param1.data.fMaxEncumbrance);
         this.setFinite("credits",param1.data.uCoin);
         this.updateDigipickDiagnostic(items);
         if(items == null)
         {
            this.clearValue("weapon.ammotype");
            this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA RECEIVED — ITEM DATA UNAVAILABLE");
            this.notifyChanged();
            return;
         }
         while(index < items.length)
         {
            item = items[index];
            if(item != null && Boolean(item.bIsEquipped) && item.WeaponInfo != null)
            {
               weaponInfo = item.WeaponInfo;
               ++equippedWeaponCount;
               if(ammoType.length == 0 && weaponInfo.sAmmoType !== undefined && weaponInfo.sAmmoType !== null)
               {
                  ammoType = String(weaponInfo.sAmmoType);
                  if(ammoType.replace(/\s/g,"").length == 0)
                  {
                     ammoType = "";
                  }
               }
            }
            if(item != null && Boolean(item.bIsEquipped) && item.ArmorInfo != null && armorResistance.length < 4)
            {
               armorInfo = item.ArmorInfo;
               armorResistance.push("T=" + this.formatDiagnosticValue(armorInfo.fThermalResist) +
                  " A=" + this.formatDiagnosticValue(armorInfo.fAirborneResist) +
                  " C=" + this.formatDiagnosticValue(armorInfo.fCorrosiveResist) +
                  " R=" + this.formatDiagnosticValue(armorInfo.fRadiationResist));
            }
            ++index;
         }
         if(armorResistance.length != 0)
         {
            this.setText("diagnostic.armorresistance","EQUIPPED ARMOR ITEMS (UNAGGREGATED): " + armorResistance.join(" | "));
         }
         if(ammoType.length != 0)
         {
            this.setText("weapon.ammotype",ammoType);
            this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA RECEIVED — " + equippedWeaponCount.toString() + " EQUIPPED WEAPON — AMMO " + ammoType);
         }
         else
         {
            this.clearValue("weapon.ammotype");
            this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA RECEIVED — " + equippedWeaponCount.toString() + " EQUIPPED WEAPON — NO AMMO NAME");
         }
         this.notifyChanged();
      }

      private function onFavoritesData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var data:Object = param1 == null ? null : param1.data;
         var favorites:Array = null;
         var item:Object = null;
         var index:int = 0;
         var limit:int = 0;
         var slotLabel:String = null;
         var name:String = "";
         var ammoName:String = "";
         var ammoCount:Number = NaN;
         var count:Number = NaN;
         var detail:String = "";
         this.resetFavoriteSlots();
         if(data == null)
         {
            this.notifyChanged();
            return;
         }
         favorites = data.aFavoriteItems as Array;
         if(favorites == null)
         {
            this.notifyChanged();
            return;
         }
         limit = Math.min(favorites.length,MAX_FAVORITE_SLOTS);
         while(index < limit)
         {
            item = favorites[index];
            slotLabel = this.formatFavoriteSlot(index + 1);
            if(item != null)
            {
               name = this.cleanFavoriteText(item.sName);
               ammoName = this.cleanFavoriteText(item.sAmmoName);
               ammoCount = Number(item.uAmmoCount);
               count = Number(item.uCount);
               detail = "";
               if(Boolean(item.bIsPower))
               {
                  detail = "";
               }
               else if(ammoName.length != 0)
               {
                  if(!isNaN(ammoCount) && isFinite(ammoCount))
                  {
                     detail = "×" + Math.max(0,Math.round(ammoCount)).toString();
                  }
               }
               else if(!isNaN(count) && isFinite(count) && count > 1)
               {
                  detail = "×" + Math.max(0,Math.round(count)).toString();
               }
               favoriteNames[index] = name.length == 0 ? "UNNAMED" : name;
               favoriteDetails[index] = detail;
            }
            ++index;
         }
         this.refreshFavoriteSlotText();
         this.notifyChanged();
      }

      private function onControlMapData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var data:Object = param1 == null ? null : param1.data;
         var index:int = 1;
         var hotkey:String = "";
         if(data == null || !(data.vMappedEvents is Array))
         {
            return;
         }
         buttonKeyHelper.OnControlMapChanged(data);
         while(index <= MAX_FAVORITE_SLOTS)
         {
            hotkey = this.cleanFavoriteText(buttonKeyHelper.GetButtonNameForEvent("Quickkey" + index.toString()));
            this.setText("favorite." + this.formatFavoriteSlot(index) + ".hotkey",hotkey.length == 0 ? "--" : hotkey);
            ++index;
         }
         this.notifyChanged();
      }

      private function onStarbornPowersData(param1:FromClientDataEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         this.clearValue("power.key");
         this.clearValue("power.name");
         this.setText("power.key",param1.data.sKey);
         this.setBoolean("power.hasspell",param1.data.bHasSpell);
         this.setFinite("power.cost",param1.data.fCost);
         this.setFinite("power.cooldown",param1.data.uCooldown);
         this.resolvePowerName(param1.data.sKey);
         this.notifyChanged();
      }

      private function resolvePowerName(param1:Object) : void
      {
         var key:String = param1 === undefined || param1 === null ? "" : String(param1);
         var name:String = "";
         switch(key)
         {
            case "ArtifactPower_AlienReanim":
               name = "Alien Reanimation";
               break;
            case "ArtifactPower_AntiGravityField":
               name = "Anti-Gravity Field";
               break;
            case "ArtifactPower_CreateVacuum":
               name = "Create Vacuum";
               break;
            case "ArtifactPower_CreatorsPeace":
               name = "Creators' Peace";
               break;
            case "ArtifactPower_Earthbound":
               name = "Earthbound";
               break;
            case "ArtifactPower_ElementalBlast":
               name = "Elemental Pull";
               break;
            case "ArtifactPower_EternalHarvest":
               name = "Eternal Harvest";
               break;
            case "ArtifactPower_GravDash":
               name = "Grav Dash";
               break;
            case "ArtifactPower_GravWave":
               name = "Gravity Wave";
               break;
            case "ArtifactPower_GravWell":
               name = "Gravity Well";
               break;
            case "ArtifactPower_InnerDemon":
               name = "Inner Demon";
               break;
            case "ArtifactPower_LifeForced":
               name = "Life Forced";
               break;
            case "ArtifactPower_MoonForm":
               name = "Moon Form";
               break;
            case "ArtifactPower_ParallelSelf":
               name = "Parallel Self";
               break;
            case "ArtifactPower_ParticleBeam":
               name = "Particle Beam";
               break;
            case "ArtifactPower_PersonalAtmo":
               name = "Personal Atmosphere";
               break;
            case "ArtifactPower_PhasedTime":
               name = "Phased Time";
               break;
            case "ArtifactPower_Precognition":
               name = "Precognition";
               break;
            case "ArtifactPower_ReactiveShield":
               name = "Reactive Shield";
               break;
            case "ArtifactPower_SenseStarStuff":
               name = "Sense Star Stuff";
               break;
            case "ArtifactPower_SolarFlare":
               name = "Solar Flare";
               break;
            case "ArtifactPower_SunlessSpace":
               name = "Sunless Space";
               break;
            case "ArtifactPower_Supernova":
               name = "Supernova";
               break;
            case "ArtifactPower_VoidForm":
               name = "Void Form";
               break;
         }
         if(name.length != 0)
         {
            this.setText("power.name",name);
            this.setText("diagnostic.powernameprovider","HUD POWER KEY MAPPED — " + name);
            return;
         }
         if(key.replace(/\s/g,"").length == 0)
         {
            this.setText("diagnostic.powernameprovider","HUD POWER KEY EMPTY — NO ACTIVE POWER NAME");
         }
         else
         {
            this.setText("diagnostic.powernameprovider","HUD POWER KEY UNKNOWN — " + key);
         }
      }

      private function setText(param1:String, param2:Object) : void
      {
         var source:String = null;
         var value:String = null;
         if(param2 !== undefined && param2 !== null)
         {
            source = normalizeSource(param1);
            value = String(param2);
            if(!this.valueMatches(source,value))
            {
               values[source] = { known:true, value:value };
               this.markChanged(source);
            }
         }
      }

      private function setBoolean(param1:String, param2:Object) : void
      {
         var source:String = null;
         var value:Boolean = false;
         if(param2 !== undefined && param2 !== null)
         {
            source = normalizeSource(param1);
            value = Boolean(param2);
            if(!this.valueMatches(source,value))
            {
               values[source] = { known:true, value:value };
               this.markChanged(source);
            }
         }
      }

      private function setFinite(param1:String, param2:Object) : void
      {
         var source:String = null;
         var value:Number = Number(param2);
         if(!isNaN(value) && isFinite(value))
         {
            source = normalizeSource(param1);
            if(!this.valueMatches(source,value))
            {
               values[source] = { known:true, value:value };
               this.markChanged(source);
            }
         }
      }

      private function clearValue(param1:String) : void
      {
         var source:String = normalizeSource(param1);
         if(values[source] != null)
         {
            delete values[source];
            this.markChanged(source);
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
         var sources:Object = null;
         if(changedSourceCount == 0)
         {
            return;
         }
         sources = changedSources;
         this.resetChangedSources();
         dispatchEvent(new CustomEvent(VALUE_CHANGE,sources));
      }

      private function valueMatches(param1:String, param2:Object) : Boolean
      {
         var current:Object = values[param1];
         return current != null && Boolean(current.known) && current.value === param2;
      }

      private function markChanged(param1:String) : void
      {
         if(changedSources[param1] === true)
         {
            return;
         }
         changedSources[param1] = true;
         ++changedSourceCount;
      }

      private function resetChangedSources() : void
      {
         changedSources = {};
         changedSourceCount = 0;
      }

      public function dispose() : void
      {
         var subscription:Object = null;
         if(this.disposed)
         {
            return;
         }
         this.disposed = true;
         if(this.exposureTimer != null)
         {
            this.exposureTimer.stop();
            this.exposureTimer.removeEventListener(TimerEvent.TIMER,this.onExposureTimer);
         }
         while(this.providerSubscriptions != null && this.providerSubscriptions.length != 0)
         {
            subscription = this.providerSubscriptions.pop();
            BSUIDataManager.Unsubscribe(String(subscription.provider),subscription.callback as Function);
         }
      }

      private function resetEnvironmentalHazards() : void
      {
         var index:int = 0;
         this.setFinite("environment.hazard.effectcount",0);
         this.setFinite("environment.hazard.airwaterlevel",0);
         this.setFinite("environment.hazard.thermallevel",0);
         this.setFinite("environment.hazard.corrosivelevel",0);
         this.setFinite("environment.hazard.radiationlevel",0);
         this.setFinite("environment.hazard.airwaterexposurelevel",0);
         this.setFinite("environment.hazard.thermalexposurelevel",0);
         this.setFinite("environment.hazard.corrosiveexposurelevel",0);
         this.setFinite("environment.hazard.radiationexposurelevel",0);
         this.setText("environment.hazard.airwaterstatus","CLEAR");
         this.setText("environment.hazard.thermalstatus","CLEAR");
         this.setText("environment.hazard.corrosivestatus","CLEAR");
         this.setText("environment.hazard.radiationstatus","CLEAR");
         this.setText("environment.hazard.airwatershortstatus","CLEAR");
         this.setText("environment.hazard.thermalshortstatus","CLEAR");
         this.setText("environment.hazard.corrosiveshortstatus","CLEAR");
         this.setText("environment.hazard.radiationshortstatus","CLEAR");
         while(index < MAX_DIAGNOSTIC_EFFECTS)
         {
            this.setText("diagnostic.effect" + index.toString(),"EFFECT " + index.toString() + ": UNUSED");
            ++index;
         }
      }

      private function updateExposureActivity(param1:Array) : void
      {
         var wasCritical:Boolean = this.environmentalCritical;
         var nextCritical:Boolean = this.currentFullSoak && this.protectionKnown &&
            this.currentProtection <= 0 && this.hasActiveFlags(param1);
         var wasActive:Boolean = false;
         var index:int = 0;
         this.environmentalCritical = nextCritical;
         while(index < EXPOSURE_SOURCES.length)
         {
            if(Boolean(param1[index]))
            {
               wasActive = Boolean(this.exposureActive[index]);
               this.exposureActive[index] = true;
               if(this.environmentalCritical)
               {
                  this.exposureCurrent[index] = 1;
                  this.exposureTarget[index] = 1;
                  this.exposureTargetTicks[index] = 0;
               }
               else if(wasCritical)
               {
                  this.chooseExposureTarget(index);
                  this.exposureCurrent[index] = this.exposureTarget[index];
               }
               else if(!wasActive)
               {
                  this.chooseExposureTarget(index);
                  this.exposureCurrent[index] = this.exposureTarget[index];
               }
               else if(!this.exposureValueInCurrentRange(Number(this.exposureTarget[index])))
               {
                  this.chooseExposureTarget(index);
               }
               this.setFinite(String(EXPOSURE_SOURCES[index]),Number(this.exposureCurrent[index]));
            }
            else
            {
               this.exposureActive[index] = false;
               this.exposureCurrent[index] = 0;
               this.exposureTarget[index] = 0;
               this.exposureTargetTicks[index] = 0;
               this.exposureRandom[index] = 0;
               this.setFinite(String(EXPOSURE_SOURCES[index]),0);
            }
            ++index;
         }
         this.updateExposureTargets();
         this.updateExposureTimerState();
         this.updateActivityDiagnostic();
      }

      private function onExposureTimer(param1:TimerEvent) : void
      {
         if(this.disposed)
         {
            return;
         }
         var current:Number = 0;
         var target:Number = 0;
         var index:int = 0;
         var previousActivity:Number = this.oxygenActivity;
         var drainDetected:Boolean = this.oxygenDrainDetected;
         var changed:Boolean = drainDetected || this.oxygenActivity > 0;
         this.oxygenDrainDetected = false;
         if(drainDetected)
         {
            this.oxygenActivity = Math.min(1,this.oxygenActivity + ACTIVITY_ATTACK_STEP);
         }
         else
         {
            this.oxygenActivity = Math.max(0,this.oxygenActivity - ACTIVITY_RELEASE_STEP);
         }
         if(this.oxygenActivity != previousActivity)
         {
            changed = true;
         }
         while(index < EXPOSURE_SOURCES.length)
         {
            if(Boolean(this.exposureActive[index]))
            {
               if(this.environmentalCritical)
               {
                  this.exposureCurrent[index] = 1;
                  this.exposureTarget[index] = 1;
                  this.exposureTargetTicks[index] = 0;
               }
               else
               {
                  this.exposureTargetTicks[index] = int(this.exposureTargetTicks[index]) - 1;
                  if(int(this.exposureTargetTicks[index]) <= 0 ||
                     isNaN(Number(this.exposureTarget[index])))
                  {
                     this.chooseExposureTarget(index);
                  }
                  else
                  {
                     this.refreshExposureTarget(index);
                  }
                  current = Number(this.exposureCurrent[index]);
                  target = Number(this.exposureTarget[index]);
                  current += (target - current) * EXPOSURE_LERP;
                  if(Math.abs(target - current) < 0.0025)
                  {
                     current = target;
                  }
                  this.exposureCurrent[index] = current;
               }
               this.setFinite(String(EXPOSURE_SOURCES[index]),Number(this.exposureCurrent[index]));
               changed = true;
            }
            ++index;
         }
         this.updateActivityDiagnostic();
         this.updateExposureTimerState();
         if(changed)
         {
            tacticalAwareness.updateEnvironmentalPressure(exposureActive,exposureCurrent,environmentalCritical);
            dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
            this.notifyChanged();
         }
      }

      private function chooseExposureTarget(param1:int) : void
      {
         this.exposureRandom[param1] = Math.random();
         this.refreshExposureTarget(param1);
         this.exposureTargetTicks[param1] = EXPOSURE_TARGET_MIN_TICKS +
            Math.floor(Math.random() * EXPOSURE_TARGET_TICK_RANGE);
      }

      private function refreshExposureTarget(param1:int) : void
      {
         var depletion:Number = 1 - this.currentProtection;
         var activity:Number = this.oxygenActivity;
         var randomValue:Number = Number(this.exposureRandom[param1]);
         if(this.environmentalCritical)
         {
            this.exposureTarget[param1] = 1;
            return;
         }
         this.exposureTarget[param1] = Math.max(0,Math.min(1,
            0.05 + 0.10 * randomValue + 0.25 * activity + 0.70 * depletion));
      }

      private function updateExposureTargets() : void
      {
         var index:int = 0;
         while(index < EXPOSURE_SOURCES.length)
         {
            if(Boolean(this.exposureActive[index]))
            {
               this.refreshExposureTarget(index);
            }
            ++index;
         }
      }

      private function captureOxygenActivity(param1:Object, param2:Object) : void
      {
         var oxygen:Number = Number(param1);
         var maximum:Number = Number(param2);
         if(isNaN(oxygen) || !isFinite(oxygen) || isNaN(maximum) || !isFinite(maximum) || maximum <= 0)
         {
            return;
         }
         this.currentOxygen = Math.max(0,Math.min(1,oxygen / maximum));
         if(!isNaN(this.previousOxygen) && this.previousOxygen - this.currentOxygen > ACTIVITY_DRAIN_EPSILON)
         {
            this.oxygenDrainDetected = true;
         }
         this.previousOxygen = this.currentOxygen;
         this.updateExposureTimerState();
      }

      private function updateExposureTimerState() : void
      {
         if(this.disposed)
         {
            if(this.exposureTimer.running)
            {
               this.exposureTimer.stop();
            }
            return;
         }
         var needsTimer:Boolean = this.hasActiveExposure() ||
            this.oxygenDrainDetected || this.oxygenActivity > 0;
         if(needsTimer && !this.exposureTimer.running)
         {
            this.exposureTimer.start();
         }
         else if(!needsTimer && this.exposureTimer.running)
         {
            this.exposureTimer.stop();
         }
      }

      private function hasActiveExposure() : Boolean
      {
         var index:int = 0;
         while(index < this.exposureActive.length)
         {
            if(Boolean(this.exposureActive[index]))
            {
               return true;
            }
            ++index;
         }
         return false;
      }

      private function hasActiveFlags(param1:Array) : Boolean
      {
         var index:int = 0;
         while(index < param1.length)
         {
            if(Boolean(param1[index]))
            {
               return true;
            }
            ++index;
         }
         return false;
      }

      private function updateActivityDiagnostic() : void
      {
         var protectionText:String = this.protectionKnown ? this.formatNormalized(this.currentProtection) : "WAITING";
         var depletionText:String = this.protectionKnown ? this.formatNormalized(1 - this.currentProtection) : "WAITING";
         this.setText("diagnostic.activityoxygen","PLAYER O2 RESERVE: " + this.formatOptionalNormalized(this.currentOxygen) +
            " // DOWNWARD DRAIN: " + (this.oxygenDrainDetected ? "TRUE" : "FALSE"));
         this.setText("diagnostic.activityenvelope","O2 ACTIVITY ENVELOPE: " +
            this.formatNormalized(this.oxygenActivity) + " // ATTACK +8%/TICK // RELEASE -10%/TICK");
         this.setText("diagnostic.activityprotection","SUIT PROTECTION: " + protectionText +
            " // DEPLETION: " + depletionText + " // FULL-SOAK FLAG: " +
            (this.currentFullSoak ? "TRUE" : "FALSE") + " // CRITICAL OVERRIDE: " +
            (this.environmentalCritical ? "TRUE" : "FALSE"));
         this.setText("diagnostic.activityloads","LOADS: AIR/WATER " + this.formatNormalized(Number(this.exposureCurrent[0])) +
            " // THERMAL " + this.formatNormalized(Number(this.exposureCurrent[1])) +
            " // CORROSIVE " + this.formatNormalized(Number(this.exposureCurrent[2])) +
            " // RADIATION " + this.formatNormalized(Number(this.exposureCurrent[3])));
      }

      private function updateDigipickDiagnostic(param1:Array) : void
      {
         var item:Object = null;
         var match:Object = null;
         var matchRoute:String = "";
         var editorId:String = "";
         var name:String = "";
         var formId:Number = NaN;
         var index:int = 0;
         var limit:int = 0;
         this.clearValue("player.digipicks");
         if(param1 == null)
         {
            this.digipickDiagnostic = "DIGIPICK: ITEM ARRAY UNAVAILABLE";
            this.updatePlayerTimeInventoryDiagnostic();
            return;
         }
         this.setFinite("player.digipicks",0);
         limit = Math.min(param1.length,MAX_DIAGNOSTIC_INVENTORY_ITEMS);
         while(index < limit)
         {
            item = param1[index];
            if(item != null)
            {
               formId = Number(item.uFormID);
               editorId = item.sEditorID !== undefined && item.sEditorID !== null ? String(item.sEditorID) :
                  (item.EditorID !== undefined && item.EditorID !== null ? String(item.EditorID) : "");
               name = item.sName !== undefined && item.sName !== null ? String(item.sName) : "";
               if(!isNaN(formId) && isFinite(formId) && formId == DIGIPICK_FORM_ID)
               {
                  match = item;
                  matchRoute = "FORM 00000A";
                  this.setFinite("player.digipicks",item.uCount);
                  break;
               }
               if(match == null && editorId.toLowerCase() == "digipick")
               {
                  match = item;
                  matchRoute = "EDITOR ID";
               }
               else if(match == null && name.toLowerCase() == "digipick")
               {
                  match = item;
                  matchRoute = "ENGLISH NAME ONLY";
               }
            }
            ++index;
         }
         if(match == null)
         {
            this.digipickDiagnostic = "DIGIPICK: NOT FOUND IN " + limit.toString() +
               " / " + param1.length.toString() + " ITEMS";
         }
         else
         {
            this.digipickDiagnostic = "DIGIPICK: " + matchRoute + " MATCH | uFormID=" +
               this.formatDiagnosticValue(match.uFormID) + " | uCount=" +
               this.formatDiagnosticValue(match.uCount) + " | sName=" +
               this.formatDiagnosticValue(match.sName) + " | sEditorID=" +
               this.formatDiagnosticValue(match.sEditorID) + " | uHandleID=" +
               this.formatDiagnosticValue(match.uHandleID);
         }
         this.updatePlayerTimeInventoryDiagnostic();
      }

      private function updatePlayerSerialDiagnostic(param1:Object) : void
      {
         var characterName:String = param1 !== undefined && param1 !== null ? String(param1) : "";
         var serial:String = "";
         if(characterName.length == 0)
         {
            this.clearValue("player.serial");
            this.setText("diagnostic.playeridentifiers","DETERMINISTIC SERIAL: CHARACTER NAME UNAVAILABLE");
            return;
         }
         serial = this.derivePlayerSerial(characterName);
         this.setText("player.serial",this.formatPlayerSerial(serial));
         this.setText("diagnostic.playeridentifiers","DETERMINISTIC SERIAL: " +
            this.formatPlayerSerial(serial) + " | SOURCE=" + this.formatDiagnosticValue(characterName) +
            " | MODE=DETERMINISTIC");
      }

      private function isValidPlayerSerial(param1:String) : Boolean
      {
         return param1 != null && /^[A-Z0-9]{18}$/.test(param1);
      }

      private function derivePlayerSerial(param1:String) : String
      {
         var serial:String = "";
         var stateA:uint = PLAYER_SERIAL_SEED_A;
         var stateB:uint = PLAYER_SERIAL_SEED_B;
         var characterCode:uint = 0;
         var index:int = 0;
         while(index < param1.length)
         {
            characterCode = uint(param1.charCodeAt(index));
            stateA = uint(((stateA << 5) - stateA) + characterCode + uint(index));
            stateA ^= stateA >>> 16;
            stateB = uint(((stateB << 7) - stateB) ^
               (characterCode + uint(index * 131)));
            stateB ^= stateB >>> 13;
            ++index;
         }
         index = 0;
         while(index < PLAYER_SERIAL_LENGTH)
         {
            stateA ^= stateA << 13;
            stateA ^= stateA >>> 17;
            stateA ^= stateA << 5;
            stateB = uint(stateB + 0x6D2B79F5 + uint(index));
            stateB ^= stateB >>> 15;
            stateB ^= stateB << 7;
            serial += PLAYER_SERIAL_ALPHABET.charAt(
               int(uint(stateA ^ stateB) % PLAYER_SERIAL_ALPHABET.length));
            ++index;
         }
         return serial;
      }

      private function formatPlayerSerial(param1:String) : String
      {
         if(!this.isValidPlayerSerial(param1))
         {
            return "INVALID";
         }
         return param1.substring(0,8) + "-" + param1.substring(8,12) + "-" +
            param1.substring(12,18);
      }

      private function updatePlayerTimeInventoryDiagnostic() : void
      {
         this.setText("diagnostic.playertimeinventory",this.universalTimeDiagnostic +
            " // " + this.digipickDiagnostic);
      }

      private function resetFavoriteSlots() : void
      {
         var index:int = 1;
         var slotLabel:String = null;
         while(index <= MAX_FAVORITE_SLOTS)
         {
            slotLabel = this.formatFavoriteSlot(index);
            favoriteNames[index - 1] = "EMPTY";
            favoriteDetails[index - 1] = "";
            this.setText("favorite." + slotLabel + ".name","EMPTY");
            this.setText("favorite." + slotLabel + ".detail","");
            ++index;
         }
      }

      private function resetFavoriteHotkeys() : void
      {
         var index:int = 1;
         while(index <= MAX_FAVORITE_SLOTS)
         {
            this.setText("favorite." + this.formatFavoriteSlot(index) + ".hotkey","--");
            ++index;
         }
      }

      private function refreshFavoriteSlotText() : void
      {
         var index:int = 0;
         var slotLabel:String = null;
         var name:String = null;
         var detail:String = null;
         while(index < MAX_FAVORITE_SLOTS)
         {
            slotLabel = this.formatFavoriteSlot(index + 1);
            name = String(favoriteNames[index]);
            detail = String(favoriteDetails[index]);
            this.setText("favorite." + slotLabel + ".name",name);
            this.setText("favorite." + slotLabel + ".detail",detail);
            ++index;
         }
      }

      private function cleanFavoriteText(param1:Object) : String
      {
         var value:String = "";
         if(param1 === undefined || param1 === null)
         {
            return value;
         }
         value = String(param1).replace(/[\r\n\t]+/g," ");
         value = value.replace(/^\s+|\s+$/g,"");
         return value;
      }

      private function formatFavoriteSlot(param1:int) : String
      {
         return (param1 < 10 ? "0" : "") + param1.toString();
      }

      private function formatOptionalNormalized(param1:Number) : String
      {
         return isNaN(param1) || !isFinite(param1) ? "WAITING" : this.formatNormalized(param1);
      }

      private function formatNormalized(param1:Number) : String
      {
         return Math.round(Math.max(0,Math.min(1,param1)) * 100).toString() + "%";
      }

      private function listFieldNames(param1:Object, param2:int) : String
      {
         var fields:Array = [];
         var field:String = null;
         if(param1 == null)
         {
            return "NULL";
         }
         for(field in param1)
         {
            fields.push(field);
         }
         fields.sort(Array.CASEINSENSITIVE);
         if(fields.length > param2)
         {
            fields.length = param2;
            return fields.join(",") + ",...";
         }
         return fields.length == 0 ? "NO ENUMERABLE FIELDS" : fields.join(",");
      }

      private function listCandidateFields(param1:Object, param2:Array, param3:int) : String
      {
         var matches:Array = [];
         var field:String = null;
         var normalized:String = null;
         var candidate:String = null;
         var index:int = 0;
         if(param1 == null)
         {
            return "NULL";
         }
         for(field in param1)
         {
            normalized = field.toLowerCase();
            index = 0;
            while(index < param2.length)
            {
               candidate = String(param2[index]).toLowerCase();
               if(normalized.indexOf(candidate) >= 0)
               {
                  matches.push(field + "=" + this.formatDiagnosticValue(param1[field]));
                  break;
               }
               ++index;
            }
         }
         matches.sort(Array.CASEINSENSITIVE);
         if(matches.length > param3)
         {
            matches.length = param3;
            return matches.join(" | ") + " | ...";
         }
         return matches.length == 0 ? "NONE" : matches.join(" | ");
      }

      private function describeObject(param1:Object, param2:int) : String
      {
         var fields:Array = [];
         var output:Array = [];
         var field:String = null;
         var index:int = 0;
         if(param1 == null)
         {
            return "NULL";
         }
         for(field in param1)
         {
            fields.push(field);
         }
         fields.sort(Array.CASEINSENSITIVE);
         while(index < fields.length && index < param2)
         {
            field = String(fields[index]);
            output.push(field + "=" + this.formatDiagnosticValue(param1[field]));
            ++index;
         }
         if(fields.length > param2)
         {
            output.push("...");
         }
         return output.length == 0 ? "NO ENUMERABLE FIELDS" : output.join(" | ");
      }

      private function formatDiagnosticValue(param1:Object) : String
      {
         var value:String = null;
         if(param1 === undefined)
         {
            return "UNDEFINED";
         }
         if(param1 === null)
         {
            return "NULL";
         }
         if(param1 is Array)
         {
            return "ARRAY[" + (param1 as Array).length.toString() + "]";
         }
         if(typeof param1 == "object")
         {
            return "OBJECT";
         }
         value = String(param1).replace(/[\r\n\t]+/g," ");
         if(value.length > 48)
         {
            value = value.substring(0,48) + "...";
         }
         return value;
      }
   }
}
