package venworks.cui
{
   public final class CUIConditionParser
   {
      private static const MAX_EXPRESSION_LENGTH:int = 256;
      private static const MAX_TOKENS:int = 64;
      private static const MAX_DEPTH:int = 8;

      private var tokens:Array;
      private var position:int;
      private var depth:int;

      public function CUIConditionParser()
      {
         super();
      }

      public function compile(param1:String) : CUIConditionExpression
      {
         var expression:String = param1.replace(/^\s+|\s+$/g,"");
         var root:Object = null;
         if(expression.length == 0)
         {
            throw new Error("INVALID|visibleWhen cannot be empty.");
         }
         if(expression.length > MAX_EXPRESSION_LENGTH)
         {
            throw new Error("INVALID|Condition exceeds the 256-character limit.");
         }
         tokens = this.tokenize(expression);
         position = 0;
         depth = 0;
         root = this.parseOr();
         if(this.current().type != "end")
         {
            throw new Error("INVALID|Unexpected condition token: " + String(this.current().value));
         }
         return new CUIConditionExpression(root);
      }

      private function tokenize(param1:String) : Array
      {
         var result:Array = [];
         var index:int = 0;
         var start:int = 0;
         var character:String = null;
         var value:String = null;
         while(index < param1.length)
         {
            character = param1.charAt(index);
            if(/\s/.test(character))
            {
               ++index;
               continue;
            }
            if(/[A-Za-z_]/.test(character))
            {
               start = index++;
               while(index < param1.length && /[A-Za-z0-9_]/.test(param1.charAt(index)))
               {
                  ++index;
               }
               value = param1.substring(start,index);
               result.push({ type:"identifier", value:value });
            }
            else if(/[0-9]/.test(character))
            {
               start = index++;
               while(index < param1.length && /[0-9.]/.test(param1.charAt(index)))
               {
                  ++index;
               }
               value = param1.substring(start,index);
               if(!/^[0-9]+(?:\.[0-9]+)?$/.test(value))
               {
                  throw new Error("INVALID|Invalid condition number: " + value);
               }
               result.push({ type:"number", value:value });
            }
            else if(character == "\"")
            {
               start = ++index;
               while(index < param1.length && param1.charAt(index) != "\"")
               {
                  ++index;
               }
               if(index >= param1.length)
               {
                  throw new Error("INVALID|Unterminated condition string.");
               }
               value = param1.substring(start,index++);
               if(!/^[A-Za-z0-9._-]{1,64}$/.test(value))
               {
                  throw new Error("INVALID|Condition effect ids may use letters, numbers, dots, underscores, and hyphens.");
               }
               result.push({ type:"string", value:value });
            }
            else if(character == "(" || character == ")" || character == ",")
            {
               result.push({ type:character, value:character });
               ++index;
            }
            else if(character == "<" || character == ">" || character == "!" || character == "=")
            {
               value = character;
               if(index + 1 < param1.length && (param1.charAt(index + 1) == "=" || character == "<" && param1.charAt(index + 1) == ">"))
               {
                  value += param1.charAt(++index);
               }
               if(value == "!")
               {
                  throw new Error("INVALID|Use NOT for Boolean negation or != for comparison.");
               }
               result.push({ type:"operator", value:value });
               ++index;
            }
            else
            {
               throw new Error("INVALID|Unsupported character in condition: " + character);
            }
            if(result.length > MAX_TOKENS)
            {
               throw new Error("INVALID|Condition exceeds the 64-token limit.");
            }
         }
         result.push({ type:"end", value:"end" });
         return result;
      }

      private function parseOr() : Object
      {
         var node:Object = this.parseAnd();
         while(this.isKeyword("or"))
         {
            this.advance();
            node = { op:"or", left:node, right:this.parseAnd() };
         }
         return node;
      }

      private function parseAnd() : Object
      {
         var node:Object = this.parseNot();
         while(this.isKeyword("and"))
         {
            this.advance();
            node = { op:"and", left:node, right:this.parseNot() };
         }
         return node;
      }

      private function parseNot() : Object
      {
         if(this.isKeyword("not"))
         {
            this.advance();
            return { op:"not", child:this.parseNot() };
         }
         return this.parsePrimary();
      }

      private function parsePrimary() : Object
      {
         var identifier:String = null;
         var normalized:String = null;
         var kind:String = null;
         var operator:String = null;
         var number:Number = NaN;
         if(this.current().type == "(")
         {
            ++depth;
            if(depth > MAX_DEPTH)
            {
               throw new Error("INVALID|Condition exceeds the 8-level nesting limit.");
            }
            this.advance();
            var grouped:Object = this.parseOr();
            this.expect(")");
            --depth;
            return grouped;
         }
         if(this.current().type != "identifier")
         {
            throw new Error("INVALID|Expected a condition name.");
         }
         identifier = String(this.current().value);
         normalized = CUIConditionContext.normalizeName(identifier);
         kind = CUIConditionContext.getKind(normalized);
         this.advance();
         if(this.current().type == "(")
         {
            return this.parseFunction(identifier,normalized,kind);
         }
         if(kind == "unknown")
         {
            throw new Error("INVALID|Unknown condition: " + identifier);
         }
         if(kind == "unavailable-function")
         {
            throw new Error("INVALID|Condition function requires an argument: " + identifier);
         }
         if(this.current().type == "operator")
         {
            if(kind != "number")
            {
               throw new Error("INVALID|Condition is not numeric: " + identifier);
            }
            operator = String(this.current().value);
            if(operator != "=" && operator != "!=" && operator != "<>" && operator != "<" &&
               operator != "<=" && operator != ">" && operator != ">=")
            {
               throw new Error("INVALID|Unsupported numeric condition operator: " + operator);
            }
            this.advance();
            if(this.current().type != "number")
            {
               throw new Error("INVALID|Numeric condition requires a 0-100 value: " + identifier);
            }
            number = Number(this.current().value);
            if(number < 0 || number > 100)
            {
               throw new Error("INVALID|Condition percentage must be between 0 and 100: " + identifier);
            }
            this.advance();
            return { op:"comparison", name:normalized, operator:operator, value:number };
         }
         if(kind != "boolean")
         {
            throw new Error("INVALID|Numeric condition requires a comparison: " + identifier);
         }
         if(normalized == "always")
         {
            return { op:"constant", value:true };
         }
         if(normalized == "never")
         {
            return { op:"constant", value:false };
         }
         return { op:"boolean", name:normalized };
      }

      private function parseFunction(param1:String, param2:String, param3:String) : Object
      {
         this.advance();
         if(this.current().type != "string")
         {
            throw new Error("INVALID|Condition function requires one quoted effect id: " + param1);
         }
         var effectId:String = String(this.current().value);
         this.advance();
         this.expect(")");
         if(param3 == "unknown")
         {
            throw new Error("INVALID|Unknown condition function: " + param1);
         }
         if(param3 == "unavailable-function")
         {
            throw new Error("INVALID|Condition provider unavailable in hudmenu.gfx: " + param1 + "(\"" + effectId + "\")");
         }
         throw new Error("INVALID|Condition is not a function: " + param1);
      }

      private function current() : Object
      {
         return tokens[position];
      }

      private function advance() : void
      {
         ++position;
      }

      private function expect(param1:String) : void
      {
         if(this.current().type != param1)
         {
            throw new Error("INVALID|Expected '" + param1 + "' in condition.");
         }
         this.advance();
      }

      private function isKeyword(param1:String) : Boolean
      {
         return this.current().type == "identifier" && String(this.current().value).toLowerCase() == param1;
      }
   }
}
