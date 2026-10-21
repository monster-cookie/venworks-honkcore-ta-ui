package
{
   import flash.display.Shape;
   import flash.display.Sprite;

   // The round contact radar. Contacts stay display objects in the VWHUD movie.
   public final class VWHudContactRadar extends Sprite
   {
      private static const CONTACTS:int = 32;
      private static const RANGE:Number = 1000;
      // Enemy, companion, parked ship, player position, and vehicle. Location markers stay off this display.
      private static const TRACKED:Array = [5,8,10,13,14];
      private static const STRUCTURES:Array = [10,13,14];

      private var contacts:Array;
      private var sizePx:Number;

      public function VWHudContactRadar(size:Number)
      {
         super();
         this.sizePx = size;
         this.contacts = [];
         mouseEnabled = false;
         mouseChildren = false;
         var index:int = 0;
         while(index < CONTACTS)
         {
            var contact:Sprite = new Sprite();
            contact.mouseEnabled = false;
            contact.mouseChildren = false;
            contact.addChild(this.dot(0xFF5A5A,false));
            contact.addChild(this.dot(0xF2F7F9,false));
            contact.addChild(this.dot(0xF2F7F9,true));
            contact.visible = false;
            this.contacts.push(contact);
            addChild(contact);
            ++index;
         }
         var player:Shape = new Shape();
         player.graphics.beginFill(0xA76BFF,1);
         player.graphics.drawRect(-4,-4,8,8);
         player.graphics.endFill();
         player.x = size / 2;
         player.y = size / 2;
         addChild(player);
      }

      public static function describeContact(source:Object, enemyList:Boolean) : Object
      {
         if(source == null) return null;
         var handle:Number = Number(VWHudViewModel.field(source,"uiHandle"));
         if(!isFinite(handle) || handle == 0) return null;
         var type:int = int(Number(VWHudViewModel.field(source,"uiMarkerIconType")));
         if(!isFinite(type)) type = 0;
         if(!enemyList && TRACKED.indexOf(type) < 0) return null;
         var headingValue:* = VWHudViewModel.field(source,"fHeading");
         if(headingValue == null || !isFinite(Number(headingValue))) return null;
         var fraction:Number = contactFraction(VWHudViewModel.field(source,"fDistanceToPlayer"),VWHudViewModel.field(source,"fDistance"));
         if(!isFinite(fraction)) return null;
         return {heading:Number(headingValue),fraction:fraction,alpha:VWHudViewModel.field(source,"fDistanceAlpha"),enemy:enemyList || type == 5,structure:!enemyList && type != 5 && STRUCTURES.indexOf(type) >= 0};
      }

      public function update(compass:Object) : void
      {
         var direction:Number = compass == null ? 0 : Number(VWHudViewModel.field(compass,"fDirection"));
         if(!isFinite(direction)) direction = 0;
         var seen:Object = {};
         var next:int = this.drawList(VWHudViewModel.collection(compass,"aEnemyMarkers"),0,direction,true,seen);
         next = this.drawList(VWHudViewModel.collection(compass,"aMarkers"),next,direction,false,seen);
         while(next < this.contacts.length)
         {
            Sprite(this.contacts[next]).visible = false;
            ++next;
         }
      }

      private function drawList(sources:Array, next:int, direction:Number, enemy:Boolean, seen:Object) : int
      {
         var index:int = 0;
         var checked:int = 0;
         while(sources != null && index < sources.length && next < this.contacts.length && checked < 256)
         {
            ++checked;
            var source:Object = sources[index];
            var described:Object = describeContact(source,enemy);
            var handle:String = source == null ? "" : String(VWHudViewModel.field(source,"uiHandle"));
            if(described != null && seen[handle] !== true)
            {
               seen[handle] = true;
               if(this.drawContact(this.contacts[next] as Sprite,described,direction)) ++next;
            }
            ++index;
         }
         return next;
      }

      private function drawContact(contact:Sprite, described:Object, direction:Number) : Boolean
      {
         contact.visible = false;
         var heading:Number = Number(described.heading);
         var fraction:Number = Number(described.fraction);
         if(!isFinite(heading) || !isFinite(fraction)) return false;
         var angle:Number = Math.PI - direction;
         var vx:Number = -Math.sin(angle);
         var vy:Number = Math.cos(angle);
         var rx:Number = Math.cos(heading) * vx - Math.sin(heading) * vy;
         var ry:Number = Math.sin(heading) * vx + Math.cos(heading) * vy;
         var radius:Number = this.sizePx * 0.5 * fraction;
         contact.x = this.sizePx / 2 + rx * radius;
         contact.y = this.sizePx / 2 + ry * radius;
         if(!isFinite(contact.x + contact.y)) return false;
         contact.alpha = this.clamp(described.alpha,0,1,1);
         contact.getChildAt(0).visible = described.enemy === true;
         contact.getChildAt(1).visible = described.enemy !== true && described.structure !== true;
         contact.getChildAt(2).visible = described.structure === true;
         contact.visible = true;
         return true;
      }

      private function dot(color:uint, square:Boolean) : Shape
      {
         var shape:Shape = new Shape();
         shape.graphics.beginFill(color,1);
         if(square) shape.graphics.drawRect(-3.5,-3.5,7,7);
         else shape.graphics.drawCircle(0,0,3);
         shape.graphics.endFill();
         shape.visible = false;
         return shape;
      }

      private static function contactFraction(meters:*, fallback:*) : Number
      {
         var distance:Number = NaN;
         if(meters != null) distance = Number(meters);
         else if(fallback != null)
         {
            distance = Number(fallback);
            if(isFinite(distance) && distance >= 0 && distance <= 1) distance *= RANGE;
         }
         else return 0.72;
         if(!isFinite(distance) || distance < 0 || distance > RANGE) return NaN;
         return distance / RANGE;
      }

      private function clamp(value:*, minimum:Number, maximum:Number, fallback:Number) : Number
      {
         var number:Number = Number(value);
         if(!isFinite(number)) return fallback;
         return Math.max(minimum,Math.min(maximum,number));
      }
   }
}
