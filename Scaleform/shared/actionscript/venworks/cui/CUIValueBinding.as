package venworks.cui
{
   import flash.display.Shape;
   import flash.geom.Matrix;
   import venworks.cui.components.CUIComponent;
   import venworks.cui.components.CUIMeter;
   import venworks.cui.components.CUIText;

   public final class CUIValueBinding
   {
      private var target:CUIComponent;
      private var node:XML;
      private var style:XML;
      private var source:String;
      private var maxSource:String;
      private var format:String;
      private var meterMask:Shape;

      public function CUIValueBinding(param1:CUIComponent, param2:XML, param3:XML = null)
      {
         super();
         target = param1;
         node = param2;
         style = param3;
         source = CUIPlayerHudDataContext.normalizeSource(String(node.@source));
         maxSource = node.@maxSource.length() == 1 ? CUIPlayerHudDataContext.normalizeSource(String(node.@maxSource)) : "";
         format = node.@format.length() == 1 ? String(node.@format).toLowerCase() : "raw";
      }

      public static function validateText(param1:XML) : void
      {
         var kind:String = validateSource(String(param1.@source));
         var valueFormat:String = param1.@format.length() == 1 ? String(param1.@format).toLowerCase() : "raw";
         if(valueFormat != "raw" && valueFormat != "integer" && valueFormat != "percent" &&
            valueFormat != "temperature" && valueFormat != "gravity" && valueFormat != "time24" &&
            valueFormat != "boolean")
         {
            throw new Error("INVALID|Unsupported value format: " + valueFormat);
         }
         if(kind == "string" && valueFormat != "raw")
         {
            throw new Error("INVALID|String source requires raw format: " + String(param1.@source));
         }
         if(kind == "boolean" && valueFormat != "raw" && valueFormat != "boolean")
         {
            throw new Error("INVALID|Boolean source requires raw or boolean format: " + String(param1.@source));
         }
         if(kind == "number" && valueFormat == "boolean")
         {
            throw new Error("INVALID|Numeric source cannot use boolean format: " + String(param1.@source));
         }
      }

      public static function validateMeter(param1:XML) : void
      {
         if(validateSource(String(param1.@source)) != "number")
         {
            throw new Error("INVALID|Meter source must be numeric: " + String(param1.@source));
         }
         if(param1.@maxSource.length() == 1 && validateSource(String(param1.@maxSource)) != "number")
         {
            throw new Error("INVALID|Meter maxSource must be numeric: " + String(param1.@maxSource));
         }
      }

      private static function validateSource(param1:String) : String
      {
         var kind:String = CUIPlayerHudDataContext.getKind(param1);
         if(kind == "unknown")
         {
            throw new Error("INVALID|Value source is not allowlisted in hudmenu.gfx: " + param1);
         }
         return kind;
      }

      public function apply(param1:CUIPlayerHudDataContext) : void
      {
         var resolved:Object = param1.getValue(source);
         if(target is CUIText)
         {
            CUIText(target).setValue(Boolean(resolved.known) ? this.formatValue(resolved.value) : String(node.@value));
         }
         else if(target is CUIMeter)
         {
            this.applyMeter(param1,resolved);
         }
      }

      private function applyMeter(param1:CUIPlayerHudDataContext, param2:Object) : void
      {
         var resolvedMaximum:Object = null;
         var current:Number = Boolean(param2.known) ? Number(param2.value) : Number(node.@value);
         var maximum:Number = Number(node.@max);
         var ratio:Number = 0;
         var width:Number = Number(node.@width);
         var height:Number = Number(node.@height);
         var direction:String = style != null && style.@direction.length() == 1 ? String(style.@direction) : "right";
         var transformMatrix:Matrix = null;
         if(maxSource.length != 0)
         {
            resolvedMaximum = param1.getValue(maxSource);
            if(Boolean(resolvedMaximum.known))
            {
               maximum = Number(resolvedMaximum.value);
            }
         }
         if(!isNaN(current) && isFinite(current) && !isNaN(maximum) && isFinite(maximum) && maximum > 0)
         {
            ratio = Math.max(0,Math.min(1,current / maximum));
         }
         this.ensureMeterMask();
         transformMatrix = target.transform.matrix.clone();
         meterMask.transform.matrix = transformMatrix;
         meterMask.graphics.clear();
         meterMask.graphics.beginFill(16777215,1);
         if(direction == "left")
         {
            meterMask.graphics.drawRect(width * (1 - ratio),0,width * ratio,height);
         }
         else if(direction == "down")
         {
            meterMask.graphics.drawRect(0,0,width,height * ratio);
         }
         else if(direction == "up")
         {
            meterMask.graphics.drawRect(0,height * (1 - ratio),width,height * ratio);
         }
         else
         {
            meterMask.graphics.drawRect(0,0,width * ratio,height);
         }
         meterMask.graphics.endFill();
      }

      private function ensureMeterMask() : void
      {
         if(meterMask != null)
         {
            return;
         }
         if(target.parent == null)
         {
            throw new Error("INVALID|Bound meter must be attached before value evaluation: " + String(node.@id));
         }
         meterMask = new Shape();
         meterMask.name = String(node.@id) + ".ValueMask";
         target.parent.addChild(meterMask);
         target.mask = meterMask;
      }

      private function formatValue(param1:Object) : String
      {
         var numeric:Number = Number(param1);
         var totalMinutes:int = 0;
         var hours:int = 0;
         var minutes:int = 0;
         if(format == "boolean")
         {
            return Boolean(param1) ? "TRUE" : "FALSE";
         }
         if(format == "integer")
         {
            return Math.round(numeric).toString();
         }
         if(format == "percent")
         {
            return Math.round(numeric).toString() + "%";
         }
         if(format == "temperature")
         {
            return Math.round(numeric).toString() + "°";
         }
         if(format == "gravity")
         {
            return numeric.toFixed(2) + "g";
         }
         if(format == "time24")
         {
            numeric = numeric - Math.floor(numeric);
            if(numeric < 0)
            {
               numeric += 1;
            }
            totalMinutes = Math.floor(numeric * 1440 + 0.5) % 1440;
            hours = int(totalMinutes / 60);
            minutes = totalMinutes % 60;
            return (hours < 10 ? "0" : "") + hours.toString() + ":" + (minutes < 10 ? "0" : "") + minutes.toString();
         }
         return String(param1);
      }
   }
}
