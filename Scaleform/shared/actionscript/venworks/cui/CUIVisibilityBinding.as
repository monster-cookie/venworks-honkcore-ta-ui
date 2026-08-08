package venworks.cui
{
   import flash.display.DisplayObject;

   public final class CUIVisibilityBinding
   {
      private var target:DisplayObject;
      private var expression:CUIConditionExpression;
      private var configuredVisible:Boolean;

      public function CUIVisibilityBinding(param1:DisplayObject, param2:CUIConditionExpression, param3:Boolean)
      {
         super();
         target = param1;
         expression = param2;
         configuredVisible = param3;
      }

      public function apply(param1:CUIConditionContext) : void
      {
         target.visible = configuredVisible && expression.evaluate(param1) == CUIConditionExpression.TRUE_VALUE;
      }
   }
}
