package venworks.cui.components
{
   import flash.display.Graphics;
   import venworks.cui.CUIPaletteResolver;

   public class CUIRadialMeter extends CUIMeter
   {
      private var startAngle:Number;
      private var sweepAngle:Number;
      private var clockwise:Boolean;
      private var thickness:Number;

      public function CUIRadialMeter(param1:XML, param2:XML, param3:CUIPaletteResolver)
      {
         super(param1,param2,param3);
         startAngle = this.readNumber(param2,"startAngle",-90);
         sweepAngle = this.readNumber(param2,"sweepAngle",360);
         clockwise = this.readBoolean(param2,"clockwise",true);
         thickness = this.readNumber(param2,"thickness",8);
         this.redraw();
      }

      override protected function redraw() : void
      {
         this.clearMeterGraphics();
         this.drawArc(graphics,startAngle,sweepAngle,clockwise,thickness,emptyColor,emptyOpacity,1);
         if(fraction > 0)
         {
            this.drawArc(graphics,startAngle,sweepAngle,clockwise,thickness,fillColor,fillOpacity,fraction);
         }
      }

      private function drawArc(param1:Graphics, param2:Number, param3:Number, param4:Boolean,
                               param5:Number, param6:uint, param7:Number, param8:Number) : void
      {
         var radius:Number = Math.min(componentWidth,componentHeight) / 2 - param5 / 2;
         var centerX:Number = componentWidth / 2;
         var centerY:Number = componentHeight / 2;
         var signedSweep:Number = param3 * param8 * (param4 ? 1 : -1);
         var steps:int = Math.max(1,Math.ceil(Math.abs(signedSweep) / 4));
         var index:int = 0;
         var angle:Number = NaN;
         param1.lineStyle(param5,param6,param7);
         angle = param2 * Math.PI / 180;
         param1.moveTo(centerX + Math.cos(angle) * radius,centerY + Math.sin(angle) * radius);
         index = 1;
         while(index <= steps)
         {
            angle = (param2 + signedSweep * index / steps) * Math.PI / 180;
            param1.lineTo(centerX + Math.cos(angle) * radius,centerY + Math.sin(angle) * radius);
            index++;
         }
      }
   }
}
