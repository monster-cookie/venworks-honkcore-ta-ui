package
{
   // Converts existing HUD calculations into bounded HTML bindings, never display objects.
   public final class VWHudPresentation
   {
      private static const HEADINGS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      public static function update(data:Object, tactical:Object, compass:Object, pulse:int) : void
      {
         var direction:Number = tactical == null ? 0 : finite(tactical.direction,0);
         var score:int = tactical == null ? 0 : Math.max(0,Math.min(100,Math.round(finite(tactical.threatScore,0))));
         data["threat.score"] = score;
         var states:Array = ["CLEAR","CAUTION","DANGER","CRITICAL"];
         var state:int = Math.min(3,int(score/25));
         data["threat.label"] = "THREAT "+score+"%  "+states[state];
         for(var i:int = 0; i < states.length; i++) data["threat."+String(states[i]).toLowerCase()] = i == state;
         var degrees:Number = normalizeDegrees(direction*180/Math.PI);
         data["scanner.heading"] = "SCANNING // HDG "+pad(Math.round(degrees)%360,3)+" "+HEADINGS[int(Math.round(degrees/45))%8];
         data["compass.ticks"] = ticks(degrees);
         data["compass.markers"] = markers(tactical == null ? null : tactical.markers as Array,direction);
         data["radar.contacts"] = contacts(compass,direction);
         data["scanner.contacts"] = scanner(tactical == null ? null : tactical.scannerTargets as Array,direction);
         data["scanner.grid"] = grid(pulse);
         var effects:Array = [];
         var row:Object;
         for each(row in data.buffrows) effects.push({label:row.label,positive:true,negative:false});
         for each(row in data.debuffrows) effects.push({label:row.label,positive:false,negative:true});
         for(i = 0; i < effects.length; i++)
         {
            effects[i].x = (i%4)*180;
            effects[i].y = int(i/4)*18;
         }
         data["effectrows"] = effects;
      }

      private static function ticks(center:Number) : Array
      {
         var result:Array = [];
         for(var heading:Number = Math.floor((center-60)/5)*5; heading <= center+65; heading += 5)
         {
            var delta:Number = signedDegrees(heading-center);
            if(Math.abs(delta) > 60) continue;
            var absolute:int = Math.round(normalizeDegrees(heading));
            var major:Boolean = absolute%45 == 0;
            var medium:Boolean = absolute%15 == 0;
            result.push({x:413+delta/60*413,y:major ? 38 : medium ? 41 : 44,major:major,medium:!major && medium,minor:!major && !medium,label:major ? HEADINGS[int(Math.round(absolute/45))%8] : ""});
         }
         return result;
      }

      private static function markers(sources:Array, direction:Number) : Array
      {
         var result:Array = [];
         var checked:int = 0;
         for each(var source:Object in sources)
         {
            if(result.length >= 48 || ++checked > 256) break;
            if(source == null) continue;
            var heading:Number = finite(VWHudViewModel.field(source,"fHeading"),NaN);
            var delta:Number = radians(heading-direction);
            if(!isFinite(delta) || Math.abs(delta) > Math.PI/3) continue;
            result.push({x:413+delta/(Math.PI/3)*413,y:20,opacity:clamp(VWHudViewModel.field(source,"fDistanceAlpha"),0,1,1),scale:clamp(VWHudViewModel.field(source,"fDistanceScale"),0.5,1.5,1)*0.48,
               marker:{type:integer(VWHudViewModel.field(source,"uiMarkerIconType"),0,255),relative:integer(VWHudViewModel.field(source,"uiRelativeMarkerHeightType"),0,3),subcategory:integer(VWHudViewModel.field(source,"uiMapMarkerSubCategoryType"),0,3),locationtype:integer(VWHudViewModel.field(source,"uMapMarkerType"),0,65535),locationcategory:integer(VWHudViewModel.field(source,"uMapMarkerCategory"),0,65535),locationstate:integer(VWHudViewModel.field(source,"uLocationMarkerState"),0,65535),effect:source.isEnvironmentEffect === true ? String(VWHudViewModel.field(source,"sEffectIcon")).substr(0,96) : ""}});
         }
         return result;
      }

      private static function contacts(compass:Object, direction:Number) : Array
      {
         var result:Array = [];
         if(compass == null) return result;
         appendContacts(result,VWHudViewModel.collection(compass,"aEnemyMarkers"),direction,true);
         appendContacts(result,VWHudViewModel.collection(compass,"aMarkers"),direction,false);
         return result;
      }

      private static function appendContacts(result:Array, sources:Array, direction:Number, enemy:Boolean) : void
      {
         var checked:int = 0;
         for each(var source:Object in sources)
         {
            if(result.length >= 32 || ++checked > 256) break;
            if(source == null || finite(VWHudViewModel.field(source,"uiHandle"),0) == 0) continue;
            var type:int = integer(VWHudViewModel.field(source,"uiMarkerIconType"),0,255);
            if(!enemy && [8,10,13,14].indexOf(type) < 0) continue;
            var distance:Number = finite(VWHudViewModel.field(source,"fDistanceToPlayer"),NaN);
            var heading:Number = finite(VWHudViewModel.field(source,"fHeading"),NaN);
            if(!isFinite(distance+heading) || distance < 0 || distance > 200) continue;
            var angle:Number = Math.PI-direction;
            var vx:Number = -Math.sin(angle); var vy:Number = Math.cos(angle);
            var radius:Number = 92*distance/200;
            var structure:Boolean = !enemy && [10,13,14].indexOf(type) >= 0;
            result.push({x:92+(Math.cos(heading)*vx-Math.sin(heading)*vy)*radius,y:92+(Math.sin(heading)*vx+Math.cos(heading)*vy)*radius,opacity:clamp(VWHudViewModel.field(source,"fDistanceAlpha"),0,1,1),enemy:enemy,ally:!enemy && !structure,structure:structure});
         }
      }

      private static function scanner(sources:Array, direction:Number) : Array
      {
         var candidates:Array = [];
         var checked:int = 0;
         for each(var source:Object in sources)
         {
            if(++checked > 256) break;
            if(source == null) continue;
            var distance:Number = finite(source.distance,NaN);
            var delta:Number = radians(finite(source.heading,NaN)-direction);
            if(!isFinite(delta+distance) || distance < 0 || Math.abs(delta) > Math.PI/4) continue;
            candidates.push({target:source,delta:delta,distance:distance,handle:finite(source.handle,0),type:integer(source.markerType,0,255)});
         }
         candidates.sortOn(["distance","handle","type"],[Array.NUMERIC,Array.NUMERIC,Array.NUMERIC]);
         var result:Array = [];
         if(candidates.length == 0) return [{label:"NO VALID CONTACTS",hostile:false,friendly:true,y:0}];
         for(var i:int = 0; i < Math.min(5,candidates.length); i++)
         {
            var item:Object = candidates[i];
            var degrees:int = Math.round(Math.abs(Number(item.delta)*180/Math.PI));
            var bearing:String = (degrees == 0 ? "C" : item.delta < 0 ? "L" : "R")+pad(degrees,3);
            result.push({label:String(item.target.codename).substr(0,128)+"  "+bearing+"  "+pad(Math.round(item.distance),5),hostile:item.type == 5,friendly:item.type != 5,y:i*21});
         }
         return result;
      }

      private static function grid(pulse:int) : Array
      {
         var result:Array = [];
         var thresholds:Array = [1,2,4,5,8];
         for(var row:int = -2; row <= 2; row++)
            for(var column:int = -2; column <= 2; column++)
            {
               if(row == 0 && column == 0) continue;
               var dot:Boolean = pulse > 0 && row*row+column*column <= thresholds[Math.min(pulse,5)-1];
               result.push({x:450+column*54,y:260+row*54,dot:dot,square:!dot});
            }
         return result;
      }

      private static function finite(value:*, fallback:Number) : Number { return value != null && value !== undefined && isFinite(Number(value)) ? Number(value) : fallback; }
      private static function clamp(value:*, minimum:Number, maximum:Number, fallback:Number) : Number { return Math.max(minimum,Math.min(maximum,finite(value,fallback))); }
      private static function integer(value:*, minimum:int, maximum:int) : int { return int(clamp(value,minimum,maximum,minimum)); }
      private static function normalizeDegrees(value:Number) : Number { return (value%360+360)%360; }
      private static function signedDegrees(value:Number) : Number { return normalizeDegrees(value+180)-180; }
      private static function radians(value:Number) : Number { return isFinite(value) ? ((value+Math.PI)%(2*Math.PI)+2*Math.PI)%(2*Math.PI)-Math.PI : NaN; }
      private static function pad(value:Number, count:int) : String { var text:String = Math.max(0,Math.round(value)).toString(); while(text.length < count) text = "0"+text; return text; }
   }
}
