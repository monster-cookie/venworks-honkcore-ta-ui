package
{
   import flash.display.Shape;
   import flash.display.Sprite;

   // The round contact radar. Contacts stay display objects in the VWHUD movie.
   public final class VWHudContactRadar extends Sprite
   {
      private static const CONTACTS:int = 32;
      private static const ALLIES:Array = [8,10,13,14];
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

      public function update(compass:Object) : void
      {
         var direction:Number = compass == null ? 0 : Number(VWHudViewModel.field(compass,"fDirection"));
         if(!isFinite(direction)) direction = 0;
         var next:int = this.drawList(VWHudViewModel.collection(compass,"aEnemyMarkers"),0,direction,true);
         next = this.drawList(VWHudViewModel.collection(compass,"aMarkers"),next,direction,false);
         while(next < this.contacts.length)
         {
            Sprite(this.contacts[next]).visible = false;
            ++next;
         }
      }

      private function drawList(sources:Array, next:int, direction:Number, enemy:Boolean) : int
      {
         var index:int = 0;
         var checked:int = 0;
         while(sources != null && index < sources.length && next < this.contacts.length && checked < 256)
         {
            ++checked;
            var source:Object = sources[index];
            var type:int = int(this.number(VWHudViewModel.field(source,"uiMarkerIconType")));
            if(source != null && this.number(VWHudViewModel.field(source,"uiHandle")) != 0 && (enemy || ALLIES.indexOf(type) >= 0))
            {
               if(this.drawContact(this.contacts[next] as Sprite,source,direction,enemy,STRUCTURES.indexOf(type) >= 0)) ++next;
            }
            ++index;
         }
         return next;
      }

      private function drawContact(contact:Sprite, source:Object, direction:Number, enemy:Boolean, structure:Boolean) : Boolean
      {
         contact.visible = false;
         var distanceValue:* = VWHudViewModel.field(source,"fDistanceToPlayer");
         var headingValue:* = VWHudViewModel.field(source,"fHeading");
         if(distanceValue == null || headingValue == null) return false;
         var distance:Number = this.number(distanceValue);
         var heading:Number = this.number(headingValue);
         if(distance < 0 || distance > 200) return false;
         var angle:Number = Math.PI - direction;
         var vx:Number = -Math.sin(angle);
         var vy:Number = Math.cos(angle);
         var rx:Number = Math.cos(heading) * vx - Math.sin(heading) * vy;
         var ry:Number = Math.sin(heading) * vx + Math.cos(heading) * vy;
         var radius:Number = this.sizePx * 0.5 * distance / 200;
         contact.x = this.sizePx / 2 + rx * radius;
         contact.y = this.sizePx / 2 + ry * radius;
         if(!isFinite(contact.x + contact.y)) return false;
         contact.alpha = this.clamp(VWHudViewModel.field(source,"fDistanceAlpha"),0,1,1);
         contact.getChildAt(0).visible = enemy;
         contact.getChildAt(1).visible = !enemy && !structure;
         contact.getChildAt(2).visible = structure;
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
   }
}
