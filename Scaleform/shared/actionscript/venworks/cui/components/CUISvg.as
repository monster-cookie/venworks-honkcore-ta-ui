package venworks.cui.components
{
   import flash.display.DisplayObject;
   import venworks.cui.CUIPaletteResolver;
   import venworks.cui.CUISvgParser;

   public class CUISvg extends CUIImage
   {
      public function CUISvg(param1:XML, param2:XML, param3:CUIPaletteResolver)
      {
         super(param1,CUISvgParser.render(param2) as DisplayObject,param3);
      }
   }
}
