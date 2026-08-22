package venworks.cui
{
   import flash.display.Graphics;
   import flash.display.Sprite;
   import flash.geom.Matrix;

   public final class CUISvgParser
   {
      private static const MAX_ELEMENTS:int = 256;
      private static const MAX_DEPTH:int = 16;

      private var elementCount:int;

      public function CUISvgParser()
      {
         super();
      }

      public static function validate(param1:XML) : void
      {
         new CUISvgParser().parse(param1);
      }

      public static function render(param1:XML) : Sprite
      {
         return new CUISvgParser().parse(param1);
      }

      private function parse(param1:XML) : Sprite
      {
         var name:String = this.nodeName(param1);
         var viewBox:Array = null;
         var root:Sprite = null;
         var content:Sprite = null;
         var transformedContent:Sprite = null;
         if(name != "svg")
         {
            throw new Error("INVALID|Local SVG root must be svg.");
         }
         this.requireAttributes(param1,["viewBox","width","height","fill","stroke","fill-opacity","stroke-opacity","stroke-width","opacity","transform"]);
         viewBox = this.parseNumbers(String(param1.@viewBox),4,"SVG viewBox");
         if(viewBox[2] <= 0 || viewBox[3] <= 0)
         {
            throw new Error("INVALID|SVG viewBox width and height must be positive.");
         }
         root = new Sprite();
         root.graphics.beginFill(0,0);
         root.graphics.drawRect(0,0,viewBox[2],viewBox[3]);
         root.graphics.endFill();
         content = new Sprite();
         content.x = -viewBox[0];
         content.y = -viewBox[1];
         root.addChild(content);
         transformedContent = new Sprite();
         content.addChild(transformedContent);
         this.applyTransform(transformedContent,String(param1.@transform));
         elementCount = 1;
         this.renderChildren(param1,transformedContent,this.createStyle(param1,null),1);
         return root;
      }

      private function renderChildren(param1:XML, param2:Sprite, param3:Object, param4:int) : void
      {
         var child:XML = null;
         var childName:String = null;
         var display:Sprite = null;
         if(param4 > MAX_DEPTH)
         {
            throw new Error("INVALID|SVG exceeds the 16-level nesting limit.");
         }
         for each(child in param1.children())
         {
            if(child.nodeKind() == "text")
            {
               if(String(child).replace(/\s/g,"").length != 0)
               {
                  throw new Error("INVALID|SVG text content is not supported.");
               }
               continue;
            }
            ++elementCount;
            if(elementCount > MAX_ELEMENTS)
            {
               throw new Error("INVALID|SVG exceeds the 256-element limit.");
            }
            childName = this.nodeName(child);
            if(childName != "g" && childName != "path" && childName != "rect" && childName != "circle" &&
               childName != "ellipse" && childName != "line" && childName != "polyline" && childName != "polygon")
            {
               throw new Error("INVALID|Unsupported SVG element: " + childName);
            }
            display = new Sprite();
            param2.addChild(display);
            this.applyTransform(display,String(child.@transform));
            if(childName == "g")
            {
               this.requireAttributes(child,["fill","stroke","fill-opacity","stroke-opacity","stroke-width","opacity","transform"]);
               this.renderChildren(child,display,this.createStyle(child,param3),param4 + 1);
            }
            else
            {
               if(child.children().length() != 0)
               {
                  throw new Error("INVALID|SVG " + childName + " elements cannot contain children.");
               }
               this.renderShape(childName,child,display.graphics,this.createStyle(child,param3));
            }
         }
      }

      private function renderShape(param1:String, param2:XML, param3:Graphics, param4:Object) : void
      {
         var common:Array = ["fill","stroke","fill-opacity","stroke-opacity","stroke-width","opacity","transform"];
         var values:Array = null;
         var index:int = 0;
         this.applyGraphicsStyle(param3,param4);
         if(param1 == "path")
         {
            this.requireAttributes(param2,common.concat(["d"]));
            CUISvgPathParser.draw(param3,String(param2.@d),0,0,1,1);
         }
         else if(param1 == "rect")
         {
            this.requireAttributes(param2,common.concat(["x","y","width","height"]));
            values = this.requireShapeNumbers(param2,["x","y","width","height"]);
            if(values[2] < 0 || values[3] < 0)
            {
               throw new Error("INVALID|SVG rect width and height cannot be negative.");
            }
            param3.drawRect(values[0],values[1],values[2],values[3]);
         }
         else if(param1 == "circle")
         {
            this.requireAttributes(param2,common.concat(["cx","cy","r"]));
            values = this.requireShapeNumbers(param2,["cx","cy","r"]);
            if(values[2] <= 0)
            {
               throw new Error("INVALID|SVG circle radius must be positive.");
            }
            param3.drawCircle(values[0],values[1],values[2]);
         }
         else if(param1 == "ellipse")
         {
            this.requireAttributes(param2,common.concat(["cx","cy","rx","ry"]));
            values = this.requireShapeNumbers(param2,["cx","cy","rx","ry"]);
            if(values[2] <= 0 || values[3] <= 0)
            {
               throw new Error("INVALID|SVG ellipse radii must be positive.");
            }
            param3.drawEllipse(values[0] - values[2],values[1] - values[3],values[2] * 2,values[3] * 2);
         }
         else if(param1 == "line")
         {
            this.requireAttributes(param2,common.concat(["x1","y1","x2","y2"]));
            values = this.requireShapeNumbers(param2,["x1","y1","x2","y2"]);
            param3.moveTo(values[0],values[1]);
            param3.lineTo(values[2],values[3]);
         }
         else
         {
            this.requireAttributes(param2,common.concat(["points"]));
            values = this.parseNumbers(String(param2.@points),-1,"SVG points");
            if(values.length < 4 || values.length % 2 != 0 || values.length > 512)
            {
               throw new Error("INVALID|SVG points require 2 through 256 coordinate pairs.");
            }
            param3.moveTo(values[0],values[1]);
            for(index = 2; index < values.length; index += 2)
            {
               param3.lineTo(values[index],values[index + 1]);
            }
            if(param1 == "polygon")
            {
               param3.lineTo(values[0],values[1]);
            }
         }
         if(param4.fill != "none")
         {
            param3.endFill();
         }
      }

      private function createStyle(param1:XML, param2:Object) : Object
      {
         var result:Object = {
            fill:param2 == null ? "#000000" : param2.fill,
            stroke:param2 == null ? "none" : param2.stroke,
            fillOpacity:param2 == null ? 1 : param2.fillOpacity,
            strokeOpacity:param2 == null ? 1 : param2.strokeOpacity,
            strokeWidth:param2 == null ? 1 : param2.strokeWidth,
            opacity:param2 == null ? 1 : param2.opacity
         };
         if(param1.@fill.length() == 1)
         {
            result.fill = this.requirePaint(String(param1.@fill),"fill");
         }
         if(param1.@stroke.length() == 1)
         {
            result.stroke = this.requirePaint(String(param1.@stroke),"stroke");
         }
         if(param1.attribute("fill-opacity").length() == 1)
         {
            result.fillOpacity = this.requireOpacity(String(param1.attribute("fill-opacity")),"fill-opacity");
         }
         if(param1.attribute("stroke-opacity").length() == 1)
         {
            result.strokeOpacity = this.requireOpacity(String(param1.attribute("stroke-opacity")),"stroke-opacity");
         }
         if(param1.attribute("stroke-width").length() == 1)
         {
            result.strokeWidth = this.requireNonNegative(String(param1.attribute("stroke-width")),"stroke-width");
         }
         if(param1.@opacity.length() == 1)
         {
            result.opacity *= this.requireOpacity(String(param1.@opacity),"opacity");
         }
         return result;
      }

      private function applyGraphicsStyle(param1:Graphics, param2:Object) : void
      {
         if(param2.stroke == "none")
         {
            param1.lineStyle();
         }
         else
         {
            param1.lineStyle(param2.strokeWidth,this.colorValue(param2.stroke),param2.strokeOpacity * param2.opacity);
         }
         if(param2.fill != "none")
         {
            param1.beginFill(this.colorValue(param2.fill),param2.fillOpacity * param2.opacity);
         }
      }

      private function applyTransform(param1:Sprite, param2:String) : void
      {
         var pattern:RegExp = /(translate|scale|rotate)\s*\(([^)]*)\)/g;
         var match:Object = null;
         var remainder:String = param2;
         var values:Array = null;
         var matrix:Matrix = new Matrix();
         var operation:Matrix = null;
         if(param2.length == 0)
         {
            return;
         }
         while((match = pattern.exec(param2)) != null)
         {
            remainder = remainder.replace(String(match[0]),"");
            values = this.parseNumbers(String(match[2]),-1,"SVG transform");
            operation = new Matrix();
            if(String(match[1]) == "translate")
            {
               if(values.length < 1 || values.length > 2)
               {
                  throw new Error("INVALID|SVG translate requires one or two values.");
               }
               operation.translate(values[0],values.length == 2 ? values[1] : 0);
            }
            else if(String(match[1]) == "scale")
            {
               if(values.length < 1 || values.length > 2)
               {
                  throw new Error("INVALID|SVG scale requires one or two values.");
               }
               operation.scale(values[0],values.length == 2 ? values[1] : values[0]);
            }
            else
            {
               if(values.length != 1)
               {
                  throw new Error("INVALID|SVG rotate requires one angle value.");
               }
               operation.rotate(values[0] * Math.PI / 180);
            }
            matrix.concat(operation);
         }
         if(remainder.replace(/[\s,]+/g,"").length != 0)
         {
            throw new Error("INVALID|Unsupported SVG transform.");
         }
         param1.transform.matrix = matrix;
      }

      private function requireAttributes(param1:XML, param2:Array) : void
      {
         var attribute:XML = null;
         var name:String = null;
         for each(attribute in param1.attributes())
         {
            name = String(attribute.name());
            if(param2.indexOf(name) < 0)
            {
               throw new Error("INVALID|Unsupported SVG attribute: " + name);
            }
         }
      }

      private function requireShapeNumbers(param1:XML, param2:Array) : Array
      {
         var result:Array = [];
         var name:String = null;
         var value:Number = NaN;
         for each(name in param2)
         {
            if(param1.attribute(name).length() != 1)
            {
               throw new Error("INVALID|Missing SVG " + name + " attribute.");
            }
            value = Number(param1.attribute(name));
            if(isNaN(value) || !isFinite(value))
            {
               throw new Error("INVALID|SVG " + name + " must be finite.");
            }
            result.push(value);
         }
         return result;
      }

      private function parseNumbers(param1:String, param2:int, param3:String) : Array
      {
         var matchPattern:RegExp = /[-+]?(?:[0-9]*\.[0-9]+|[0-9]+\.?)(?:[eE][-+]?[0-9]+)?/g;
         var removalPattern:RegExp = /[-+]?(?:[0-9]*\.[0-9]+|[0-9]+\.?)(?:[eE][-+]?[0-9]+)?/g;
         var raw:Array = param1.match(matchPattern);
         var remainder:String = param1.replace(removalPattern,"").replace(/[\s,]+/g,"");
         var result:Array = [];
         var entry:String = null;
         var value:Number = NaN;
         if(remainder.length != 0 || raw == null || raw.length == 0 || param2 >= 0 && raw.length != param2)
         {
            throw new Error("INVALID|" + param3 + " has invalid numeric data.");
         }
         for each(entry in raw)
         {
            value = Number(entry);
            if(isNaN(value) || !isFinite(value))
            {
               throw new Error("INVALID|" + param3 + " contains a non-finite number.");
            }
            result.push(value);
         }
         return result;
      }

      private function requirePaint(param1:String, param2:String) : String
      {
         if(param1 != "none" && !/^#[0-9A-Fa-f]{6}$/.test(param1))
         {
            throw new Error("INVALID|SVG " + param2 + " must be none or #RRGGBB.");
         }
         return param1;
      }

      private function requireOpacity(param1:String, param2:String) : Number
      {
         var value:Number = Number(param1);
         if(isNaN(value) || !isFinite(value) || value < 0 || value > 1)
         {
            throw new Error("INVALID|SVG " + param2 + " must be between 0 and 1.");
         }
         return value;
      }

      private function requireNonNegative(param1:String, param2:String) : Number
      {
         var value:Number = Number(param1);
         if(isNaN(value) || !isFinite(value) || value < 0)
         {
            throw new Error("INVALID|SVG " + param2 + " cannot be negative.");
         }
         return value;
      }

      private function colorValue(param1:String) : uint
      {
         return uint(parseInt(param1.replace("#",""),16));
      }

      private function nodeName(param1:XML) : String
      {
         return String(param1.localName());
      }
   }
}
