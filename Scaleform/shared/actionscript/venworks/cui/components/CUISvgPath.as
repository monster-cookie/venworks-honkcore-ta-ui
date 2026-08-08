package venworks.cui.components
{
   import venworks.cui.CUISvgPathParser;

   public class CUISvgPath extends CUIComponent
   {
      public function CUISvgPath(param1:XML)
      {
         super(param1);
         graphics.lineStyle(
            this.readNumber(param1,"strokeWidth",0),
            this.readColor(param1,"strokeColor",16777215),
            this.readNumber(param1,"strokeOpacity",1)
         );
         graphics.beginFill(
            this.readColor(param1,"fillColor",16777215),
            this.readNumber(param1,"fillOpacity",1)
         );
         CUISvgPathParser.draw(
            graphics,
            String(param1.@data),
            Number(param1.@viewBoxX),
            Number(param1.@viewBoxY),
            componentWidth / Number(param1.@viewBoxWidth),
            componentHeight / Number(param1.@viewBoxHeight)
         );
         graphics.endFill();
      }
   }
}
