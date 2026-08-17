package venworks.cui.components
{
   import flash.display.Shape;
   import flash.display.Sprite;

   public final class CUIContactRadar extends CUIComponent
   {
      private static const MIT_MARKER_ENEMY:uint = 5;
      private static const MIT_MARKER_COMPANION:uint = 8;
      private static const MIT_MARKER_SHIP_PARKED:uint = 10;
      private static const MIT_MARKER_POSITION:uint = 13;
      private static const MIT_MARKER_VEHICLE:uint = 14;
      private static const MAX_DISTANCE:Number = 200;
      private static const MAX_CONTACTS:int = 32;
      private static const STYLE_ENEMY:int = 0;
      private static const STYLE_ALLY:int = 1;
      private static const STYLE_STRUCTURE:int = 2;

      private var contacts:Array;
      private var playerMarker:Shape;
      private var enemyColor:uint;
      private var allyColor:uint;
      private var playerColor:uint;

      public function CUIContactRadar(param1:XML)
      {
         super(param1);
         enemyColor = this.readColor(param1,"enemyColor",0xFF5A5A);
         allyColor = this.readColor(param1,"allyColor",0xF2F7F9);
         playerColor = this.readColor(param1,"playerColor",0xA76BFF);
         contacts = [];
         this.createContacts();
         this.createPlayerMarker();
      }

      public function updateData(param1:Object) : void
      {
         var index:int = 0;
         var general:Array = param1 == null ? null : param1.aMarkers as Array;
         var enemies:Array = param1 == null ? null : param1.aEnemyMarkers as Array;
         index = this.renderArray(enemies,index,param1,MIT_MARKER_ENEMY);
         index = this.renderArray(general,index,param1,0);
         while(index < contacts.length)
         {
            Sprite(contacts[index]).visible = false;
            ++index;
         }
      }

      private function createContacts() : void
      {
         var index:int = 0;
         var marker:Sprite = null;
         while(index < MAX_CONTACTS)
         {
            marker = this.createContactMarker();
            contacts.push(marker);
            addChild(marker);
            ++index;
         }
      }

      private function createContactMarker() : Sprite
      {
         var marker:Sprite = new Sprite();
         marker.addChild(this.createContactShape(enemyColor,false));
         marker.addChild(this.createContactShape(allyColor,false));
         marker.addChild(this.createContactShape(allyColor,true));
         marker.scaleX = 1;
         marker.scaleY = 1;
         marker.visible = false;
         return marker;
      }

      private function createContactShape(param1:uint, param2:Boolean) : Shape
      {
         var marker:Shape = new Shape();
         marker.graphics.beginFill(param1,1);
         if(param2)
         {
            marker.graphics.drawRect(-3.5,-3.5,7,7);
         }
         else
         {
            marker.graphics.drawCircle(0,0,3);
         }
         marker.graphics.endFill();
         marker.visible = false;
         return marker;
      }

      private function createPlayerMarker() : void
      {
         playerMarker = new Shape();
         playerMarker.graphics.beginFill(playerColor,1);
         playerMarker.graphics.drawRect(-4,-4,8,8);
         playerMarker.graphics.endFill();
         playerMarker.x = componentWidth / 2;
         playerMarker.y = componentHeight / 2;
         addChild(playerMarker);
      }

      private function renderArray(param1:Array, param2:int, param3:Object, param4:uint) : int
      {
         var sourceIndex:int = 0;
         var marker:Object = null;
         var type:uint = 0;
         while(param1 != null && sourceIndex < param1.length && param2 < contacts.length)
         {
            marker = param1[sourceIndex];
            type = marker == null ? 0 : uint(marker.uiMarkerIconType);
            if(marker != null && Number(marker.uiHandle) != 0 &&
               (param4 == MIT_MARKER_ENEMY || type == MIT_MARKER_COMPANION ||
                type == MIT_MARKER_SHIP_PARKED || type == MIT_MARKER_POSITION ||
                type == MIT_MARKER_VEHICLE))
            {
               if(this.renderContact(Sprite(contacts[param2]),marker,param3 == null ? 0 : Number(param3.fDirection),
                  param4 == MIT_MARKER_ENEMY,type == MIT_MARKER_SHIP_PARKED ||
                  type == MIT_MARKER_POSITION || type == MIT_MARKER_VEHICLE))
               {
                  ++param2;
               }
            }
            ++sourceIndex;
         }
         return param2;
      }

      private function renderContact(param1:Sprite, param2:Object, param3:Number, param4:Boolean, param5:Boolean) : Boolean
      {
         param1.visible = false;
         if(param2.fDistanceToPlayer === undefined || param2.fDistanceToPlayer === null)
         {
            return false;
         }
         var distance:Number = Number(param2.fDistanceToPlayer);
         if(!this.isFiniteNumber(distance) || distance < 0 || distance > MAX_DISTANCE ||
            param2.fHeading === undefined || param2.fHeading === null || !this.isFiniteNumber(param3))
         {
            return false;
         }
         var heading:Number = Number(param2.fHeading);
         if(!this.isFiniteNumber(heading))
         {
            return false;
         }
         var angle:Number = Math.PI - param3;
         var vectorX:Number = -Math.sin(angle);
         var vectorY:Number = Math.cos(angle);
         var rotatedX:Number = Math.cos(heading) * vectorX - Math.sin(heading) * vectorY;
         var rotatedY:Number = Math.sin(heading) * vectorX + Math.cos(heading) * vectorY;
         var radius:Number = Math.min(componentWidth,componentHeight) * 0.5 * (distance / MAX_DISTANCE);
         var contactX:Number = componentWidth / 2 + rotatedX * radius;
         var contactY:Number = componentHeight / 2 + rotatedY * radius;
         if(!this.isFiniteNumber(vectorX) || !this.isFiniteNumber(vectorY) ||
            !this.isFiniteNumber(rotatedX) || !this.isFiniteNumber(rotatedY) ||
            !this.isFiniteNumber(radius) || !this.isFiniteNumber(contactX) || !this.isFiniteNumber(contactY))
         {
            return false;
         }
         var markerAlpha:Number = param2.fDistanceAlpha === undefined || param2.fDistanceAlpha === null ? 1 : Number(param2.fDistanceAlpha);
         if(!this.isFiniteNumber(markerAlpha))
         {
            markerAlpha = 1;
         }
         this.selectContactStyle(param1,param4 ? STYLE_ENEMY : param5 ? STYLE_STRUCTURE : STYLE_ALLY);
         param1.x = contactX;
         param1.y = contactY;
         param1.scaleX = 1;
         param1.scaleY = 1;
         param1.alpha = Math.max(0,Math.min(1,markerAlpha));
         param1.visible = true;
         return true;
      }

      private function selectContactStyle(param1:Sprite, param2:int) : void
      {
         var index:int = 0;
         while(index < param1.numChildren)
         {
            param1.getChildAt(index).visible = index == param2;
            ++index;
         }
      }

      private function isFiniteNumber(param1:Number) : Boolean
      {
         return !isNaN(param1) && isFinite(param1);
      }
   }
}
