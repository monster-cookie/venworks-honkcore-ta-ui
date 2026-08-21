package venworks.cui.components
{
   import venworks.cui.CUIPaletteResolver;

   public class CUIDivider extends CUIComponent
   {
      public function CUIDivider(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,param2);
         graphics.lineStyle(
            this.readNumber(param1,"strokeWidth",1),
            this.readColor(param1,"color",16777215),
            this.readNumber(param1,"strokeOpacity",1)
         );
         graphics.moveTo(0,0);
         graphics.lineTo(componentWidth,componentHeight);
      }
   }
}
