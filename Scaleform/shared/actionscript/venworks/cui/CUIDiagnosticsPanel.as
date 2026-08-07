package venworks.cui
{
   import flash.display.Sprite;
   import flash.text.TextField;
   import flash.text.TextFormat;

   public final class CUIDiagnosticsPanel extends Sprite
   {
      private var titleField:TextField;
      private var detailField:TextField;

      public function CUIDiagnosticsPanel()
      {
         super();
         x = 720;
         y = 150;
         mouseEnabled = false;
         mouseChildren = false;
         graphics.lineStyle(2,16728128,1);
         graphics.beginFill(1572864,0.94);
         graphics.drawRect(0,0,620,150);
         graphics.endFill();

         titleField = this.createField(20,14,580,34,22,16728128,true);
         detailField = this.createField(20,54,580,78,17,16777215,false);
         detailField.multiline = true;
         detailField.wordWrap = true;
         addChild(titleField);
         addChild(detailField);
         visible = false;
      }

      public function showError(param1:String, param2:String) : void
      {
         titleField.text = param1;
         detailField.text = param2;
         visible = true;
      }

      public function clear() : void
      {
         titleField.text = "";
         detailField.text = "";
         visible = false;
      }

      private function createField(param1:Number, param2:Number, param3:Number, param4:Number, param5:Number, param6:uint, param7:Boolean) : TextField
      {
         var field:TextField = new TextField();
         field.x = param1;
         field.y = param2;
         field.width = param3;
         field.height = param4;
         field.selectable = false;
         field.mouseEnabled = false;
         field.embedFonts = true;
         field.defaultTextFormat = new TextFormat("$MAIN_Font_Bold",param5,param6,param7);
         return field;
      }
   }
}
