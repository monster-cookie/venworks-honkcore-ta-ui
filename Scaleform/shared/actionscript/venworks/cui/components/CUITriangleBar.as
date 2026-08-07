package venworks.cui.components
{
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.display.Sprite;

   public class CUITriangleBar extends CUIMeter
   {
      public function CUITriangleBar(param1:XML, param2:XML)
      {
         var segmentCount:int = 0;
         var gap:Number = NaN;
         var segmentWidth:Number = NaN;
         var filled:Number = NaN;
         var index:int = 0;
         var segmentFraction:Number = NaN;
         super(param1,param2);
         segmentCount = int(this.readNumber(param2,"segmentCount",12));
         gap = this.readNumber(param2,"gap",2);
         segmentWidth = (componentWidth - gap * (segmentCount - 1)) / segmentCount;
         filled = fraction * segmentCount;
         index = 0;
         while(index < segmentCount)
         {
            this.drawTriangle(graphics,index * (segmentWidth + gap),segmentWidth,emptyColor,emptyOpacity);
            segmentFraction = Math.max(0,Math.min(1,filled - index));
            if(segmentFraction > 0)
            {
               this.drawFilledSegment(index * (segmentWidth + gap),segmentWidth,segmentFraction);
            }
            index++;
         }
      }

      private function drawFilledSegment(param1:Number, param2:Number, param3:Number) : void
      {
         var fill:Sprite = new Sprite();
         var clippingMask:Shape = new Shape();
         this.drawTriangle(fill.graphics,0,param2,fillColor,fillOpacity);
         clippingMask.graphics.beginFill(16777215,1);
         clippingMask.graphics.drawRect(0,0,param2 * param3,componentHeight);
         clippingMask.graphics.endFill();
         fill.x = param1;
         clippingMask.x = param1;
         addChild(fill);
         addChild(clippingMask);
         fill.mask = clippingMask;
      }

      private function drawTriangle(param1:Graphics, param2:Number, param3:Number, param4:uint, param5:Number) : void
      {
         param1.beginFill(param4,param5);
         param1.moveTo(param2,0);
         param1.lineTo(param2 + param3,0);
         param1.lineTo(param2 + param3 / 2,componentHeight);
         param1.lineTo(param2,0);
         param1.endFill();
      }
   }
}
