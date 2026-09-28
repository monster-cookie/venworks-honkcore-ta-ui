package
{
   import flash.display.DisplayObject;
   import flash.display.InteractiveObject;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.text.TextField;
   import flash.text.TextFormat;
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
         this.ticks = new Shape();
         addChild(this.ticks);
         var index:int = 0;
         while(index < LABELS)
         {
            var field:TextField = new TextField();
            field.width = 36;
            field.height = 16;
            field.selectable = false;
            field.mouseEnabled = false;
            field.embedFonts = false;
            var format:TextFormat = new TextFormat("$MAIN_Font_Bold",11,0xF4FBFF,true);
            format.align = "center";
            field.defaultTextFormat = format;
            field.text = "";
            var host:Sprite = new Sprite();
            host.addChild(field);
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
                  host.x = x - 18;
                  host.y = this.heightPx - 28;
                  TextField(host.getChildAt(0)).text = HEADINGS[int(Math.round(absolute / 45)) % 8];
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
         var type:uint = uint(this.number(this.markerValue(source,"uiMarkerIconType")));
         var stamp:String = String(this.number(this.markerValue(source,"uiHandle"))) + "|" + type + "|" + this.number(this.markerValue(source,"uMapMarkerType")) + "|" + this.number(this.markerValue(source,"uMapMarkerCategory")) + "|" + this.number(this.markerValue(source,"uLocationMarkerState")) + "|" + this.number(this.markerValue(source,"uiRelativeMarkerHeightType")) + "|" + this.number(this.markerValue(source,"uiMapMarkerSubCategoryType")) + "|" + (source.isEnvironmentEffect === true ? String(this.markerValue(source,"sEffectIcon")) : "");
         if(stamp == entry.stamp) return;
         var painted:Boolean = marker != null && this.markerUtility != null && type != 0;
         if(painted)
         {
            try
            {
               var frame:String = String(this.markerUtility["GetMajorFrameFromMitMarkerType"](type));
               var clip:MovieClip = MovieClip(marker);
               clip.gotoAndStop(frame);
               if(frame.length == 0 || frame == "null" || frame == "undefined") painted = false;
               // The in operator misses sealed widget methods, so the location icon never replaced the generic dot.
               var widget:Object = marker;
               if(type == LOCATIONS && widget["SetLocation"] is Function) widget["SetLocation"](uint(this.number(this.markerValue(source,"uMapMarkerType"))),uint(this.number(this.markerValue(source,"uMapMarkerCategory"))),uint(this.number(this.markerValue(source,"uLocationMarkerState"))));
               else if(widget["ClearLocation"] is Function) widget["ClearLocation"]();
               var relative:int = int(this.number(this.markerValue(source,"uiRelativeMarkerHeightType")));
               if(relative > 0 && relative < RELATIVE.length && widget["SetFrame"] is Function) widget["SetFrame"](RELATIVE[relative],false);
               var category:int = int(this.number(this.markerValue(source,"uiMapMarkerSubCategoryType")));
               if(category > 0 && category < CATEGORY.length && widget["SetFrame"] is Function) widget["SetFrame"](CATEGORY[category],true);
               var effect:String = source.isEnvironmentEffect === true ? String(this.markerValue(source,"sEffectIcon")) : "";
               if(effect.length > 0)
               {
                  var icon:MovieClip = widget["MarkerIcon_mc"] as MovieClip;
                  if(icon != null) icon.gotoAndStop(effect.substr(0,96));
               }
            }
            catch(paintError:*) { painted = false; }
         }
         if(marker != null) marker.visible = painted;
         fallback.visible = !painted;
         if(!painted) this.drawFallback(fallback,type);
         if(painted || marker == null) entry.stamp = stamp;
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
