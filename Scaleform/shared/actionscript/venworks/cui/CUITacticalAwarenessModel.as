package venworks.cui
{
   public final class CUITacticalAwarenessModel
   {
      private static const MAX_COMPASS_MARKERS:int = 48;
      private static const MAX_THREAT_MARKERS:int = 64;
      private static const MAX_STATUS_EFFECTS:int = 64;
      private static const AWARENESS_DISTANCE:Number = 300;
      private static const CRITICAL_HOSTILE_DISTANCE:Number = 25;
      private static const SEVERE_HOSTILE_DISTANCE:Number = 50;
      private static const SEVERE_HOSTILE_SCORE:Number = 90;
      private static const MIT_MARKER_HAZARD:uint = 12;
      private static const HOSTILE_MAX:Number = 35;
      private static const PHYSICAL_HAZARD_MAX:Number = 15;
      private static const DEBUFF_MAX:Number = 35;
      private static const ENVIRONMENT_MAX:Number = 15;

      private var compassData:Object;
      private var environmentData:Object;
      private var personalEffectsData:Object;
      private var exposureActive:Array;
      private var exposureLevels:Array;
      private var environmentCritical:Boolean;
      private var inCombat:Boolean;
      private var snapshotValue:Object;

      public function CUITacticalAwarenessModel()
      {
         super();
         exposureActive = [false,false,false,false];
         exposureLevels = [0,0,0,0];
         snapshotValue = this.createSnapshot();
      }

      public function get snapshot() : Object
      {
         return snapshotValue;
      }

      public function updateCompass(param1:Object) : void
      {
         compassData = param1;
         snapshotValue = this.createSnapshot();
      }

      public function updateEnvironment(param1:Object, param2:Array, param3:Array, param4:Boolean) : void
      {
         environmentData = param1;
         this.updateEnvironmentalPressure(param2,param3,param4);
      }

      public function updateEnvironmentalPressure(param1:Array, param2:Array, param3:Boolean) : void
      {
         exposureActive = this.copyBooleanArray(param1,4);
         exposureLevels = this.copyNormalizedArray(param2,4);
         environmentCritical = param3;
         snapshotValue = this.createSnapshot();
      }

      public function updatePersonalEffects(param1:Object) : void
      {
         personalEffectsData = param1;
         snapshotValue = this.createSnapshot();
      }

      public function updateCombatState(param1:Boolean) : Boolean
      {
         if(inCombat == param1)
         {
            return false;
         }
         inCombat = param1;
         snapshotValue = this.createSnapshot();
         return true;
      }

      private function createSnapshot() : Object
      {
         var markers:Array = this.collectCompassMarkers();
         var statuses:Array = this.collectStatusEffects();
         var enemyMarkers:Array = compassData == null ? null : compassData.aEnemyMarkers as Array;
         var hostilePressure:Number = this.calculateNearbyPressure(
            enemyMarkers,
            5,
            0
         );
         var nearestHostileDistance:Number = this.findNearestHostileDistance(enemyMarkers);
         var physicalHazardPressure:Number = this.calculateNearbyPressure(
            compassData == null ? null : compassData.aMarkers as Array,
            3,
            MIT_MARKER_HAZARD
         );
         var debuffCount:int = this.countStatuses(statuses,"debuff");
         var debuffPressure:Number = debuffCount == 0 ? 0 : debuffCount == 1 ? 0.5 : debuffCount == 2 ? 0.75 : 1;
         var environmentPressure:Number = this.calculateEnvironmentPressure();
         var hostileScore:Number = hostilePressure * HOSTILE_MAX;
         var physicalHazardScore:Number = physicalHazardPressure * PHYSICAL_HAZARD_MAX;
         var debuffScore:Number = debuffPressure * DEBUFF_MAX;
         var environmentScore:Number = environmentPressure * ENVIRONMENT_MAX;
         var score:Number = Math.max(0,Math.min(100,
            hostileScore + physicalHazardScore + debuffScore + environmentScore));
         if(inCombat || nearestHostileDistance < CRITICAL_HOSTILE_DISTANCE)
         {
            score = 100;
         }
         else if(nearestHostileDistance < SEVERE_HOSTILE_DISTANCE)
         {
            score = Math.max(score,SEVERE_HOSTILE_SCORE);
         }
         var direction:Number = compassData == null ? 0 : Number(compassData.fDirection);
         if(!this.isFiniteNumber(direction))
         {
            direction = 0;
         }
         return {
            direction:direction,
            markers:markers,
            statuses:statuses,
            threatScore:Math.round(score),
            hostileContribution:hostileScore,
            physicalHazardContribution:physicalHazardScore,
            debuffContribution:debuffScore,
            environmentContribution:environmentScore
         };
      }

      private function collectCompassMarkers() : Array
      {
         var result:Array = [];
         var byHandle:Object = {};
         var general:Array = compassData == null ? null : compassData.aMarkers as Array;
         var environmental:Array = environmentData == null ? null : environmentData.aEnvironmentEffects as Array;
         this.appendCompassMarkers(result,byHandle,general,false);
         this.appendCompassMarkers(result,byHandle,environmental,true);
         if(result.length > MAX_COMPASS_MARKERS)
         {
            result.length = MAX_COMPASS_MARKERS;
         }
         return result;
      }

      private function appendCompassMarkers(param1:Array, param2:Object, param3:Array, param4:Boolean) : void
      {
         var index:int = 0;
         var source:Object = null;
         var marker:Object = null;
         var handle:Number = NaN;
         var key:String = null;
         while(param3 != null && index < param3.length)
         {
            source = param3[index];
            handle = source == null ? 0 : Number(source.uiHandle);
            if(source != null && this.isFiniteNumber(handle) && handle != 0)
            {
               key = String(handle);
               marker = param2[key];
               if(marker == null && param1.length < MAX_COMPASS_MARKERS)
               {
                  marker = this.copyObject(source);
                  marker.isEnvironmentEffect = param4;
                  param2[key] = marker;
                  param1.push(marker);
               }
               else if(marker != null && param4)
               {
                  this.copyFields(source,marker);
                  marker.isEnvironmentEffect = true;
               }
            }
            ++index;
         }
      }

      private function collectStatusEffects() : Array
      {
         var result:Array = [];
         var seen:Object = {};
         var effects:Array = personalEffectsData == null ? null : personalEffectsData.aPersonalEffects as Array;
         var source:Object = null;
         var icon:String = null;
         var key:String = null;
         var kind:String = null;
         var index:int = 0;
         while(effects != null && index < effects.length && result.length < MAX_STATUS_EFFECTS)
         {
            source = effects[index];
            icon = source == null || source.sEffectIcon === undefined || source.sEffectIcon === null ? "" :
               String(source.sEffectIcon);
            key = icon.toUpperCase();
            if(key.length != 0 && seen[key] !== true)
            {
               seen[key] = true;
               kind = this.classifyStatus(key);
               result.push({
                  icon:icon,
                  label:this.createStatusLabel(key,kind),
                  kind:kind,
                  sourceIndex:index
               });
            }
            ++index;
         }
         result.sort(this.compareStatuses);
         return result;
      }

      private function classifyStatus(param1:String) : String
      {
         if(param1.indexOf("PERSONALEFFECT_") == 0)
         {
            return "debuff";
         }
         if(param1.indexOf("SUSTENANCE_") == 0)
         {
            return "sustenance";
         }
         return "neutral";
      }

      private function createStatusLabel(param1:String, param2:String) : String
      {
         var match:Array = null;
         var category:String = null;
         var sign:String = null;
         if(param1 == "SUSTENANCE_FOOD_POSITIVE_1")
         {
            return "FED";
         }
         if(param1 == "SUSTENANCE_DRINK_POSITIVE_1")
         {
            return "HYDRATED";
         }
         if(param2 == "debuff")
         {
            return "AFFLICTION";
         }
         if(param2 == "sustenance")
         {
            match = /^SUSTENANCE_(FOOD|DRINK)_(POSITIVE|NEGATIVE)_([0-9]+)$/.exec(param1);
            if(match != null)
            {
               category = String(match[1]);
               sign = String(match[2]) == "POSITIVE" ? "+" : "-";
               return category + " " + sign + String(match[3]);
            }
            return param1.indexOf("FOOD") >= 0 ? "FOOD" : param1.indexOf("DRINK") >= 0 ? "DRINK" : "SUSTENANCE";
         }
         return "EFFECT";
      }

      private function compareStatuses(param1:Object, param2:Object) : Number
      {
         var first:int = param1.kind == "debuff" ? 0 : param1.kind == "neutral" ? 1 : 2;
         var second:int = param2.kind == "debuff" ? 0 : param2.kind == "neutral" ? 1 : 2;
         if(first != second)
         {
            return first - second;
         }
         return int(param1.sourceIndex) - int(param2.sourceIndex);
      }

      private function countStatuses(param1:Array, param2:String) : int
      {
         var count:int = 0;
         var index:int = 0;
         while(index < param1.length)
         {
            if(param1[index].kind == param2)
            {
               ++count;
            }
            ++index;
         }
         return count;
      }

      private function calculateNearbyPressure(param1:Array, param2:Number, param3:uint) : Number
      {
         var handles:Object = {};
         var marker:Object = null;
         var handle:Number = NaN;
         var distance:Number = NaN;
         var count:int = 0;
         var nearest:Number = AWARENESS_DISTANCE;
         var index:int = 0;
         var limit:int = param1 == null ? 0 : Math.min(param1.length,MAX_THREAT_MARKERS);
         while(index < limit)
         {
            marker = param1[index];
            handle = marker == null ? 0 : Number(marker.uiHandle);
            distance = marker == null ? NaN : Number(marker.fDistanceToPlayer);
            if(marker != null && this.isFiniteNumber(handle) && handle != 0 && handles[String(handle)] !== true &&
               this.isFiniteNumber(distance) && distance >= 0 && distance <= AWARENESS_DISTANCE &&
               (param3 == 0 || uint(marker.uiMarkerIconType) == param3))
            {
               handles[String(handle)] = true;
               ++count;
               nearest = Math.min(nearest,distance);
            }
            ++index;
         }
         if(count == 0)
         {
            return 0;
         }
         return Math.max(0,Math.min(1,
            0.6 * Math.min(count / param2,1) + 0.4 * (1 - nearest / AWARENESS_DISTANCE)));
      }

      private function findNearestHostileDistance(param1:Array) : Number
      {
         var marker:Object = null;
         var handle:Number = NaN;
         var distance:Number = NaN;
         var nearest:Number = SEVERE_HOSTILE_DISTANCE;
         var index:int = 0;
         var limit:int = param1 == null ? 0 : Math.min(param1.length,MAX_THREAT_MARKERS);
         while(index < limit)
         {
            marker = param1[index];
            handle = marker == null ? 0 : Number(marker.uiHandle);
            distance = marker == null ? NaN : Number(marker.fDistanceToPlayer);
            if(marker != null && this.isFiniteNumber(handle) && handle != 0 &&
               this.isFiniteNumber(distance) && distance >= 0 && distance < nearest)
            {
               nearest = distance;
            }
            ++index;
         }
         return nearest;
      }

      private function calculateEnvironmentPressure() : Number
      {
         var activeCount:int = 0;
         var maximum:Number = 0;
         var index:int = 0;
         if(environmentCritical)
         {
            return 1;
         }
         while(index < exposureActive.length)
         {
            if(Boolean(exposureActive[index]))
            {
               ++activeCount;
               maximum = Math.max(maximum,Number(exposureLevels[index]));
            }
            ++index;
         }
         return Math.max(0,Math.min(1,0.6 * maximum + 0.4 * Math.min(activeCount / 4,1)));
      }

      private function copyBooleanArray(param1:Array, param2:int) : Array
      {
         var result:Array = [];
         var index:int = 0;
         while(index < param2)
         {
            result.push(param1 != null && index < param1.length && Boolean(param1[index]));
            ++index;
         }
         return result;
      }

      private function copyNormalizedArray(param1:Array, param2:int) : Array
      {
         var result:Array = [];
         var value:Number = 0;
         var index:int = 0;
         while(index < param2)
         {
            value = param1 == null || index >= param1.length ? 0 : Number(param1[index]);
            result.push(this.isFiniteNumber(value) ? Math.max(0,Math.min(1,value)) : 0);
            ++index;
         }
         return result;
      }

      private function copyObject(param1:Object) : Object
      {
         var result:Object = {};
         this.copyFields(param1,result);
         return result;
      }

      private function copyFields(param1:Object, param2:Object) : void
      {
         var field:String = null;
         for(field in param1)
         {
            param2[field] = param1[field];
         }
      }

      private function isFiniteNumber(param1:Number) : Boolean
      {
         return !isNaN(param1) && isFinite(param1);
      }
   }
}
