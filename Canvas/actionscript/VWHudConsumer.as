package
{
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

      public function getCanvasRegistration() : Object
      {
         var channels:Array = ["LocalEnvironmentData","LocalEnvData_Frequent","PlayerData","PlayerFrequentData","PlayerInventoryData","HudJetpackData","EnvironmentEffectsData","PersonalEffectsData","StarmapSystemBodyInfoProvider","HudCompassData","HudCrosshairData","HUDStealthData","HUDVehicleData","HUDOpacityData"];
         if(!VWHudVariant.MINIMALIST) channels = channels.concat(["WeaponData","HUDStarbornPowersData","FavoritesData","ControlMapData"]);
         return {protocol:"VWCANVAS_CONSUMER/3",consumerId:VWHudVariant.CONSUMER_ID,assetNamespace:VWHudVariant.NAMESPACE,version:1,minimumContractVersion:3,maximumContractVersion:3,hostKinds:["player"],uiChannels:channels,eventSubscriptions:[{topic:VWHudVariant.NAMESPACE+".status",startup:"latest"}]};
      }

      public function getCanvasHtmlRegistration() : Object
      {
         return {contract:"VWCANVAS_HTML/3",entryDocument:"index.html"};
      }

      public function handleLifecycle(state:String, detail:Object) : void
      {
         if(state == "unload") { this.dispose(); return; }
         if(state != "ready") return;
         if(detail == null || detail.html == null || !(detail.features is Array) || detail.features.indexOf("htmlRendering") < 0 || !("setData" in detail.html) || !("getUpdateState" in detail.html))
            throw new Error("VWHUD requires Canvas HTML/3");
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
      }

      private function onModelChange(event:Event) : void { if(!this.receiving) this.publish(); }
      private function onPage(event:TimerEvent) : void { if(this.effects.advancePage()) this.publish(); }
      private function onScanner(event:TimerEvent) : void { this.scannerStep = (this.scannerStep+1)%7; this.publish(); }

      private function publish() : void
      {
         if(this.bridge == null || this.model == null) return;
         var data:Object = this.model.snapshot();
         var flags:Object = this.conditions.snapshot();
         var status:Object = this.effects.view();
         for(var name:String in flags) data[name] = flags[name];
         for(name in status) data[name] = status[name];
         data["hudopacity"] = isFinite(this.conditions.hudOpacity) ? this.conditions.hudOpacity : 1;
         data["theme.logo"] = VWHudVariant.LOGO;
         VWHudPresentation.update(data,this.model.currentTacticalAwarenessData,this.model.currentCompassData,this.scannerStep);
         this.bridge.setData(data);
      }
   }
}
