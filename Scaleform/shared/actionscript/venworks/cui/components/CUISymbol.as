package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.utils.getDefinitionByName;

   public class CUISymbol extends CUIImage
   {
      private static const SYMBOLS:Object = {
         "environment-alert":{
            classes:["HUDMenu_fla.envAlertIcon_174","HUDMenu_LRG_fla.envAlertIcon_174"],
            initialFrame:1
         },
         "quest-door-marker":{
            classes:["QuestDoorMarker"],
            initialFrame:1
         },
         "boost-fill":{
            classes:["HUDMenu_fla.BoostBarFill_mc_139","HUDMenu_LRG_fla.BoostBarFill_mc_139"],
            initialFrame:1
         }
      };

      public function CUISymbol(param1:XML, param2:DisplayObject = null)
      {
         super(param1,param1.@library.length() == 1 ?
            requireLibrarySymbol(param1,param2) :
            createEmbeddedSymbol(String(param1.@name)));
      }

      public static function isAllowlisted(param1:String) : Boolean
      {
         return SYMBOLS[param1] != null;
      }

      public static function libraryLinkageName(param1:String, param2:String) : String
      {
         return "VenworksCUI_" + param1.replace(/-/g,"_") + "_" + param2.replace(/-/g,"_");
      }

      private static function requireLibrarySymbol(param1:XML, param2:DisplayObject) : DisplayObject
      {
         if(param2 == null)
         {
            throw new Error("INVALID|Resolved symbol is unavailable: " + String(param1.@library) + "/" + String(param1.@name));
         }
         return param2;
      }

      private static function createEmbeddedSymbol(param1:String) : DisplayObject
      {
         var definition:Object = null;
         var className:String = null;
         var symbolClass:Class = null;
         var result:DisplayObject = null;
         if(!isAllowlisted(param1))
         {
            throw new Error("INVALID|Embedded symbol is not allowlisted: " + param1);
         }
         definition = SYMBOLS[param1];
         for each(className in definition.classes)
         {
            try
            {
               symbolClass = getDefinitionByName(className) as Class;
               if(symbolClass != null)
               {
                  result = new symbolClass() as DisplayObject;
               }
            }
            catch(param2:Error)
            {
               result = null;
            }
            if(result != null)
            {
               break;
            }
         }
         if(result == null)
         {
            throw new Error("INVALID|Embedded symbol is unavailable in this HUD movie: " + param1);
         }
         if(result is MovieClip && definition.initialFrame != null)
         {
            MovieClip(result).gotoAndStop(int(definition.initialFrame));
         }
         return result;
      }
   }
}
