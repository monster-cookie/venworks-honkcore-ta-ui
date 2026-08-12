package venworks.cui
{
   import Shared.AS3.Data.BSUIDataManager;
   import Shared.AS3.Data.FromClientDataEvent;
   import flash.events.Event;
   import flash.events.EventDispatcher;

   public final class CUIPlayerHudDataContext extends EventDispatcher
   {
      private static const MAX_DIAGNOSTIC_FIELDS:int = 12;
      private static const MAX_DIAGNOSTIC_EFFECTS:int = 4;
      private static const MAX_HAZARD_EFFECTS:int = 32;

      private var values:Object;
      public function CUIPlayerHudDataContext()
      {
         super();
         values = {};
         BSUIDataManager.Subscribe("LocalEnvironmentData",this.onLocalEnvironmentData);
         BSUIDataManager.Subscribe("LocalEnvData_Frequent",this.onLocalEnvironmentFrequentData);
         BSUIDataManager.Subscribe("PlayerFrequentData",this.onPlayerFrequentData);
         BSUIDataManager.Subscribe("PlayerInventoryData",this.onPlayerInventoryData);
         BSUIDataManager.Subscribe("WeaponData",this.onWeaponData);
         BSUIDataManager.Subscribe("HudJetpackData",this.onJetpackData);
         BSUIDataManager.Subscribe("HUDStarbornPowersData",this.onStarbornPowersData);
         BSUIDataManager.Subscribe("EnvironmentEffectsData",this.onEnvironmentEffectsData);
         BSUIDataManager.Subscribe("StarmapSystemBodyInfoProvider",this.onStarmapSystemBodyInfoData);
         this.setText("diagnostic.inventoryprovider","PLAYERINVENTORYDATA NOT RECEIVED");
         this.setText("diagnostic.powernameprovider","HUD POWER NAME FIELDS NOT RECEIVED");
         this.setText("diagnostic.environmentprovider","ENVIRONMENTEFFECTSDATA NOT RECEIVED");
         this.setText("diagnostic.environmentfields","ENVIRONMENT ROOT FIELDS UNAVAILABLE");
         this.setText("diagnostic.environmentcandidates","PULSE / AGGREGATE CANDIDATES UNAVAILABLE");
         this.setText("diagnostic.localenvironmentfields","LOCALENVIRONMENTDATA NOT RECEIVED");
         this.setText("diagnostic.armorresistance","EQUIPPED ARMOR RESISTANCE DATA NOT RECEIVED");
         this.setText("diagnostic.starmapprovider","STARMAP BODY PROVIDER NOT RECEIVED IN HUD");
         this.resetEnvironmentalHazards();
         this.setText("environment.hazard.airwaterstatus","ENVIRONMENT PROVIDER NOT RECEIVED / WATER UNPROVEN");
         this.setText("environment.hazard.thermalstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.corrosivestatus","ENVIRONMENT PROVIDER NOT RECEIVED");
         this.setText("environment.hazard.radiationstatus","ENVIRONMENT PROVIDER NOT RECEIVED");
      }

      public static function normalizeSource(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var source:String = normalizeSource(param1);
         if(source == "location.name" || source == "power.key" || source == "power.name" ||
            source == "weapon.name" || source == "weapon.icon" || source == "weapon.ammotype" ||
            source == "diagnostic.inventoryprovider" || source == "diagnostic.powernameprovider" ||
            source == "environment.hazard.airwaterstatus" || source == "environment.hazard.thermalstatus" ||
            source == "environment.hazard.corrosivestatus" || source == "environment.hazard.radiationstatus" ||
            source == "diagnostic.environmentprovider" || source == "diagnostic.environmentfields" ||
            source == "diagnostic.environmentcandidates" || source == "diagnostic.localenvironmentfields" ||
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
            source == "player.health" || source == "player.maxhealth" ||
            source == "player.healthpercentage" || source == "player.oxygen" ||
            source == "player.maxoxygen" || source == "player.oxygenpercentage" ||
            source == "player.carbondioxide" || source == "power.current" ||
            source == "power.maximum" || source == "power.percentage" ||
            source == "power.cost" || source == "power.cooldown" ||
            source == "carry.current" || source == "carry.maximum" || source == "credits" ||
            source == "weapon.clipammo" || source == "weapon.totalammo" ||
            source == "weapon.reserveammo" || source == "weapon.explosivecount" ||
            source == "weapon.explosivetype" || source == "boost.charge" ||
            source == "environment.hazard.effectcount" || source == "environment.hazard.airwaterlevel" ||
            source == "environment.hazard.thermallevel" || source == "environment.hazard.corrosivelevel" ||
            source == "environment.hazard.radiationlevel" || source == "environment.soakcandidate")
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
         this.setText("diagnostic.localenvironmentfields","LOCAL ENV ROOT: " + this.listFieldNames(param1.data,MAX_DIAGNOSTIC_FIELDS));
         this.notifyChanged();
      }

      private function onEnvironmentEffectsData(param1:FromClientDataEvent) : void
      {
         var effects:Array = param1.data.aEnvironmentEffects as Array;
         var effect:Object = null;
         var icon:String = "";
         var normalizedIcon:String = "";
         var index:int = 0;
         var diagnosticIndex:int = 0;
         this.resetEnvironmentalHazards();
         this.clearValue("environment.soakcandidate");
         this.clearValue("environment.fullsoakalertcandidate");
         this.setText("diagnostic.environmentprovider","ENVIRONMENTEFFECTSDATA RECEIVED");
         this.setText("diagnostic.environmentfields","ENVIRONMENT ROOT: " + this.listFieldNames(param1.data,MAX_DIAGNOSTIC_FIELDS));
         this.setText("diagnostic.environmentcandidates","PULSE / AGGREGATE CANDIDATES: " +
            this.listCandidateFields(param1.data,["pulse","speed","threat","severity","exposure","soak"],8));
         this.setFinite("environment.soakcandidate",param1.data.fSoakDamagePct);
         this.setBoolean("environment.fullsoakalertcandidate",param1.data.bShouldPlayAlertAtFullSoak);
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
                        this.setFinite("environment.hazard.airwaterlevel",1);
                        this.setText("environment.hazard.airwaterstatus","AIRBORNE DETECTED / WATER UNPROVEN");
                     }
                     else if(normalizedIcon.indexOf("thermal") >= 0)
                     {
                        this.setFinite("environment.hazard.thermallevel",1);
                        this.setText("environment.hazard.thermalstatus","THERMAL EFFECT DETECTED");
                     }
                     else if(normalizedIcon.indexOf("corrosive") >= 0)
                     {
                        this.setFinite("environment.hazard.corrosivelevel",1);
                        this.setText("environment.hazard.corrosivestatus","CORROSIVE EFFECT DETECTED");
                     }
                     else if(normalizedIcon.indexOf("radiation") >= 0)
                     {
                        this.setFinite("environment.hazard.radiationlevel",1);
                        this.setText("environment.hazard.radiationstatus","RADIATION EFFECT DETECTED");
                     }
                  }
               }
               ++index;
            }
         }
         this.notifyChanged();
      }

      private function onStarmapSystemBodyInfoData(param1:FromClientDataEvent) : void
      {
         this.setText("diagnostic.starmapprovider","STARMAP BODY PROVIDER RECEIVED IN HUD: " +
            this.listCandidateFields(param1.data,["body","gravity","temp","atmosphere","magnetosphere","water"],8));
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
         this.setFinite("weapon.explosivecount",param1.data.uExplosiveCount);
         this.setFinite("weapon.explosivetype",param1.data.uExplosiveIndicatorType);
         this.notifyChanged();
      }

      private function onJetpackData(param1:FromClientDataEvent) : void
      {
         var charge:Number = Number(param1.data.fJetpackCharge);
         if(!isNaN(charge) && isFinite(charge))
         {
            this.setFinite("boost.charge",Math.max(0,Math.min(1,charge)));
            this.notifyChanged();
         }
      }

      private function onPlayerInventoryData(param1:FromClientDataEvent) : void
      {
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
         this.clearValue("credits");
         this.setText("diagnostic.armorresistance","EQUIPPED ARMOR RESISTANCE FIELDS NOT PRESENT");
         this.setFinite("carry.current",param1.data.fEncumbrance);
         this.setFinite("carry.maximum",param1.data.fMaxEncumbrance);
         this.setFinite("credits",param1.data.uCoin);
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

      private function onStarbornPowersData(param1:FromClientDataEvent) : void
      {
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
               name = "Elemental Blast";
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

      private function clearValue(param1:String) : void
      {
         delete values[normalizeSource(param1)];
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

      private function resetEnvironmentalHazards() : void
      {
         var index:int = 0;
         this.setFinite("environment.hazard.effectcount",0);
         this.setFinite("environment.hazard.airwaterlevel",0);
         this.setFinite("environment.hazard.thermallevel",0);
         this.setFinite("environment.hazard.corrosivelevel",0);
         this.setFinite("environment.hazard.radiationlevel",0);
         this.setText("environment.hazard.airwaterstatus","AIRBORNE CLEAR / WATER UNPROVEN");
         this.setText("environment.hazard.thermalstatus","NO THERMAL EFFECT");
         this.setText("environment.hazard.corrosivestatus","NO CORROSIVE EFFECT");
         this.setText("environment.hazard.radiationstatus","NO RADIATION EFFECT");
         while(index < MAX_DIAGNOSTIC_EFFECTS)
         {
            this.setText("diagnostic.effect" + index.toString(),"EFFECT " + index.toString() + ": UNUSED");
            ++index;
         }
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
