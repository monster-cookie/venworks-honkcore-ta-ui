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
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import venworks.cui.components.CUISymbol;

   public final class CUIAssetManager extends EventDispatcher
   {
      private static const SVG_ASSET_ROOT:String = "VenworksCUI/Assets/";
      private static const SYMBOL_LIBRARY_ROOT:String = "VenworksCUI/Libraries/";

      private var records:Array;
      private var assets:Object;
      private var libraries:Object;
      private var pending:int;
      private var failed:Boolean;
      private var failureMessage:String;

      public function CUIAssetManager()
      {
         super();
         records = [];
         assets = {};
         libraries = {};
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

      public function createLibrarySymbol(param1:String, param2:String) : DisplayObject
      {
         var record:Object = libraries[param1];
         var linkage:String = CUISymbol.libraryLinkageName(param1,param2);
         var domain:ApplicationDomain = null;
         var symbolClass:Class = null;
         var result:DisplayObject = null;
         if(record == null || record.domain == null)
         {
            throw new Error("INVALID|Symbol library is not loaded: " + param1);
         }
         domain = record.domain as ApplicationDomain;
         if(domain == null || !domain.hasDefinition(linkage))
         {
            throw new Error("INVALID|Symbol library does not export requested symbol: " + param1 + "/" + param2);
         }
         try
         {
            symbolClass = domain.getDefinition(linkage) as Class;
            if(symbolClass != null)
            {
               result = new symbolClass() as DisplayObject;
            }
         }
         catch(param3:Error)
         {
            throw new Error("INVALID|Could not create symbol " + param1 + "/" + param2 + ". " + param3.toString());
         }
         if(result == null)
         {
            throw new Error("INVALID|Symbol export is not a display object: " + param1 + "/" + param2);
         }
         return result;
      }

      private function collect(param1:XML) : void
      {
         var node:XML = null;
         var type:String = null;
         for each(node in param1.children())
         {
            type = String(node.name());
            if(type == "svg")
            {
               this.loadSvg(node);
            }
            else if(type == "symbol" && node.@library.length() == 1)
            {
               this.loadSymbolLibrary(node);
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
            loader.load(new URLRequest(SVG_ASSET_ROOT + record.src));
         }
         catch(param2:Error)
         {
            this.fail("Could not start SVG asset request: " + record.src);
         }
      }

      private function loadSymbolLibrary(param1:XML) : void
      {
         var library:String = String(param1.@library);
         var symbolName:String = String(param1.@name);
         var loader:Loader = null;
         var record:Object = libraries[library];
         if(record != null)
         {
            if(record.symbols.indexOf(symbolName) < 0)
            {
               record.symbols.push(symbolName);
            }
            return;
         }
         loader = new Loader();
         record = {
            id:library,
            src:library + ".swf",
            kind:"library",
            loader:loader,
            info:loader.contentLoaderInfo,
            domain:new ApplicationDomain(ApplicationDomain.currentDomain),
            symbols:[symbolName]
         };
         libraries[library] = record;
         records.push(record);
         ++pending;
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE,this.onLibraryLoaded);
         loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,this.onAssetMissing);
         loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onAssetSecurityError);
         try
         {
            loader.load(
               new URLRequest(SYMBOL_LIBRARY_ROOT + record.src),
               new LoaderContext(false,record.domain as ApplicationDomain)
            );
         }
         catch(param2:Error)
         {
            this.fail("Could not start symbol library request: " + record.src + ". " + param2.toString());
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

      private function onLibraryLoaded(param1:Event) : void
      {
         var record:Object = this.findByLoaderInfo(param1.currentTarget as LoaderInfo);
         var symbolName:String = null;
         if(record == null)
         {
            this.fail("Symbol library loader completed without a matching library.");
            return;
         }
         this.clearRecordListeners(record);
         record.domain = LoaderInfo(record.info).applicationDomain;
         for each(symbolName in record.symbols)
         {
            if(!this.isLibrarySymbolAvailable(record,symbolName))
            {
               this.fail("Symbol library does not export requested symbol: " + record.id + "/" + symbolName);
               return;
            }
         }
         this.completeOne();
      }

      private function onAssetMissing(param1:IOErrorEvent) : void
      {
         var record:Object = this.findEventRecord(param1.currentTarget);
         var detail:String = param1.text == null ? "" : String(param1.text);
         var description:String = record != null && record.kind == "library" ?
            "Symbol library is missing or unreadable: " : "Asset is missing or unreadable: ";
         this.fail(description + (record == null ? "unknown" : record.src) + (detail.length == 0 ? "" : ". " + detail));
      }

      private function onAssetSecurityError(param1:SecurityErrorEvent) : void
      {
         var record:Object = this.findEventRecord(param1.currentTarget);
         this.fail("Scaleform denied access to " + (record != null && record.kind == "library" ? "symbol library: " : "asset: ") +
            (record == null ? "unknown" : record.src));
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

      private function isLibrarySymbolAvailable(param1:Object, param2:String) : Boolean
      {
         var domain:ApplicationDomain = param1.domain as ApplicationDomain;
         return domain != null && domain.hasDefinition(CUISymbol.libraryLinkageName(param1.id,param2));
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
         if(param1.kind == "library")
         {
            LoaderInfo(param1.info).removeEventListener(Event.COMPLETE,this.onLibraryLoaded);
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
