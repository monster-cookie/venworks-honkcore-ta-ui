package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import scaleform.gfx.Extensions;
   import venworks.cui.components.CUIComponent;

   public final class CUILayoutEngine
   {
      private var rootLayer:DisplayObjectContainer;
      private var rootConfig:XML;
      private var rootSafeRect:Rectangle;

      public function CUILayoutEngine(param1:DisplayObjectContainer, param2:XML)
      {
         super();
         rootLayer = param1;
         rootConfig = param2;
         rootSafeRect = this.createRootSafeRect(param2,rootLayer);
      }

      public function position(param1:CUIComponent, param2:XML, param3:DisplayObjectContainer, param4:XML) : void
      {
         var anchor:String = null;
         var containerRect:Rectangle = null;
         var bounds:Rectangle = null;
         var targetX:Number = NaN;
         var targetY:Number = NaN;
         var currentX:Number = NaN;
         var currentY:Number = NaN;
         if(param2.@anchor.length() == 0)
         {
            return;
         }
         anchor = String(param2.@anchor);
         if(String(param4.name()) == "components")
         {
            containerRect = rootSafeRect;
         }
         else
         {
            containerRect = new Rectangle(0,0,Number(param4.@width),Number(param4.@height));
         }
         bounds = this.configuredBounds(param1,param2);
         targetX = this.anchorX(containerRect,anchor) + Number(param2.@x);
         targetY = this.anchorY(containerRect,anchor) + Number(param2.@y);
         currentX = this.anchorX(bounds,anchor);
         currentY = this.anchorY(bounds,anchor);
         param1.x += targetX - currentX;
         param1.y += targetY - currentY;
      }

      public function positionVanilla(param1:DisplayObject, param2:XML) : void
      {
         var parent:DisplayObjectContainer = null;
         var containerRect:Rectangle = null;
         var bounds:Rectangle = null;
         var anchor:String = null;
         var targetX:Number = NaN;
         var targetY:Number = NaN;
         var currentX:Number = NaN;
         var currentY:Number = NaN;
         if(param2.@anchor.length() == 0)
         {
            return;
         }
         parent = param1.parent;
         if(parent == null)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target has no display-list parent: " + String(param2.@id));
         }
         anchor = String(param2.@anchor);
         containerRect = this.createRootSafeRect(rootConfig,parent);
         bounds = param1.getBounds(parent);
         if(bounds.width <= 0 || bounds.height <= 0)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target has no positionable bounds: " + String(param2.@id));
         }
         targetX = this.anchorX(containerRect,anchor) + Number(param2.@x);
         targetY = this.anchorY(containerRect,anchor) + Number(param2.@y);
         currentX = this.anchorX(bounds,anchor);
         currentY = this.anchorY(bounds,anchor);
         param1.x += targetX - currentX;
         param1.y += targetY - currentY;
      }

      private function configuredBounds(param1:CUIComponent, param2:XML) : Rectangle
      {
         var matrix:Matrix = param1.transform.matrix;
         var topLeft:Point = matrix.transformPoint(new Point(0,0));
         var topRight:Point = matrix.transformPoint(new Point(Number(param2.@width),0));
         var bottomLeft:Point = matrix.transformPoint(new Point(0,Number(param2.@height)));
         var bottomRight:Point = matrix.transformPoint(new Point(Number(param2.@width),Number(param2.@height)));
         var left:Number = Math.min(topLeft.x,topRight.x,bottomLeft.x,bottomRight.x);
         var top:Number = Math.min(topLeft.y,topRight.y,bottomLeft.y,bottomRight.y);
         var right:Number = Math.max(topLeft.x,topRight.x,bottomLeft.x,bottomRight.x);
         var bottom:Number = Math.max(topLeft.y,topRight.y,bottomLeft.y,bottomRight.y);
         return new Rectangle(left,top,right - left,bottom - top);
      }

      private function createRootSafeRect(param1:XML, param2:DisplayObjectContainer) : Rectangle
      {
         var visible:Rectangle = Extensions.visibleRect;
         var topLeft:Point = null;
         var bottomRight:Point = null;
         var result:Rectangle = null;
         if(visible == null || visible.width <= 0 || visible.height <= 0)
         {
            result = new Rectangle(0,0,Number(param1.@designWidth),Number(param1.@designHeight));
         }
         else
         {
            topLeft = param2.globalToLocal(visible.topLeft);
            bottomRight = param2.globalToLocal(visible.bottomRight);
            result = new Rectangle(
               Math.min(topLeft.x,bottomRight.x),
               Math.min(topLeft.y,bottomRight.y),
               Math.abs(bottomRight.x - topLeft.x),
               Math.abs(bottomRight.y - topLeft.y)
            );
         }
         result.x += Number(param1.@safeLeft);
         result.y += Number(param1.@safeTop);
         result.width -= Number(param1.@safeLeft) + Number(param1.@safeRight);
         result.height -= Number(param1.@safeTop) + Number(param1.@safeBottom);
         if(result.width <= 0 || result.height <= 0)
         {
            throw new Error("INVALID|Safe-area insets leave no visible layout area.");
         }
         return result;
      }

      private function anchorX(param1:Rectangle, param2:String) : Number
      {
         if(param2 == "top-left" || param2 == "center-left" || param2 == "bottom-left")
         {
            return param1.left;
         }
         if(param2 == "top-center" || param2 == "center" || param2 == "bottom-center")
         {
            return param1.left + param1.width / 2;
         }
         if(param2 == "top-right" || param2 == "center-right" || param2 == "bottom-right")
         {
            return param1.right;
         }
         throw new Error("INVALID|Unsupported component anchor: " + param2);
      }

      private function anchorY(param1:Rectangle, param2:String) : Number
      {
         if(param2 == "top-left" || param2 == "top-center" || param2 == "top-right")
         {
            return param1.top;
         }
         if(param2 == "center-left" || param2 == "center" || param2 == "center-right")
         {
            return param1.top + param1.height / 2;
         }
         if(param2 == "bottom-left" || param2 == "bottom-center" || param2 == "bottom-right")
         {
            return param1.bottom;
         }
         throw new Error("INVALID|Unsupported component anchor: " + param2);
      }
   }
}
