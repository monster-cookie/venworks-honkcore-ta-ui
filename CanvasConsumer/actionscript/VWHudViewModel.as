package
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.TimerEvent;
   import flash.utils.Timer;

   public final class VWHudViewModel extends EventDispatcher
   {
      public static const VALUE_CHANGE:String = "cuiValueChange";
      public static const COMPASS_CHANGE:String = "cuiCompassChange";
      public static const TACTICAL_AWARENESS_CHANGE:String = "cuiTacticalAwarenessChange";
      public static const PROVIDER_ERROR:String = "cuiValueProviderError";

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
      private var favoriteAmmoCounts:Array;
      private var favoriteItemCounts:Array;
      private var favoriteIsWeapon:Array;
      private var favoriteIsPower:Array;
      private var buttonKeyHelper:VWHudControlMap;
      private var universalTimeDiagnostic:String = "UT: LOCAL ENV FREQUENT DATA NOT RECEIVED";
      private var digipickDiagnostic:String = "DIGIPICK: PLAYER INVENTORY DATA NOT RECEIVED";
      private var inventoryTraceSummary:String = "";
      private var compassData:Object;
      private var activeQuestName:String = "";
      private var activeQuestId:* = null;
      private var missionTitle:String = "";
      private var tacticalAwareness:VWHudTacticalModel;
      private var disposed:Boolean = false;

      public function VWHudViewModel()
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
         favoriteAmmoCounts = [];
         favoriteItemCounts = [];
         favoriteIsWeapon = [];
         favoriteIsPower = [];
         tacticalAwareness = new VWHudTacticalModel();
         buttonKeyHelper = new VWHudControlMap();
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
         this.setText("quest.name","");
         this.setText("quest.objective","");
         this.resetChangedSources();
      }

      // Canvas owns provider subscriptions. This model only interprets delivered data.
      public function receive(channel:String, data:Object) : void
      {
         if(this.disposed) return;
         var event:Object = {data:data};
         switch(channel)
         {
            case "LocalEnvironmentData": this.onLocalEnvironmentData(event); break;
            case "LocalEnvData_Frequent": this.onLocalEnvironmentFrequentData(event); break;
            case "PlayerData": this.onPlayerData(event); break;
            case "PlayerFrequentData": this.onPlayerFrequentData(event); break;
            case "PlayerInventoryData": this.onPlayerInventoryData(event); break;
            case "WeaponData": this.onWeaponData(event); break;
            case "HudJetpackData": this.onJetpackData(event); break;
            case "HUDStarbornPowersData": this.onStarbornPowersData(event); break;
            case "FavoritesData": this.onFavoritesData(event); break;
            case "ControlMapData": this.onControlMapData(event); break;
            case "EnvironmentEffectsData": this.onEnvironmentEffectsData(event); break;
            case "PersonalEffectsData": this.onPersonalEffectsData(event); break;
            case "StarmapSystemBodyInfoProvider": this.onStarmapSystemBodyInfoData(event); break;
            case "HudCompassData": this.onRadarCompassData(event); break;
            case "QuestUpdateData": this.onQuestUpdateData(event); break;
            case "QuestData": this.onQuestData(event); break;
         }
      }

      public function snapshot() : Object
      {
         var result:Object = {};
         for(var key:String in this.values)
         {
            if(key.indexOf("diagnostic.") == 0) continue;
            var value:Object = this.values[key];
            if(value != null && value.known === true)
            {
               var published:String = key;
               var favorite:Array = key.match(/^favorite\.([0-9][0-9])\.(name|detail|hotkey)$/);
               if(favorite != null) published = "favorite.slot" + favorite[1] + "." + favorite[2];
               result[published] = value.value;
            }
         }
         return result;
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
         if(/^favorite\.(0[1-9]|1[0-2])\.(loaded|spare)$/.test(source))
         {
            return "number";
         }
         if(source == "location.name" || source == "environment.solartransitioncountdown" ||
            source == "player.serial" ||
            source == "power.key" || source == "power.name" ||
            source == "quest.name" || source == "quest.objective" ||
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

      public static function field(param1:Object, param2:String) : *
      {
         if(param1 == null) return null;
         var present:Boolean = false;
         try { present = param2 in param1; }
         catch(checkError:*) { present = false; }
         if(present)
         {
            try { return param1[param2]; }
            catch(readError:*) { return null; }
         }
         // Some game data objects report a field as absent to the in operator and still return it by name.
         try { return param1[param2]; }
         catch(missingError:*) { return null; }
      }

      public static function collection(param1:Object, param2:String) : Array
      {
         var value:* = field(param1,param2);
         if(value == null) return null;
         if(value is Array) return value as Array;
         if(!("length" in value)) return null;
         var length:Number = Number(value.length);
         if(!isFinite(length) || length <= 0) return null;
         var copy:Array = [];
         var count:int = int(Math.min(length,64));
         var index:int = 0;
         while(index < count)
         {
            try { copy.push(value[index]); }
            catch(readError:*) { break; }
            ++index;
         }
         return copy;
      }

      private static const QUEST_NAME_FIELDS:Array = ["sQuestName","strQuestName","sMissionName","strMissionName","sTrackedQuestName","strTrackedQuestName"];
      private static const QUEST_UPDATE_SET_ACTIVE:uint = 1;
      private static const QUEST_UPDATE_SET_INACTIVE:uint = 2;

      public static function nextQuestTitle(param1:String, param2:*, param3:Object) : Object
      {
         var name:String = param1 == null ? "" : param1;
         var id:* = param2;
         var updates:Array = collection(param3,"QuestUpdatesA");
         var index:int = 0;
         var update:Object = null;
         var type:uint = 0;
         var title:String = "";
         while(updates != null && index < updates.length)
         {
            update = updates[index];
            if(update != null)
            {
               type = uint(update.uType);
               title = update.strQuestName == null ? "" : String(update.strQuestName).replace(/^\s+|\s+$/g,"");
               if(type == QUEST_UPDATE_SET_INACTIVE)
               {
                  if(sameQuest(id,update.uQuestID))
                  {
                     name = "";
                     id = null;
                  }
               }
               else if(title.length != 0 && (type == QUEST_UPDATE_SET_ACTIVE || update.bActiveQuest === true || sameQuest(id,update.uQuestID)))
               {
                  name = title;
                  if(update.uQuestID != null) id = update.uQuestID;
               }
            }
            ++index;
         }
         return {name:name,id:id};
      }

      public static function resolveActiveMissionTitle(param1:Object) : String
      {
         var quests:Array = collection(param1,"aQuests");
         var index:int = 0;
         var quest:Object = null;
         var objectives:Array = null;
         var objectiveIndex:int = 0;
         var titled:String = "";
         while(quests != null && index < quests.length)
         {
            quest = quests[index];
            if(quest != null && quest.aObjectives is Array)
            {
               if(quest.bActive === true) return missionLabel(quest.sName);
               objectives = collection(quest,"aObjectives");
               objectiveIndex = 0;
               while(objectives != null && objectiveIndex < objectives.length)
               {
                  if(objectives[objectiveIndex] != null && objectives[objectiveIndex].bActive === true) titled = missionLabel(quest.sName);
                  ++objectiveIndex;
               }
            }
            ++index;
         }
         return titled;
      }

      private static function missionLabel(param1:*) : String
      {
         var title:String = param1 == null ? "" : String(param1).replace(/^\s+|\s+$/g,"");
         return title.toUpperCase();
      }

      private static function sameQuest(param1:*, param2:*) : Boolean
      {
         if(param1 == null || param2 == null) return false;
         return String(param1) == String(param2);
      }

      public static function resolveTrackedObjective(param1:Object) : String
      {
         return trackedQuest(param1).objective;
      }

      public static function resolveTrackedQuestName(param1:Object) : String
      {
         return trackedQuest(param1).name;
      }

      private static function trackedQuest(param1:Object) : Object
      {
         var markers:Array = collection(param1,"aMissionMarkers");
         var marker:Object = null;
         var text:String = "";
         var objective:String = "";
         var fallback:String = "";
         var name:String = questName(param1);
         var index:int = 0;
         while(markers != null && index < markers.length)
         {
            marker = markers[index];
            if(name.length == 0) name = questName(marker);
            text = markerText(marker);
            if(text.length != 0)
            {
               if(marker != null && marker.bShouldShowText === true && objective.length == 0) objective = text;
               else if(fallback.length == 0) fallback = text;
            }
            ++index;
         }
         if(objective.length == 0) objective = fallback;
         var split:Array = splitLines(objective);
         if(split.length > 1)
         {
            if(name.length == 0) name = String(split[0]).replace(/^\s+|\s+$/g,"");
            objective = String(split[split.length - 1]).replace(/^\s+|\s+$/g,"");
         }
         if(name == objective) name = "";
         return {name:name,objective:objective};
      }

      private static function questName(param1:Object) : String
      {
         var index:int = 0;
         var text:String = "";
         while(param1 != null && index < QUEST_NAME_FIELDS.length)
         {
            text = field(param1,QUEST_NAME_FIELDS[index]) == null ? "" : String(field(param1,QUEST_NAME_FIELDS[index])).replace(/^\s+|\s+$/g,"");
            if(text.length != 0) return text;
            ++index;
         }
         return "";
      }

      private static function markerText(param1:Object) : String
      {
         if(param1 == null || param1.strText === undefined || param1.strText === null) return "";
         return String(param1.strText).replace(/^\s+|\s+$/g,"");
      }

      private static function splitLines(param1:String) : Array
      {
         var lines:Array = [];
         var rest:String = param1 == null ? "" : param1;
         var cut:int = 0;
         var newline:int = 0;
         var carriage:int = 0;
         while(rest.length > 0)
         {
            newline = rest.indexOf("\n");
            carriage = rest.indexOf("\r");
            cut = newline;
            if(carriage >= 0 && (cut < 0 || carriage < cut)) cut = carriage;
            if(cut < 0)
            {
               lines.push(rest);
               break;
            }
            lines.push(rest.substring(0,cut));
            rest = rest.substring(cut + 1);
            if(rest.length > 0 && rest.charAt(0) == "\n") rest = rest.substring(1);
         }
         return lines;
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

      private function onLocalEnvironmentData(param1:Object) : void
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
         this.setText("location.name",field(param1.data,"sLocationName"));
         this.setFinite("environment.oxygenpercentage",this.readFinite(param1.data,"fOxygenPercent"));
         this.setFinite("environment.temperature",this.readFinite(param1.data,"fTemperature"));
         this.setFinite("environment.gravity",this.readFinite(param1.data,"fGravity"));
         this.setText("diagnostic.localenvironmentfields","LOCAL ENV ROOT: " + this.listFieldNames(param1.data,MAX_DIAGNOSTIC_FIELDS));
         this.notifyChanged();
      }

      private function onEnvironmentEffectsData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var effects:Array = collection(param1.data,"aEnvironmentEffects");
         var activeEffects:Array = [false,false,false,false];
         var effect:Object = null;
         var icon:String = "";
         var normalizedIcon:String = "";
         var soakProtection:Number = this.readFinite(param1.data,"fSoakDamagePct");
         var normalizedProtection:Number = 0;
         var fullSoak:Boolean = field(param1.data,"bShouldPlayAlertAtFullSoak") === true;
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
         this.setFinite("environment.soakcandidate",soakProtection);
         this.setBoolean("environment.fullsoakalertcandidate",fullSoak);
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
                  icon = field(effect,"sEffectIcon") == null ? "" : String(field(effect,"sEffectIcon"));
                  if(icon.length > 0)
                  {
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

      private function onStarmapSystemBodyInfoData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         this.setText("diagnostic.starmapprovider","STARMAP BODY PROVIDER RECEIVED IN HUD: " +
            this.listCandidateFields(param1.data,["body","gravity","temp","atmosphere","magnetosphere","water"],8));
         this.notifyChanged();
      }

      private function onPersonalEffectsData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var data:Object = param1 == null ? null : param1.data;
         tacticalAwareness.updatePersonalEffects(data);
         dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
      }

      private function onQuestData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var data:Object = param1 == null ? null : param1.data;
         if(data == null || collection(data,"aQuests") == null) return;
         this.missionTitle = resolveActiveMissionTitle(data);
         this.publishQuestText();
         this.notifyChanged();
      }

      private function onQuestUpdateData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var next:Object = nextQuestTitle(this.activeQuestName,this.activeQuestId,param1 == null ? null : param1.data);
         this.activeQuestName = next.name == null ? "" : String(next.name);
         this.activeQuestId = next.id;
         this.publishQuestText();
         this.notifyChanged();
      }

      private function publishQuestText() : void
      {
         var compassName:String = resolveTrackedQuestName(compassData);
         var title:String = this.missionTitle;
         if(title.length == 0) title = this.activeQuestName;
         if(title.length == 0) title = compassName;
         this.setText("quest.name",title);
         this.setText("quest.objective",resolveTrackedObjective(compassData));
      }

      private function onRadarCompassData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         compassData = param1 == null ? null : param1.data;
         this.publishQuestText();
         tacticalAwareness.updateCompass(compassData);
         dispatchEvent(new Event(COMPASS_CHANGE));
         dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
         this.notifyChanged();
      }

      private function onLocalEnvironmentFrequentData(param1:Object) : void
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
         var localTime:* = field(param1.data,"fLocalPlanetTime");
         var hoursPerDay:* = field(param1.data,"fLocalPlanetHoursPerDay");
         var galacticTime:* = field(param1.data,"fGalacticStandardTime");
         this.setFinite("environment.localtime",localTime);
         this.updateSolarTransitionCountdown(localTime,hoursPerDay);
         if(galacticTime != null) this.setFinite("player.universaltime",Number(galacticTime) / 24);
         this.universalTimeDiagnostic = "UT: fGalacticStandardTime=" +
            this.formatDiagnosticValue(galacticTime) +
            " | fLocalPlanetTime=" + this.formatDiagnosticValue(localTime) +
            " | fLocalPlanetHoursPerDay=" + this.formatDiagnosticValue(hoursPerDay);
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

      private function onPlayerData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         if(tacticalAwareness.updateCombatState(field(param1.data,"bIsInCombat") === true))
         {
            dispatchEvent(new Event(TACTICAL_AWARENESS_CHANGE));
         }
         this.setFinite("player.level",this.readFinite(param1.data,"uLevel"));
         this.setFinite("player.levelxp",this.readFinite(param1.data,"fLevelXP"));
         this.setFinite("player.nextlevelxp",this.readFinite(param1.data,"fNextLevelXP"));
         this.setRatio("player.xppercentage",this.readFinite(param1.data,"fLevelXP"),this.readFinite(param1.data,"fNextLevelXP"));
         this.setText("diagnostic.playerfields","PLAYERDATA ROOT: " +
            this.listFieldNames(param1.data,MAX_PLAYER_DIAGNOSTIC_FIELDS));
         this.setText("diagnostic.playertargets","PLAYER TARGETS: sName=" +
            this.formatDiagnosticValue(field(param1.data,"sName")) + " | uLevel=" +
            this.formatDiagnosticValue(field(param1.data,"uLevel")) + " | fLevelXP=" +
            this.formatDiagnosticValue(field(param1.data,"fLevelXP")) + " | fNextLevelXP=" +
            this.formatDiagnosticValue(field(param1.data,"fNextLevelXP")) + " | VWKS_PlayerLevel=" +
            this.formatDiagnosticValue(field(param1.data,"VWKS_PlayerLevel")));
         this.updatePlayerSerialDiagnostic(field(param1.data,"sName"));
         this.notifyChanged();
      }

      private function onPlayerFrequentData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         this.setFinite("player.health",this.readFinite(param1.data,"fHealth"));
         this.setFinite("player.maxhealth",this.readFinite(param1.data,"fMaxHealth"));
         this.setRatio("player.healthpercentage",this.readFinite(param1.data,"fHealth"),this.readFinite(param1.data,"fMaxHealth"));
         this.setFinite("player.oxygen",this.readFinite(param1.data,"fOxygen"));
         this.setFinite("player.maxoxygen",this.readFinite(param1.data,"fMaxO2CO2"));
         this.setRatio("player.oxygenpercentage",this.readFinite(param1.data,"fOxygen"),this.readFinite(param1.data,"fMaxO2CO2"));
         this.setFinite("player.carbondioxide",this.readFinite(param1.data,"fCarbonDioxide"));
         this.setRatio("player.carbondioxidepercentage",this.readFinite(param1.data,"fCarbonDioxide"),this.readFinite(param1.data,"fMaxO2CO2"));
         this.setFinite("power.current",this.readFinite(param1.data,"fStarPower"));
         this.setFinite("power.maximum",this.readFinite(param1.data,"fMaxStarPower"));
         this.setRatio("power.percentage",this.readFinite(param1.data,"fStarPower"),this.readFinite(param1.data,"fMaxStarPower"));
         this.captureOxygenActivity(this.readFinite(param1.data,"fOxygen"),this.readFinite(param1.data,"fMaxO2CO2"));
         this.updateActivityDiagnostic();
         this.notifyChanged();
      }

      private function onWeaponData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var clip:Number = this.readFinite(param1.data,"uClipAmmo");
         var total:Number = this.readFinite(param1.data,"uTotalAmmo");
         var explosiveCount:Number = this.readFinite(param1.data,"uExplosiveCount");
         var explosiveType:Number = this.readFinite(param1.data,"uExplosiveIndicatorType");
         this.setText("weapon.name",field(param1.data,"sWeaponName"));
         this.setText("weapon.icon",field(param1.data,"sIconLinkageName"));
         this.setFinite("weapon.clipammo",clip);
         this.setFinite("weapon.totalammo",total);
         if(!isNaN(clip) && isFinite(clip) && !isNaN(total) && isFinite(total))
         {
            this.setFinite("weapon.reserveammo",Math.max(0,total - clip));
         }
         this.setBoolean("weapon.displayammo",field(param1.data,"bDisplayAmmo") === true);
         this.setBoolean("weapon.ammoaspercent",field(param1.data,"bShowAmmoAsPercent") === true);
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

      private function onJetpackData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var charge:Number = this.readFinite(param1.data,"fJetpackCharge");
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

      private function onPlayerInventoryData(param1:Object) : void
      {
         if(this.disposed)
         {
            return;
         }
         var items:Array = collection(param1.data,"aItems");
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
         this.setFinite("carry.current",this.readFinite(param1.data,"fEncumbrance"));
         this.setFinite("carry.maximum",this.readFinite(param1.data,"fMaxEncumbrance"));
         this.setRatio("carry.percentage",this.readFinite(param1.data,"fEncumbrance"),this.readFinite(param1.data,"fMaxEncumbrance"));
         this.setFinite("credits",this.readFinite(param1.data,"uCoin"));
         this.updateDigipickDiagnostic(items);
         if(items == null)
         {
            this.clearValue("weapon.ammotype");
            this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA RECEIVED — ITEM DATA UNAVAILABLE");
            this.traceInventorySubscription(param1.data,null);
            this.notifyChanged();
            return;
         }
         while(index < items.length)
         {
            item = items[index];
            if(item != null && field(item,"bIsEquipped") === true && field(item,"WeaponInfo") != null)
            {
               weaponInfo = field(item,"WeaponInfo");
               ++equippedWeaponCount;
               if(ammoType.length == 0 && field(weaponInfo,"sAmmoType") != null)
               {
                  ammoType = String(field(weaponInfo,"sAmmoType"));
                  if(ammoType.replace(/\s/g,"").length == 0)
                  {
                     ammoType = "";
                  }
               }
            }
            if(item != null && field(item,"bIsEquipped") === true && field(item,"ArmorInfo") != null && armorResistance.length < 4)
            {
               armorInfo = field(item,"ArmorInfo");
               armorResistance.push("T=" + this.formatDiagnosticValue(field(armorInfo,"fThermalResist")) +
                  " A=" + this.formatDiagnosticValue(field(armorInfo,"fAirborneResist")) +
                  " C=" + this.formatDiagnosticValue(field(armorInfo,"fCorrosiveResist")) +
                  " R=" + this.formatDiagnosticValue(field(armorInfo,"fRadiationResist")));
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
         this.traceInventorySubscription(param1.data,items);
         this.notifyChanged();
      }

      private function onFavoritesData(param1:Object) : void
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
         favorites = collection(data,"aFavoriteItems");
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
               name = this.cleanFavoriteText(field(item,"sName"));
               ammoName = this.cleanFavoriteText(field(item,"sAmmoName"));
               ammoCount = this.readFinite(item,"uAmmoCount");
               count = this.readFinite(item,"uCount");
               detail = "";
               if(field(item,"bIsPower") === true)
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
               favoriteIsPower[index] = field(item,"bIsPower") === true;
               favoriteIsWeapon[index] = favoriteIsPower[index] !== true && ammoName.length != 0;
               favoriteAmmoCounts[index] = ammoCount;
               favoriteItemCounts[index] = count;
            }
            ++index;
         }
         this.refreshFavoriteSlotText();
         this.notifyChanged();
      }

      private function onControlMapData(param1:Object) : void
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

      private function onStarbornPowersData(param1:Object) : void
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

      private function readFinite(param1:Object, param2:String) : Number
      {
         var value:* = field(param1,param2);
         var number:Number = Number(value);
         return value != null && isFinite(number) ? number : NaN;
      }

      public static function quantizeDisplay(key:String, value:Number) : Number
      {
         if(key.indexOf("exposurelevel") >= 0) return Math.round(value * 8) / 8;
         if(key == "environment.protectionlevel" || key == "boost.charge") return Math.round(value * 16) / 16;
         if(key == "environment.gravity" || key == "environment.soakcandidate") return Math.round(value * 100) / 100;
         if(key.indexOf("percentage") >= 0 || key == "environment.temperature" ||
            key == "player.health" || key == "player.maxhealth" ||
            key == "player.oxygen" || key == "player.maxoxygen" || key == "player.carbondioxide" ||
            key == "player.level" || key == "player.digipicks" || key == "credits" ||
            key == "carry.current" || key == "carry.maximum" ||
            key == "power.current" || key == "power.maximum" ||
            key == "weapon.clipammo" || key == "weapon.totalammo" || key == "weapon.reserveammo" ||
            /^favorite\.(0[1-9]|1[0-2])\.(loaded|spare)$/.test(key) ||
            key == "weapon.explosivecount" || key == "environment.hazard.effectcount" ||
            key == "environment.hazard.airwaterlevel" || key == "environment.hazard.thermallevel" ||
            key == "environment.hazard.corrosivelevel" || key == "environment.hazard.radiationlevel")
         {
            return Math.round(value);
         }
         return value;
      }

      private function setFinite(param1:String, param2:Object) : void
      {
         var source:String = null;
         var value:Number = Number(param2);
         if(!isNaN(value) && isFinite(value))
         {
            source = normalizeSource(param1);
            value = quantizeDisplay(source,value);
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
         dispatchEvent(new Event(VALUE_CHANGE));
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
         if(this.disposed) return;
         this.disposed = true;
         if(this.exposureTimer != null)
         {
            this.exposureTimer.stop();
            this.exposureTimer.removeEventListener(TimerEvent.TIMER,this.onExposureTimer);
            this.exposureTimer = null;
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
         try
         {
            this.updateExposureState();
         }
         catch(param2:Error)
         {
            this.failProvider({ provider:"EXPOSURE_TIMER" },"CUI-EVT-CALLBACK",param2);
         }
      }

      private function updateExposureState() : void
      {
         var current:Number = 0;
         var target:Number = 0;
         var index:int = 0;
         var previousActivity:Number = this.oxygenActivity;
         var drainDetected:Boolean = this.oxygenDrainDetected;
         var changed:Boolean = false;
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
               var exposureSource:String = normalizeSource(String(EXPOSURE_SOURCES[index]));
               var exposureStep:Number = quantizeDisplay(exposureSource,Number(this.exposureCurrent[index]));
               if(!this.valueMatches(exposureSource,exposureStep)) changed = true;
               this.setFinite(exposureSource,exposureStep);
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

      private function exposureValueInCurrentRange(param1:Number) : Boolean
      {
         return !isNaN(param1) && isFinite(param1) && param1 >= 0 && param1 <= 1;
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
               formId = this.readFinite(item,"uFormID");
               editorId = field(item,"sEditorID") != null ? String(field(item,"sEditorID")) :
                  (field(item,"EditorID") != null ? String(field(item,"EditorID")) : "");
               name = field(item,"sName") != null ? String(field(item,"sName")) : "";
               if(!isNaN(formId) && isFinite(formId) && formId == DIGIPICK_FORM_ID)
               {
                  match = item;
                  matchRoute = "FORM 00000A";
                  this.setFinite("player.digipicks",this.readFinite(item,"uCount"));
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
            favoriteAmmoCounts[index - 1] = NaN;
            favoriteItemCounts[index - 1] = NaN;
            favoriteIsWeapon[index - 1] = false;
            favoriteIsPower[index - 1] = false;
            this.setText("favorite." + slotLabel + ".name","EMPTY");
            this.setText("favorite." + slotLabel + ".detail","");
            this.clearValue("favorite." + slotLabel + ".loaded");
            this.clearValue("favorite." + slotLabel + ".spare");
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
            this.publishFavoriteAmmo(index,slotLabel,name);
            ++index;
         }
      }

      private function publishFavoriteAmmo(index:int, slotLabel:String, name:String) : void
      {
         var loadedKey:String = "favorite." + slotLabel + ".loaded";
         var spareKey:String = "favorite." + slotLabel + ".spare";
         var weaponRecord:Object = values["weapon.name"];
         var clipRecord:Object = values["weapon.clipammo"];
         var reserveRecord:Object = values["weapon.reserveammo"];
         var weaponName:String = "";
         var ammo:Number = Number(favoriteAmmoCounts[index]);
         var count:Number = Number(favoriteItemCounts[index]);
         var equipped:Boolean = false;
         var isPower:Boolean = Boolean(favoriteIsPower[index]);
         var isWeapon:Boolean = Boolean(favoriteIsWeapon[index]);
         this.clearValue(loadedKey);
         this.clearValue(spareKey);
         if(weaponRecord != null && weaponRecord.known)
         {
            weaponName = this.cleanFavoriteText(weaponRecord.value);
         }
         equipped = weaponName.length != 0 && name.toLowerCase() == weaponName.toLowerCase();
         if(equipped)
         {
            isWeapon = true;
         }
         if(!isWeapon)
         {
            if(!isPower && !isNaN(count) && isFinite(count) && count > 1)
            {
               this.setFinite(spareKey,Math.max(0,count));
            }
            return;
         }
         if(equipped && clipRecord != null && clipRecord.known)
         {
            this.setFinite(loadedKey,clipRecord.value);
         }
         if(equipped && reserveRecord != null && reserveRecord.known)
         {
            this.setFinite(spareKey,reserveRecord.value);
         }
         else if(!isNaN(ammo) && isFinite(ammo))
         {
            this.setFinite(spareKey,Math.max(0,ammo));
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

      private function traceInventorySubscription(data:Object, items:Array) : void
      {
         var lines:Array = null;
         var summary:String = null;
         var chosen:Array = null;
         var entry:Object = null;
         var index:int = 0;
         try
         {
            lines = [];
            lines.push("VWHUD TRACE | inventory | items=" + (items == null ? "null" : items.length.toString()) +
               " | root=" + this.listFieldNames(data,24) +
               " | rootprobe=" + this.inventoryProbe(data));
            if(items != null)
            {
               chosen = this.chooseInventoryTraceItems(items);
               while(index < chosen.length)
               {
                  entry = chosen[index];
                  lines.push("VWHUD TRACE | inventory | " + this.describeInventoryTraceItem(entry.item,int(entry.index)));
                  ++index;
               }
            }
            summary = lines.join("\n");
            if(summary == this.inventoryTraceSummary)
            {
               return;
            }
            this.inventoryTraceSummary = summary;
            index = 0;
            while(index < lines.length)
            {
               trace(String(lines[index]));
               ++index;
            }
         }
         catch(traceError:*)
         {
            trace("VWHUD TRACE | inventory | error=" + String(traceError).substr(0,180));
         }
      }

      private function chooseInventoryTraceItems(items:Array) : Array
      {
         var chosen:Array = [];
         var used:Object = {};
         var index:int = 0;
         var item:Object = null;
         while(index < items.length && chosen.length < 3)
         {
            item = items[index];
            if(item != null && field(item,"bIsEquipped") === true)
            {
               chosen.push({item:item,index:index});
               used[index] = true;
            }
            ++index;
         }
         index = 0;
         while(index < items.length && chosen.length < 3)
         {
            if(used[index] !== true && items[index] != null)
            {
               chosen.push({item:items[index],index:index});
            }
            ++index;
         }
         return chosen;
      }

      private function describeInventoryTraceItem(item:Object, index:int) : String
      {
         var nested:Array = [];
         var name:String = null;
         var value:* = null;
         var text:String = null;
         if(item == null)
         {
            return "item=" + index.toString() + " | NULL";
         }
         for(name in item)
         {
            value = item[name];
            if(value != null && typeof value == "object" && !(value is Array) && nested.length < 4)
            {
               nested.push(name + "{" + this.listFieldNames(value,12) + " probe=" + this.inventoryProbe(value) + "}");
            }
         }
         this.appendNamedInventoryObject(nested,item,"WeaponInfo");
         this.appendNamedInventoryObject(nested,item,"ArmorInfo");
         text = "item=" + index.toString() +
            " | name=" + this.formatDiagnosticValue(field(item,"sName")) +
            " | equipped=" + this.formatDiagnosticValue(field(item,"bIsEquipped")) +
            " | keys=" + this.listFieldNames(item,24) +
            " | probe=" + this.inventoryProbe(item);
         if(nested.length != 0)
         {
            text += " | nested=" + nested.join(" ; ");
         }
         return text.length > 700 ? text.substring(0,700) + "..." : text;
      }

      private function appendNamedInventoryObject(nested:Array, item:Object, name:String) : void
      {
         var value:* = field(item,name);
         var index:int = 0;
         if(value == null || typeof value != "object" || value is Array || nested.length >= 6)
         {
            return;
         }
         while(index < nested.length)
         {
            if(String(nested[index]).indexOf(name + "{") == 0)
            {
               return;
            }
            ++index;
         }
         nested.push(name + "{" + this.listFieldNames(value,12) + " probe=" + this.inventoryProbe(value) + "}");
      }

      private function inventoryProbe(target:Object) : String
      {
         var names:Array = ["sIcon","sIconName","sIconPath","sIconLinkageName","sTexture","sTexturePath","sModel","sModelPath","sPlugin","sPluginName","sModName","sFile","sFileName","sEditorID","EditorID","uFormID","uHandleID"];
         var found:Array = [];
         var index:int = 0;
         var name:String = null;
         var value:* = null;
         if(target == null)
         {
            return "NULL";
         }
         while(index < names.length)
         {
            name = String(names[index]);
            value = field(target,name);
            if(value !== undefined && value !== null)
            {
               found.push(name + "=" + this.formatDiagnosticValue(value));
            }
            ++index;
         }
         return found.length == 0 ? "NONE" : found.join(" | ");
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
