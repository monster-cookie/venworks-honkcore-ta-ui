package venworks.cui.components
{
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.display.Sprite;

   public class CUITriangleBar extends CUIMeter
   {
      private var segmentCount:int;
      private var segmentGap:Number;
      private var alternating:Boolean;

      public function CUITriangleBar(param1:XML, param2:XML)
      {
         super(param1,param2);
         segmentCount = int(this.readNumber(param2,"segmentCount",12));
         segmentGap = this.readNumber(param2,"gap",2);
         alternating = String(param2.@trianglePattern) == "alternating";
         this.redraw();
      }

      override protected function redraw() : void
      {
         var segmentExtent:Number = NaN;
         var visualIndex:int = 0;
         var segmentX:Number = NaN;
         var segmentY:Number = NaN;
         var index:int = 0;
         var segmentFraction:Number = NaN;
         this.clearMeterGraphics();
         segmentExtent = (axisLength - segmentGap * (segmentCount - 1)) / segmentCount;
         index = 0;
         while(index < segmentCount)
         {
            visualIndex = this.displayIndex(index,segmentCount);
            segmentX = horizontal ? visualIndex * (segmentExtent + segmentGap) : 0;
            segmentY = horizontal ? 0 : visualIndex * (segmentExtent + segmentGap);
            this.drawTriangle(graphics,segmentX,segmentY,
                              horizontal ? segmentExtent : componentWidth,
                              horizontal ? componentHeight : segmentExtent,
                              alternating && visualIndex % 2 == 0,emptyColor,emptyOpacity);
            segmentFraction = this.segmentFraction(index,segmentCount);
            if(segmentFraction > 0)
            {
               this.drawFilledSegment(segmentX,segmentY,
                                      horizontal ? segmentExtent : componentWidth,
                                      horizontal ? componentHeight : segmentExtent,
                                      alternating && visualIndex % 2 == 0,segmentFraction);
            }
            index++;
         }
      }

      private function drawFilledSegment(param1:Number, param2:Number, param3:Number,
                                         param4:Number, param5:Boolean, param6:Number) : void
      {
         var fill:Sprite = new Sprite();
         var clippingMask:Shape = new Shape();
         this.drawTriangle(fill.graphics,param1,param2,param3,param4,param5,fillColor,fillOpacity);
         this.drawDirectionalMask(clippingMask,param1,param2,param3,param4,param6);
         addChild(fill);
         addChild(clippingMask);
         fill.mask = clippingMask;
      }

      private function drawTriangle(param1:Graphics, param2:Number, param3:Number,
                                    param4:Number, param5:Number, param6:Boolean,
                                    param7:uint, param8:Number) : void
      {
         param1.beginFill(param7,param8);
         if(horizontal && param6)
         {
            param1.moveTo(param2 + param4 / 2,param3);
            param1.lineTo(param2 + param4,param3 + param5);
            param1.lineTo(param2,param3 + param5);
         }
         else if(horizontal)
         {
            param1.moveTo(param2,param3);
            param1.lineTo(param2 + param4,param3);
            param1.lineTo(param2 + param4 / 2,param3 + param5);
         }
         else if(param6)
         {
            param1.moveTo(param2,param3 + param5 / 2);
            param1.lineTo(param2 + param4,param3);
            param1.lineTo(param2 + param4,param3 + param5);
         }
         else
         {
            param1.moveTo(param2,param3);
            param1.lineTo(param2 + param4,param3 + param5 / 2);
            param1.lineTo(param2,param3 + param5);
         }
         param1.endFill();
      }
   }
}
