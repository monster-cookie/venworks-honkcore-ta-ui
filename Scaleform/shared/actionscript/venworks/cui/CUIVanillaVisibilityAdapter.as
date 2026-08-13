package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;

   public final class CUIVanillaVisibilityAdapter
   {
      private var targets:Array;
      private var expression:CUIConditionExpression;
      private var initialAlphas:Array;
      private var initialXs:Array;
      private var initialYs:Array;

      public function CUIVanillaVisibilityAdapter(param1:DisplayObjectContainer, param2:XML, param3:CUIConditionExpression, param4:CUILayoutEngine)
      {
         super();
         var id:String = String(param2.@id);
         var targetName:String = normalizeTarget(id);
         var target:DisplayObject = null;
         targets = [];
         initialAlphas = [];
         initialXs = [];
         initialYs = [];
         target = param1.getChildByName(this.getDisplayName(id));
         if(target == null)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target is missing: " + id);
         }
         targets.push(target);
         initialAlphas.push(target.alpha);
         initialXs.push(target.x);
         initialYs.push(target.y);
         param4.positionVanilla(target,param2);
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

      public function dispose() : void
      {
         var index:int = 0;
         while(index < targets.length)
         {
            DisplayObject(targets[index]).alpha = Number(initialAlphas[index]);
            DisplayObject(targets[index]).x = Number(initialXs[index]);
            DisplayObject(targets[index]).y = Number(initialYs[index]);
            index++;
         }
         targets = [];
         initialAlphas = [];
         initialXs = [];
         initialYs = [];
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
