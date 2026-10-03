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
      private var sentHtmlKey:String = "";
      private var compassSlot:DisplayObject;
      private var radarSlot:DisplayObject;

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
         catch(receiveError:*) {}
         finally { this.receiving = false; }
         var scanner:Object = this.conditions.getValue("inscanner");
         if(scanner != null && scanner.value === true) this.scannerTimer.start();
         else { this.scannerTimer.stop(); this.scannerStep = 0; }
         this.publish();
      }

      public function handleCanvasEvent(topic:String, body:String) : void
      {
         if(this.disposed || topic != VWHudVariant.NAMESPACE+".status") return;
         if(this.effects.acceptDatagram(body)) this.publish();
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
         this.compassSlot = null; this.radarSlot = null; this.sentHtmlKey = "";
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
            var scanning:Object = this.conditions.getValue("inscanner");
            VWHudPresentation.update(data,this.model.currentTacticalAwarenessData,this.scannerStep,scanning != null && scanning.value === true);
            this.updateInstruments();
         }
         catch(error:*) { throw this.stageError("present",error); }
         // Compass and environment packets arrive many times a second. Rebuilding the HTML document for an unchanged clock, threat, or hazard set is what drops the frame rate.
         var key:String = this.htmlSignature(data);
         if(key == this.sentHtmlKey) return;
         try
         {
            this.bridge.setData(data);
            this.sentHtmlKey = key;
         }
         catch(error:*)
         {
            var text:String = "error";
            try { text = String(error); } catch(ignored:*) { text = "unprintable"; }
            if(text.indexOf("#1069") < 0 && text.indexOf("1069 ") != 0) throw this.stageError("setdata",text);
         }
         finally { this.alignInstruments(); }
      }

      private function htmlSignature(data:Object) : String
      {
         var names:Array = [];
         for(var name:String in data) names.push(name);
         names.sort();
         var parts:Array = [];
         var index:int = 0;
         while(index < names.length)
         {
            if(this.signsHtml(String(names[index]), data))
               parts.push(names[index] + "=" + this.signValue(String(names[index]), data[names[index]], 0));
            ++index;
         }
         return parts.join("\n");
      }

      // The theme prints percentages and 16-segment meters. The raw point values are not on screen, except the critical-health banner.
      private function signsHtml(key:String, data:Object) : Boolean
      {
         if(key == "player.oxygen" || key == "player.maxoxygen" || key == "player.carbondioxide" || key == "boost.charge") return false;
         if(key == "player.health" || key == "player.maxhealth") return data["condition.criticalhealth"] === true;
         return true;
      }

      private function signValue(key:String, value:*, depth:int) : String
      {
         if(value == null || depth > 4) return "";
         if(value is Array)
         {
            var items:Array = value as Array;
            var itemText:Array = [];
            var index:int = 0;
            var count:int = Math.min(items.length, 64);
            while(index < count)
            {
               itemText.push(this.signValue("", items[index], depth + 1));
               ++index;
            }
            return itemText.join(",");
         }
         var kind:String = typeof value;
         if(kind == "number")
         {
            var number:Number = Number(value);
            if(!isFinite(number)) return "nan";
            if(key == "environment.localtime" || key == "player.universaltime")
            {
               var fraction:Number = number - Math.floor(number);
               if(fraction < 0) fraction += 1;
               return "m" + String(int(Math.floor(fraction * 1440 + 0.5)) % 1440);
            }
            // A one-point change used to rebuild the whole theme. Suit meters are 16 segments, so sign that step.
            number = VWHudViewModel.quantizeDisplay(key,number);
            if(key == "player.healthpercentage" || key == "player.oxygenpercentage" || key == "player.carbondioxidepercentage" || key == "boost.percentage")
            {
               var segment:int = int(Math.floor(Math.max(0,Math.min(100,number)) * 16 / 100));
               if(number >= 100) segment = 16;
               return "seg" + String(segment);
            }
            return "n" + String(Math.round(number * 100));
         }
         if(kind == "boolean") return value === true ? "b1" : "b0";
         if(kind == "string") return String(value);
         var names:Array = [];
         for(var name:String in value) names.push(name);
         names.sort();
         var fields:Array = [];
         index = 0;
         while(index < names.length)
         {
            fields.push(names[index] + ":" + this.signValue(String(names[index]), value[names[index]], depth + 1));
            ++index;
         }
         return "{" + fields.join(";") + "}";
      }

      private function updateInstruments() : void
      {
         if(this.compassTape == null || this.contactRadar == null || this.model == null) return;
         var tactical:Object = this.model.currentTacticalAwarenessData;
         var direction:Number = Number(VWHudViewModel.field(tactical,"direction"));
         try { this.compassTape.update(direction,tactical == null ? null : tactical.markers as Array); }
         catch(compassError:*) {}
         try { this.contactRadar.update(this.model.currentCompassData); }
         catch(radarError:*) {}
      }

      private function alignInstruments() : void
      {
         if(this.compassSlot == null || this.compassSlot.parent == null) this.compassSlot = this.findSlot(this,true);
         if(this.radarSlot == null || this.radarSlot.parent == null) this.radarSlot = this.findSlot(this,false);
         this.placeOver(this.compassTape,this.compassSlot);
         this.placeOver(this.contactRadar,this.radarSlot);
         this.applySlotVisibility(this.compassTape,this.compassSlot);
         this.applySlotVisibility(this.contactRadar,this.radarSlot);
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

      private function applySlotVisibility(overlay:DisplayObject, slot:DisplayObject) : void
      {
         if(overlay == null) return;
         var visibleSlot:Boolean = slot != null && slot.parent != null;
         var current:DisplayObject = slot;
         while(visibleSlot && current != null && current !== this)
         {
            if(!current.visible) visibleSlot = false;
            current = current.parent;
         }
         overlay.visible = visibleSlot;
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
