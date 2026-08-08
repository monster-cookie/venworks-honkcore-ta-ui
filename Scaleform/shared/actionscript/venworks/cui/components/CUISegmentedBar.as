package venworks.cui.components
{
   public class CUISegmentedBar extends CUIMeter
   {
      public function CUISegmentedBar(param1:XML, param2:XML)
      {
         var count:int = 0;
         var gap:Number = NaN;
         var extent:Number = NaN;
         var logicalIndex:int = 0;
         var visualIndex:int = 0;
         var amount:Number = NaN;
         var segmentX:Number = NaN;
         var segmentY:Number = NaN;
         var segmentWidth:Number = NaN;
         var segmentHeight:Number = NaN;
         super(param1,param2);
         count = int(this.readNumber(param2,"segmentCount",12));
         gap = this.readNumber(param2,"gap",2);
         extent = (axisLength - gap * (count - 1)) / count;
         logicalIndex = 0;
         while(logicalIndex < count)
         {
            visualIndex = this.displayIndex(logicalIndex,count);
            segmentX = horizontal ? visualIndex * (extent + gap) : 0;
            segmentY = horizontal ? 0 : visualIndex * (extent + gap);
            segmentWidth = horizontal ? extent : componentWidth;
            segmentHeight = horizontal ? componentHeight : extent;
            graphics.beginFill(emptyColor,emptyOpacity);
            graphics.drawRect(segmentX,segmentY,segmentWidth,segmentHeight);
            graphics.endFill();
            amount = this.segmentFraction(logicalIndex,count);
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
