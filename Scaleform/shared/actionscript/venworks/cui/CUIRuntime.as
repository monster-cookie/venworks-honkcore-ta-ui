package venworks.cui
{
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import venworks.cui.components.CUIComponent;
   import venworks.cui.components.CUIContinuousBar;
   import venworks.cui.components.CUIDotBar;
   import venworks.cui.components.CUIDivider;
   import venworks.cui.components.CUIGroup;
   import venworks.cui.components.CUIMeter;
   import venworks.cui.components.CUIPanel;
   import venworks.cui.components.CUIRadialMeter;
   import venworks.cui.components.CUISegmentedBar;
   import venworks.cui.components.CUIShape;
   import venworks.cui.components.CUIText;
   import venworks.cui.components.CUITriangleBar;

   public final class CUIRuntime
   {
      private static const LAYOUT_PATH:String = "VenworksCUI/layout.xml";

      private var owner:DisplayObjectContainer;
      private var componentLayer:Sprite;
      private var diagnostics:CUIDiagnosticsPanel;
      private var loader:URLLoader;
      private var parser:CUILayoutParser;
      private var layoutEngine:CUILayoutEngine;
      private var conditionParser:CUIConditionParser;
      private var conditionContext:CUIConditionContext;
      private var visibilityBindings:Array;
      private var vanillaAdapters:Array;

      public function CUIRuntime(param1:DisplayObjectContainer)
      {
         super();
         owner = param1;
         componentLayer = new Sprite();
         componentLayer.name = "VenworksCUIComponentLayer";
         diagnostics = new CUIDiagnosticsPanel();
         diagnostics.name = "VenworksCUIDiagnosticsPanel";
         owner.addChild(componentLayer);
         owner.addChild(diagnostics);
      }

      public function load() : void
      {
         if(loader != null)
         {
            return;
         }
         loader = new URLLoader();
         loader.addEventListener(Event.COMPLETE,this.onLoaded);
         loader.addEventListener(IOErrorEvent.IO_ERROR,this.onMissing);
         loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         try
         {
            loader.load(new URLRequest(LAYOUT_PATH));
         }
         catch(param1:Error)
         {
            this.clearListeners();
            diagnostics.showError("CUI LAYOUT LOAD ERROR","Starfield could not start the layout request.");
         }
      }

      private function onLoaded(param1:Event) : void
      {
         var config:XML = null;
         var message:String = null;
         var separator:int = 0;
         this.clearListeners();
         try
         {
            config = new XML(loader.data);
         }
         catch(param2:Error)
         {
            diagnostics.showError("CUI LAYOUT MALFORMED","layout.xml is not well-formed XML.");
            return;
         }
         try
         {
            parser = new CUILayoutParser();
            parser.parse(config);
            conditionParser = new CUIConditionParser();
            visibilityBindings = [];
            vanillaAdapters = [];
            conditionContext = new CUIConditionContext();
            conditionContext.addEventListener(Event.CHANGE,this.onConditionChanged);
            layoutEngine = new CUILayoutEngine(componentLayer,config);
            this.renderChildren(parser.components,componentLayer,parser.components);
            this.createVanillaAdapters(parser.vanillaVisibility);
            this.applyConditions();
            diagnostics.clear();
         }
         catch(param3:Error)
         {
            this.clearComponentLayer();
            message = param3.message;
            separator = message.indexOf("|");
            if(message.indexOf("UNSUPPORTED|") == 0)
            {
               diagnostics.showError("CUI LAYOUT UNSUPPORTED",message.substring(separator + 1));
            }
            else
            {
               diagnostics.showError("CUI LAYOUT INVALID",separator >= 0 ? message.substring(separator + 1) : message);
            }
         }
      }

      private function onMissing(param1:IOErrorEvent) : void
      {
         this.clearListeners();
         diagnostics.showError("CUI LAYOUT MISSING","Expected Interface/VenworksCUI/layout.xml.");
      }

      private function onSecurityError(param1:SecurityErrorEvent) : void
      {
         this.clearListeners();
         diagnostics.showError("CUI LAYOUT SECURITY ERROR","Scaleform denied access to layout.xml.");
      }

      private function clearListeners() : void
      {
         if(loader != null)
         {
            loader.removeEventListener(Event.COMPLETE,this.onLoaded);
            loader.removeEventListener(IOErrorEvent.IO_ERROR,this.onMissing);
            loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onSecurityError);
         }
      }

      private function renderChildren(param1:XML, param2:DisplayObjectContainer, param3:XML) : void
      {
         var entries:Array = [];
         var node:XML = null;
         var entry:Object = null;
         var component:CUIComponent = null;
         for each(node in param1.children())
         {
            entries.push({ xml:node, z:Number(node.@z) });
         }
         entries.sortOn("z",Array.NUMERIC);
         for each(entry in entries)
         {
            node = entry.xml as XML;
            component = this.createComponent(node);
            param2.addChild(component);
            layoutEngine.position(component,node,param2,param3);
            if(node.@visibleWhen.length() == 1)
            {
               visibilityBindings.push(new CUIVisibilityBinding(
                  component,
                  conditionParser.compile(String(node.@visibleWhen)),
                  node.@visible.length() == 0 || String(node.@visible).toLowerCase() == "true"
               ));
            }
            if(String(node.name()) == "group")
            {
               this.renderChildren(node,component,node);
            }
         }
      }

      private function createComponent(param1:XML) : CUIComponent
      {
         var type:String = String(param1.name());
         var style:XML = null;
         if(type == "group")
         {
            return new CUIGroup(param1);
         }
         if(type == "text")
         {
            return new CUIText(param1);
         }
         if(type == "panel")
         {
            return new CUIPanel(param1);
         }
         if(type == "shape")
         {
            return new CUIShape(param1);
         }
         if(type == "divider")
         {
            return new CUIDivider(param1);
         }
         if(type == "meter")
         {
            style = parser.getMeterStyle(String(param1.@style));
            if(String(style.@renderer) == "continuous")
            {
               return new CUIContinuousBar(param1,style);
            }
            if(String(style.@renderer) == "triangles")
            {
               return new CUITriangleBar(param1,style);
            }
            if(String(style.@renderer) == "segments")
            {
               return new CUISegmentedBar(param1,style);
            }
            if(String(style.@renderer) == "dots")
            {
               return new CUIDotBar(param1,style);
            }
            return new CUIRadialMeter(param1,style);
         }
         throw new Error("INVALID|Unknown component: " + type);
      }

      private function createVanillaAdapters(param1:XML) : void
      {
         var target:XML = null;
         for each(target in param1.children())
         {
            vanillaAdapters.push(new CUIVanillaVisibilityAdapter(
               owner,
               String(target.@id),
               conditionParser.compile(String(target.@visibleWhen))
            ));
         }
      }

      private function onConditionChanged(param1:Event) : void
      {
         this.applyConditions();
      }

      private function applyConditions() : void
      {
         var binding:CUIVisibilityBinding = null;
         var adapter:CUIVanillaVisibilityAdapter = null;
         for each(binding in visibilityBindings)
         {
            binding.apply(conditionContext);
         }
         for each(adapter in vanillaAdapters)
         {
            adapter.apply(conditionContext);
         }
      }

      private function clearComponentLayer() : void
      {
         while(componentLayer.numChildren > 0)
         {
            componentLayer.removeChildAt(componentLayer.numChildren - 1);
         }
         visibilityBindings = [];
         vanillaAdapters = [];
      }
   }
}
