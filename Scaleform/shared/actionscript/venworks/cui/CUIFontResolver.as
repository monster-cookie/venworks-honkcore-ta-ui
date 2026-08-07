package venworks.cui
{
   import flash.text.Font;
   import flash.utils.getDefinitionByName;

   public final class CUIFontResolver
   {
      private static var resolvedFontNames:Object = {};

      public static function resolve(param1:String) : String
      {
         var fontClass:Class = null;
         var font:Font = null;
         var resolvedName:String = null;
         if(resolvedFontNames[param1] != null)
         {
            return String(resolvedFontNames[param1]);
         }
         try
         {
            fontClass = getDefinitionByName(param1) as Class;
            Font.registerFont(fontClass);
            font = new fontClass() as Font;
            if(font != null && font.fontName != null && font.fontName.length > 0)
            {
               resolvedName = font.fontName;
            }
         }
         catch(param2:Error)
         {
         }
         if(resolvedName == null)
         {
            resolvedName = param1;
         }
         resolvedFontNames[param1] = resolvedName;
         return resolvedName;
      }
   }
}
