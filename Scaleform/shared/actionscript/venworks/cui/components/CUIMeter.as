package venworks.cui.components
{
   public class CUIMeter extends CUIComponent
   {
      protected var meterValue:Number;
      protected var meterMaximum:Number;
      protected var fillColor:uint;
      protected var emptyColor:uint;
      protected var fillOpacity:Number;
      protected var emptyOpacity:Number;

      public function CUIMeter(param1:XML, param2:XML)
      {
         super(param1);
         meterValue = this.readNumber(param1,"value",0);
         meterMaximum = this.readNumber(param1,"max",100);
         fillColor = this.readColor(param2,"fillColor",16777215);
         emptyColor = this.readColor(param2,"emptyColor",3355443);
         fillOpacity = this.readNumber(param2,"fillOpacity",1);
         emptyOpacity = this.readNumber(param2,"emptyOpacity",0.35);
      }

      protected function get fraction() : Number
      {
         if(meterMaximum <= 0)
         {
            return 0;
         }
         return Math.max(0,Math.min(1,meterValue / meterMaximum));
      }
   }
}
