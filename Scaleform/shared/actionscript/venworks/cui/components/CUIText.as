package venworks.cui.components
{
   import flash.text.TextField;
   import flash.text.TextFormat;
   import venworks.cui.CUIPaletteResolver;
   import venworks.cui.CUITextFieldHost;

   public class CUIText extends CUIComponent
   {
      private var label:TextField;
      private var labelHost:CUITextFieldHost;

      public function CUIText(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,param2);
         labelHost = new CUITextFieldHost();
         label = labelHost.field;
         label.width = componentWidth;
         label.height = componentHeight;
         label.selectable = false;
         label.mouseEnabled = false;
         label.multiline = this.readBoolean(param1,"multiline",false);
         label.wordWrap = this.readBoolean(param1,"wordWrap",false);
         var format:TextFormat = label.defaultTextFormat;
         format.font = this.readString(param1,"font",format.font);
         format.size = this.readNumber(param1,"fontSize",18);
         format.color = this.readColor(param1,"color",16777215);
         format.bold = this.readBoolean(param1,"bold",false);
         format.align = this.readString(param1,"align","left");
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
