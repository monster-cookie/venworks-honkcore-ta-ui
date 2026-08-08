package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.utils.getDefinitionByName;

   public class CUISymbol extends CUIImage
   {
      private static const SYMBOLS:Object = {
         "skill-tech":"Skill_Tech"
      };

      public function CUISymbol(param1:XML)
      {
         super(param1,createSymbol(String(param1.@name)));
      }

      public static function isAllowlisted(param1:String) : Boolean
      {
         return SYMBOLS[param1] != null;
      }

      private static function createSymbol(param1:String) : DisplayObject
      {
         var symbolClass:Class = null;
         var result:DisplayObject = null;
         if(!isAllowlisted(param1))
         {
            throw new Error("INVALID|Embedded symbol is not allowlisted: " + param1);
         }
         try
         {
            symbolClass = getDefinitionByName(String(SYMBOLS[param1])) as Class;
            result = new symbolClass() as DisplayObject;
         }
         catch(param2:Error)
         {
            throw new Error("INVALID|Embedded symbol is unavailable in this HUD movie: " + param1);
         }
         if(result == null)
         {
            throw new Error("INVALID|Embedded symbol is not displayable: " + param1);
         }
         return result;
      }
   }
}
