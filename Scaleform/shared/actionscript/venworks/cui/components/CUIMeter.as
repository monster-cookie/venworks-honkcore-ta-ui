package venworks.cui.components
{
   import flash.display.Shape;

   public class CUIMeter extends CUIComponent
   {
      protected var meterValue:Number;
      protected var meterMaximum:Number;
      protected var fillColor:uint;
      protected var emptyColor:uint;
      protected var fillOpacity:Number;
      protected var emptyOpacity:Number;
      protected var meterDirection:String;
      protected var partialSegments:Boolean;

      public function CUIMeter(param1:XML, param2:XML)
      {
         super(param1);
         meterValue = this.readNumber(param1,"value",0);
         meterMaximum = this.readNumber(param1,"max",100);
         fillColor = this.readColor(param2,"fillColor",16777215);
         emptyColor = this.readColor(param2,"emptyColor",3355443);
         fillOpacity = this.readNumber(param2,"fillOpacity",1);
         emptyOpacity = this.readNumber(param2,"emptyOpacity",0.35);
         meterDirection = param2.@direction.length() == 1 ? String(param2.@direction) : "right";
         partialSegments = this.readBoolean(param2,"partialSegments",true);
      }

      public function setValue(param1:Number, param2:Number) : void
      {
         meterValue = !isNaN(param1) && isFinite(param1) ? param1 : 0;
         meterMaximum = !isNaN(param2) && isFinite(param2) && param2 > 0 ? param2 : 1;
         this.redraw();
      }

      protected function redraw() : void
      {
         throw new Error("Meter renderer must implement redraw.");
      }

      protected function clearMeterGraphics() : void
      {
         graphics.clear();
         while(numChildren > 0)
         {
            removeChildAt(numChildren - 1);
         }
      }

      protected function get fraction() : Number
      {
         if(meterMaximum <= 0)
         {
            return 0;
         }
         return Math.max(0,Math.min(1,meterValue / meterMaximum));
      }

      protected function get horizontal() : Boolean
      {
         return meterDirection == "right" || meterDirection == "left";
      }

      protected function get reverse() : Boolean
      {
         return meterDirection == "left" || meterDirection == "up";
      }

      protected function get axisLength() : Number
      {
         return horizontal ? componentWidth : componentHeight;
      }

      protected function get crossLength() : Number
      {
         return horizontal ? componentHeight : componentWidth;
      }

      protected function displayIndex(param1:int, param2:int) : int
      {
         return reverse ? param2 - param1 - 1 : param1;
      }

      protected function segmentFraction(param1:int, param2:int) : Number
      {
         var result:Number = Math.max(0,Math.min(1,fraction * param2 - param1));
         if(!partialSegments && result < 1)
         {
            return 0;
         }
         return result;
      }

      protected function drawDirectionalMask(param1:Shape, param2:Number, param3:Number,
                                               param4:Number, param5:Number, param6:Number) : void
      {
         param1.graphics.beginFill(16777215,1);
         if(meterDirection == "left")
         {
            param1.graphics.drawRect(param2 + param4 * (1 - param6),param3,param4 * param6,param5);
         }
         else if(meterDirection == "down")
         {
            param1.graphics.drawRect(param2,param3,param4,param5 * param6);
         }
         else if(meterDirection == "up")
         {
            param1.graphics.drawRect(param2,param3 + param5 * (1 - param6),param4,param5 * param6);
         }
         else
         {
            param1.graphics.drawRect(param2,param3,param4 * param6,param5);
         }
         param1.graphics.endFill();
      }
   }
}
