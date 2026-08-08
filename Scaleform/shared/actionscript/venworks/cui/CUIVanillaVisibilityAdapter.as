package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;

   public final class CUIVanillaVisibilityAdapter
   {
      private var target:DisplayObject;
      private var expression:CUIConditionExpression;
      private var initialAlpha:Number;

      public function CUIVanillaVisibilityAdapter(param1:DisplayObjectContainer, param2:String, param3:CUIConditionExpression)
      {
         super();
         var displayName:String = this.getDisplayName(param2);
         target = param1.getChildByName(displayName);
         if(target == null)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target is missing: " + param2);
         }
         expression = param3;
         initialAlpha = target.alpha;
      }

      public static function normalizeTarget(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function isAllowlisted(param1:String) : Boolean
      {
         var targetName:String = normalizeTarget(param1);
         return targetName == "topcenter" || targetName == "bottomleft" ||
            targetName == "socialcommandicons" || targetName == "floatingquestmarkers" ||
            targetName == "crewbuffwidget";
      }

      public function apply(param1:CUIConditionContext) : void
      {
         var opacity:Number = param1.hudOpacity;
         var conditionVisible:Boolean = expression.evaluate(param1) == CUIConditionExpression.TRUE_VALUE;
         if(!conditionVisible)
         {
            target.alpha = 0;
         }
         else
         {
            target.alpha = isNaN(opacity) ? initialAlpha : opacity;
         }
      }

      private function getDisplayName(param1:String) : String
      {
         var targetName:String = normalizeTarget(param1);
         if(targetName == "topcenter")
         {
            return "TopCenterGroup_mc";
         }
         if(targetName == "bottomleft")
         {
            return "BottomLeftGroup_mc";
         }
         if(targetName == "socialcommandicons")
         {
            return "SocialCommandIcons_mc";
         }
         if(targetName == "floatingquestmarkers")
         {
            return "FloatingQuestMarkerBase";
         }
         if(targetName == "crewbuffwidget")
         {
            return "CrewBuffWidget_mc";
         }
         throw new Error("INVALID|Vanilla visibility target is not allowlisted: " + param1);
      }
   }
}
