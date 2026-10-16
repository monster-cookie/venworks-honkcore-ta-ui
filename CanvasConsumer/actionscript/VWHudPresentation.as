package
{
   // Converts existing HUD calculations into bounded HTML bindings, never display objects.
   public final class VWHudPresentation
   {
      private static const HEADINGS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      // One 720px line holds 18 icons. Debuffs occupy the next two lines. The 35px pitch keeps the third line above the critical-health alert. The visor lays the same groups on a center arc: buffs to the left, debuffs to the right.
      public static const BUFF_COLUMNS:int = 18;

      public static const DEBUFF_COLUMNS:int = 18;

      public static const DEBUFF_ROWS:int = 2;

      public static const COLUMN_STRIDE:int = 40;

      public static const ROW_STRIDE:int = 35;

      public static const VISOR_STRIDE:int = 36;

      // Icon centers sit on y = 58 + 96*(dist/524)^2, with the arc midpoint at x=600.
      public static function visorArcPoint(index:int, count:int, right:Boolean, line:int) : Object
      {
         var slots:int = count < 1 ? 1 : count;
         var t:Number = slots <= 1 ? 0 : index / (slots - 1);
         var dist:Number = 56 + t * 468;
         var iconCenter:Number = right ? 600 + dist : 600 - dist;
         var drop:Number = dist / 524;
         return {x:int(Math.round(iconCenter - 18)), y:int(Math.round(40 + 96 * drop * drop + line * 46))};
      }

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
         var column:int = 0;
         var buffCount:int = data.buffrows == null ? 0 : data.buffrows.length;
         for each(row in data.buffrows)
         {
            var buff:Object = effectRow(row,true);
            if(VWHudVariant.VISOR)
            {
               var buffPoint:Object = visorArcPoint(column,buffCount,false,0);
               buff.x = buffPoint.x;
               buff.y = buffPoint.y;
            }
            else
            {
               buff.x = column * COLUMN_STRIDE;
               buff.y = 0;
            }
            effects.push(buff);
            column++;
         }
         column = 0;
         var debuffCount:int = data.debuffrows == null ? 0 : data.debuffrows.length;
         for each(row in data.debuffrows)
         {
            var debuff:Object = effectRow(row,false);
            var line:int = int(column / DEBUFF_COLUMNS);
            var lineIndex:int = column % DEBUFF_COLUMNS;
            if(VWHudVariant.VISOR)
            {
               var lineCount:int = debuffCount - line * DEBUFF_COLUMNS;
               if(lineCount > DEBUFF_COLUMNS) lineCount = DEBUFF_COLUMNS;
               var debuffPoint:Object = visorArcPoint(lineIndex,lineCount,true,line);
               debuff.x = debuffPoint.x;
               debuff.y = debuffPoint.y;
            }
            else
            {
               debuff.x = lineIndex * COLUMN_STRIDE;
               debuff.y = (1 + line) * ROW_STRIDE;
            }
            effects.push(debuff);
            column++;
         }
         data["effectrows"] = effects;
      }

      private static const EFFECT_ICONS:Object = {
         "Fed":"fed","Hydrated":"hydrated","Well Rested":"rested","Malnourished":"malnourished","Dehydrated":"dehydrated",
         "Bleeding":"bleed","Poisoning":"poison","Radiation":"radiation","Radiation Poisoning":"radiation","Corrosive":"corrosive","Corrosive Environment":"corrosive","Corrosive Rain":"corrosive",
         "Corrosive Particulates":"corrosive","Corrosive Vapor":"corrosive","Freezing Cold and Snow":"cold","Freezing Rain":"cold","Freezing Vapor":"cold",
         "Intense Heat":"thermal","Scalding Rain":"thermal","Scalding Vapor":"thermal","Thermal":"thermal","Poor Air Quality":"gas","Gas":"gas","Sandstorm":"sandstorm","Cold":"cold","Incoming Weather":"fallbackdebuff",
         "Burns":"thermal","Heatstroke":"thermal","Frostbite":"cold","Hypothermia":"cold",
         "Injury":"injury","Lacerations":"injury","Puncture Wounds":"injury","Contusions":"injury","Torn Muscle":"injury","Sprain":"injury","Dislocated Limb":"injury","Fractured Limb":"injury","Fractured Skull":"injury","Concussion":"injury","Brain Injury":"injury","Hernia":"injury",
         "Infection":"infection","Bone Infection":"infection","Brain Infection":"infection","Intestinal Infection":"infection","Lung Infection":"infection","Tissue Infection":"infection",
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
