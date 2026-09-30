package
{
   // Converts existing HUD calculations into bounded HTML bindings, never display objects.
   public final class VWHudPresentation
   {
      private static const HEADINGS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      public static function update(data:Object, tactical:Object, pulse:int, scanning:Boolean) : void
      {
         var direction:Number = tactical == null ? 0 : finite(tactical.direction,0);
         var score:int = tactical == null ? 0 : Math.max(0,Math.min(100,Math.round(finite(tactical.threatScore,0))));
         data["threat.score"] = score;
         var states:Array = ["CLEAR","CAUTION","DANGER","CRITICAL"];
         var state:int = Math.min(3,int(score/25));
         data["threat.label"] = "THREAT "+score+"%  "+states[state];
         for(var i:int = 0; i < states.length; i++) data["threat."+String(states[i]).toLowerCase()] = i == state;
         if(scanning)
         {
            var degrees:Number = normalizeDegrees(direction*180/Math.PI);
            data["scanner.heading"] = "SCANNING // HDG "+pad(Math.round(degrees)%360,3)+" "+HEADINGS[int(Math.round(degrees/45))%8];
            data["scanner.contacts"] = scanner(tactical == null ? null : tactical.scannerTargets as Array,direction);
            data["scanner.grid"] = grid(pulse);
         }
         else
         {
            data["scanner.heading"] = "";
            data["scanner.contacts"] = [{label:"NO VALID CONTACTS",hostile:false,friendly:true,y:0}];
            data["scanner.grid"] = grid(0);
         }
         var effects:Array = [];
         var row:Object;
         for each(row in data.buffrows) effects.push(effectRow(row,true));
         for each(row in data.debuffrows) effects.push(effectRow(row,false));
         for(i = 0; i < effects.length; i++)
         {
            effects[i].x = (i%8)*40;
            effects[i].y = 0;
         }
         data["effectrows"] = effects;
      }

      private static const EFFECT_ICONS:Object = {
         "Fed":"fed","Hydrated":"hydrated","Well Rested":"rested","Malnourished":"malnourished","Dehydrated":"dehydrated",
         "Bleeding":"bleed","Poisoning":"poison","Radiation Poisoning":"radiation","Corrosive Environment":"corrosive","Corrosive Rain":"corrosive",
         "Corrosive Particulates":"corrosive","Corrosive Vapor":"corrosive","Freezing Cold and Snow":"cold","Freezing Rain":"cold","Freezing Vapor":"cold",
         "Intense Heat":"thermal","Scalding Rain":"thermal","Scalding Vapor":"thermal","Poor Air Quality":"gas",
         "Burns":"thermal","Heatstroke":"thermal","Frostbite":"cold","Hypothermia":"cold",
         "Lacerations":"injury","Puncture Wounds":"injury","Contusions":"injury","Torn Muscle":"injury","Sprain":"injury","Dislocated Limb":"injury","Fractured Limb":"injury","Fractured Skull":"injury","Concussion":"injury","Brain Injury":"injury","Hernia":"injury",
         "Bone Infection":"infection","Brain Infection":"infection","Intestinal Infection":"infection","Lung Infection":"infection","Tissue Infection":"infection",
         "Lung Damage":"lungs","Fortify O2":"lungs","Fortify O2 Recovery Rate":"lungs","Toxic Gas Hazard":"gas",
         "Restore Health":"health","Heart+":"health","Fortify Carry Weight":"weight","Fortify Movement Speed":"speed","Fortify Jump Height":"speed",
         "Fortify Physical Damage Resistance":"shield","Fortify Energy Damage Resistance":"shield","Increased Weapon Accuracy":"accuracy","Reduce Movement Noise":"stealth","Slow Time":"time",
         "Fortify Damage":"damage","Fortify Melee Damage":"damage","Fortify Ranged Damage":"damage","Improved Research Crit Chance":"research","Reduced Research Cost":"research",
         "Fortify Persuasion":"persuasion","Companion Affinity Increases Faster":"companion","Addiction Suppression":"addiction","Fortify Power Recovery Rate":"power"
      };

      private static var foldedIcons:Object = null;

      private static function effectRow(row:Object, positive:Boolean) : Object
      {
         var label:String = row == null || row.label == null ? "" : String(row.label);
         var known:* = iconId(label);
         var icon:String = known == null ? (positive ? "fallbackbuff" : "fallbackdebuff") : String(known);
         return {label:label,positive:positive,negative:!positive,icon:"assets/effect-"+icon+".svg"};
      }

      private static function iconId(label:String) : *
      {
         if(foldedIcons == null)
         {
            foldedIcons = {};
            for(var name:String in EFFECT_ICONS) foldedIcons[name.toLowerCase()] = EFFECT_ICONS[name];
         }
         return foldedIcons[label.toLowerCase()];
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
