package
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Timer;

   public final class VWHudConsumer extends MovieClip
   {
      private var bridge:Object;
      private var model:VWHudViewModel;
      private var conditions:VWHudConditions;
      private var effects:VWHudEffectsAdapter = new VWHudEffectsAdapter();
      private var pageTimer:Timer;
      private var scannerTimer:Timer;
      private var scannerStep:int = 0;
      private var receiving:Boolean = false;
      private var disposed:Boolean = false;
      private var vanillaMeters:DisplayObject;
      private var vanillaMetersVisible:Boolean = true;
      private var holdingVanillaMeters:Boolean = false;

      public function getCanvasRegistration() : Object
      {
         var channels:Array = ["LocalEnvironmentData","LocalEnvData_Frequent","PlayerData","PlayerFrequentData","PlayerInventoryData","HudJetpackData","EnvironmentEffectsData","PersonalEffectsData","StarmapSystemBodyInfoProvider","HudCompassData","HudCrosshairData","HUDStealthData","HUDVehicleData","HUDOpacityData"];
         if(!VWHudVariant.MINIMALIST) channels = channels.concat(["WeaponData","HUDStarbornPowersData","FavoritesData","ControlMapData"]);
         return {protocol:"VWCANVAS_CONSUMER/3",consumerId:VWHudVariant.CONSUMER_ID,assetNamespace:VWHudVariant.NAMESPACE,version:1,minimumContractVersion:3,maximumContractVersion:3,hostKinds:["player"],uiChannels:channels,eventSubscriptions:[{topic:VWHudVariant.NAMESPACE+".status",startup:"latest"}]};
      }

      public function getCanvasHtmlRegistration() : Object
      {
         return {contract:"VWCANVAS_HTML/2",entryDocument:"index.html"};
      }

      public function handleLifecycle(state:String, detail:Object) : void
      {
         if(state == "unload") { this.dispose(); return; }
         if(state != "ready") return;
         if(detail == null || detail.html == null || !(detail.features is Array) || detail.features.indexOf("htmlRendering") < 0 || !("setData" in detail.html))
            throw new Error("VWHUD requires Canvas HTML/2");
         this.teardownPresentation();
         this.disposed = false;
         this.bridge = detail.html;
         this.model = new VWHudViewModel();
         this.conditions = new VWHudConditions();
         this.model.addEventListener(VWHudViewModel.VALUE_CHANGE,this.onModelChange);
         this.model.addEventListener(VWHudViewModel.TACTICAL_AWARENESS_CHANGE,this.onModelChange);
         this.pageTimer = new Timer(6000);
         this.pageTimer.addEventListener(TimerEvent.TIMER,this.onPage);
         this.pageTimer.start();
         this.scannerTimer = new Timer(140);
         this.scannerTimer.addEventListener(TimerEvent.TIMER,this.onScanner);
         this.publish();
         if(this.stage != null) this.hideVanillaMeters();
         else this.addEventListener(Event.ADDED_TO_STAGE,this.onAddedHideMeters,false,0,true);
      }

      public function handleUIData(channel:String, data:Object) : void
      {
         if(this.model == null || data == null) return;
         this.receiving = true;
         try
         {
            this.model.receive(channel,data);
            this.conditions.receive(channel,data);
            this.conditions.updateCriticalHealth(this.model.getValue("player.healthpercentage"));
         }
         finally { this.receiving = false; }
         var scanner:Object = this.conditions.getValue("inscanner");
         if(scanner != null && scanner.value === true) this.scannerTimer.start();
         else { this.scannerTimer.stop(); this.scannerStep = 0; }
         this.publish();
      }

      public function handleCanvasEvent(topic:String, body:String) : void
      {
         if(!this.disposed && topic == VWHudVariant.NAMESPACE+".status" && this.effects.acceptDatagram(body)) this.publish();
      }

      public function dispose() : void
      {
         this.disposed = true;
         this.teardownPresentation();
         this.effects.reset();
      }

      // A replacement bridge receives the latest validated status, even before ready.
      private function teardownPresentation() : void
      {
         if(this.pageTimer != null)
         {
            this.pageTimer.stop(); this.pageTimer.removeEventListener(TimerEvent.TIMER,this.onPage); this.pageTimer = null;
         }
         if(this.scannerTimer != null)
         {
            this.scannerTimer.stop(); this.scannerTimer.removeEventListener(TimerEvent.TIMER,this.onScanner); this.scannerTimer = null;
         }
         if(this.model != null)
         {
            this.model.removeEventListener(VWHudViewModel.VALUE_CHANGE,this.onModelChange);
            this.model.removeEventListener(VWHudViewModel.TACTICAL_AWARENESS_CHANGE,this.onModelChange);
            this.model.dispose(); this.model = null;
         }
         this.bridge = null; this.conditions = null; this.scannerStep = 0; this.receiving = false;
         this.removeEventListener(Event.ADDED_TO_STAGE,this.onAddedHideMeters);
         this.releaseVanillaMeters();
      }

      private function onAddedHideMeters(event:Event) : void
      {
         if(event.target !== this) return;
         this.removeEventListener(Event.ADDED_TO_STAGE,this.onAddedHideMeters);
         this.hideVanillaMeters();
      }

      private function findVanillaMeters() : DisplayObject
      {
         var node:DisplayObject = this;
         var hops:int = 0;
         while(node != null && hops < 8)
         {
            var container:DisplayObjectContainer = node as DisplayObjectContainer;
            if(container != null)
            {
               var meters:DisplayObject = container.getChildByName("RightMeters_mc");
               if(meters != null) return meters;
            }
            node = node.parent;
            hops++;
         }
         return null;
      }

      private function hideVanillaMeters() : void
      {
         if(this.disposed) return;
         var meters:DisplayObject = this.findVanillaMeters();
         if(meters == null) return;
         if(this.vanillaMeters !== meters)
         {
            this.releaseVanillaMeters();
            this.vanillaMeters = meters;
            this.vanillaMetersVisible = meters.visible;
         }
         meters.visible = false;
         if(!this.holdingVanillaMeters)
         {
            meters.addEventListener(Event.ENTER_FRAME,this.holdVanillaMeters,false,-1000,true);
            this.holdingVanillaMeters = true;
         }
      }

      private function holdVanillaMeters(event:Event) : void
      {
         if(this.vanillaMeters != null) this.vanillaMeters.visible = false;
      }

      private function releaseVanillaMeters() : void
      {
         if(this.vanillaMeters != null)
         {
            this.vanillaMeters.removeEventListener(Event.ENTER_FRAME,this.holdVanillaMeters);
            this.vanillaMeters.visible = this.vanillaMetersVisible;
         }
         this.vanillaMeters = null;
         this.holdingVanillaMeters = false;
      }

      private function onModelChange(event:Event) : void { if(!this.receiving) this.publish(); }
      private function onPage(event:TimerEvent) : void { if(this.effects.advancePage()) this.publish(); }
      private function onScanner(event:TimerEvent) : void { this.scannerStep = (this.scannerStep+1)%7; this.publish(); }

      private function publish() : void
      {
         if(this.bridge == null || this.model == null) return;
         var data:Object = null;
         var flags:Object = null;
         var status:Object = null;
         try { data = this.model.snapshot(); }
         catch(error:*) { throw this.stageError("model",error); }
         try { flags = this.conditions.snapshot(); }
         catch(error:*) { throw this.stageError("flags",error); }
         try { status = this.effects.view(); }
         catch(error:*) { throw this.stageError("effects",error); }
         try
         {
            for(var name:String in flags) data[name] = flags[name];
            for(name in status) data[name] = status[name];
            data["hudopacity"] = isFinite(this.conditions.hudOpacity) ? this.conditions.hudOpacity : 1;
            data["theme.logo"] = VWHudVariant.LOGO;
            VWHudPresentation.update(data,this.model.currentTacticalAwarenessData,this.model.currentCompassData,this.scannerStep);
         }
         catch(error:*) { throw this.stageError("present",error); }
         try { this.bridge.setData(data); }
         catch(error:*) { throw this.stageError("setdata",error); }
      }

      private function stageError(stage:String, error:*) : Error
      {
         var text:String = "error";
         try { text = String(error); }
         catch(ignored:*) { text = "unprintable"; }
         if((text.indexOf("1069 ") == 0 || text.indexOf("PUBLISH ") == 0) && error is Error) return error as Error;
         if(text.length > 70) text = text.substr(0,67) + "...";
         return new Error("PUBLISH " + stage + " | " + text);
      }
   }
}
