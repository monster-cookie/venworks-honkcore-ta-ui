package venworks.cui.components
{
   import flash.display.Sprite;
   import venworks.cui.CUIPaletteResolver;

   public class CUIComponent extends Sprite
   {
      protected var componentWidth:Number = 0;
      protected var componentHeight:Number = 0;
      protected var paletteResolver:CUIPaletteResolver;

      public function CUIComponent(param1:XML, param2:CUIPaletteResolver)
      {
         super();
         paletteResolver = param2;
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
         return Number(this.readString(param1,param2,""));
      }

      protected function readBoolean(param1:XML, param2:String, param3:Boolean) : Boolean
      {
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         return this.readString(param1,param2,"").toLowerCase() == "true";
      }

      protected function readColor(param1:XML, param2:String, param3:uint) : uint
      {
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         return uint(parseInt(this.readString(param1,param2,"").replace("#",""),16));
      }

      protected function readString(param1:XML, param2:String, param3:String) : String
      {
         var value:String = null;
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         value = String(param1.attribute(param2));
         if(paletteResolver != null && value.indexOf("@palette.") == 0)
         {
            return paletteResolver.resolveAttribute(param1,param2);
         }
         return value;
      }
   }
}
