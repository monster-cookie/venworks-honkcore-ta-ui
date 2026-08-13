package venworks.cui
{
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import venworks.cui.components.CUIComponent;
   import venworks.cui.components.CUIContinuousBar;
   import venworks.cui.components.CUIDotBar;
   import venworks.cui.components.CUIDivider;
   import venworks.cui.components.CUIGroup;
   import venworks.cui.components.CUIIcon;
   import venworks.cui.components.CUIImage;
   import venworks.cui.components.CUIMask;
   import venworks.cui.components.CUIMeter;
   import venworks.cui.components.CUIPanel;
   import venworks.cui.components.CUIProviderSymbol;
   import venworks.cui.components.CUIRadialMeter;
   import venworks.cui.components.CUISegmentedBar;
   import venworks.cui.components.CUIShape;
   import venworks.cui.components.CUISvg;
   import venworks.cui.components.CUISvgPath;
   import venworks.cui.components.CUISymbol;
   import venworks.cui.components.CUIText;
   import venworks.cui.components.CUITriangleBar;

   public final class CUIRuntime
   {
      private var owner:DisplayObjectContainer;
      private var componentLayer:Sprite;
      private var diagnostics:CUIDiagnosticsPanel;
      private var loader:CUILayoutImportLoader;
      private var layoutConfig:XML;
      private var assetManager:CUIAssetManager;
      private var parser:CUILayoutParser;
      private var layoutEngine:CUILayoutEngine;
      private var conditionParser:CUIConditionParser;
      private var conditionContext:CUIConditionContext;
      private var valueContext:CUIPlayerHudDataContext;
      private var visibilityBindings:Array;
      private var valueBindings:Array;
      private var vanillaAdapters:Array;
      private var diagnosticPhase:String = "";
      private var diagnosticNode:XML;

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
         loader = new CUILayoutImportLoader();
         loader.addEventListener(Event.COMPLETE,this.onLoaded);
         loader.addEventListener(Event.CANCEL,this.onLoadFailed);
         loader.load();
      }

      private function onLoaded(param1:Event) : void
      {
         var config:XML = loader.layout;
         this.clearListeners();
         try
         {
            this.setDiagnosticContext("LAYOUT PARSING",null);
            parser = new CUILayoutParser();
            parser.parse(config);
            layoutConfig = config;
            assetManager = new CUIAssetManager();
            assetManager.addEventListener(Event.COMPLETE,this.onAssetsLoaded);
            assetManager.addEventListener(Event.CANCEL,this.onAssetFailed);
            assetManager.load(parser.components);
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onLoadFailed(param1:Event) : void
      {
         this.clearListeners();
         this.clearComponentLayer();
         diagnostics.showError(loader.errorTitle,loader.errorMessage);
      }

      private function onAssetsLoaded(param1:Event) : void
      {
         this.clearAssetListeners();
         try
         {
            this.setDiagnosticContext("CONDITION INITIALIZATION",null);
            conditionParser = new CUIConditionParser();
            visibilityBindings = [];
            valueBindings = [];
            vanillaAdapters = [];
            conditionContext = new CUIConditionContext();
            conditionContext.addEventListener(Event.CHANGE,this.onConditionChanged);
            valueContext = new CUIPlayerHudDataContext();
            valueContext.addEventListener(Event.CHANGE,this.onValueChanged);
            layoutEngine = new CUILayoutEngine(componentLayer,layoutConfig);
            this.renderChildren(parser.components,componentLayer,parser.components);
            this.setDiagnosticContext("VANILLA ADAPTER INITIALIZATION",null);
            this.createVanillaAdapters(parser.vanillaVisibility);
            this.setDiagnosticContext("INITIAL LIVE VALUE EVALUATION",null);
            this.applyValues();
            this.setDiagnosticContext("INITIAL VISIBILITY EVALUATION",null);
            this.applyConditions();
            this.clearDiagnosticContext();
            diagnostics.clear();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onAssetFailed(param1:Event) : void
      {
         this.clearAssetListeners();
         this.clearComponentLayer();
         diagnostics.showError("CUI ASSET LOAD ERROR","PHASE: ASSET LOADING\n" + assetManager.errorMessage);
      }

      private function clearAssetListeners() : void
      {
         if(assetManager != null)
         {
            assetManager.removeEventListener(Event.COMPLETE,this.onAssetsLoaded);
            assetManager.removeEventListener(Event.CANCEL,this.onAssetFailed);
         }
      }

      private function showRuntimeError(param1:Error) : void
      {
         var message:String = param1.message;
         var separator:int = message.indexOf("|");
         var detail:String = this.formatRuntimeError(param1,separator >= 0 ? message.substring(separator + 1) : message);
         this.clearComponentLayer();
         if(message.indexOf("UNSUPPORTED|") == 0)
         {
            diagnostics.showError("CUI LAYOUT UNSUPPORTED",detail);
         }
         else
         {
            diagnostics.showError("CUI LAYOUT INVALID",detail);
         }
      }

      private function formatRuntimeError(param1:Error, param2:String) : String
      {
         var lines:Array = [];
         var component:String = null;
         var exceptionText:String = param1.toString();
         if(diagnosticPhase.length != 0)
         {
            lines.push("PHASE: " + diagnosticPhase);
         }
         if(diagnosticNode != null)
         {
            component = String(diagnosticNode.name()).toUpperCase();
            if(diagnosticNode.@id.length() == 1)
            {
               component += " #" + String(diagnosticNode.@id);
            }
            lines.push("COMPONENT: " + component);
            if(diagnosticNode.@library.length() == 1)
            {
               lines.push("LIBRARY: " + String(diagnosticNode.@library));
            }
            if(diagnosticNode.@name.length() == 1)
            {
               lines.push("SYMBOL: " + String(diagnosticNode.@name));
            }
         }
         if(param2.length != 0)
         {
            lines.push(param2);
         }
         if(exceptionText != null && exceptionText.length != 0 && exceptionText != param1.message && exceptionText != "Error: " + param1.message)
         {
            lines.push("EXCEPTION: " + exceptionText);
         }
         if(param1.errorID != 0)
         {
            lines.push("ERROR ID: " + param1.errorID);
         }
         return lines.join("\n");
      }

      private function setDiagnosticContext(param1:String, param2:XML) : void
      {
         diagnosticPhase = param1;
         diagnosticNode = param2;
      }

      private function clearDiagnosticContext() : void
      {
         diagnosticPhase = "";
         diagnosticNode = null;
      }

      private function clearListeners() : void
      {
         if(loader != null)
         {
            loader.removeEventListener(Event.COMPLETE,this.onLoaded);
            loader.removeEventListener(Event.CANCEL,this.onLoadFailed);
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
            this.setDiagnosticContext("COMPONENT CREATION",node);
            component = this.createComponent(node);
            this.setDiagnosticContext("DISPLAY LIST ATTACHMENT",node);
            param2.addChild(component);
            this.setDiagnosticContext("LAYOUT POSITIONING",node);
            layoutEngine.position(component,node,param2,param3);
            if(node.@source.length() == 1 || node.@valueTemplate.length() == 1)
            {
               this.setDiagnosticContext("VALUE BINDING CREATION",node);
               valueBindings.push(new CUIValueBinding(
                  component,
                  node,
                  String(node.name()) == "meter" ? parser.getMeterStyle(String(node.@style)) : null
               ));
            }
            if(node.@visibleWhen.length() == 1)
            {
               this.setDiagnosticContext("VISIBILITY CONDITION COMPILATION",node);
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
            else if(String(node.name()) == "mask")
            {
               this.renderChildren(node,CUIMask(component).content,node);
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
         if(type == "svg")
         {
            return new CUISvg(param1,assetManager.getSvg(String(param1.@id)));
         }
         if(type == "path")
         {
            return new CUISvgPath(param1);
         }
         if(type == "mask")
         {
            return new CUIMask(param1);
         }
         if(type == "icon")
         {
            return new CUIIcon(param1);
         }
         if(type == "providerSymbol")
         {
            return new CUIProviderSymbol(param1);
         }
         if(type == "symbol")
         {
            return new CUISymbol(param1);
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
            this.setDiagnosticContext("VANILLA ADAPTER CREATION",target);
            vanillaAdapters.push(new CUIVanillaVisibilityAdapter(
               owner,
               target,
               conditionParser.compile(String(target.@visibleWhen)),
               layoutEngine
            ));
         }
      }

      private function onConditionChanged(param1:Event) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE VISIBILITY EVALUATION",null);
            this.applyConditions();
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onValueChanged(param1:Event) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE VALUE EVALUATION",null);
            this.applyValues();
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function applyValues() : void
      {
         var binding:CUIValueBinding = null;
         for each(binding in valueBindings)
         {
            binding.apply(valueContext);
         }
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
         var adapter:CUIVanillaVisibilityAdapter = null;
         if(conditionContext != null)
         {
            conditionContext.removeEventListener(Event.CHANGE,this.onConditionChanged);
         }
         if(valueContext != null)
         {
            valueContext.removeEventListener(Event.CHANGE,this.onValueChanged);
            valueContext.dispose();
         }
         if(vanillaAdapters != null)
         {
            for each(adapter in vanillaAdapters)
            {
               adapter.dispose();
            }
         }
         while(componentLayer.numChildren > 0)
         {
            componentLayer.removeChildAt(componentLayer.numChildren - 1);
         }
         visibilityBindings = [];
         valueBindings = [];
         vanillaAdapters = [];
      }
   }
}
