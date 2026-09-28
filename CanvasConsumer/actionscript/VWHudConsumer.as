package
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.geom.Point;
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
      private var compassTape:VWHudCompassTape;
      private var contactRadar:VWHudContactRadar;

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
         this.compassTape = new VWHudCompassTape(826,48);
         this.contactRadar = new VWHudContactRadar(184);
         addChild(this.compassTape);
         addChild(this.contactRadar);
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
         if(this.compassTape != null && this.compassTape.parent === this) removeChild(this.compassTape);
         if(this.contactRadar != null && this.contactRadar.parent === this) removeChild(this.contactRadar);
         this.compassTape = null; this.contactRadar = null;
         this.bridge = null; this.conditions = null; this.scannerStep = 0; this.receiving = false;
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
            VWHudPresentation.update(data,this.model.currentTacticalAwarenessData,this.scannerStep);
            this.updateInstruments();
         }
         catch(error:*) { throw this.stageError("present",error); }
         try { this.bridge.setData(data); }
         catch(error:*)
         {
            var text:String = "error";
            try { text = String(error); } catch(ignored:*) { text = "unprintable"; }
            if(text.indexOf("#1069") < 0 && text.indexOf("1069 ") != 0) throw this.stageError("setdata",text);
         }
         finally { this.alignInstruments(); }
      }

      private function updateInstruments() : void
      {
         if(this.compassTape == null || this.contactRadar == null || this.model == null) return;
         var tactical:Object = this.model.currentTacticalAwarenessData;
         var direction:Number = Number(VWHudViewModel.field(tactical,"direction"));
         this.compassTape.update(direction,tactical == null ? null : tactical.markers as Array);
         this.contactRadar.update(this.model.currentCompassData);
      }

      private function alignInstruments() : void
      {
         this.placeOver(this.compassTape,this.findSlot(this,true));
         this.placeOver(this.contactRadar,this.findSlot(this,false));
         if(this.compassTape != null && this.compassTape.parent === this) setChildIndex(this.compassTape,numChildren - 1);
         if(this.contactRadar != null && this.contactRadar.parent === this) setChildIndex(this.contactRadar,numChildren - 1);
      }

      private function placeOver(overlay:DisplayObject, slot:DisplayObject) : void
      {
         if(overlay == null || slot == null) return;
         var local:Point = globalToLocal(slot.localToGlobal(new Point(0,0)));
         overlay.x = local.x;
         overlay.y = local.y;
      }

      private function findSlot(root:DisplayObject, compass:Boolean) : DisplayObject
      {
         var container:DisplayObjectContainer = root as DisplayObjectContainer;
         if(container == null || root === this.compassTape || root === this.contactRadar) return null;
         var index:int = 0;
         while(index < container.numChildren)
         {
            var child:DisplayObject = container.getChildAt(index);
            if(child !== this.compassTape && child !== this.contactRadar)
            {
               var sprite:Sprite = child as Sprite;
               if(compass && sprite != null && sprite.scrollRect != null && Math.abs(sprite.scrollRect.width - 826) < 1 && Math.abs(sprite.scrollRect.height - 48) < 1) return sprite;
               if(!compass && Math.abs(child.width - 184) < 2 && Math.abs(child.height - 184) < 2) return child;
               var nested:DisplayObject = this.findSlot(child,compass);
               if(nested != null) return nested;
            }
            ++index;
         }
         return null;
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
