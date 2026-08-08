package venworks.cui.components
{
   import flash.display.Sprite;
   import venworks.cui.CUISvgPathParser;

   public class CUIMask extends CUIComponent
   {
      private var contentLayer:Sprite;
      private var maskShape:Sprite;

      public function CUIMask(param1:XML)
      {
         super(param1);
         contentLayer = new Sprite();
         maskShape = new Sprite();
         addChild(contentLayer);
         addChild(maskShape);
         maskShape.graphics.beginFill(16777215,1);
         if(String(param1.@shape) == "ellipse")
         {
            maskShape.graphics.drawEllipse(0,0,componentWidth,componentHeight);
         }
         else if(String(param1.@shape) == "path")
         {
            CUISvgPathParser.draw(
               maskShape.graphics,
               String(param1.@data),
               Number(param1.@viewBoxX),
               Number(param1.@viewBoxY),
               componentWidth / Number(param1.@viewBoxWidth),
               componentHeight / Number(param1.@viewBoxHeight)
            );
         }
         else
         {
            maskShape.graphics.drawRect(0,0,componentWidth,componentHeight);
         }
         maskShape.graphics.endFill();
         contentLayer.mask = maskShape;
      }

      public function get content() : Sprite
      {
         return contentLayer;
      }
   }
}
