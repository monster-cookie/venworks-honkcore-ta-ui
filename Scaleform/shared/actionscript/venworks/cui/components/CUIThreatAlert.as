package venworks.cui.components
{
   import flash.display.Shape;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import venworks.cui.CUITextFieldHost;

   public final class CUIThreatAlert extends CUIComponent
   {
      private var background:Shape;
      private var accent:Shape;
      private var label:TextField;
      private var labelHost:CUITextFieldHost;
      private var backgroundColor:uint;
      private var clearColor:uint;
      private var cautionColor:uint;
      private var dangerColor:uint;
      private var criticalColor:uint;

      public function CUIThreatAlert(param1:XML)
      {
         super(param1);
         backgroundColor = this.readColor(param1,"backgroundColor",0x020B10);
         clearColor = this.readColor(param1,"clearColor",0x62DDF2);
         cautionColor = this.readColor(param1,"cautionColor",0xE6B840);
         dangerColor = this.readColor(param1,"dangerColor",0xFF9A3D);
         criticalColor = this.readColor(param1,"criticalColor",0xFF5A5A);
         this.createDisplay();
         this.updateData(null);
      }

      public function updateData(param1:Object) : void
      {
         var score:Number = param1 == null ? 0 : Number(param1.threatScore);
         var color:uint = clearColor;
         var state:String = "CLEAR";
         var format:TextFormat = null;
         if(isNaN(score) || !isFinite(score))
         {
            score = 0;
         }
         score = Math.max(0,Math.min(100,Math.round(score)));
         if(score >= 75)
         {
            color = criticalColor;
            state = "CRITICAL";
         }
         else if(score >= 50)
         {
            color = dangerColor;
            state = "DANGER";
         }
         else if(score >= 25)
         {
            color = cautionColor;
            state = "CAUTION";
         }
         accent.graphics.clear();
         accent.graphics.beginFill(color,0.95);
         accent.graphics.drawRect(0,componentHeight - 3,componentWidth * score / 100,3);
         accent.graphics.endFill();
         label.text = "THREAT " + int(score).toString() + "%  " + state;
         format = label.defaultTextFormat;
         format.color = color;
         label.defaultTextFormat = format;
         label.setTextFormat(format);
      }

      private function createDisplay() : void
      {
         var format:TextFormat = null;
         background = new Shape();
         background.graphics.beginFill(backgroundColor,0.76);
         background.graphics.drawRect(0,0,componentWidth,componentHeight);
         background.graphics.endFill();
         addChild(background);
         accent = new Shape();
         addChild(accent);
         labelHost = new CUITextFieldHost();
         label = labelHost.field;
         label.width = componentWidth;
         label.height = componentHeight - 2;
         label.selectable = false;
         label.mouseEnabled = false;
         format = label.defaultTextFormat;
         format.size = 10;
         format.color = clearColor;
         format.bold = true;
         format.align = "center";
         label.defaultTextFormat = format;
         addChild(labelHost);
      }
   }
}
