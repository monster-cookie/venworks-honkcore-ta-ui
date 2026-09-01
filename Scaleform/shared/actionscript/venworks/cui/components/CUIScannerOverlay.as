package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.display.Shape;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.Timer;
   import venworks.cui.CUIPaletteResolver;
   import venworks.cui.CUITextFieldHost;

   public final class CUIScannerOverlay extends CUIComponent
   {
      private static const GRID_COLUMNS:int = 5;
      private static const GRID_ROWS:int = 5;
      private static const PULSE_RING_THRESHOLDS:Array = [1,2,4,5,8];
      private static const PULSE_HOLD_STEPS:int = 1;
      private static const HARD_MAX_TARGETS:int = 5;
      private static const RAD_TO_DEG:Number = 180 / Math.PI;
      private static const HEADING_LABELS:Array = ["N","NE","E","SE","S","SW","W","NW"];

      private var fieldOfView:Number;
      private var section:String;
      private var showHash:Boolean;
      private var showData:Boolean;
      private var maximumTargets:int;
      private var pulseIntervalMs:int;
      private var scanningColor:uint;
      private var gridColor:uint;
      private var contactColor:uint;
      private var hostileColor:uint;
      private var backgroundColor:uint;
      private var gridShape:Shape;
      private var headingField:TextField;
      private var contactFields:Array;
      private var pulseTimer:Timer;
      private var pulseStep:int;

      public function CUIScannerOverlay(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,param2);
         mouseEnabled = false;
         mouseChildren = false;
         fieldOfView = Math.max(30,Math.min(180,this.readNumber(param1,"fieldOfView",90)));
         section = param1.@section.length() == 1 ? String(param1.@section) : "both";
         showHash = section != "data";
         showData = section != "hash";
         maximumTargets = Math.max(1,Math.min(HARD_MAX_TARGETS,
            int(this.readNumber(param1,"maxTargets",HARD_MAX_TARGETS))));
         pulseIntervalMs = Math.max(50,Math.min(2000,
            int(this.readNumber(param1,"flickerIntervalMs",140))));
         scanningColor = this.readColor(param1,"scanningColor",0x62DDF2);
         gridColor = this.readColor(param1,"gridColor",0xFFB51B);
         contactColor = this.readColor(param1,"contactColor",0xF2F7F9);
         hostileColor = this.readColor(param1,"hostileColor",0xFF5A5A);
         backgroundColor = this.readColor(param1,"backgroundColor",0x020B10);
         contactFields = [];
         this.createOverlay();
         pulseTimer = new Timer(pulseIntervalMs);
         pulseTimer.addEventListener(TimerEvent.TIMER,this.onPulseTimer);
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE,this.onRemovedFromStage);
         this.updateData(null);
      }

      public function updateData(param1:Object) : void
      {
         var direction:Number = param1 == null ? 0 : Number(param1.direction);
         var targets:Array = param1 == null ? null : param1.scannerTargets as Array;
         if(!this.isFiniteNumber(direction))
         {
            direction = 0;
         }
         if(showHash)
         {
            this.updateHeading(direction);
         }
         if(showData)
         {
            this.updateContacts(targets,direction);
         }
      }

      public function updateVisibilityState() : void
      {
         if(!showHash)
         {
            return;
         }
         if(this.isEffectivelyVisible())
         {
            if(!pulseTimer.running)
            {
               pulseStep = 0;
               this.drawGrid();
               pulseTimer.start();
            }
            return;
         }
         pulseTimer.stop();
         pulseTimer.reset();
         pulseStep = 0;
         this.drawGrid();
      }

      private function createOverlay() : void
      {
         var panelShape:Shape = new Shape();
         if(showHash)
         {
            panelShape.graphics.lineStyle(1,scanningColor,0.86);
            panelShape.graphics.beginFill(backgroundColor,0.76);
            panelShape.graphics.drawRect(componentWidth / 2 - 112,0,224,26);
            panelShape.graphics.endFill();
         }
         if(showData)
         {
            panelShape.graphics.lineStyle(1,contactColor,0.64);
            panelShape.graphics.beginFill(backgroundColor,0.72);
            panelShape.graphics.drawRect(componentWidth - 270,156,260,146);
            panelShape.graphics.endFill();
         }
         addChild(panelShape);

         if(showHash)
         {
            headingField = this.createTextField(componentWidth / 2 - 108,4,216,19,11,scanningColor,"center",true);
            gridShape = new Shape();
            this.drawGrid();
            gridShape.alpha = 1;
            addChild(gridShape);
         }
         if(showData)
         {
            this.createTextField(componentWidth - 262,162,244,18,9,scanningColor,"left",true).text =
               "FORWARD CONTACTS // DIR / RANGE";
            this.createContactFields();
         }
      }

      private function createContactFields() : void
      {
         var index:int = 0;
         var field:TextField = null;
         while(index < HARD_MAX_TARGETS)
         {
            field = this.createTextField(componentWidth - 262,184 + index * 21,244,18,9,contactColor,"left",true);
            contactFields.push(field);
            ++index;
         }
      }

      private function createTextField(param1:Number, param2:Number, param3:Number, param4:Number,
         param5:Number, param6:uint, param7:String, param8:Boolean) : TextField
      {
         var host:CUITextFieldHost = new CUITextFieldHost();
         var field:TextField = host.field;
         var format:TextFormat = field.defaultTextFormat;
         host.x = param1;
         host.y = param2;
         field.width = param3;
         field.height = param4;
         field.selectable = false;
         field.mouseEnabled = false;
         format.size = param5;
         format.color = param6;
         format.align = param7;
         format.bold = param8;
         field.defaultTextFormat = format;
         field.text = "";
         field.setTextFormat(format);
         addChild(host);
         return field;
      }

      private function drawGrid() : void
      {
         if(gridShape == null)
         {
            return;
         }
         var centerX:Number = componentWidth / 2;
         var centerY:Number = componentHeight / 2;
         var spacing:Number = Math.min(54,Math.max(30,componentHeight / 9));
         var centerColumn:int = int(GRID_COLUMNS / 2);
         var centerRow:int = int(GRID_ROWS / 2);
         var column:int = 0;
         var row:int = 0;
         var columnOffset:int = 0;
         var rowOffset:int = 0;
         var distanceSquared:int = 0;
         var xPosition:Number = 0;
         var yPosition:Number = 0;
         gridShape.graphics.clear();
         while(row < GRID_ROWS)
         {
            column = 0;
            while(column < GRID_COLUMNS)
            {
               if(column != centerColumn || row != centerRow)
               {
                  columnOffset = column - centerColumn;
                  rowOffset = row - centerRow;
                  distanceSquared = columnOffset * columnOffset + rowOffset * rowOffset;
                  xPosition = centerX + columnOffset * spacing;
                  yPosition = centerY + rowOffset * spacing;
                  if(this.isPulseReached(distanceSquared))
                  {
                     this.drawDot(xPosition,yPosition);
                  }
                  else
                  {
                     this.drawSquare(xPosition,yPosition);
                  }
               }
               ++column;
            }
            ++row;
         }
      }

      private function isPulseReached(param1:int) : Boolean
      {
         var ringIndex:int = 0;
         if(pulseStep <= 0)
         {
            return false;
         }
         ringIndex = Math.min(pulseStep,PULSE_RING_THRESHOLDS.length) - 1;
         return param1 <= int(PULSE_RING_THRESHOLDS[ringIndex]);
      }

      private function drawSquare(param1:Number, param2:Number) : void
      {
         var halfSize:Number = 4;
         gridShape.graphics.lineStyle(2,gridColor,1);
         gridShape.graphics.drawRect(param1 - halfSize,param2 - halfSize,halfSize * 2,halfSize * 2);
      }

      private function drawDot(param1:Number, param2:Number) : void
      {
         gridShape.graphics.lineStyle(0,gridColor,0);
         gridShape.graphics.beginFill(gridColor,1);
         gridShape.graphics.drawCircle(param1,param2,3.5);
         gridShape.graphics.endFill();
      }

      private function updateHeading(param1:Number) : void
      {
         var degrees:Number = this.normalizeDegrees(param1 * RAD_TO_DEG);
         var displayDegrees:int = int(Math.round(degrees)) % 360;
         var headingIndex:int = int(Math.round(degrees / 45)) % HEADING_LABELS.length;
         headingField.text = "SCANNING // HDG " + this.padNumber(displayDegrees,3) + " " +
            HEADING_LABELS[headingIndex];
         headingField.setTextFormat(headingField.defaultTextFormat);
      }

      private function updateContacts(param1:Array, param2:Number) : void
      {
         var candidates:Array = [];
         var halfField:Number = fieldOfView * Math.PI / 360;
         var source:Object = null;
         var heading:Number = NaN;
         var distance:Number = NaN;
         var delta:Number = NaN;
         var index:int = 0;
         while(param1 != null && index < param1.length)
         {
            source = param1[index];
            heading = source == null ? NaN : Number(source.heading);
            distance = source == null ? NaN : Number(source.distance);
            delta = this.normalizeRadians(heading - param2);
            if(source != null && this.isFiniteNumber(heading) && this.isFiniteNumber(distance) && distance >= 0 &&
               this.isFiniteNumber(delta) && Math.abs(delta) <= halfField)
            {
               candidates.push({ target:source, delta:delta });
            }
            ++index;
         }
         candidates.sort(this.compareTargets);
         this.renderContacts(candidates);
      }

      private function renderContacts(param1:Array) : void
      {
         var count:int = Math.min(param1.length,maximumTargets);
         var entry:Object = null;
         var target:Object = null;
         var field:TextField = null;
         var format:TextFormat = null;
         var index:int = 0;
         if(count == 0)
         {
            field = contactFields[0] as TextField;
            field.text = "NO VALID CONTACTS";
            format = field.defaultTextFormat;
            format.color = contactColor;
            field.setTextFormat(format);
            field.visible = true;
            index = 1;
         }
         while(index < count)
         {
            entry = param1[index];
            target = entry.target;
            field = contactFields[index] as TextField;
            field.text = String(target.codename) + "  " + this.formatBearing(Number(entry.delta)) + "  " +
               this.padNumber(Math.round(Number(target.distance)),5);
            format = field.defaultTextFormat;
            format.color = uint(target.markerType) == 5 ? hostileColor : contactColor;
            field.setTextFormat(format);
            field.visible = true;
            ++index;
         }
         while(index < contactFields.length)
         {
            contactFields[index].visible = false;
            ++index;
         }
      }

      private function compareTargets(param1:Object, param2:Object) : Number
      {
         var distanceDifference:Number = Number(param1.target.distance) - Number(param2.target.distance);
         if(distanceDifference != 0)
         {
            return distanceDifference;
         }
         var handleDifference:Number = Number(param1.target.handle) - Number(param2.target.handle);
         if(handleDifference != 0)
         {
            return handleDifference;
         }
         return uint(param1.target.markerType) - uint(param2.target.markerType);
      }

      private function formatBearing(param1:Number) : String
      {
         var degrees:int = Math.round(Math.abs(param1 * RAD_TO_DEG));
         if(degrees == 0)
         {
            return "C" + this.padNumber(0,3);
         }
         return (param1 < 0 ? "L" : "R") + this.padNumber(degrees,3);
      }

      private function padNumber(param1:Number, param2:int) : String
      {
         var value:int = Math.max(0,Math.round(param1));
         var text:String = value.toString();
         while(text.length < param2)
         {
            text = "0" + text;
         }
         return text;
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

      private function isFiniteNumber(param1:Number) : Boolean
      {
         return !isNaN(param1) && isFinite(param1);
      }

      private function isEffectivelyVisible() : Boolean
      {
         var current:DisplayObject = this;
         if(stage == null)
         {
            return false;
         }
         while(current != null)
         {
            if(!current.visible)
            {
               return false;
            }
            current = current.parent;
         }
         return true;
      }

      private function onAddedToStage(param1:Event) : void
      {
         this.updateVisibilityState();
      }

      private function onRemovedFromStage(param1:Event) : void
      {
         pulseTimer.stop();
         pulseTimer.reset();
         pulseStep = 0;
         this.drawGrid();
      }

      private function onPulseTimer(param1:TimerEvent) : void
      {
         if(!this.isEffectivelyVisible())
         {
            this.updateVisibilityState();
            return;
         }
         if(pulseStep >= PULSE_RING_THRESHOLDS.length + PULSE_HOLD_STEPS)
         {
            pulseStep = 0;
         }
         else
         {
            ++pulseStep;
         }
         this.drawGrid();
      }
   }
}
