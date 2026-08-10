package venworks.cui
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;

   public final class CUIAssetManager extends EventDispatcher
   {
      private static const SVG_ASSET_ROOT:String = "VenworksCUI/Assets/";

      private var records:Array;
      private var assets:Object;
      private var pending:int;
      private var failed:Boolean;
      private var failureMessage:String;

      public function CUIAssetManager()
      {
         super();
         records = [];
         assets = {};
      }

      public function load(param1:XML) : void
      {
         this.collect(param1);
         if(pending == 0)
         {
            dispatchEvent(new Event(Event.COMPLETE));
         }
      }

      public function getSvg(param1:String) : XML
      {
         var record:Object = assets[param1];
         if(record == null || record.xml == null)
         {
            throw new Error("INVALID|Loaded SVG asset is unavailable: " + param1);
         }
         return record.xml as XML;
      }

      public function get errorMessage() : String
      {
         return failureMessage;
      }

      private function collect(param1:XML) : void
      {
         var node:XML = null;
         for each(node in param1.children())
         {
            if(String(node.name()) == "svg")
            {
               this.loadSvg(node);
            }
            if(node.children().length() != 0)
            {
               this.collect(node);
            }
         }
      }

      private function loadSvg(param1:XML) : void
      {
         var loader:URLLoader = new URLLoader();
         var record:Object = {
            id:String(param1.@id),
            src:String(param1.@src),
            loader:loader,
            xml:null
         };
         records.push(record);
         assets[record.id] = record;
         ++pending;
         loader.addEventListener(Event.COMPLETE,this.onSvgLoaded);
         loader.addEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
         loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
         try
         {
            loader.load(new URLRequest(SVG_ASSET_ROOT + record.src));
         }
         catch(param2:Error)
         {
            this.fail("Could not start SVG asset request: " + record.src);
         }
      }

      private function onSvgLoaded(param1:Event) : void
      {
         var record:Object = this.findByLoader(param1.currentTarget);
         var config:XML = null;
         if(record == null)
         {
            this.fail("SVG loader completed without a matching component.");
            return;
         }
         this.clearRecordListeners(record);
         try
         {
            config = new XML(URLLoader(record.loader).data);
            CUISvgParser.validate(config);
            record.xml = config;
         }
         catch(param2:Error)
         {
            this.fail("SVG asset is invalid: " + record.src + " (component " + record.id + "). " + this.cleanMessage(param2.toString()));
            return;
         }
         this.completeOne();
      }

      private function onAssetMissing(param1:IOErrorEvent) : void
      {
         var record:Object = this.findByLoader(param1.currentTarget);
         var detail:String = param1.text == null ? "" : String(param1.text);
         this.fail("Asset is missing or unreadable: " + (record == null ? "unknown" : record.src) +
            (detail.length == 0 ? "" : ". " + detail));
      }

      private function onAssetSecurityError(param1:SecurityErrorEvent) : void
      {
         var record:Object = this.findByLoader(param1.currentTarget);
         this.fail("Scaleform denied access to asset: " + (record == null ? "unknown" : record.src));
      }

      private function completeOne() : void
      {
         if(failed)
         {
            return;
         }
         --pending;
         if(pending == 0)
         {
            dispatchEvent(new Event(Event.COMPLETE));
         }
      }

      private function fail(param1:String) : void
      {
         if(failed)
         {
            return;
         }
         failed = true;
         failureMessage = param1;
         this.clearAllListeners();
         dispatchEvent(new Event(Event.CANCEL));
      }

      private function findByLoader(param1:Object) : Object
      {
         var record:Object = null;
         for each(record in records)
         {
            if(record.loader === param1)
            {
               return record;
            }
         }
         return null;
      }

      private function clearAllListeners() : void
      {
         var record:Object = null;
         for each(record in records)
         {
            this.clearRecordListeners(record);
         }
      }

      private function clearRecordListeners(param1:Object) : void
      {
         URLLoader(param1.loader).removeEventListener(Event.COMPLETE,this.onSvgLoaded);
         URLLoader(param1.loader).removeEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
         URLLoader(param1.loader).removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
      }

      private function cleanMessage(param1:String) : String
      {
         var separator:int = param1.indexOf("|");
         return separator >= 0 ? param1.substring(separator + 1) : param1;
      }
   }
}
