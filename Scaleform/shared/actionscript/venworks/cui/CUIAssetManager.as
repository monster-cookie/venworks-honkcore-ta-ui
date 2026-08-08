package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;

   public final class CUIAssetManager extends EventDispatcher
   {
      private static const ASSET_ROOT:String = "VenworksCUI/Assets/";
      private static const IMAGE_ASSET_ROOT:String = "img://VenworksCUI/Assets/";

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

      public function getImage(param1:String) : DisplayObject
      {
         var record:Object = assets[param1];
         if(record == null || record.kind != "image")
         {
            throw new Error("INVALID|Loaded PNG asset is unavailable: " + param1);
         }
         return record.loader as DisplayObject;
      }

      public function getSvg(param1:String) : XML
      {
         var record:Object = assets[param1];
         if(record == null || record.kind != "svg" || record.xml == null)
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
         var type:String = null;
         for each(node in param1.children())
         {
            type = String(node.name());
            if(type == "image")
            {
               this.loadImage(node);
            }
            else if(type == "svg")
            {
               this.loadSvg(node);
            }
            if(node.children().length() != 0)
            {
               this.collect(node);
            }
         }
      }

      private function loadImage(param1:XML) : void
      {
         var loader:Loader = new Loader();
         var record:Object = {
            id:String(param1.@id),
            src:String(param1.@src),
            kind:"image",
            loader:loader,
            info:loader.contentLoaderInfo
         };
         records.push(record);
         assets[record.id] = record;
         ++pending;
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE,this.onImageLoaded);
         loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
         loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
         try
         {
            loader.load(new URLRequest(IMAGE_ASSET_ROOT + record.src));
         }
         catch(param2:Error)
         {
            this.fail("Could not start PNG asset request: " + record.src);
         }
      }

      private function loadSvg(param1:XML) : void
      {
         var loader:URLLoader = new URLLoader();
         var record:Object = {
            id:String(param1.@id),
            src:String(param1.@src),
            kind:"svg",
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
            loader.load(new URLRequest(ASSET_ROOT + record.src));
         }
         catch(param2:Error)
         {
            this.fail("Could not start SVG asset request: " + record.src);
         }
      }

      private function onImageLoaded(param1:Event) : void
      {
         var record:Object = this.findByLoaderInfo(param1.currentTarget as LoaderInfo);
         if(record == null)
         {
            this.fail("PNG loader completed without a matching component.");
            return;
         }
         this.clearRecordListeners(record);
         this.completeOne();
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
            this.fail("SVG asset is invalid: " + record.src + ". " + this.cleanMessage(param2.message));
            return;
         }
         this.completeOne();
      }

      private function onAssetMissing(param1:IOErrorEvent) : void
      {
         var record:Object = this.findEventRecord(param1.currentTarget);
         var detail:String = param1.text == null ? "" : String(param1.text);
         this.fail("Asset is missing or unreadable: " + (record == null ? "unknown" : record.src) + (detail.length == 0 ? "" : ". " + detail));
      }

      private function onAssetSecurityError(param1:SecurityErrorEvent) : void
      {
         var record:Object = this.findEventRecord(param1.currentTarget);
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

      private function findEventRecord(param1:Object) : Object
      {
         if(param1 is LoaderInfo)
         {
            return this.findByLoaderInfo(param1 as LoaderInfo);
         }
         return this.findByLoader(param1);
      }

      private function findByLoaderInfo(param1:LoaderInfo) : Object
      {
         var record:Object = null;
         for each(record in records)
         {
            if(record.info === param1)
            {
               return record;
            }
         }
         return null;
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
         if(param1.kind == "image")
         {
            LoaderInfo(param1.info).removeEventListener(Event.COMPLETE,this.onImageLoaded);
            LoaderInfo(param1.info).removeEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
            LoaderInfo(param1.info).removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
         }
         else
         {
            URLLoader(param1.loader).removeEventListener(Event.COMPLETE,this.onSvgLoaded);
            URLLoader(param1.loader).removeEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
            URLLoader(param1.loader).removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
         }
      }

      private function cleanMessage(param1:String) : String
      {
         var separator:int = param1.indexOf("|");
         return separator >= 0 ? param1.substring(separator + 1) : param1;
      }
   }
}
