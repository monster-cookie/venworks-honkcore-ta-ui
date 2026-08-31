package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.text.TextField;
   import flash.text.TextFormat;

   public final class VenworksCUIDiagnosticEntrypoint extends MovieClip
   {
      public static const CLASS_FINGERPRINT:String = "VENWORKS_CUI_CLASSES_SHA256:________________________________________________________________";

      private var owner:DisplayObjectContainer = null;
      private var pane:TextField = null;

      public function VenworksCUIDiagnosticEntrypoint()
      {
         super();
      }

      public function initialize(param1:DisplayObjectContainer) : void
      {
         var format:TextFormat = new TextFormat("$MAIN_Font_Bold",18,16777215,true);
         if(this.owner === param1 && this.pane != null)
         {
            return;
         }
         this.dispose();
         this.owner = param1;
         if(this.owner == null)
         {
            return;
         }
         this.pane = new TextField();
         this.pane.name = "VenworksCUIDiagnosticPane";
         this.pane.x = 760;
         this.pane.y = 160;
         this.pane.width = 400;
         this.pane.height = 48;
         this.pane.background = true;
         this.pane.backgroundColor = 2631720;
         this.pane.border = true;
         this.pane.borderColor = 65535;
         this.pane.textColor = 16777215;
         this.pane.embedFonts = true;
         this.pane.defaultTextFormat = format;
         this.pane.selectable = false;
         this.pane.mouseEnabled = false;
         this.pane.text = "venworkscui.swf loaded";
         this.pane.setTextFormat(format);
         addChild(this.pane);
      }

      public function reapplyVanillaPlacements() : void
      {
      }

      public function updateVanillaHudModeVisibility(param1:Array) : void
      {
      }

      public function dispose() : void
      {
         if(this.pane != null && this.pane.parent === this)
         {
            removeChild(this.pane);
         }
         this.pane = null;
         this.owner = null;
      }
   }
}
