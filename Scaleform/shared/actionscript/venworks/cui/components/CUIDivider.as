package venworks.cui.components
{
   public class CUIDivider extends CUIComponent
   {
      public function CUIDivider(param1:XML)
      {
         super(param1);
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
