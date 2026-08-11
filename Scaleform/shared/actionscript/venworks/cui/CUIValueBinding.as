package venworks.cui
{
   import venworks.cui.components.CUIComponent;
   import venworks.cui.components.CUIMeter;
   import venworks.cui.components.CUIProviderSymbol;
   import venworks.cui.components.CUIText;

   public final class CUIValueBinding
   {
      private var target:CUIComponent;
      private var node:XML;
      private var source:String;
      private var maxSource:String;
      private var format:String;
      private var valueTemplate:String;
      private var templateVariables:Array;

      public function CUIValueBinding(param1:CUIComponent, param2:XML, param3:XML = null)
      {
         super();
         target = param1;
         node = param2;
         source = CUIPlayerHudDataContext.normalizeSource(String(node.@source));
         maxSource = node.@maxSource.length() == 1 ? CUIPlayerHudDataContext.normalizeSource(String(node.@maxSource)) : "";
         format = node.@format.length() == 1 ? String(node.@format).toLowerCase() : "raw";
         valueTemplate = node.@valueTemplate.length() == 1 ? String(node.@valueTemplate) : "";
         templateVariables = valueTemplate.length == 0 ? [] : parseTextTemplate(valueTemplate);
      }

      public static function validateText(param1:XML) : void
      {
         var kind:String = validateSource(String(param1.@source));
         var valueFormat:String = param1.@format.length() == 1 ? String(param1.@format).toLowerCase() : "raw";
         validateFormat(String(param1.@source),kind,valueFormat);
      }

      public static function validateTextTemplate(param1:XML) : void
      {
         parseTextTemplate(String(param1.@valueTemplate));
      }

      private static function validateFormat(param1:String, param2:String, param3:String) : void
      {
         var kind:String = param2;
         var valueFormat:String = param3;
         if(valueFormat != "raw" && valueFormat != "integer" && valueFormat != "percent" &&
            valueFormat != "temperature" && valueFormat != "gravity" && valueFormat != "time24" &&
            valueFormat != "boolean")
         {
            throw new Error("INVALID|Unsupported value format: " + valueFormat);
         }
         if(kind == "string" && valueFormat != "raw")
         {
            throw new Error("INVALID|String source requires raw format: " + param1);
         }
         if(kind == "boolean" && valueFormat != "raw" && valueFormat != "boolean")
         {
            throw new Error("INVALID|Boolean source requires raw or boolean format: " + param1);
         }
         if(kind == "number" && valueFormat == "boolean")
         {
            throw new Error("INVALID|Numeric source cannot use boolean format: " + param1);
         }
      }

      private static function parseTextTemplate(param1:String) : Array
      {
         var variables:Array = [];
         var cursor:int = 0;
         var openIndex:int = 0;
         var closeIndex:int = 0;
         var body:String = null;
         var separatorIndex:int = 0;
         var variableSource:String = null;
         var variableFormat:String = null;
         if(param1.length == 0 || param1.length > 256)
         {
            throw new Error("INVALID|Text valueTemplate length must be between 1 and 256 characters.");
         }
         while(cursor < param1.length)
         {
            if(param1.charAt(cursor) == "}")
            {
               throw new Error("INVALID|Malformed text valueTemplate.");
            }
            if(param1.charAt(cursor) != "{")
            {
               ++cursor;
               continue;
            }
            openIndex = cursor;
            closeIndex = param1.indexOf("}",openIndex + 1);
            if(closeIndex < 0 || param1.indexOf("{",openIndex + 1) >= 0 && param1.indexOf("{",openIndex + 1) < closeIndex)
            {
               throw new Error("INVALID|Malformed text valueTemplate.");
            }
            body = param1.substring(openIndex + 1,closeIndex);
            separatorIndex = body.indexOf(":");
            variableSource = separatorIndex < 0 ? body : body.substring(0,separatorIndex);
            variableFormat = separatorIndex < 0 ? "raw" : body.substring(separatorIndex + 1).toLowerCase();
            if(variableSource.length == 0 || variableSource.search(/^[A-Za-z][A-Za-z0-9._]*$/) != 0 ||
               separatorIndex >= 0 && body.indexOf(":",separatorIndex + 1) >= 0)
            {
               throw new Error("INVALID|Malformed text valueTemplate variable: " + body);
            }
            validateFormat(variableSource,validateSource(variableSource),variableFormat);
            variables.push({ source:CUIPlayerHudDataContext.normalizeSource(variableSource), format:variableFormat, token:param1.substring(openIndex,closeIndex + 1) });
            if(variables.length > 8)
            {
               throw new Error("INVALID|Text valueTemplate exceeds the 8-variable limit.");
            }
            cursor = closeIndex + 1;
         }
         if(variables.length == 0)
         {
            throw new Error("INVALID|Text valueTemplate requires at least one well-formed variable.");
         }
         return variables;
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

      public static function validateProviderSymbol(param1:XML) : void
      {
         var normalizedSource:String = CUIPlayerHudDataContext.normalizeSource(String(param1.@source));
         if(normalizedSource != "weapon.icon")
         {
            throw new Error("INVALID|Provider symbol source is not allowlisted: " + String(param1.@source));
         }
         if(validateSource(String(param1.@source)) != "string")
         {
            throw new Error("INVALID|Provider symbol source must be a string: " + String(param1.@source));
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
            if(valueTemplate.length != 0)
            {
               CUIText(target).setValue(this.applyTextTemplate(param1));
            }
            else
            {
               CUIText(target).setValue(Boolean(resolved.known) ? this.formatValue(resolved.value,format) : String(node.@value));
            }
         }
         else if(target is CUIMeter)
         {
            this.applyMeter(param1,resolved);
         }
         else if(target is CUIProviderSymbol)
         {
            CUIProviderSymbol(target).setSymbol(Boolean(resolved.known) ? String(resolved.value) : "");
         }
      }

      private function applyTextTemplate(param1:CUIPlayerHudDataContext) : String
      {
         var output:String = valueTemplate;
         var variable:Object = null;
         var resolved:Object = null;
         for each(variable in templateVariables)
         {
            resolved = param1.getValue(String(variable.source));
            if(!Boolean(resolved.known))
            {
               return String(node.@value);
            }
            output = output.split(String(variable.token)).join(this.formatValue(resolved.value,String(variable.format)));
         }
         return output;
      }

      private function applyMeter(param1:CUIPlayerHudDataContext, param2:Object) : void
      {
         var resolvedMaximum:Object = null;
         var current:Number = Boolean(param2.known) ? Number(param2.value) : Number(node.@value);
         var maximum:Number = Number(node.@max);
         if(maxSource.length != 0)
         {
            resolvedMaximum = param1.getValue(maxSource);
            if(Boolean(resolvedMaximum.known))
            {
               maximum = Number(resolvedMaximum.value);
            }
         }
         CUIMeter(target).setValue(current,maximum);
      }

      private function formatValue(param1:Object, param2:String) : String
      {
         var numeric:Number = Number(param1);
         var totalMinutes:int = 0;
         var hours:int = 0;
         var minutes:int = 0;
         if(param2 == "boolean")
         {
            return Boolean(param1) ? "TRUE" : "FALSE";
         }
         if(param2 == "integer")
         {
            return Math.round(numeric).toString();
         }
         if(param2 == "percent")
         {
            return Math.round(numeric).toString() + "%";
         }
         if(param2 == "temperature")
         {
            return Math.round(numeric).toString() + "°";
         }
         if(param2 == "gravity")
         {
            return numeric.toFixed(2) + "g";
         }
         if(param2 == "time24")
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
