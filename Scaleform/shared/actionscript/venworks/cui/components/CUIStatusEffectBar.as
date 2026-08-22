package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getDefinitionByName;
   import venworks.cui.CUIPaletteResolver;
   import venworks.cui.CUITextFieldHost;

   public final class CUIStatusEffectBar extends CUIComponent
   {
      private static const COLUMN_COUNT:int = 8;
      private static const ROW_COUNT:int = 2;
      private static const HARD_MAX_ITEMS:int = COLUMN_COUNT * ROW_COUNT;

      private var slots:Array;
      private var maximumItems:int;
      private var debuffColor:uint;
      private var sustenanceColor:uint;
      private var neutralColor:uint;
      private var backgroundColor:uint;
      private var effectWidgetClass:Class;

      public function CUIStatusEffectBar(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,param2);
         maximumItems = Math.max(1,Math.min(HARD_MAX_ITEMS,int(this.readNumber(param1,"maxItems",HARD_MAX_ITEMS))));
         debuffColor = this.readColor(param1,"debuffColor",0xFF5A5A);
         sustenanceColor = this.readColor(param1,"sustenanceColor",0x62DDF2);
         neutralColor = this.readColor(param1,"neutralColor",0xF2F7F9);
         backgroundColor = this.readColor(param1,"backgroundColor",0x020B10);
         slots = [];
         this.resolveEffectWidgetClass();
         this.createSlots();
         this.updateData(null);
      }

      public function updateData(param1:Object) : void
      {
         var statuses:Array = param1 == null ? null : param1.statuses as Array;
         var count:int = statuses == null ? 0 : statuses.length;
         var visibleEffects:int = Math.min(count,maximumItems);
         var overflow:int = count > maximumItems ? count - maximumItems + 1 : 0;
         var index:int = 0;
         if(overflow > 0)
         {
            visibleEffects = maximumItems - 1;
         }
         while(index < visibleEffects)
         {
            this.configureSlot(slots[index],statuses[index]);
            ++index;
         }
         if(overflow > 0 && index < slots.length)
         {
            this.configureOverflowSlot(slots[index],overflow);
            ++index;
         }
         while(index < slots.length)
         {
            slots[index].host.visible = false;
            ++index;
         }
      }

      private function resolveEffectWidgetClass() : void
      {
         try
         {
            effectWidgetClass = getDefinitionByName("PersonalEffectsWidget") as Class;
         }
         catch(param1:Error)
         {
            effectWidgetClass = null;
         }
      }

      private function createSlots() : void
      {
         var icons:Array = this.createEffectIcons();
         var slotWidth:Number = componentWidth / COLUMN_COUNT;
         var slotHeight:Number = componentHeight / ROW_COUNT;
         var index:int = 0;
         var column:int = 0;
         var row:int = 0;
         var host:Sprite = null;
         var background:Shape = null;
         var fallback:Shape = null;
         var labelHost:CUITextFieldHost = null;
         var label:TextField = null;
         var format:TextFormat = null;
         var icon:MovieClip = null;
         while(index < maximumItems)
         {
            column = index % COLUMN_COUNT;
            row = int(index / COLUMN_COUNT);
            host = new Sprite();
            host.x = column * slotWidth;
            host.y = row * slotHeight;
            host.visible = false;
            background = new Shape();
            host.addChild(background);
            icon = index < icons.length ? icons[index] as MovieClip : null;
            if(icon != null)
            {
               icon.visible = false;
               host.addChild(icon);
            }
            fallback = new Shape();
            this.drawFallbackIcon(fallback,neutralColor);
            fallback.x = 12;
            fallback.y = slotHeight / 2;
            host.addChild(fallback);
            labelHost = new CUITextFieldHost();
            label = labelHost.field;
            labelHost.x = 24;
            labelHost.y = 2;
            label.width = Math.max(0,slotWidth - 26);
            label.height = Math.max(0,slotHeight - 2);
            label.selectable = false;
            label.mouseEnabled = false;
            format = label.defaultTextFormat;
            format.size = 8;
            format.color = neutralColor;
            format.bold = true;
            format.align = "left";
            label.defaultTextFormat = format;
            host.addChild(labelHost);
            slots.push({
               host:host,
               background:background,
               icon:icon,
               fallback:fallback,
               label:label,
               width:slotWidth,
               height:slotHeight
            });
            addChild(host);
            ++index;
         }
      }

      private function createEffectIcons() : Array
      {
         var result:Array = [];
         var widget:Object = null;
         var icon:MovieClip = null;
         var display:DisplayObject = null;
         var widgetIndex:int = 0;
         var iconIndex:int = 0;
         if(effectWidgetClass == null)
         {
            return result;
         }
         while(result.length < maximumItems)
         {
            try
            {
               widget = new effectWidgetClass();
            }
            catch(param1:Error)
            {
               break;
            }
            iconIndex = 0;
            while(iconIndex < 5 && result.length < maximumItems)
            {
               icon = widget["BioCondition" + iconIndex.toString() + "_mc"] as MovieClip;
               if(icon != null)
               {
                  display = icon as DisplayObject;
                  if(display.parent != null)
                  {
                     display.parent.removeChild(display);
                  }
                  result.push(icon);
               }
               ++iconIndex;
            }
            ++widgetIndex;
            if(iconIndex == 0 || widgetIndex > 4)
            {
               break;
            }
         }
         return result;
      }

      private function configureSlot(param1:Object, param2:Object) : void
      {
         var color:uint = param2.kind == "debuff" ? debuffColor :
            param2.kind == "sustenance" ? sustenanceColor : neutralColor;
         var format:TextFormat = param1.label.defaultTextFormat;
         var iconSucceeded:Boolean = false;
         this.drawSlotBackground(param1.background,param1.width,param1.height,color);
         param1.label.text = String(param2.label);
         format.color = color;
         param1.label.defaultTextFormat = format;
         param1.label.setTextFormat(format);
         if(param1.icon != null)
         {
            try
            {
               param1.icon.gotoAndStop(String(param2.icon));
               param1.icon.width = 16;
               param1.icon.height = 16;
               param1.icon.x = 4;
               param1.icon.y = (Number(param1.height) - 16) / 2;
               param1.icon.visible = true;
               iconSucceeded = true;
            }
            catch(param3:Error)
            {
               param1.icon.visible = false;
            }
         }
         this.drawFallbackIcon(param1.fallback,color);
         param1.fallback.visible = !iconSucceeded;
         param1.host.visible = true;
      }

      private function configureOverflowSlot(param1:Object, param2:int) : void
      {
         var format:TextFormat = param1.label.defaultTextFormat;
         this.drawSlotBackground(param1.background,param1.width,param1.height,neutralColor);
         param1.label.text = "+" + param2.toString();
         format.color = neutralColor;
         param1.label.defaultTextFormat = format;
         param1.label.setTextFormat(format);
         if(param1.icon != null)
         {
            param1.icon.visible = false;
         }
         param1.fallback.visible = false;
         param1.host.visible = true;
      }

      private function drawSlotBackground(param1:Shape, param2:Number, param3:Number, param4:uint) : void
      {
         param1.graphics.clear();
         param1.graphics.lineStyle(1,param4,0.54);
         param1.graphics.beginFill(backgroundColor,0.68);
         param1.graphics.drawRect(1,1,Math.max(0,param2 - 2),Math.max(0,param3 - 2));
         param1.graphics.endFill();
      }

      private function drawFallbackIcon(param1:Shape, param2:uint) : void
      {
         param1.graphics.clear();
         param1.graphics.lineStyle(2,param2,0.9);
         param1.graphics.drawCircle(0,0,6);
         param1.graphics.moveTo(0,-4);
         param1.graphics.lineTo(0,2);
         param1.graphics.moveTo(0,4);
         param1.graphics.lineTo(0,5);
      }
   }
}
