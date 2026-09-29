package
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.InteractiveObject;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.geom.Rectangle;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.utils.getDefinitionByName;

   // The top-strip compass. Ticks, labels, and the game marker widgets live on this strip.
   public final class VWHudCompassTape extends Sprite
   {
      private static const MARKERS:int = 48;
      private static const LABELS:int = 7;
      private static const LOCATIONS:uint = 7;
      private static const RELATIVE:Array = ["","BelowPlayer","LevelWithPlayer","AbovePlayer"];
      private static const CATEGORY:Array = ["","Undiscovered","Discovered","Targeted"];
      private static const HEADINGS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      private var ticks:Shape;
      private var labels:Array;
      private var entries:Array;
      private var markerType:Class;
      private var markerUtility:Class;
      private var widthPx:Number;
      private var heightPx:Number;
      private var iconLoader:Loader;
      private var iconContent:DisplayObject;
      private var iconDomain:ApplicationDomain;
      private var iconUrls:Array;
      private var iconAttempt:int;
      private var iconWait:int;

      public function VWHudCompassTape(width:Number, height:Number)
      {
         super();
         this.widthPx = width;
         this.heightPx = height;
         mouseEnabled = false;
         mouseChildren = false;
         this.labels = [];
         this.entries = [];
         try { this.markerType = getDefinitionByName("CompassMarkerWidget") as Class; }
         catch(defineError:*) { this.markerType = null; }
         try { this.markerUtility = getDefinitionByName("Shared.MapMarkerUtils") as Class; }
         catch(utilityError:*) { this.markerUtility = null; }
         var plate:Shape = new Shape();
         plate.graphics.beginFill(0x0D1114,0.88);
         plate.graphics.drawRect(0,0,width,height);
         plate.graphics.endFill();
         addChild(plate);
         this.ticks = new Shape();
         addChild(this.ticks);
         var index:int = 0;
         while(index < LABELS)
         {
            var mark:Shape = new Shape();
            var host:Sprite = new Sprite();
            host.addChild(mark);
            host.visible = false;
            host.mouseEnabled = false;
            host.mouseChildren = false;
            this.labels.push(host);
            addChild(host);
            ++index;
         }
         var caret:Shape = new Shape();
         caret.graphics.beginFill(0xFFB51B,1);
         caret.graphics.moveTo(width / 2 - 4,0);
         caret.graphics.lineTo(width / 2 + 4,0);
         caret.graphics.lineTo(width / 2,7);
         caret.graphics.endFill();
         addChild(caret);
         index = 0;
         while(index < MARKERS)
         {
            var markerHost:Sprite = new Sprite();
            markerHost.mouseEnabled = false;
            markerHost.mouseChildren = false;
            markerHost.visible = false;
            var marker:DisplayObject = this.createMarker();
            var fallback:Shape = new Shape();
            fallback.visible = marker == null;
            if(marker != null) markerHost.addChild(marker);
            markerHost.addChild(fallback);
            this.entries.push({host:markerHost,marker:marker,fallback:fallback});
            addChild(markerHost);
            ++index;
         }
         this.update(0,null);
      }

      public function update(direction:Number, markers:Array) : void
      {
         if(!isFinite(direction)) direction = 0;
         this.drawTicks(direction);
         this.drawMarkers(markers,direction);
      }

      private function createMarker() : DisplayObject
      {
         if(this.markerType == null) return null;
         var marker:DisplayObject = null;
         try { marker = new this.markerType() as DisplayObject; }
         catch(createError:*) { return null; }
         if(marker == null) return null;
         marker.visible = false;
         if(marker is InteractiveObject) InteractiveObject(marker).mouseEnabled = false;
         if(marker is Sprite) Sprite(marker).mouseChildren = false;
         // BitmapData.draw of this widget throws TypeError 2077. Its own added-to-stage listener throws ReferenceError 1069, so that listener is stopped and the widget stays on the strip.
         marker.addEventListener(Event.ADDED_TO_STAGE,VWHudCompassTape.blockStageHook,true,10000,true);
         marker.addEventListener(Event.ADDED_TO_STAGE,VWHudCompassTape.blockStageHook,false,10000,true);
         return marker;
      }

      private static function blockStageHook(event:Event) : void
      {
         event.stopImmediatePropagation();
      }

      private function drawTicks(direction:Number) : void
      {
         var center:Number = this.degrees(direction * 180 / Math.PI);
         var first:Number = Math.floor((center - 60) / 5) * 5;
         var labelIndex:int = 0;
         this.ticks.graphics.clear();
         this.ticks.graphics.lineStyle(1,0x62DDF2,0.72);
         var heading:Number = first;
         while(heading <= center + 65)
         {
            var delta:Number = this.signed(heading - center);
            if(Math.abs(delta) <= 60)
            {
               var absolute:int = Math.round(this.degrees(heading));
               var major:Boolean = absolute % 45 == 0;
               var medium:Boolean = absolute % 15 == 0;
               var x:Number = this.widthPx / 2 + delta / 60 * this.widthPx / 2;
               var tickHeight:Number = major ? 10 : medium ? 7 : 4;
               this.ticks.graphics.moveTo(x,this.heightPx - tickHeight);
               this.ticks.graphics.lineTo(x,this.heightPx);
               if(major && labelIndex < this.labels.length)
               {
                  var host:Sprite = this.labels[labelIndex] as Sprite;
                  var headingName:String = String(HEADINGS[int(Math.round(absolute / 45)) % 8]);
                  this.drawHeading(Shape(host.getChildAt(0)),headingName);
                  host.x = x - (headingName.length > 1 ? 7 : 3);
                  host.y = this.heightPx - 12;
                  host.visible = true;
                  ++labelIndex;
               }
            }
            heading += 5;
         }
         while(labelIndex < this.labels.length)
         {
            Sprite(this.labels[labelIndex]).visible = false;
            ++labelIndex;
         }
      }

      private function drawMarkers(markers:Array, direction:Number) : void
      {
         var sourceIndex:int = 0;
         var outputIndex:int = 0;
         var checked:int = 0;
         while(markers != null && sourceIndex < markers.length && outputIndex < this.entries.length && checked < 256)
         {
            ++checked;
            var source:Object = markers[sourceIndex];
            var heading:Number = this.number(VWHudViewModel.field(source,"fHeading"));
            var delta:Number = this.radians(heading - direction);
            if(source != null && isFinite(delta) && Math.abs(delta) <= Math.PI / 3)
            {
               var entry:Object = this.entries[outputIndex];
               var host:Sprite = entry.host as Sprite;
               try
               {
                  host.x = this.widthPx / 2 + delta / (Math.PI / 3) * this.widthPx / 2;
                  host.y = 20;
                  host.alpha = this.clamp(VWHudViewModel.field(source,"fDistanceAlpha"),0,1,1);
                  host.scaleX = host.scaleY = 0.48 * this.clamp(VWHudViewModel.field(source,"fDistanceScale"),0.5,1.5,1);
                  this.paintMarker(entry,source);
                  host.visible = true;
               }
               catch(markerError:*)
               {
                  host.visible = false;
               }
               ++outputIndex;
            }
            ++sourceIndex;
         }
         while(outputIndex < this.entries.length)
         {
            Sprite(this.entries[outputIndex].host).visible = false;
            ++outputIndex;
         }
      }

      private function paintMarker(entry:Object, source:Object) : void
      {
         var marker:DisplayObject = entry.marker as DisplayObject;
         var fallback:Shape = entry.fallback as Shape;
         var widget:Object = marker;
         var type:uint = uint(this.number(this.markerValue(source,"uiMarkerIconType")));
         var stamp:String = String(this.number(this.markerValue(source,"uiHandle"))) + "|" + type + "|" + this.number(this.markerValue(source,"uMapMarkerType")) + "|" + this.number(this.markerValue(source,"uMapMarkerCategory")) + "|" + this.number(this.markerValue(source,"uLocationMarkerState")) + "|" + this.number(this.markerValue(source,"uiRelativeMarkerHeightType")) + "|" + this.number(this.markerValue(source,"uiMapMarkerSubCategoryType")) + "|" + (source.isEnvironmentEffect === true ? String(this.markerValue(source,"sEffectIcon")) : "");
         var waiting:Boolean = false;
         if(type == LOCATIONS && widget != null)
         {
            try { waiting = Boolean(widget.needsLocationLoaded); }
            catch(waitError:*) { waiting = true; }
         }
         if(stamp != entry.stamp || waiting) this.paintMarkerFrame(entry,source,marker,fallback,widget,type,stamp);
         this.placeLocationIcon(entry,marker,fallback,widget,source,type);
      }

      private function paintMarkerFrame(entry:Object, source:Object, marker:DisplayObject, fallback:Shape, widget:Object, type:uint, stamp:String) : void
      {
         var painted:Boolean = marker != null && this.markerUtility != null && type != 0;
         if(painted)
         {
            try
            {
               var frame:String = String(this.markerUtility["GetMajorFrameFromMitMarkerType"](type));
               var clip:MovieClip = MovieClip(marker);
               if(frame.length == 0 || frame == "null" || frame == "undefined") painted = false;
               else if(clip.currentFrameLabel != frame) clip.gotoAndStop(frame);
            }
            catch(frameError:*) { painted = false; }
         }
         if(painted && type != LOCATIONS)
         {
            try
            {
               if(widget.PoiIcon_mc != null) widget.ClearLocation();
            }
            catch(clearError:*) {}
         }
         if(painted)
         {
            var relative:int = int(this.number(this.markerValue(source,"uiRelativeMarkerHeightType")));
            if(relative > 0 && relative < RELATIVE.length) this.callMarker(widget,"SetFrame",RELATIVE[relative],false,null);
            var category:int = int(this.number(this.markerValue(source,"uiMapMarkerSubCategoryType")));
            if(category > 0 && category < CATEGORY.length) this.callMarker(widget,"SetFrame",CATEGORY[category],true,null);
            var effect:String = source.isEnvironmentEffect === true ? String(this.markerValue(source,"sEffectIcon")) : "";
            if(effect.length > 0)
            {
               try
               {
                  var icon:MovieClip = widget.MarkerIcon_mc as MovieClip;
                  if(icon != null) icon.gotoAndStop(effect.substr(0,96));
               }
               catch(effectError:*) {}
            }
         }
         if(marker != null) marker.visible = painted;
         fallback.visible = !painted;
         if(!painted) this.drawFallback(fallback,type);
         if(painted || marker == null) entry.stamp = stamp;
      }

      private function placeLocationIcon(entry:Object, marker:DisplayObject, fallback:Shape, widget:Object, source:Object, type:uint) : void
      {
         if(widget == null || type != LOCATIONS)
         {
            this.clearOwnIcon(entry);
            return;
         }
         var mapType:uint = uint(this.number(this.markerValue(source,"uMapMarkerType")));
         var category:uint = uint(this.number(this.markerValue(source,"uMapMarkerCategory")));
         var state:uint = uint(this.number(this.markerValue(source,"uLocationMarkerState")));
         var sub:int = int(this.number(this.markerValue(source,"uiMapMarkerSubCategoryType")));
         this.callMarker(widget,"SetLocation",mapType,category,state);
         if(sub > 0 && sub < CATEGORY.length) this.callMarker(widget,"SetFrame",CATEGORY[sub],true,null);
         if(this.poiHasArt(widget))
         {
            this.clearOwnIcon(entry);
            if(marker != null) marker.visible = true;
            fallback.visible = false;
            return;
         }
         var icon:MovieClip = this.ownIcon(entry,this.iconName(mapType,category,state),state,sub,widget);
         if(icon == null)
         {
            this.pumpIconLoad();
            return;
         }
         var host:Sprite = entry.host as Sprite;
         if(icon.parent !== host) host.addChild(icon);
         if(marker != null) marker.visible = false;
         fallback.visible = false;
      }

      private function poiHasArt(widget:Object) : Boolean
      {
         var hasArt:Boolean = false;
         try
         {
            var poi:DisplayObjectContainer = widget.PoiIcon_mc as DisplayObjectContainer;
            hasArt = poi != null && poi.numChildren > 0;
         }
         catch(artError:*) { hasArt = false; }
         return hasArt;
      }

      private function iconName(mapType:uint, category:uint, state:uint) : String
      {
         var name:String = "";
         if(this.markerUtility != null)
         {
            try
            {
               if(state == 2) name = String(this.markerUtility["GetSymbolName"](mapType));
               else if(state == 1) name = String(this.markerUtility["GetGenericSymbolName"](mapType,category));
               else name = String(this.markerUtility["GetUnknownSymbolName"](category));
            }
            catch(nameError:*) { name = ""; }
         }
         return name;
      }

      private function ownIcon(entry:Object, name:String, state:uint, category:int, widget:Object) : MovieClip
      {
         if(name == null || name.length == 0 || name == "null" || name == "undefined") return null;
         var current:MovieClip = entry.ownIcon as MovieClip;
         if(current != null && entry.iconName == name) return current;
         var type:Class = this.iconClass(name,widget);
         if(type == null) return null;
         var created:MovieClip = null;
         try { created = new type() as MovieClip; }
         catch(createError:*) { return null; }
         if(created == null) return null;
         created.mouseEnabled = false;
         created.mouseChildren = false;
         var frame:String = state == 2 ? "Discovered" : "";
         if(category > 0 && category < CATEGORY.length) frame = String(CATEGORY[category]);
         if(frame.length > 0)
         {
            try { if(created.currentFrameLabel != frame) created.gotoAndStop(frame); }
            catch(frameError:*) {}
         }
         var bounds:Rectangle = created.getBounds(created);
         if(!bounds.isEmpty() && bounds.width >= 1 && bounds.height >= 1)
         {
            var fit:Number = 36 / Math.max(bounds.width,bounds.height);
            created.scaleX = created.scaleY = fit;
            created.x = -(bounds.x + bounds.width * 0.5) * fit;
            created.y = -(bounds.y + bounds.height * 0.5) * fit;
         }
         this.clearOwnIcon(entry);
         entry.ownIcon = created;
         entry.iconName = name;
         return created;
      }

      private function iconClass(name:String, widget:Object) : Class
      {
         var type:Class = this.definition(ApplicationDomain.currentDomain,name);
         if(type == null && this.iconDomain != null) type = this.definition(this.iconDomain,name);
         if(type == null) type = this.definitionChain(widget,name);
         if(type == null) this.ensureIconLibrary(widget);
         return type;
      }

      private function definition(domain:ApplicationDomain, name:String) : Class
      {
         if(domain == null) return null;
         try { if(domain.hasDefinition(name)) return domain.getDefinition(name) as Class; }
         catch(defineError:*) {}
         return null;
      }

      private function definitionChain(widget:Object, name:String) : Class
      {
         var domain:ApplicationDomain = null;
         try { if(widget != null) domain = widget.loaderInfo.applicationDomain; }
         catch(domainError:*) { domain = null; }
         var guard:int = 0;
         while(domain != null && guard < 6)
         {
            var type:Class = this.definition(domain,name);
            if(type != null) return type;
            try { domain = domain.parentDomain; }
            catch(parentError:*) { domain = null; }
            ++guard;
         }
         return null;
      }

      private function ensureIconLibrary(widget:Object) : void
      {
         if(this.iconContent != null || this.iconLoader != null) return;
         if(this.iconUrls == null) this.iconUrls = this.buildIconUrls(widget);
         if(this.iconAttempt >= this.iconUrls.length) return;
         var url:String = String(this.iconUrls[this.iconAttempt]);
         ++this.iconAttempt;
         this.iconWait = 0;
         var loader:Loader = new Loader();
         loader.alpha = 0;
         loader.mouseEnabled = false;
         loader.mouseChildren = false;
         this.iconLoader = loader;
         addChild(loader);
         var info:LoaderInfo = loader.contentLoaderInfo;
         info.addEventListener(Event.COMPLETE,this.onIconLoad);
         info.addEventListener(IOErrorEvent.IO_ERROR,this.onIconError);
         info.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onIconError);
         try { loader.load(new URLRequest(url),new LoaderContext(false,ApplicationDomain.currentDomain)); }
         catch(loadError:*) { this.onIconError(null); }
      }

      private function buildIconUrls(widget:Object) : Array
      {
         var urls:Array = [];
         this.pushIconUrl(urls,this.siblingIconUrl(widget));
         this.pushIconUrl(urls,"MapIcons.swf");
         this.pushIconUrl(urls,"../../../MapIcons.swf");
         this.pushIconUrl(urls,"/MapIcons.swf");
         return urls;
      }

      private function siblingIconUrl(widget:Object) : String
      {
         var url:String = "";
         try { if(widget != null) url = String(widget.loaderInfo.url); }
         catch(urlError:*) { return ""; }
         var slash:int = url.lastIndexOf("/");
         var back:int = url.lastIndexOf("\\");
         var cut:int = slash > back ? slash : back;
         if(cut < 0 || url.length == 0) return "";
         return url.substring(0,cut + 1) + "MapIcons.swf";
      }

      private function pushIconUrl(urls:Array, url:String) : void
      {
         if(url == null || url.length == 0) return;
         var index:int = 0;
         while(index < urls.length)
         {
            if(String(urls[index]) == url) return;
            ++index;
         }
         urls.push(url);
      }

      private function pumpIconLoad() : void
      {
         if(this.iconLoader == null || this.iconContent != null) return;
         ++this.iconWait;
         if(this.iconWait > 20) this.onIconError(null);
      }

      private function onIconLoad(event:Event) : void
      {
         var info:LoaderInfo = event.target as LoaderInfo;
         if(info != null)
         {
            this.iconContent = info.content as DisplayObject;
            this.iconDomain = info.applicationDomain;
            if(this.iconContent != null) this.iconContent.alpha = 0;
         }
         this.iconWait = 0;
      }

      private function onIconError(event:Event) : void
      {
         var loader:Loader = this.iconLoader;
         this.iconLoader = null;
         this.iconContent = null;
         this.iconWait = 0;
         if(loader != null)
         {
            try
            {
               var info:LoaderInfo = loader.contentLoaderInfo;
               info.removeEventListener(Event.COMPLETE,this.onIconLoad);
               info.removeEventListener(IOErrorEvent.IO_ERROR,this.onIconError);
               info.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onIconError);
               if(loader.parent != null) loader.parent.removeChild(loader);
               loader.unload();
            }
            catch(releaseError:*) {}
         }
         this.ensureIconLibrary(null);
      }

      private function clearOwnIcon(entry:Object) : void
      {
         if(entry == null) return;
         var icon:DisplayObject = entry.ownIcon as DisplayObject;
         entry.ownIcon = null;
         entry.iconName = null;
         if(icon != null && icon.parent != null) icon.parent.removeChild(icon);
      }

      private function drawHeading(shape:Shape, label:String) : void
      {
         shape.graphics.clear();
         shape.graphics.lineStyle(1.25,0xF4FBFF,1);
         var index:int = 0;
         while(index < label.length)
         {
            this.drawLetter(shape,label.charAt(index),index * 8);
            ++index;
         }
      }

      private function drawLetter(shape:Shape, letter:String, x:Number) : void
      {
         var g:* = shape.graphics;
         if(letter == "N") { g.moveTo(x,9); g.lineTo(x,0); g.lineTo(x + 6,9); g.lineTo(x + 6,0); }
         else if(letter == "E") { g.moveTo(x + 6,0); g.lineTo(x,0); g.lineTo(x,9); g.lineTo(x + 6,9); g.moveTo(x,4.5); g.lineTo(x + 4,4.5); }
         else if(letter == "S") { g.moveTo(x + 6,1); g.lineTo(x + 1,1); g.lineTo(x + 1,4.5); g.lineTo(x + 5,4.5); g.lineTo(x + 5,8); g.lineTo(x,8); }
         else if(letter == "W") { g.moveTo(x,0); g.lineTo(x + 1.5,9); g.lineTo(x + 3,4); g.lineTo(x + 4.5,9); g.lineTo(x + 6,0); }
      }

      private function callMarker(widget:Object, name:String, arg1:*, arg2:*, arg3:*) : void
      {
         try
         {
            if(name == "SetLocation") widget.SetLocation(arg1,arg2,arg3);
            else if(name == "SetFrame") widget.SetFrame(arg1,arg2);
         }
         catch(callError:*) {}
      }

      private function markerValue(source:Object, name:String) : *
      {
         if(source == null) return null;
         try
         {
            var value:* = source[name];
            if(value != null) return value;
         }
         catch(readError:*) {}
         return VWHudViewModel.field(source,name);
      }

      private function drawFallback(shape:Shape, type:uint) : void
      {
         var color:uint = type == 5 ? 0xFF5A5A : type == 12 ? 0xFFB51B : 0xF2F7F9;
         shape.graphics.clear();
         shape.graphics.beginFill(color,1);
         shape.graphics.moveTo(0,-7);
         shape.graphics.lineTo(6,5);
         shape.graphics.lineTo(0,2);
         shape.graphics.lineTo(-6,5);
         shape.graphics.lineTo(0,-7);
         shape.graphics.endFill();
      }

      private function number(value:*) : Number
      {
         var number:Number = Number(value);
         return isFinite(number) ? number : 0;
      }

      private function clamp(value:*, minimum:Number, maximum:Number, fallback:Number) : Number
      {
         var number:Number = Number(value);
         if(!isFinite(number)) return fallback;
         return Math.max(minimum,Math.min(maximum,number));
      }

      private function radians(value:Number) : Number
      {
         if(!isFinite(value)) return NaN;
         while(value > Math.PI) value -= Math.PI * 2;
         while(value < -Math.PI) value += Math.PI * 2;
         return value;
      }

      private function degrees(value:Number) : Number
      {
         value %= 360;
         return value < 0 ? value + 360 : value;
      }

      private function signed(value:Number) : Number
      {
         value = this.degrees(value);
         return value > 180 ? value - 360 : value;
      }
   }
}
