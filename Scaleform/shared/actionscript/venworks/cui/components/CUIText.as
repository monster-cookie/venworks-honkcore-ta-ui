package venworks.cui.components
{
   import flash.text.TextField;
   import flash.text.TextFormat;
   import venworks.cui.CUITextFieldHost;

   public class CUIText extends CUIComponent
   {
      private var label:TextField;
      private var labelHost:CUITextFieldHost;

      public function CUIText(param1:XML)
      {
         super(param1);
         labelHost = new CUITextFieldHost();
         label = labelHost.field;
         label.width = componentWidth;
         label.height = componentHeight;
         label.selectable = false;
         label.mouseEnabled = false;
         label.multiline = this.readBoolean(param1,"multiline",false);
         label.wordWrap = this.readBoolean(param1,"wordWrap",false);
         var format:TextFormat = label.defaultTextFormat;
         format.size = this.readNumber(param1,"fontSize",18);
         format.color = this.readColor(param1,"color",16777215);
         format.bold = String(param1.@bold).toLowerCase() == "true";
         format.align = String(param1.@align);
         label.defaultTextFormat = format;
         label.text = String(param1.@value);
         label.setTextFormat(format);
         addChild(labelHost);
      }

      public function setValue(param1:String) : void
      {
         label.text = param1;
         label.setTextFormat(label.defaultTextFormat);
      }
   }
}
