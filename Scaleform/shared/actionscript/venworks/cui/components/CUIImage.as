package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.geom.ColorTransform;
   import flash.geom.Rectangle;

   public class CUIImage extends CUIComponent
   {
      protected var content:DisplayObject;

      public function CUIImage(param1:XML, param2:DisplayObject)
      {
         super(param1);
         if(param2 == null)
         {
            throw new Error("INVALID|Asset is unavailable: " + String(param1.@id));
         }
         try
         {
            if(param2.width <= 0 || param2.height <= 0)
            {
               throw new Error("Asset has no renderable dimensions.");
            }
         }
         catch(param3:Error)
         {
            throw this.phaseError("dimension inspection",param1,param3);
         }
         content = param2;
         try
         {
            addChild(content);
         }
         catch(param4:Error)
         {
            throw this.phaseError("display-list attachment",param1,param4);
         }
         try
         {
            this.applyTint(param1);
         }
         catch(param5:Error)
         {
            throw this.phaseError("tint application",param1,param5);
         }
         try
         {
            this.fitContent(param1);
         }
         catch(param6:Error)
         {
            throw this.phaseError("fit and alignment",param1,param6);
         }
         try
         {
            scrollRect = new Rectangle(0,0,componentWidth,componentHeight);
         }
         catch(param7:Error)
         {
            throw this.phaseError("clipping setup",param1,param7);
         }
      }

      private function phaseError(param1:String, param2:XML, param3:Error) : Error
      {
         return new Error("INVALID|Asset " + param1 + " failed: " + String(param2.@id) + ". " + param3.toString());
      }

      private function applyTint(param1:XML) : void
      {
         var color:uint = 0;
         if(param1.@color.length() == 0)
         {
            return;
         }
         color = readColor(String(param1.@color));
         content.transform.colorTransform = new ColorTransform(
            0,0,0,1,
            color >> 16 & 255,
            color >> 8 & 255,
            color & 255,
            0
         );
      }

      private function fitContent(param1:XML) : void
      {
         var fit:String = param1.@fit.length() == 1 ? String(param1.@fit) : "contain";
         var originalWidth:Number = content.width;
         var originalHeight:Number = content.height;
         var scale:Number = 1;
         if(fit == "stretch")
         {
            content.scaleX = componentWidth / originalWidth;
            content.scaleY = componentHeight / originalHeight;
         }
         else if(fit == "contain" || fit == "cover")
         {
            scale = fit == "contain" ?
               Math.min(componentWidth / originalWidth,componentHeight / originalHeight) :
               Math.max(componentWidth / originalWidth,componentHeight / originalHeight);
            content.scaleX = scale;
            content.scaleY = scale;
         }
         this.alignContent(param1);
      }

      private function alignContent(param1:XML) : void
      {
         var alignX:String = param1.@alignX.length() == 1 ? String(param1.@alignX) : "center";
         var alignY:String = param1.@alignY.length() == 1 ? String(param1.@alignY) : "center";
         if(alignX == "right")
         {
            content.x = componentWidth - content.width;
         }
         else if(alignX == "center")
         {
            content.x = (componentWidth - content.width) / 2;
         }
         if(alignY == "bottom")
         {
            content.y = componentHeight - content.height;
         }
         else if(alignY == "center")
         {
            content.y = (componentHeight - content.height) / 2;
         }
      }
   }
}
