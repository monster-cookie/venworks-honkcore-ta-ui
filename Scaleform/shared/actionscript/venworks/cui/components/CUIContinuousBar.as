package venworks.cui.components
{
   import venworks.cui.CUIPaletteResolver;

   public class CUIContinuousBar extends CUIMeter
   {
      public function CUIContinuousBar(param1:XML, param2:XML, param3:CUIPaletteResolver)
      {
         super(param1,param2,param3);
         this.redraw();
      }

      override protected function redraw() : void
      {
         var fillWidth:Number = NaN;
         var fillHeight:Number = NaN;
         var fillX:Number = 0;
         var fillY:Number = 0;
         this.clearMeterGraphics();
         graphics.beginFill(emptyColor,emptyOpacity);
         graphics.drawRect(0,0,componentWidth,componentHeight);
         graphics.endFill();
         fillWidth = horizontal ? componentWidth * fraction : componentWidth;
         fillHeight = horizontal ? componentHeight : componentHeight * fraction;
         if(meterDirection == "left")
         {
            fillX = componentWidth - fillWidth;
         }
         else if(meterDirection == "up")
         {
            fillY = componentHeight - fillHeight;
         }
         graphics.beginFill(fillColor,fillOpacity);
         graphics.drawRect(fillX,fillY,fillWidth,fillHeight);
         graphics.endFill();
      }
   }
}
