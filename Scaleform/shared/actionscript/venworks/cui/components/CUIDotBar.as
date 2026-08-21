package venworks.cui.components
{
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.display.Graphics;
   import venworks.cui.CUIPaletteResolver;

   public class CUIDotBar extends CUIMeter
   {
      private var segmentCount:int;
      private var segmentGap:Number;

      public function CUIDotBar(param1:XML, param2:XML, param3:CUIPaletteResolver)
      {
         super(param1,param2,param3);
         segmentCount = int(this.readNumber(param2,"segmentCount",12));
         segmentGap = this.readNumber(param2,"gap",2);
         this.redraw();
      }

      override protected function redraw() : void
      {
         var extent:Number = NaN;
         var diameter:Number = NaN;
         var logicalIndex:int = 0;
         var visualIndex:int = 0;
         var amount:Number = NaN;
         var dotX:Number = NaN;
         var dotY:Number = NaN;
         this.clearMeterGraphics();
         extent = (axisLength - segmentGap * (segmentCount - 1)) / segmentCount;
         diameter = Math.min(extent,crossLength);
         logicalIndex = 0;
         while(logicalIndex < segmentCount)
         {
            visualIndex = this.displayIndex(logicalIndex,segmentCount);
            dotX = horizontal ? visualIndex * (extent + segmentGap) + (extent - diameter) / 2 :
                                (componentWidth - diameter) / 2;
            dotY = horizontal ? (componentHeight - diameter) / 2 :
                                visualIndex * (extent + segmentGap) + (extent - diameter) / 2;
            this.drawDot(graphics,dotX,dotY,diameter,emptyColor,emptyOpacity);
            amount = this.segmentFraction(logicalIndex,segmentCount);
            if(amount > 0)
            {
               this.drawFilledDot(dotX,dotY,diameter,amount);
            }
            logicalIndex++;
         }
      }

      private function drawFilledDot(param1:Number, param2:Number, param3:Number, param4:Number) : void
      {
         var fill:Sprite = new Sprite();
         var clippingMask:Shape = new Shape();
         this.drawDot(fill.graphics,param1,param2,param3,fillColor,fillOpacity);
         this.drawDirectionalMask(clippingMask,param1,param2,param3,param3,param4);
         addChild(fill);
         addChild(clippingMask);
         fill.mask = clippingMask;
      }

      private function drawDot(param1:Graphics, param2:Number, param3:Number, param4:Number,
                               param5:uint, param6:Number) : void
      {
         param1.beginFill(param5,param6);
         param1.drawEllipse(param2,param3,param4,param4);
         param1.endFill();
      }
   }
}
