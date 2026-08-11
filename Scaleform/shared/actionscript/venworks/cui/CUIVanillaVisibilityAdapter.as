package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;

   public final class CUIVanillaVisibilityAdapter
   {
      private var targets:Array;
      private var expression:CUIConditionExpression;
      private var initialAlphas:Array;

      public function CUIVanillaVisibilityAdapter(param1:DisplayObjectContainer, param2:String, param3:CUIConditionExpression)
      {
         super();
         var targetName:String = normalizeTarget(param2);
         var target:DisplayObject = null;
         targets = [];
         initialAlphas = [];
         target = param1.getChildByName(this.getDisplayName(param2));
         if(target == null)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target is missing: " + param2);
         }
         targets.push(target);
         initialAlphas.push(target.alpha);
         expression = param3;
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
            targetName == "crewbuffwidget" || targetName == "rightmeters";
      }

      public function apply(param1:CUIConditionContext) : void
      {
         var opacity:Number = param1.hudOpacity;
         var conditionVisible:Boolean = expression.evaluate(param1) == CUIConditionExpression.TRUE_VALUE;
         var index:int = 0;
         while(index < targets.length)
         {
            if(!conditionVisible)
            {
               DisplayObject(targets[index]).alpha = 0;
            }
            else
            {
               DisplayObject(targets[index]).alpha = isNaN(opacity) ? Number(initialAlphas[index]) : opacity;
            }
            index++;
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
         if(targetName == "rightmeters")
         {
            return "RightMeters_mc";
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
