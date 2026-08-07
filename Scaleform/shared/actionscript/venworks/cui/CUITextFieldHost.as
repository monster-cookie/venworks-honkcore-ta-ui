package venworks.cui
{
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.text.TextField;
   import flash.utils.getDefinitionByName;

   public final class CUITextFieldHost extends Sprite
   {
      private var fieldValue:TextField;

      public function CUITextFieldHost()
      {
         var symbolClass:Class = null;
         var symbol:DisplayObjectContainer = null;
         super();
         symbolClass = getDefinitionByName("PromptMessageWidget") as Class;
         symbol = new symbolClass() as DisplayObjectContainer;
         if(symbol == null)
         {
            throw new Error("CUI TEXT TEMPLATE UNAVAILABLE");
         }
         addChild(symbol);
         fieldValue = symbol.getChildByName("textField") as TextField;
         if(fieldValue == null)
         {
            throw new Error("CUI TEXT FIELD UNAVAILABLE");
         }
         symbol.x = 0;
         symbol.y = 0;
         symbol.scaleX = 1;
         symbol.scaleY = 1;
         fieldValue.x = 0;
         fieldValue.y = 0;
         fieldValue.scaleX = 1;
         fieldValue.scaleY = 1;
         fieldValue.filters = [];
         fieldValue.selectable = false;
         fieldValue.mouseEnabled = false;
      }

      public function get field() : TextField
      {
         return fieldValue;
      }
   }
}
