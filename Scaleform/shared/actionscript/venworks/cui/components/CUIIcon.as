package venworks.cui.components
{
   import venworks.cui.CUIIconLibrary;

   public class CUIIcon extends CUIImage
   {
      public function CUIIcon(param1:XML)
      {
         super(param1,CUIIconLibrary.create(String(param1.@name)));
      }
   }
}
