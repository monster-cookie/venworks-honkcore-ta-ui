package venworks.cui
{
   import flash.display.Graphics;

   public final class CUISvgPathParser
   {
      private static const MAX_TOKENS:int = 2048;
      private static const MAX_COMMANDS:int = 512;
      private static const CUBIC_STEPS:int = 12;

      public function CUISvgPathParser()
      {
         super();
      }

      public static function validate(param1:String) : void
      {
         parse(param1,null,0,0,1,1);
      }

      public static function draw(param1:Graphics, param2:String, param3:Number, param4:Number,
                                  param5:Number, param6:Number) : void
      {
         parse(param2,param1,param3,param4,param5,param6);
      }

      private static function parse(param1:String, param2:Graphics, param3:Number, param4:Number,
                                    param5:Number, param6:Number) : void
      {
         var tokenPattern:RegExp = /[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:[0-9]*\.[0-9]+|[0-9]+\.?)(?:[eE][-+]?[0-9]+)?/g;
         var tokens:Array = [];
         var token:Object = null;
         var gap:String = null;
         var lastEnd:int = 0;
         var index:int = 0;
         var command:String = null;
         var upper:String = null;
         var relative:Boolean = false;
         var arity:int = 0;
         var values:Array = null;
         var currentX:Number = 0;
         var currentY:Number = 0;
         var startX:Number = 0;
         var startY:Number = 0;
         var lastControlX:Number = 0;
         var lastControlY:Number = 0;
         var lastControlKind:String = "";
         var commandCount:int = 0;
         var x1:Number = NaN;
         var y1:Number = NaN;
         var x2:Number = NaN;
         var y2:Number = NaN;
         var x3:Number = NaN;
         var y3:Number = NaN;
         var step:int = 0;
         var t:Number = NaN;
         var inverse:Number = NaN;
         var curveX:Number = NaN;
         var curveY:Number = NaN;

         if(param1 == null || param1.replace(/\s/g,"").length == 0)
         {
            throw new Error("INVALID|SVG path data cannot be empty.");
         }

         tokenPattern.lastIndex = 0;
         while((token = tokenPattern.exec(param1)) != null)
         {
            gap = param1.substring(lastEnd,int(token.index)).replace(/[\s,]+/g,"");
            if(gap.length != 0)
            {
               throw new Error("INVALID|SVG path contains unsupported syntax.");
            }
            tokens.push(String(token[0]));
            lastEnd = tokenPattern.lastIndex;
         }
         gap = param1.substring(lastEnd).replace(/[\s,]+/g,"");
         if(gap.length != 0 || tokens.length == 0)
         {
            throw new Error("INVALID|SVG path contains unsupported syntax.");
         }
         if(tokens.length > MAX_TOKENS)
         {
            throw new Error("INVALID|SVG path exceeds the 2048-token limit.");
         }

         while(index < tokens.length)
         {
            if(isCommand(String(tokens[index])))
            {
               command = String(tokens[index++]);
            }
            else if(command == null)
            {
               throw new Error("INVALID|SVG path data must begin with a command.");
            }

            upper = command.toUpperCase();
            relative = command != upper;
            if(upper == "A")
            {
               throw new Error("INVALID|SVG arc path commands are not supported.");
            }
            if(upper == "Z")
            {
               if(param2 != null)
               {
                  param2.lineTo(transformX(startX,param3,param5),transformY(startY,param4,param6));
               }
               currentX = startX;
               currentY = startY;
               command = null;
               lastControlKind = "";
               ++commandCount;
               ensureCommandLimit(commandCount);
               continue;
            }

            arity = commandArity(upper);
            if(index + arity > tokens.length)
            {
               throw new Error("INVALID|SVG path command " + command + " has too few values.");
            }
            values = [];
            while(values.length < arity)
            {
               if(isCommand(String(tokens[index])))
               {
                  throw new Error("INVALID|SVG path command " + command + " has too few values.");
               }
               values.push(Number(tokens[index++]));
            }
            ++commandCount;
            ensureCommandLimit(commandCount);

            if(upper == "M" || upper == "L" || upper == "T")
            {
               x1 = coordinate(Number(values[0]),currentX,relative);
               y1 = coordinate(Number(values[1]),currentY,relative);
               if(upper == "M")
               {
                  if(param2 != null)
                  {
                     param2.moveTo(transformX(x1,param3,param5),transformY(y1,param4,param6));
                  }
                  startX = x1;
                  startY = y1;
                  command = relative ? "l" : "L";
               }
               else if(upper == "T")
               {
                  x2 = lastControlKind == "Q" ? 2 * currentX - lastControlX : currentX;
                  y2 = lastControlKind == "Q" ? 2 * currentY - lastControlY : currentY;
                  if(param2 != null)
                  {
                     param2.curveTo(transformX(x2,param3,param5),transformY(y2,param4,param6),
                                    transformX(x1,param3,param5),transformY(y1,param4,param6));
                  }
                  lastControlX = x2;
                  lastControlY = y2;
                  lastControlKind = "Q";
               }
               else if(param2 != null)
               {
                  param2.lineTo(transformX(x1,param3,param5),transformY(y1,param4,param6));
               }
               currentX = x1;
               currentY = y1;
               if(upper != "T")
               {
                  lastControlKind = "";
               }
            }
            else if(upper == "H")
            {
               currentX = coordinate(Number(values[0]),currentX,relative);
               if(param2 != null)
               {
                  param2.lineTo(transformX(currentX,param3,param5),transformY(currentY,param4,param6));
               }
               lastControlKind = "";
            }
            else if(upper == "V")
            {
               currentY = coordinate(Number(values[0]),currentY,relative);
               if(param2 != null)
               {
                  param2.lineTo(transformX(currentX,param3,param5),transformY(currentY,param4,param6));
               }
               lastControlKind = "";
            }
            else if(upper == "Q")
            {
               x1 = coordinate(Number(values[0]),currentX,relative);
               y1 = coordinate(Number(values[1]),currentY,relative);
               x2 = coordinate(Number(values[2]),currentX,relative);
               y2 = coordinate(Number(values[3]),currentY,relative);
               if(param2 != null)
               {
                  param2.curveTo(transformX(x1,param3,param5),transformY(y1,param4,param6),
                                 transformX(x2,param3,param5),transformY(y2,param4,param6));
               }
               currentX = x2;
               currentY = y2;
               lastControlX = x1;
               lastControlY = y1;
               lastControlKind = "Q";
            }
            else if(upper == "C" || upper == "S")
            {
               if(upper == "C")
               {
                  x1 = coordinate(Number(values[0]),currentX,relative);
                  y1 = coordinate(Number(values[1]),currentY,relative);
                  x2 = coordinate(Number(values[2]),currentX,relative);
                  y2 = coordinate(Number(values[3]),currentY,relative);
                  x3 = coordinate(Number(values[4]),currentX,relative);
                  y3 = coordinate(Number(values[5]),currentY,relative);
               }
               else
               {
                  x1 = lastControlKind == "C" ? 2 * currentX - lastControlX : currentX;
                  y1 = lastControlKind == "C" ? 2 * currentY - lastControlY : currentY;
                  x2 = coordinate(Number(values[0]),currentX,relative);
                  y2 = coordinate(Number(values[1]),currentY,relative);
                  x3 = coordinate(Number(values[2]),currentX,relative);
                  y3 = coordinate(Number(values[3]),currentY,relative);
               }
               if(param2 != null)
               {
                  for(step = 1; step <= CUBIC_STEPS; ++step)
                  {
                     t = step / CUBIC_STEPS;
                     inverse = 1 - t;
                     curveX = inverse * inverse * inverse * currentX + 3 * inverse * inverse * t * x1 +
                              3 * inverse * t * t * x2 + t * t * t * x3;
                     curveY = inverse * inverse * inverse * currentY + 3 * inverse * inverse * t * y1 +
                              3 * inverse * t * t * y2 + t * t * t * y3;
                     param2.lineTo(transformX(curveX,param3,param5),transformY(curveY,param4,param6));
                  }
               }
               currentX = x3;
               currentY = y3;
               lastControlX = x2;
               lastControlY = y2;
               lastControlKind = "C";
            }
         }
      }

      private static function isCommand(param1:String) : Boolean
      {
         return /^[AaCcHhLlMmQqSsTtVvZz]$/.test(param1);
      }

      private static function commandArity(param1:String) : int
      {
         if(param1 == "H" || param1 == "V")
         {
            return 1;
         }
         if(param1 == "M" || param1 == "L" || param1 == "T")
         {
            return 2;
         }
         if(param1 == "S" || param1 == "Q")
         {
            return 4;
         }
         if(param1 == "C")
         {
            return 6;
         }
         throw new Error("INVALID|Unsupported SVG path command: " + param1 + ".");
      }

      private static function coordinate(param1:Number, param2:Number, param3:Boolean) : Number
      {
         if(isNaN(param1) || !isFinite(param1))
         {
            throw new Error("INVALID|SVG path contains a non-finite coordinate.");
         }
         return param3 ? param1 + param2 : param1;
      }

      private static function transformX(param1:Number, param2:Number, param3:Number) : Number
      {
         return (param1 - param2) * param3;
      }

      private static function transformY(param1:Number, param2:Number, param3:Number) : Number
      {
         return (param1 - param2) * param3;
      }

      private static function ensureCommandLimit(param1:int) : void
      {
         if(param1 > MAX_COMMANDS)
         {
            throw new Error("INVALID|SVG path exceeds the 512-command limit.");
         }
      }
   }
}
