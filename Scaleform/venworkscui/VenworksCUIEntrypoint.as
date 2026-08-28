package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import venworks.cui.CUIRuntime;

   public final class VenworksCUIEntrypoint extends MovieClip
   {
      public static const SOURCE_FINGERPRINT:String = "VENWORKS_CUI_SOURCE_SHA256:________________________________________________________________";
      public static const CLASS_FINGERPRINT:String = "VENWORKS_CUI_CLASSES_SHA256:________________________________________________________________";

      private var owner:DisplayObjectContainer = null;
      private var runtime:CUIRuntime = null;

      public function VenworksCUIEntrypoint()
      {
         super();
      }

      public function initialize(param1:DisplayObjectContainer) : void
      {
         if(this.owner === param1 && this.runtime != null && !this.runtime.isDisposed)
         {
            return;
         }
         this.dispose();
         this.owner = param1;
         if(this.owner == null)
         {
            return;
         }
         this.runtime = new CUIRuntime(this.owner);
         this.runtime.load();
      }

      public function reapplyVanillaPlacements() : void
      {
         if(this.runtime != null && !this.runtime.isDisposed)
         {
            this.runtime.reapplyVanillaPlacements();
         }
      }

      public function updateVanillaHudModeVisibility(param1:Array) : void
      {
         if(this.runtime != null && !this.runtime.isDisposed)
         {
            this.runtime.updateVanillaHudModeVisibility(param1);
         }
      }

      public function dispose() : void
      {
         if(this.runtime != null)
         {
            this.runtime.dispose();
         }
         this.runtime = null;
         this.owner = null;
      }
   }
}
