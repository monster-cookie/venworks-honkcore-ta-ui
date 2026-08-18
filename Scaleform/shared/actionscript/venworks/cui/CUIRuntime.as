package venworks.cui
{
   import Shared.AS3.Events.CustomEvent;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import venworks.cui.components.CUIComponent;
   import venworks.cui.components.CUIContinuousBar;
   import venworks.cui.components.CUICompassTape;
   import venworks.cui.components.CUIContactRadar;
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
   import venworks.cui.components.CUIStatusEffectBar;
   import venworks.cui.components.CUISvg;
   import venworks.cui.components.CUISvgPath;
   import venworks.cui.components.CUISymbol;
   import venworks.cui.components.CUIText;
   import venworks.cui.components.CUIThreatAlert;
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
      private var hudModeVisibility:Array;
      private var contactRadars:Array;
      private var compassTapes:Array;
      private var threatAlerts:Array;
      private var statusEffectBars:Array;
      private var diagnosticPhase:String = "";
      private var diagnosticNode:XML;
      private var diagnosticCheckpoint:String = "";

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

      public function reapplyVanillaPlacements() : void
      {
         var adapter:CUIVanillaVisibilityAdapter = null;
         if(vanillaAdapters == null)
         {
            return;
         }
         try
         {
            this.setDiagnosticContext("VANILLA SAFE-RECT PLACEMENT",null);
            for each(adapter in vanillaAdapters)
            {
               adapter.reapplyPlacement();
            }
            this.clearDiagnosticContext();
         }
         catch(param1:Error)
         {
            this.showRuntimeError(param1);
         }
      }

      public function updateVanillaHudModeVisibility(param1:Array) : void
      {
         var adapter:CUIVanillaVisibilityAdapter = null;
         hudModeVisibility = param1 == null ? null : param1.concat();
         if(vanillaAdapters == null || conditionContext == null)
         {
            return;
         }
         try
         {
            this.setDiagnosticContext("VANILLA HUD MODE VISIBILITY",null);
            for each(adapter in vanillaAdapters)
            {
               if(adapter.updateHudMode(hudModeVisibility))
               {
                  adapter.apply(conditionContext);
               }
            }
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onLoaded(param1:Event) : void
      {
         var config:XML = loader.layout;
         this.clearListeners();
         try
         {
            this.setDiagnosticContext("LAYOUT VALIDATION",null,"PARSER INITIALIZATION");
            parser = new CUILayoutParser();
            parser.parse(config);
            layoutConfig = config;
            this.setDiagnosticContext("ASSET MANAGER INITIALIZATION",null,"CONSTRUCTOR");
            assetManager = new CUIAssetManager();
            assetManager.addEventListener(Event.COMPLETE,this.onAssetsLoaded);
            assetManager.addEventListener(Event.CANCEL,this.onAssetFailed);
            this.setDiagnosticContext("ASSET COLLECTION",null,"COLLECTION AND REQUEST START");
            assetManager.load(parser.components);
         }
         catch(param2:Error)
         {
            if(diagnosticPhase == "LAYOUT VALIDATION" && parser != null)
            {
               diagnosticNode = parser.lastDiagnosticNode;
               diagnosticCheckpoint = parser.lastDiagnosticCheckpoint;
            }
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
            contactRadars = [];
            compassTapes = [];
            threatAlerts = [];
            statusEffectBars = [];
            conditionContext = new CUIConditionContext();
            conditionContext.addEventListener(CUIConditionContext.CONDITION_CHANGE,this.onConditionChanged);
            valueContext = new CUIPlayerHudDataContext();
            valueContext.addEventListener(CUIPlayerHudDataContext.VALUE_CHANGE,this.onValueChanged);
            valueContext.addEventListener(CUIPlayerHudDataContext.COMPASS_CHANGE,this.onCompassChanged);
            valueContext.addEventListener(CUIPlayerHudDataContext.TACTICAL_AWARENESS_CHANGE,this.onTacticalAwarenessChanged);
            layoutEngine = new CUILayoutEngine(componentLayer,layoutConfig);
            this.renderChildren(parser.components,componentLayer,parser.components);
            this.setDiagnosticContext("VANILLA ADAPTER INITIALIZATION",null);
            this.createVanillaAdapters(parser.vanillaVisibility);
            this.setDiagnosticContext("INITIAL LIVE VALUE EVALUATION",null);
            this.applyValues();
            this.applyContactRadars();
            this.applyTacticalAwareness();
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
         var stackTrace:String = param1.getStackTrace();
         if(diagnosticPhase.length != 0)
         {
            lines.push("PHASE: " + diagnosticPhase);
         }
         if(diagnosticCheckpoint.length != 0)
         {
            lines.push("CHECKPOINT: " + diagnosticCheckpoint);
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
         if(stackTrace != null && stackTrace.length != 0)
         {
            lines.push("STACK: " + stackTrace);
         }
         return lines.join("\n");
      }

      private function setDiagnosticContext(param1:String, param2:XML, param3:String = "") : void
      {
         diagnosticPhase = param1;
         diagnosticNode = param2;
         diagnosticCheckpoint = param3;
      }

      private function clearDiagnosticContext() : void
      {
         diagnosticPhase = "";
         diagnosticNode = null;
         diagnosticCheckpoint = "";
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
         var radar:CUIContactRadar = null;
         if(type == "group")
         {
            return new CUIGroup(param1);
         }
         if(type == "text")
         {
            return new CUIText(param1);
         }
         if(type == "contactRadar")
         {
            radar = new CUIContactRadar(param1);
            contactRadars.push(radar);
            return radar;
         }
         if(type == "compassTape")
         {
            var compassTape:CUICompassTape = new CUICompassTape(param1);
            compassTapes.push(compassTape);
            return compassTape;
         }
         if(type == "threatAlert")
         {
            var threatAlert:CUIThreatAlert = new CUIThreatAlert(param1);
            threatAlerts.push(threatAlert);
            return threatAlert;
         }
         if(type == "statusEffectBar")
         {
            var statusEffectBar:CUIStatusEffectBar = new CUIStatusEffectBar(param1);
            statusEffectBars.push(statusEffectBar);
            return statusEffectBar;
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
         var adapter:CUIVanillaVisibilityAdapter = null;
         for each(target in param1.children())
         {
            this.setDiagnosticContext("VANILLA ADAPTER CREATION",target);
            adapter = new CUIVanillaVisibilityAdapter(
               owner,
               target,
               conditionParser.compile(String(target.@visibleWhen)),
               layoutEngine
            );
            adapter.updateHudMode(hudModeVisibility);
            vanillaAdapters.push(adapter);
         }
      }

      private function onConditionChanged(param1:CustomEvent) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE VISIBILITY EVALUATION",null);
            this.applyConditions(param1.params);
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onValueChanged(param1:CustomEvent) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE VALUE EVALUATION",null);
            this.applyValues(param1.params);
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onCompassChanged(param1:Event) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE CONTACT RADAR EVALUATION",null);
            this.applyContactRadars();
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function onTacticalAwarenessChanged(param1:Event) : void
      {
         try
         {
            this.setDiagnosticContext("LIVE TACTICAL AWARENESS EVALUATION",null);
            this.applyTacticalAwareness();
            this.clearDiagnosticContext();
         }
         catch(param2:Error)
         {
            this.showRuntimeError(param2);
         }
      }

      private function applyValues(param1:Object = null) : void
      {
         var binding:CUIValueBinding = null;
         for each(binding in valueBindings)
         {
            if(binding.isAffectedBy(param1))
            {
               binding.apply(valueContext);
            }
         }
      }

      private function applyContactRadars() : void
      {
         var radar:CUIContactRadar = null;
         for each(radar in contactRadars)
         {
            radar.updateData(valueContext.currentCompassData);
         }
      }

      private function applyTacticalAwareness() : void
      {
         var compassTape:CUICompassTape = null;
         var threatAlert:CUIThreatAlert = null;
         var statusEffectBar:CUIStatusEffectBar = null;
         var data:Object = valueContext.currentTacticalAwarenessData;
         for each(compassTape in compassTapes)
         {
            compassTape.updateData(data);
         }
         for each(threatAlert in threatAlerts)
         {
            threatAlert.updateData(data);
         }
         for each(statusEffectBar in statusEffectBars)
         {
            statusEffectBar.updateData(data);
         }
      }

      private function applyConditions(param1:Object = null) : void
      {
         var binding:CUIVisibilityBinding = null;
         var adapter:CUIVanillaVisibilityAdapter = null;
         for each(binding in visibilityBindings)
         {
            if(binding.isAffectedBy(param1))
            {
               binding.apply(conditionContext);
            }
         }
         for each(adapter in vanillaAdapters)
         {
            if(adapter.isAffectedBy(param1))
            {
               adapter.apply(conditionContext);
            }
         }
      }

      private function clearComponentLayer() : void
      {
         var adapter:CUIVanillaVisibilityAdapter = null;
         if(conditionContext != null)
         {
            conditionContext.removeEventListener(CUIConditionContext.CONDITION_CHANGE,this.onConditionChanged);
         }
         if(valueContext != null)
         {
            valueContext.removeEventListener(CUIPlayerHudDataContext.VALUE_CHANGE,this.onValueChanged);
            valueContext.removeEventListener(CUIPlayerHudDataContext.COMPASS_CHANGE,this.onCompassChanged);
            valueContext.removeEventListener(CUIPlayerHudDataContext.TACTICAL_AWARENESS_CHANGE,this.onTacticalAwarenessChanged);
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
         contactRadars = [];
         compassTapes = [];
         threatAlerts = [];
         statusEffectBars = [];
      }
   }
}
