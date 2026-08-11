package venworks.cui
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;

   public final class CUILayoutImportLoader extends EventDispatcher
   {
      private static const LAYOUT_PATH:String = "VenworksCUI/layout.xml";
      private static const COMPONENT_ROOT:String = "VenworksCUI/components/";
      private static const MAX_INCLUDES:int = 16;
      private static const MAX_FRAGMENT_BYTES:int = 65536;

      private var rootLoader:URLLoader;
      private var records:Array;
      private var pending:int = 0;
      private var resolvedLayout:XML;
      private var failureTitle:String = "CUI LAYOUT LOAD ERROR";
      private var failureMessage:String = "Starfield could not load the CUI layout.";

      public function CUILayoutImportLoader()
      {
         super();
         records = [];
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

      public function load() : void
      {
         if(rootLoader != null)
         {
            return;
         }
         rootLoader = new URLLoader();
         rootLoader.addEventListener(Event.COMPLETE,this.onRootLoaded);
         rootLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onRootMissing);
         rootLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onRootSecurityError);
         try
         {
            rootLoader.load(new URLRequest(LAYOUT_PATH));
         }
         catch(param1:Error)
         {
            this.fail("CUI LAYOUT LOAD ERROR","Starfield could not start the layout request.");
         }
      }

      private function onRootLoaded(param1:Event) : void
      {
         var config:XML = null;
         var includes:XMLList = null;
         var node:XML = null;
         var ids:Object = {};
         this.clearRootListeners();
         try
         {
            config = new XML(rootLoader.data);
         }
         catch(param2:Error)
         {
            this.fail("CUI LAYOUT MALFORMED","layout.xml is not well-formed XML.");
            return;
         }
         if(String(config.name()) != "venworksCUI")
         {
            this.fail("CUI LAYOUT INVALID","The root document must be venworksCUI.");
            return;
         }
         if(config.includes.length() > 1)
         {
            this.fail("CUI LAYOUT INVALID","At most one includes element is allowed.");
            return;
         }
         includes = config.includes.include;
         if(includes.length() > MAX_INCLUDES)
         {
            this.fail("CUI LAYOUT INVALID","The layout exceeds the 16-include limit.");
            return;
         }
         resolvedLayout = config;
         if(includes.length() == 0)
         {
            delete resolvedLayout.includes;
            dispatchEvent(new Event(Event.COMPLETE));
            return;
         }
         for each(node in includes)
         {
            if(!this.validateInclude(node,ids))
            {
               return;
            }
            this.loadFragment(node);
         }
      }

      private function validateInclude(param1:XML, param2:Object) : Boolean
      {
         var allowed:Object = { id:true,src:true,x:true,y:true,anchor:true,visible:true,visibleWhen:true,z:true };
         var attribute:XML = null;
         var id:String = String(param1.@id);
         var src:String = String(param1.@src);
         for each(attribute in param1.attributes())
         {
            if(allowed[String(attribute.name())] !== true)
            {
               this.fail("CUI LAYOUT INVALID","Unsupported include attribute: " + String(attribute.name()));
               return false;
            }
         }
         if(!/^[A-Za-z][A-Za-z0-9._-]{0,63}$/.test(id) || param2[id] === true)
         {
            this.fail("CUI LAYOUT INVALID","Include IDs must be unique valid identifiers: " + id);
            return false;
         }
         param2[id] = true;
         if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,59}\.xml$/.test(src) || src.indexOf("..") >= 0 ||
            src.indexOf("/") >= 0 || src.indexOf("\\") >= 0 || src.indexOf(":") >= 0 ||
            src.indexOf("?") >= 0 || src.indexOf("#") >= 0)
         {
            this.fail("CUI LAYOUT INVALID","Include paths must name one XML file under VenworksCUI/components: " + src);
            return false;
         }
         if(param1.children().length() != 0)
         {
            this.fail("CUI LAYOUT INVALID","Include declarations cannot contain child elements: " + id);
            return false;
         }
         return true;
      }

      private function loadFragment(param1:XML) : void
      {
         var childLoader:URLLoader = new URLLoader();
         var record:Object = { includeNode:param1.copy(),loader:childLoader };
         records.push(record);
         ++pending;
         childLoader.addEventListener(Event.COMPLETE,this.onFragmentLoaded);
         childLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onFragmentMissing);
         childLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onFragmentSecurityError);
         try
         {
            childLoader.load(new URLRequest(COMPONENT_ROOT + String(param1.@src)));
         }
         catch(param2:Error)
         {
            this.fail("CUI COMPONENT LOAD ERROR","Could not start component request: " + String(param1.@src));
         }
      }

      private function onFragmentLoaded(param1:Event) : void
      {
         var record:Object = this.findRecord(param1.currentTarget);
         var source:String = null;
         var fragment:XML = null;
         if(record == null)
         {
            this.fail("CUI COMPONENT LOAD ERROR","A component loader completed without a matching include.");
            return;
         }
         this.clearRecordListeners(record);
         source = String(URLLoader(record.loader).data);
         if(source.length > MAX_FRAGMENT_BYTES)
         {
            this.fail("CUI COMPONENT INVALID","Component file exceeds the 65536-character limit: " + String(record.includeNode.@src));
            return;
         }
         try
         {
            fragment = new XML(source);
         }
         catch(param2:Error)
         {
            this.fail("CUI COMPONENT MALFORMED","Component file is not well-formed XML: " + String(record.includeNode.@src));
            return;
         }
         try
         {
            record.group = this.resolveFragment(record.includeNode,fragment);
         }
         catch(param3:Error)
         {
            this.fail("CUI COMPONENT INVALID",param3.message);
            return;
         }
         --pending;
         if(pending == 0)
         {
            this.finish();
         }
      }

      private function resolveFragment(param1:XML, param2:XML) : XML
      {
         var root:XML = null;
         var wrapper:XML = null;
         if(String(param2.name()) != "venworksCUIFragment" || String(param2.@schemaVersion) != "1" ||
            String(param2.@runtimeVersion) != "1" || param2.attributes().length() != 2)
         {
            throw new Error("Component root must be venworksCUIFragment with schemaVersion=1 and runtimeVersion=1: " + String(param1.@src));
         }
         if(param2.children().length() != 1 || param2.group.length() != 1 || param2.descendants("include").length() != 0 ||
            param2.descendants("includes").length() != 0)
         {
            throw new Error("Component file must contain exactly one group and cannot contain imports: " + String(param1.@src));
         }
         root = param2.group[0].copy();
         this.prefixIds(root,String(param1.@id) + ".");
         wrapper = <group />;
         wrapper.@id = String(param1.@id);
         wrapper.@x = String(param1.@x);
         wrapper.@y = String(param1.@y);
         wrapper.@width = String(root.@width);
         wrapper.@height = String(root.@height);
         wrapper.@opacity = "1";
         wrapper.@visible = param1.@visible.length() == 1 ? String(param1.@visible) : "true";
         if(param1.@visibleWhen.length() == 1)
         {
            wrapper.@visibleWhen = String(param1.@visibleWhen);
         }
         wrapper.@rotation = "0";
         wrapper.@scaleX = "1";
         wrapper.@scaleY = "1";
         wrapper.@z = String(param1.@z);
         if(param1.@anchor.length() == 1)
         {
            wrapper.@anchor = String(param1.@anchor);
         }
         root.@x = "0";
         root.@y = "0";
         root.@anchor = "top-left";
         wrapper.appendChild(root);
         return wrapper;
      }

      private function prefixIds(param1:XML, param2:String) : void
      {
         var node:XML = null;
         if(param1.@id.length() == 1)
         {
            param1.@id = param2 + String(param1.@id);
         }
         for each(node in param1.children())
         {
            this.prefixIds(node,param2);
         }
      }

      private function finish() : void
      {
         var record:Object = null;
         if(resolvedLayout.components.length() != 1)
         {
            this.fail("CUI LAYOUT INVALID","Exactly one components element is required.");
            return;
         }
         for each(record in records)
         {
            resolvedLayout.components[0].appendChild(record.group);
         }
         delete resolvedLayout.includes;
         dispatchEvent(new Event(Event.COMPLETE));
      }

      private function onRootMissing(param1:IOErrorEvent) : void
      {
         this.fail("CUI LAYOUT MISSING","Expected Interface/VenworksCUI/layout.xml.");
      }

      private function onRootSecurityError(param1:SecurityErrorEvent) : void
      {
         this.fail("CUI LAYOUT SECURITY ERROR","Scaleform denied access to layout.xml.");
      }

      private function onFragmentMissing(param1:IOErrorEvent) : void
      {
         var record:Object = this.findRecord(param1.currentTarget);
         this.fail("CUI COMPONENT MISSING","Expected Interface/VenworksCUI/components/" + (record == null ? "unknown.xml" : String(record.includeNode.@src)) + ".");
      }

      private function onFragmentSecurityError(param1:SecurityErrorEvent) : void
      {
         var record:Object = this.findRecord(param1.currentTarget);
         this.fail("CUI COMPONENT SECURITY ERROR","Scaleform denied access to component " + (record == null ? "unknown.xml" : String(record.includeNode.@src)) + ".");
      }

      private function findRecord(param1:Object) : Object
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

      private function fail(param1:String, param2:String) : void
      {
         var record:Object = null;
         failureTitle = param1;
         failureMessage = param2;
         this.clearRootListeners();
         for each(record in records)
         {
            this.clearRecordListeners(record);
         }
         dispatchEvent(new Event(Event.CANCEL));
      }

      private function clearRootListeners() : void
      {
         if(rootLoader != null)
         {
            rootLoader.removeEventListener(Event.COMPLETE,this.onRootLoaded);
            rootLoader.removeEventListener(IOErrorEvent.IO_ERROR,this.onRootMissing);
            rootLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onRootSecurityError);
         }
      }

      private function clearRecordListeners(param1:Object) : void
      {
         URLLoader(param1.loader).removeEventListener(Event.COMPLETE,this.onFragmentLoaded);
         URLLoader(param1.loader).removeEventListener(IOErrorEvent.IO_ERROR,this.onFragmentMissing);
         URLLoader(param1.loader).removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onFragmentSecurityError);
      }
   }
}
