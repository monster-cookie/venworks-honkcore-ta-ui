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

      public function CUISymbol(param1:XML)
      {
         super(param1,param1.@library.length() == 1 ?
            createLibrarySymbol(String(param1.@library),String(param1.@name)) :
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

      public static function isLibrarySymbolAvailable(param1:String, param2:String) : Boolean
      {
         try
         {
            return getDefinitionByName(libraryLinkageName(param1,param2)) as Class != null;
         }
         catch(param3:Error)
         {
            return false;
         }
      }

      private static function createLibrarySymbol(param1:String, param2:String) : DisplayObject
      {
         var symbolClass:Class = null;
         var result:DisplayObject = null;
         try
         {
            symbolClass = getDefinitionByName(libraryLinkageName(param1,param2)) as Class;
            if(symbolClass != null)
            {
               result = new symbolClass() as DisplayObject;
            }
         }
         catch(param3:Error)
         {
            result = null;
         }
         if(result == null)
         {
            throw new Error("INVALID|Symbol library does not export requested symbol: " + param1 + "/" + param2);
         }
         return result;
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
