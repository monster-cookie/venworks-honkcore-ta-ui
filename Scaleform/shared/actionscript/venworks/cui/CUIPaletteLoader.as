package venworks.cui
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;

   public final class CUIPaletteLoader extends EventDispatcher
   {
      private static const PALETTE_ROOT:String = "VenworksCUI/palettes/";
      private static const MAX_PALETTE_BYTES:int = 65536;

      private var sourceLayout:XML;
      private var paletteLoader:URLLoader;
      private var resolvedLayout:XML;
      private var failureTitle:String = "CUI PALETTE LOAD ERROR";
      private var failureMessage:String = "Starfield could not load the CUI palette.";
      private var cancelled:Boolean = false;

      public function CUIPaletteLoader()
      {
         super();
      }

      public function get layout() : XML
      {
         return resolvedLayout;
      }

      public function get errorTitle() : String
      {
         return failureTitle;
      }

      public function get errorMessage() : String
      {
         return failureMessage;
      }

      public function load(param1:XML) : void
      {
         var palette:String = null;
         if(cancelled || sourceLayout != null)
         {
            return;
         }
         sourceLayout = param1;
         if(param1.@palette.length() == 0)
         {
            resolvedLayout = param1.copy();
            dispatchEvent(new Event(Event.COMPLETE));
            return;
         }
         if(param1.@palette.length() != 1)
         {
            this.fail("CUI PALETTE INVALID","The layout must select at most one palette.");
            return;
         }
         palette = String(param1.@palette);
         if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,59}\.xml$/.test(palette) || palette.indexOf("..") >= 0 ||
            palette.indexOf("/") >= 0 || palette.indexOf("\\") >= 0 || palette.indexOf(":") >= 0 ||
            palette.indexOf("?") >= 0 || palette.indexOf("#") >= 0)
         {
            this.fail("CUI PALETTE SECURITY ERROR","Palette paths must name one XML file under VenworksCUI/palettes: " + palette);
            return;
         }
         paletteLoader = new URLLoader();
         paletteLoader.addEventListener(Event.COMPLETE,this.onLoaded);
         paletteLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onMissing);
         paletteLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         try
         {
            paletteLoader.load(new URLRequest(PALETTE_ROOT + palette));
         }
         catch(param2:Error)
         {
            this.fail("CUI PALETTE LOAD ERROR","Starfield could not start the palette request: " + palette);
         }
      }

      private function onLoaded(param1:Event) : void
      {
         var source:String = String(paletteLoader.data);
         var palette:XML = null;
         var resolver:CUIPaletteResolver = null;
         var message:String = null;
         if(cancelled)
         {
            return;
         }
         this.clearListeners();
         if(source.length > MAX_PALETTE_BYTES)
         {
            this.fail("CUI PALETTE INVALID","Palette file exceeds the 65536-character limit.");
            return;
         }
         try
         {
            palette = new XML(source);
         }
         catch(param2:Error)
         {
            this.fail("CUI PALETTE MALFORMED","The selected palette is not well-formed XML.");
            return;
         }
         try
         {
            resolver = new CUIPaletteResolver(palette);
            resolvedLayout = sourceLayout.copy();
            resolvedLayout.insertChildBefore(resolvedLayout.children()[0],palette.copy());
            delete resolvedLayout.@palette;
         }
         catch(param3:Error)
         {
            message = param3.message;
            if(message.indexOf("UNSUPPORTED|") == 0)
            {
               this.fail("CUI PALETTE UNSUPPORTED",message.substring(12));
            }
            else if(message.indexOf("SECURITY|") == 0)
            {
               this.fail("CUI PALETTE SECURITY ERROR",message.substring(9));
            }
            else
            {
               this.fail("CUI PALETTE INVALID",message.indexOf("INVALID|") == 0 ? message.substring(8) : message);
            }
            return;
         }
         dispatchEvent(new Event(Event.COMPLETE));
      }

      private function onMissing(param1:IOErrorEvent) : void
      {
         this.fail("CUI PALETTE MISSING","Expected Interface/" + PALETTE_ROOT + String(sourceLayout.@palette) + ".");
      }

      private function onSecurityError(param1:SecurityErrorEvent) : void
      {
         this.fail("CUI PALETTE SECURITY ERROR","Scaleform denied access to palette " + String(sourceLayout.@palette) + ".");
      }

      private function fail(param1:String, param2:String) : void
      {
         if(cancelled)
         {
            return;
         }
         failureTitle = param1;
         failureMessage = param2;
         this.clearListeners();
         dispatchEvent(new Event(Event.CANCEL));
      }

      public function cancel() : void
      {
         if(cancelled)
         {
            return;
         }
         cancelled = true;
         this.clearListeners();
         if(paletteLoader != null)
         {
            try
            {
               paletteLoader.close();
            }
            catch(param1:Error)
            {
            }
         }
      }

      private function clearListeners() : void
      {
         if(paletteLoader != null)
         {
            paletteLoader.removeEventListener(Event.COMPLETE,this.onLoaded);
            paletteLoader.removeEventListener(IOErrorEvent.IO_ERROR,this.onMissing);
            paletteLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         }
      }
   }
}
