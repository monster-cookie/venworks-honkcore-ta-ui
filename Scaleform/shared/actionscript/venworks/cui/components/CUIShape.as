package venworks.cui.components
{
   public class CUIShape extends CUIComponent
   {
      public function CUIShape(param1:XML)
      {
         super(param1);
         graphics.lineStyle(
            this.readNumber(param1,"strokeWidth",0),
            this.readColor(param1,"strokeColor",16777215),
            this.readNumber(param1,"strokeOpacity",1)
         );
         graphics.beginFill(
            this.readColor(param1,"fillColor",16777215),
            this.readNumber(param1,"fillOpacity",1)
         );
         if(String(param1.@shape) == "ellipse")
         {
            graphics.drawEllipse(0,0,componentWidth,componentHeight);
         }
         else
         {
            graphics.drawRect(0,0,componentWidth,componentHeight);
         }
         graphics.endFill();
      }
   }
}
