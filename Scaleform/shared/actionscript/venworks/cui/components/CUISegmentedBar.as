package venworks.cui.components
{
   import venworks.cui.CUIPaletteResolver;

   public class CUISegmentedBar extends CUIMeter
   {
      private var segmentCount:int;
      private var segmentGap:Number;

      public function CUISegmentedBar(param1:XML, param2:XML, param3:CUIPaletteResolver)
      {
         super(param1,param2,param3);
         segmentCount = int(this.readNumber(param2,"segmentCount",12));
         segmentGap = this.readNumber(param2,"gap",2);
         this.redraw();
      }

      override protected function redraw() : void
      {
         var extent:Number = NaN;
         var logicalIndex:int = 0;
         var visualIndex:int = 0;
         var amount:Number = NaN;
         var segmentX:Number = NaN;
         var segmentY:Number = NaN;
         var segmentWidth:Number = NaN;
         var segmentHeight:Number = NaN;
         this.clearMeterGraphics();
         extent = (axisLength - segmentGap * (segmentCount - 1)) / segmentCount;
         logicalIndex = 0;
         while(logicalIndex < segmentCount)
         {
            visualIndex = this.displayIndex(logicalIndex,segmentCount);
            segmentX = horizontal ? visualIndex * (extent + segmentGap) : 0;
            segmentY = horizontal ? 0 : visualIndex * (extent + segmentGap);
            segmentWidth = horizontal ? extent : componentWidth;
            segmentHeight = horizontal ? componentHeight : extent;
            graphics.beginFill(emptyColor,emptyOpacity);
            graphics.drawRect(segmentX,segmentY,segmentWidth,segmentHeight);
            graphics.endFill();
            amount = this.segmentFraction(logicalIndex,segmentCount);
            if(amount > 0)
            {
               graphics.beginFill(fillColor,fillOpacity);
               if(meterDirection == "left")
               {
                  graphics.drawRect(segmentX + segmentWidth * (1 - amount),segmentY,
                                    segmentWidth * amount,segmentHeight);
               }
               else if(meterDirection == "down")
               {
                  graphics.drawRect(segmentX,segmentY,segmentWidth,segmentHeight * amount);
               }
               else if(meterDirection == "up")
               {
                  graphics.drawRect(segmentX,segmentY + segmentHeight * (1 - amount),
                                    segmentWidth,segmentHeight * amount);
               }
               else
               {
                  graphics.drawRect(segmentX,segmentY,segmentWidth * amount,segmentHeight);
               }
               graphics.endFill();
            }
            logicalIndex++;
         }
      }
   }
}
