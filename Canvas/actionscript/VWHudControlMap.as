package
{
   import flash.utils.getDefinitionByName;
   // Provider-owned key names remain data; native vehicle glyphs stay host-owned.
   public final class VWHudControlMap
   {
      private var mappings:Array = [];
      private var nativeHelper:Object;

      public function OnControlMapChanged(data:Object) : void
      {
         this.mappings = data != null && data.vMappedEvents is Array ? (data.vMappedEvents as Array).slice(0,512) : [];
         try
         {
            if(this.nativeHelper == null)
            {
               var helper:Class = getDefinitionByName("Shared.Components.ButtonControls.Utils.ButtonKeyHelper") as Class;
               this.nativeHelper = new helper();
            }
            // The native helper owns controller text/chord translation, not input handling.
            this.nativeHelper.OnControlMapChanged({vMappedEvents:this.mappings,uiController:data == null ? 0 : data.uiController});
         }
         catch(error:*) { this.nativeHelper = null; }
      }

      public function GetButtonNameForEvent(name:String) : String
      {
         if(this.nativeHelper != null)
         {
            try { return String(this.nativeHelper.GetButtonNameForEvent(name)).substr(0,64); }
            catch(error:*) { }
         }
         for each(var mapping:Object in this.mappings)
            if(mapping != null && mapping.strUserEventName == name && typeof mapping.strButtonName == "string")
               return String(mapping.strButtonName).substr(0,64);
         return "";
      }
   }
}
