package venworks.cui.components
{
   import Shared.MapMarkerUtils;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getDefinitionByName;
   import venworks.cui.CUITextFieldHost;

   public final class CUICompassTape extends CUIComponent
   {
      private static const MAX_MARKERS:int = 48;
      private static const MAX_HEADING_LABELS:int = 7;
      private static const TICK_DEGREES:Number = 5;
      private static const MEDIUM_TICK_DEGREES:Number = 15;
      private static const MAJOR_TICK_DEGREES:Number = 45;
      private static const RAD_TO_DEG:Number = 180 / Math.PI;
      private static const MIT_MARKER_LOCATIONS:uint = 7;
      private static const RELATIVE_FRAME_LABELS:Array = ["","BelowPlayer","LevelWithPlayer","AbovePlayer"];
      private static const MAP_MARKER_SUBCATEGORY_LABELS:Array = ["","Undiscovered","Discovered","Targeted"];
      private static const HEADING_LABELS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      private var tickShape:Shape;
      private var centerShape:Shape;
      private var headingFields:Array;
      private var markerEntries:Array;
      private var fieldOfView:Number;
      private var tickColor:uint;
      private var headingColor:uint;
      private var centerColor:uint;
      private var fallbackColor:uint;
      private var markerClass:Class;

      public function CUICompassTape(param1:XML)
      {
         super(param1);
         fieldOfView = this.readNumber(param1,"fieldOfView",120);
         tickColor = this.readColor(param1,"tickColor",0x62DDF2);
         headingColor = this.readColor(param1,"headingColor",0xF2F7F9);
         centerColor = this.readColor(param1,"centerColor",0xFFB51B);
         fallbackColor = this.readColor(param1,"fallbackColor",0xF2F7F9);
         headingFields = [];
         markerEntries = [];
         this.resolveMarkerClass();
         this.createTape();
         this.createMarkerPool();
         this.drawTape(0);
      }

      public function updateData(param1:Object) : void
      {
         var direction:Number = param1 == null ? 0 : Number(param1.direction);
         var markers:Array = param1 == null ? null : param1.markers as Array;
         if(!this.isFiniteNumber(direction))
         {
            direction = 0;
         }
         this.drawTape(direction);
         this.renderMarkers(markers,direction);
      }

      private function resolveMarkerClass() : void
      {
         try
         {
            markerClass = getDefinitionByName("CompassMarkerWidget") as Class;
         }
         catch(param1:Error)
         {
            markerClass = null;
         }
      }

      private function createTape() : void
      {
         var index:int = 0;
         var host:CUITextFieldHost = null;
         var field:TextField = null;
         var format:TextFormat = null;
         tickShape = new Shape();
         addChild(tickShape);
         while(index < MAX_HEADING_LABELS)
         {
            host = new CUITextFieldHost();
            field = host.field;
            field.width = 44;
            field.height = 18;
            field.selectable = false;
            field.mouseEnabled = false;
            format = field.defaultTextFormat;
            format.size = 10;
            format.color = headingColor;
            format.bold = true;
            format.align = "center";
            field.defaultTextFormat = format;
            field.text = "";
            field.setTextFormat(format);
            host.visible = false;
            headingFields.push({ host:host, field:field });
            addChild(host);
            ++index;
         }
         centerShape = new Shape();
         centerShape.graphics.beginFill(centerColor,1);
         centerShape.graphics.moveTo(componentWidth / 2 - 4,0);
         centerShape.graphics.lineTo(componentWidth / 2 + 4,0);
         centerShape.graphics.lineTo(componentWidth / 2,7);
         centerShape.graphics.lineTo(componentWidth / 2 - 4,0);
         centerShape.graphics.endFill();
         addChild(centerShape);
      }

      private function createMarkerPool() : void
      {
         var index:int = 0;
         var host:Sprite = null;
         var marker:DisplayObject = null;
         var fallback:Shape = null;
         while(index < MAX_MARKERS)
         {
            host = new Sprite();
            marker = this.createVanillaMarker();
            fallback = new Shape();
            fallback.visible = marker == null;
            if(marker != null)
            {
               host.addChild(marker);
            }
            host.addChild(fallback);
            host.visible = false;
            markerEntries.push({ host:host, marker:marker, fallback:fallback });
            addChild(host);
            ++index;
         }
      }

      private function createVanillaMarker() : DisplayObject
      {
         var marker:DisplayObject = null;
         if(markerClass == null)
         {
            return null;
         }
         try
         {
            marker = new markerClass() as DisplayObject;
         }
         catch(param1:Error)
         {
            marker = null;
         }
         return marker;
      }

      private function drawTape(param1:Number) : void
      {
         var halfField:Number = Math.max(30,Math.min(180,fieldOfView)) / 2;
         var centerDegrees:Number = this.normalizeDegrees(param1 * RAD_TO_DEG);
         var firstDegrees:Number = Math.floor((centerDegrees - halfField) / TICK_DEGREES) * TICK_DEGREES;
         var heading:Number = firstDegrees;
         var delta:Number = 0;
         var absoluteHeading:Number = 0;
         var xPosition:Number = 0;
         var tickHeight:Number = 0;
         var major:Boolean = false;
         var medium:Boolean = false;
         var labelIndex:int = 0;
         var labelEntry:Object = null;
         var format:TextFormat = null;
         tickShape.graphics.clear();
         tickShape.graphics.lineStyle(1,tickColor,0.72);
         while(heading <= centerDegrees + halfField + TICK_DEGREES)
         {
            delta = this.normalizeSignedDegrees(heading - centerDegrees);
            if(Math.abs(delta) <= halfField + 0.001)
            {
               absoluteHeading = this.normalizeDegrees(heading);
               major = Math.round(absoluteHeading) % int(MAJOR_TICK_DEGREES) == 0;
               medium = Math.round(absoluteHeading) % int(MEDIUM_TICK_DEGREES) == 0;
               tickHeight = major ? 10 : medium ? 7 : 4;
               xPosition = componentWidth / 2 + delta / halfField * componentWidth / 2;
               tickShape.graphics.moveTo(xPosition,componentHeight - tickHeight);
               tickShape.graphics.lineTo(xPosition,componentHeight);
               if(major && labelIndex < headingFields.length)
               {
                  labelEntry = headingFields[labelIndex];
                  labelEntry.host.x = xPosition - 22;
                  labelEntry.host.y = componentHeight - 29;
                  labelEntry.field.text = HEADING_LABELS[int(Math.round(absoluteHeading / MAJOR_TICK_DEGREES)) % HEADING_LABELS.length];
                  format = labelEntry.field.defaultTextFormat;
                  labelEntry.field.setTextFormat(format);
                  labelEntry.host.visible = true;
                  ++labelIndex;
               }
            }
            heading += TICK_DEGREES;
         }
         while(labelIndex < headingFields.length)
         {
            headingFields[labelIndex].host.visible = false;
            ++labelIndex;
         }
      }

      private function renderMarkers(param1:Array, param2:Number) : void
      {
         var halfRadians:Number = Math.max(30,Math.min(180,fieldOfView)) * Math.PI / 360;
         var sourceIndex:int = 0;
         var outputIndex:int = 0;
         var marker:Object = null;
         var heading:Number = NaN;
         var delta:Number = NaN;
         var entry:Object = null;
         while(param1 != null && sourceIndex < param1.length && outputIndex < markerEntries.length)
         {
            marker = param1[sourceIndex];
            heading = marker == null ? NaN : Number(marker.fHeading);
            delta = this.normalizeRadians(heading - param2);
            if(marker != null && this.isFiniteNumber(heading) && Math.abs(delta) <= halfRadians)
            {
               entry = markerEntries[outputIndex];
               entry.host.x = componentWidth / 2 + delta / halfRadians * componentWidth / 2;
               entry.host.y = 20;
               entry.host.alpha = this.readMarkerAlpha(marker);
               entry.host.scaleX = 0.48 * this.readMarkerScale(marker);
               entry.host.scaleY = entry.host.scaleX;
               this.updateMarkerVisual(entry,marker);
               entry.host.visible = true;
               ++outputIndex;
            }
            ++sourceIndex;
         }
         while(outputIndex < markerEntries.length)
         {
            markerEntries[outputIndex].host.visible = false;
            ++outputIndex;
         }
      }

      private function updateMarkerVisual(param1:Object, param2:Object) : void
      {
         var marker:Object = param1.marker;
         var fallback:Shape = param1.fallback as Shape;
         var majorFrame:String = "";
         var markerIcon:MovieClip = null;
         var relativeType:int = 0;
         var subcategory:int = 0;
         var succeeded:Boolean = marker != null;
         if(succeeded)
         {
            try
            {
               majorFrame = MapMarkerUtils.GetMajorFrameFromMitMarkerType(uint(param2.uiMarkerIconType));
               MovieClip(marker).gotoAndStop(majorFrame);
               if(uint(param2.uiMarkerIconType) == MIT_MARKER_LOCATIONS && marker["SetLocation"] is Function)
               {
                  marker["SetLocation"](param2.uMapMarkerType,param2.uMapMarkerCategory,param2.uLocationMarkerState);
               }
               else if(marker["ClearLocation"] is Function)
               {
                  marker["ClearLocation"]();
               }
               relativeType = param2.uiRelativeMarkerHeightType === undefined || param2.uiRelativeMarkerHeightType === null ?
                  0 : int(param2.uiRelativeMarkerHeightType);
               if(relativeType > 0 && relativeType < RELATIVE_FRAME_LABELS.length && marker["SetFrame"] is Function)
               {
                  marker["SetFrame"](RELATIVE_FRAME_LABELS[relativeType],false);
               }
               subcategory = param2.uiMapMarkerSubCategoryType === undefined || param2.uiMapMarkerSubCategoryType === null ?
                  0 : int(param2.uiMapMarkerSubCategoryType);
               if(subcategory > 0 && subcategory < MAP_MARKER_SUBCATEGORY_LABELS.length && marker["SetFrame"] is Function)
               {
                  marker["SetFrame"](MAP_MARKER_SUBCATEGORY_LABELS[subcategory],true);
               }
               if(Boolean(param2.isEnvironmentEffect) && param2.sEffectIcon !== undefined &&
                  param2.sEffectIcon !== null)
               {
                  markerIcon = marker["MarkerIcon_mc"] as MovieClip;
                  if(markerIcon != null)
                  {
                     markerIcon.gotoAndStop(String(param2.sEffectIcon));
                  }
               }
            }
            catch(param3:Error)
            {
               succeeded = false;
            }
         }
         if(param1.marker != null)
         {
            DisplayObject(param1.marker).visible = succeeded;
         }
         fallback.visible = !succeeded;
         if(!succeeded)
         {
            this.drawFallbackMarker(fallback,uint(param2.uiMarkerIconType));
         }
      }

      private function drawFallbackMarker(param1:Shape, param2:uint) : void
      {
         var color:uint = param2 == 5 ? 0xFF5A5A : param2 == 12 ? 0xFFB51B : fallbackColor;
         param1.graphics.clear();
         param1.graphics.beginFill(color,1);
         param1.graphics.moveTo(0,-7);
         param1.graphics.lineTo(6,5);
         param1.graphics.lineTo(0,2);
         param1.graphics.lineTo(-6,5);
         param1.graphics.lineTo(0,-7);
         param1.graphics.endFill();
      }

      private function readMarkerAlpha(param1:Object) : Number
      {
         var value:Number = param1.fDistanceAlpha === undefined || param1.fDistanceAlpha === null ?
            1 : Number(param1.fDistanceAlpha);
         return this.isFiniteNumber(value) ? Math.max(0,Math.min(1,value)) : 1;
      }

      private function readMarkerScale(param1:Object) : Number
      {
         var value:Number = param1.fDistanceScale === undefined || param1.fDistanceScale === null ?
            1 : Number(param1.fDistanceScale);
         return this.isFiniteNumber(value) ? Math.max(0.5,Math.min(1.5,value)) : 1;
      }

      private function normalizeRadians(param1:Number) : Number
      {
         if(!this.isFiniteNumber(param1))
         {
            return NaN;
         }
         while(param1 > Math.PI)
         {
            param1 -= Math.PI * 2;
         }
         while(param1 < -Math.PI)
         {
            param1 += Math.PI * 2;
         }
         return param1;
      }

      private function normalizeDegrees(param1:Number) : Number
      {
         param1 %= 360;
         if(param1 < 0)
         {
            param1 += 360;
         }
         return param1;
      }

      private function normalizeSignedDegrees(param1:Number) : Number
      {
         param1 = this.normalizeDegrees(param1);
         return param1 > 180 ? param1 - 360 : param1;
      }

      private function isFiniteNumber(param1:Number) : Boolean
      {
         return !isNaN(param1) && isFinite(param1);
      }
   }
}
