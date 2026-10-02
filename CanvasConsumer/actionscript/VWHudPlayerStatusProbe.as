package
{
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;

   // Diagnostic only. The quest snapshot remains the writer of the HUD status rows.
   public final class VWHudPlayerStatusProbe
   {
      private static const CHANNEL:String = "PlayerStatusData";

      private var host:DisplayObject;
      private var manager:Object;
      private var callback:Function;
      private var timer:Timer;
      private var subscribed:Boolean = false;
      private var stopped:Boolean = false;
      private var payloadCount:int = 0;
      private var lastAttempt:String = "";
      private var lastAttemptAt:int = -20000;
      private var lastPayload:String = "";
      private var lastPayloadAt:int = 0;
      private var lastWaitAt:int = 0;
      private var lastWatch:Object = {};

      public function VWHudPlayerStatusProbe(host:DisplayObject)
      {
         this.host = host;
         // A bare method reference loses this when the client calls it.
         var probe:VWHudPlayerStatusProbe = this;
         this.callback = function(event:*):void { probe.onPayload(event); };
      }

      public function start() : void
      {
         if(this.stopped || this.host == null) return;
         if(this.host.stage != null) this.attempt();
         else this.host.addEventListener(Event.ADDED_TO_STAGE,this.onAdded,false,0,true);
         if(this.timer == null)
         {
            this.timer = new Timer(5000);
            this.timer.addEventListener(TimerEvent.TIMER,this.onTimer);
            this.timer.start();
         }
      }

      public function stop() : void
      {
         this.stopped = true;
         if(this.host != null) this.host.removeEventListener(Event.ADDED_TO_STAGE,this.onAdded);
         if(this.timer != null)
         {
            this.timer.stop();
            this.timer.removeEventListener(TimerEvent.TIMER,this.onTimer);
            this.timer = null;
         }
         if(this.subscribed && this.manager != null && this.callback != null)
         {
            try { this.manager.Unsubscribe(CHANNEL,this.callback); }
            catch(unsubscribeError:*) { this.report("unsubscribe | error=" + this.errorText(unsubscribeError),true); }
         }
         this.subscribed = false;
         this.manager = null;
         this.callback = null;
         this.host = null;
      }

      private function onAdded(event:Event) : void
      {
         if(this.host != null) this.host.removeEventListener(Event.ADDED_TO_STAGE,this.onAdded);
         this.attempt();
      }

      private function onTimer(event:TimerEvent) : void
      {
         if(this.stopped) return;
         if(!this.subscribed) this.attempt();
         else if(this.payloadCount == 0 && getTimer() - this.lastWaitAt >= 30000)
         {
            this.lastWaitAt = getTimer();
            this.report("wait | subscribed=1 | payloads=0",true);
         }
      }

      private function attempt() : void
      {
         if(this.stopped || this.subscribed) return;
         var found:Object = null;
         var where:String = "missing";
         try
         {
            var located:Object = this.findManager();
            found = located.manager;
            where = String(located.where);
         }
         catch(findError:*)
         {
            this.report("seek | error=" + this.errorText(findError),false);
            return;
         }
         if(found == null)
         {
            this.report("seek | manager=missing | " + where,false);
            return;
         }
         this.manager = found;
         var provider:String = "missing";
         try
         {
            if(!("GetDataFromClient" in this.manager) || !("Subscribe" in this.manager))
            {
               this.manager = null;
               this.report("seek | manager=" + where + " | methods=missing",false);
               return;
            }
            var client:Object = this.manager.GetDataFromClient(CHANNEL,true);
            provider = client == null ? "null" : "object";
         }
         catch(getError:*)
         {
            this.manager = null;
            this.report("get | manager=" + where + " | error=" + this.errorText(getError),false);
            return;
         }
         try
         {
            this.subscribed = true;
            this.manager.Subscribe(CHANNEL,this.callback);
            this.lastWaitAt = getTimer();
            this.report("subscribe | manager=" + where + " | provider=" + provider + " | ok=1 | payloads=" + this.payloadCount,true);
         }
         catch(subscribeError:*)
         {
            this.subscribed = false;
            this.manager = null;
            this.report("subscribe | manager=" + where + " | provider=" + provider + " | error=" + this.errorText(subscribeError),false);
         }
      }

      // The HUD menu owns the manager. This movie is not on that display list until the host adds its loader.
      private function findManager() : Object
      {
         var node:DisplayObject = this.host;
         var depth:int = 0;
         var chain:Array = [];
         while(node != null && depth < 12)
         {
            chain.push(this.nodeName(node));
            try
            {
               if(("getVenworksCanvasDataManager" in node) && typeof node["getVenworksCanvasDataManager"] == "function")
                  return {"manager":node["getVenworksCanvasDataManager"](),"where":"parent:" + depth + " | chain=" + chain.join(">")};
            }
            catch(callError:*)
            {
               return {"manager":null,"where":"parent:" + depth + " | chain=" + chain.join(">") + " | error=" + this.errorText(callError)};
            }
            node = node.parent;
            depth++;
         }
         return {"manager":null,"where":"chain=" + chain.join(">")};
      }

      private function onPayload(event:*) : void
      {
         if(this.stopped) return;
         try
         {
            this.payloadCount++;
            var data:Object = null;
            try { data = event == null ? null : event.data; } catch(dataError:*) { data = null; }
            if(data == null) data = event;
            var summary:String = this.summarize(data);
            var now:int = getTimer();
            if(summary == this.lastPayload && now - this.lastPayloadAt < 1000) return;
            this.lastPayload = summary;
            this.lastPayloadAt = now;
            this.report("payload | n=" + this.payloadCount + " | " + summary,true);
         }
         catch(payloadError:*)
         {
            this.report("payload | error=" + this.errorText(payloadError),true);
         }
      }

      private function summarize(data:Object) : String
      {
         if(data == null) return "data=null";
         var groups:Object = null;
         try { groups = data.aEffectGroups; } catch(groupError:*) { groups = null; }
         if(!(groups is Array)) return "keys=" + this.keyList(data);
         var effects:int = 0;
         var buffs:int = 0;
         var debuffs:int = 0;
         var timed:int = 0;
         var names:Array = [];
         var groupIndex:int = 0;
         while(groupIndex < (groups as Array).length && groupIndex < 8)
         {
            var group:Object = (groups as Array)[groupIndex];
            var rows:Object = null;
            try { rows = group == null ? null : group.aEffects; } catch(rowError:*) { rows = null; }
            if(rows is Array)
            {
               var rowIndex:int = 0;
               while(rowIndex < (rows as Array).length && effects < 24)
               {
                  var row:Object = (rows as Array)[rowIndex];
                  effects++;
                  var buff:Boolean = false;
                  var remaining:Number = NaN;
                  var name:String = "";
                  try { buff = row != null && row.bIsBuff === true; } catch(buffError:*) {}
                  try { remaining = row == null ? NaN : Number(row.fTimeRemaining); } catch(timeError:*) {}
                  try { name = row == null || row.sName == null ? "" : String(row.sName); } catch(nameError:*) {}
                  if(buff) buffs++; else debuffs++;
                  if(isFinite(remaining) && remaining > 0) timed++;
                  if(names.length < 6 && name != "") names.push(name);
                  rowIndex++;
               }
            }
            groupIndex++;
         }
         return "groups=" + (groups as Array).length + " | effects=" + effects + " | buffs=" + buffs + " | debuffs=" + debuffs + " | timed=" + timed + " | names=" + names.join(",");
      }

      private function keyList(data:Object) : String
      {
         var names:Array = [];
         try
         {
            for(var name:String in data)
            {
               names.push(name);
               if(names.length >= 8) break;
            }
         }
         catch(keyError:*) { return "unreadable"; }
         names.sort();
         return names.join(",");
      }

      private function nodeName(node:DisplayObject) : String
      {
         var name:String = "";
         try { name = getQualifiedClassName(node); } catch(nameError:*) { name = "unknown"; }
         var cut:int = name.lastIndexOf("::");
         if(cut >= 0) name = name.substr(cut + 2);
         cut = name.lastIndexOf(".");
         if(cut >= 0) name = name.substr(cut + 1);
         return name;
      }

      private function errorText(error:*) : String
      {
         var text:String = "unprintable";
         try { text = String(error); } catch(ignored:*) { return text; }
         var cleaned:String = "";
         var index:int = 0;
         while(index < text.length && cleaned.length < 160)
         {
            var letter:String = text.charAt(index);
            cleaned += (letter == "\n" || letter == "\r" || letter == "|") ? " " : letter;
            index++;
         }
         return cleaned;
      }

      // PersonalEffectsData and EnvironmentEffectsData are the watch's reduced effect list. Heading churn is left out of the summary.
      public function noteWatch(channel:String, data:Object) : void
      {
         if(this.stopped || (channel != "PersonalEffectsData" && channel != "EnvironmentEffectsData")) return;
         try
         {
            var summary:String = this.watchSummary(channel,data);
            if(summary == this.lastWatch[channel]) return;
            this.lastWatch[channel] = summary;
            trace("VWHUD TRACE | watchdata | t=" + getTimer() + " | " + summary);
         }
         catch(watchError:*)
         {
            trace("VWHUD TRACE | watchdata | t=" + getTimer() + " | channel=" + channel + " | error=" + this.errorText(watchError));
         }
      }

      private function watchSummary(channel:String, data:Object) : String
      {
         if(data == null) return "channel=" + channel + " | data=null";
         var rows:Object = this.readNamed(data,"aPersonalEffects");
         if(!(rows is Array)) rows = this.readNamed(data,"aEnvironmentEffects");
         var icons:Array = [];
         var names:Array = [];
         var times:Array = [];
         var rowKeys:String = "";
         if(rows is Array)
         {
            var index:int = 0;
            while(index < (rows as Array).length && index < 8)
            {
               var row:Object = (rows as Array)[index];
               if(rowKeys == "" && row != null) rowKeys = this.keyList(row);
               var icon:String = this.valueText(this.readNamed(row,"sEffectIcon"));
               if(icon != "") icons.push(icon);
               var label:String = this.valueText(this.readNamed(row,"sName"));
               if(label == "") label = this.valueText(this.readNamed(row,"sDescription"));
               if(label != "") names.push(label);
               var remaining:* = this.readNamed(row,"fTimeRemaining");
               if(remaining == null) remaining = this.readNamed(row,"fDuration");
               if(remaining != null && isFinite(Number(remaining))) times.push(String(int(Math.round(Number(remaining)))));
               index++;
            }
         }
         return "channel=" + channel + " | count=" + (rows is Array ? (rows as Array).length : -1) + " | root=" + this.keyList(data) + " | rowkeys=" + rowKeys + " | icons=" + icons.join(",") + " | names=" + names.join(",") + " | times=" + times.join(",");
      }

      private function readNamed(source:Object, name:String) : *
      {
         if(source == null) return null;
         try { return source[name]; }
         catch(readError:*) { return null; }
      }

      private function valueText(value:*) : String
      {
         if(value == null) return "";
         var kind:String = typeof value;
         if(kind == "string") return this.clip(String(value));
         if(kind == "boolean") return value === true ? "1" : "0";
         if(kind == "number") return isFinite(Number(value)) ? String(Number(value)) : "";
         return "";
      }

      private function clip(text:String) : String
      {
         var cleaned:String = "";
         var index:int = 0;
         while(index < text.length && cleaned.length < 40)
         {
            var letter:String = text.charAt(index);
            cleaned += (letter == "\n" || letter == "\r" || letter == "|" || letter == ",") ? " " : letter;
            index++;
         }
         return cleaned;
      }

      private function report(message:String, force:Boolean) : void
      {
         var now:int = getTimer();
         if(!force && message == this.lastAttempt && now - this.lastAttemptAt < 15000) return;
         this.lastAttempt = message;
         this.lastAttemptAt = now;
         trace("VWHUD TRACE | playerstatus | t=" + now + " | " + message);
      }
   }
}
