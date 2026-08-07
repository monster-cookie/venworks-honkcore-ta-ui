package venworks.cui.components
{
   import flash.display.Sprite;

   public class CUIComponent extends Sprite
   {
      protected var componentWidth:Number = 0;
      protected var componentHeight:Number = 0;

      public function CUIComponent(param1:XML)
      {
         super();
         this.configureBase(param1);
      }

      protected function configureBase(param1:XML) : void
      {
         if(param1.@id.length() == 1)
         {
            name = String(param1.@id);
         }
         x = this.readNumber(param1,"x",0);
         y = this.readNumber(param1,"y",0);
         componentWidth = this.readNumber(param1,"width",0);
         componentHeight = this.readNumber(param1,"height",0);
         alpha = this.readNumber(param1,"opacity",1);
         visible = this.readBoolean(param1,"visible",true);
         rotation = this.readNumber(param1,"rotation",0);
         scaleX = this.readNumber(param1,"scaleX",1);
         scaleY = this.readNumber(param1,"scaleY",1);
      }

      protected function readNumber(param1:XML, param2:String, param3:Number) : Number
      {
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         return Number(param1.attribute(param2));
      }

      protected function readBoolean(param1:XML, param2:String, param3:Boolean) : Boolean
      {
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         return String(param1.attribute(param2)).toLowerCase() == "true";
      }

      protected function readColor(param1:XML, param2:String, param3:uint) : uint
      {
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         return uint(parseInt(String(param1.attribute(param2)).replace("#",""),16));
      }
   }
}
