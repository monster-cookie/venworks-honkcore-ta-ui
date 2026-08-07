package venworks.cui.components
{
   public class CUIContinuousBar extends CUIMeter
   {
      public function CUIContinuousBar(param1:XML, param2:XML)
      {
         super(param1,param2);
         graphics.beginFill(emptyColor,emptyOpacity);
         graphics.drawRect(0,0,componentWidth,componentHeight);
         graphics.endFill();
         graphics.beginFill(fillColor,fillOpacity);
         graphics.drawRect(0,0,componentWidth * fraction,componentHeight);
         graphics.endFill();
      }
   }
}
