package venworks.cui
{
   public final class CUIConditionExpression
   {
      public static const UNKNOWN:int = -1;
      public static const FALSE_VALUE:int = 0;
      public static const TRUE_VALUE:int = 1;

      private var root:Object;

      public function CUIConditionExpression(param1:Object)
      {
         super();
         root = param1;
      }

      public function evaluate(param1:CUIConditionContext) : int
      {
         return this.evaluateNode(root,param1);
      }

      private function evaluateNode(param1:Object, param2:CUIConditionContext) : int
      {
         var left:int = UNKNOWN;
         var right:int = UNKNOWN;
         var value:Object = null;
         var numericValue:Number = NaN;
         if(param1.op == "constant")
         {
            return Boolean(param1.value) ? TRUE_VALUE : FALSE_VALUE;
         }
         if(param1.op == "boolean")
         {
            value = param2.getValue(String(param1.name));
            if(value == null || !Boolean(value.known))
            {
               return UNKNOWN;
            }
            return Boolean(value.value) ? TRUE_VALUE : FALSE_VALUE;
         }
         if(param1.op == "comparison")
         {
            value = param2.getValue(String(param1.name));
            if(value == null || !Boolean(value.known))
            {
               return UNKNOWN;
            }
            numericValue = Number(value.value);
            if(param1.operator == "=")
            {
               return numericValue == Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
            }
            if(param1.operator == "!=" || param1.operator == "<>")
            {
               return numericValue != Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
            }
            if(param1.operator == "<")
            {
               return numericValue < Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
            }
            if(param1.operator == "<=")
            {
               return numericValue <= Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
            }
            if(param1.operator == ">")
            {
               return numericValue > Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
            }
            return numericValue >= Number(param1.value) ? TRUE_VALUE : FALSE_VALUE;
         }
         if(param1.op == "not")
         {
            left = this.evaluateNode(param1.child,param2);
            if(left == UNKNOWN)
            {
               return UNKNOWN;
            }
            return left == TRUE_VALUE ? FALSE_VALUE : TRUE_VALUE;
         }
         if(param1.op == "and")
         {
            left = this.evaluateNode(param1.left,param2);
            right = this.evaluateNode(param1.right,param2);
            if(left == FALSE_VALUE || right == FALSE_VALUE)
            {
               return FALSE_VALUE;
            }
            if(left == UNKNOWN || right == UNKNOWN)
            {
               return UNKNOWN;
            }
            return TRUE_VALUE;
         }
         if(param1.op == "or")
         {
            left = this.evaluateNode(param1.left,param2);
            right = this.evaluateNode(param1.right,param2);
            if(left == TRUE_VALUE || right == TRUE_VALUE)
            {
               return TRUE_VALUE;
            }
            if(left == UNKNOWN || right == UNKNOWN)
            {
               return UNKNOWN;
            }
            return FALSE_VALUE;
         }
         return UNKNOWN;
      }
   }
}
