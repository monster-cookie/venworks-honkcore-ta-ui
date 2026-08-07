package venworks.cui.components
{
   public class CUIPanel extends CUIComponent
   {
      public function CUIPanel(param1:XML)
      {
         super(param1);
         graphics.lineStyle(
            this.readNumber(param1,"strokeWidth",1),
            this.readColor(param1,"strokeColor",16777215),
            this.readNumber(param1,"strokeOpacity",1)
         );
         graphics.beginFill(
            this.readColor(param1,"fillColor",0),
            this.readNumber(param1,"fillOpacity",0.75)
         );
         graphics.drawRect(0,0,componentWidth,componentHeight);
         graphics.endFill();
      }
   }
}
