package venworks.cui.components
{
   import flash.display.Shape;

   public final class CUIContactRadar extends CUIComponent
   {
      private static const MIT_MARKER_ENEMY:uint = 5;
      private static const MIT_MARKER_COMPANION:uint = 8;
      private static const MIT_MARKER_SHIP_PARKED:uint = 11;
      private static const MIT_MARKER_VEHICLE:uint = 15;
      private static const MAX_CONTACTS:int = 32;

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
            Shape(contacts[index]).visible = false;
            ++index;
         }
      }

      private function createContacts() : void
      {
         var index:int = 0;
         var marker:Shape = null;
         while(index < MAX_CONTACTS)
         {
            marker = new Shape();
            marker.visible = false;
            contacts.push(marker);
            addChild(marker);
            ++index;
         }
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
                type == MIT_MARKER_SHIP_PARKED || type == MIT_MARKER_VEHICLE))
            {
               this.renderContact(Shape(contacts[param2]),marker,param3 == null ? 0 : Number(param3.fDirection),
                  param4 == MIT_MARKER_ENEMY,type == MIT_MARKER_SHIP_PARKED || type == MIT_MARKER_VEHICLE);
               ++param2;
            }
            ++sourceIndex;
         }
         return param2;
      }

      private function renderContact(param1:Shape, param2:Object, param3:Number, param4:Boolean, param5:Boolean) : void
      {
         var heading:Number = Number(param2.fHeading);
         var angle:Number = Math.PI - param3;
         var vectorX:Number = -Math.sin(angle);
         var vectorY:Number = Math.cos(angle);
         var rotatedX:Number = Math.cos(heading) * vectorX - Math.sin(heading) * vectorY;
         var rotatedY:Number = Math.sin(heading) * vectorX + Math.cos(heading) * vectorY;
         var radius:Number = Math.min(componentWidth,componentHeight) * (Boolean(param2.bIsNear) ? 0.43 : 0.39);
         var scale:Number = param2.fDistanceScale === undefined || param2.fDistanceScale === null ? 1 : Number(param2.fDistanceScale);
         var markerAlpha:Number = param2.fDistanceAlpha === undefined || param2.fDistanceAlpha === null ? 1 : Number(param2.fDistanceAlpha);
         var size:Number = param5 ? 7 : 6;
         if(isNaN(scale) || scale <= 0)
         {
            scale = 1;
         }
         if(isNaN(markerAlpha))
         {
            markerAlpha = 1;
         }
         param1.graphics.clear();
         param1.graphics.beginFill(param4 ? enemyColor : allyColor,1);
         if(param5)
         {
            param1.graphics.drawRect(-size / 2,-size / 2,size,size);
         }
         else
         {
            param1.graphics.drawCircle(0,0,size / 2);
         }
         param1.graphics.endFill();
         param1.x = componentWidth / 2 + rotatedX * radius;
         param1.y = componentHeight / 2 + rotatedY * radius;
         param1.scaleX = scale;
         param1.scaleY = scale;
         param1.alpha = Math.max(0,Math.min(1,markerAlpha));
         param1.visible = true;
      }
   }
}
