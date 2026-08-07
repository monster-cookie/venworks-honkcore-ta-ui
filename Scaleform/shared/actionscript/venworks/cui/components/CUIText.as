package venworks.cui.components
{
   import flash.text.TextField;
   import flash.text.TextFormat;

   public class CUIText extends CUIComponent
   {
      private var label:TextField;

      public function CUIText(param1:XML)
      {
         super(param1);
         label = new TextField();
         label.width = componentWidth;
         label.height = componentHeight;
         label.selectable = false;
         label.mouseEnabled = false;
         label.multiline = false;
         label.wordWrap = false;
         label.embedFonts = false;
         label.defaultTextFormat = new TextFormat(
            String(param1.@font),
            this.readNumber(param1,"fontSize",18),
            this.readColor(param1,"color",16777215),
            String(param1.@bold).toLowerCase() == "true",
            false,
            false,
            null,
            null,
            String(param1.@align)
         );
         label.text = String(param1.@value);
         addChild(label);
      }
   }
}
