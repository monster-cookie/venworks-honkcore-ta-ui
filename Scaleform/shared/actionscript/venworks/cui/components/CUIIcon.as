package venworks.cui.components
{
   import venworks.cui.CUIIconLibrary;
   import venworks.cui.CUIPaletteResolver;

   public class CUIIcon extends CUIImage
   {
      public function CUIIcon(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,CUIIconLibrary.create(param2 == null ? String(param1.@name) :
            param2.resolveAttribute(param1,"name")),param2);
      }
   }
}
