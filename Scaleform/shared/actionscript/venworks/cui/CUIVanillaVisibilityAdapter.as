package venworks.cui
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;

   public final class CUIVanillaVisibilityAdapter
   {
      private var targets:Array;
      private var expression:CUIConditionExpression;
      private var initialAlphas:Array;
      private var initialVisibilities:Array;
      private var gameVisibilities:Array;
      private var initialXs:Array;
      private var initialYs:Array;
      private var hudModeIndex:int;
      private var targetConfig:XML;
      private var layoutEngine:CUILayoutEngine;

      public function CUIVanillaVisibilityAdapter(param1:DisplayObjectContainer, param2:XML, param3:CUIConditionExpression, param4:CUILayoutEngine)
      {
         super();
         var id:String = String(param2.@id);
         var targetName:String = normalizeTarget(id);
         var target:DisplayObject = null;
         targets = [];
         initialAlphas = [];
         initialVisibilities = [];
         gameVisibilities = [];
         initialXs = [];
         initialYs = [];
         hudModeIndex = this.getHudModeIndex(id);
         targetConfig = param2.copy();
         layoutEngine = param4;
         target = param1.getChildByName(this.getDisplayName(id));
         if(target == null)
         {
            throw new Error("INVALID|Allowlisted vanilla HUD target is missing: " + id);
         }
         targets.push(target);
         initialAlphas.push(target.alpha);
         initialVisibilities.push(target.visible);
         gameVisibilities.push(target.visible);
         initialXs.push(target.x);
         initialYs.push(target.y);
         this.reapplyPlacement();
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
         var target:DisplayObject = null;
         var effectiveVisible:Boolean = false;
         while(index < targets.length)
         {
            target = DisplayObject(targets[index]);
            effectiveVisible = Boolean(gameVisibilities[index]) && conditionVisible;
            target.visible = effectiveVisible;
            target.alpha = effectiveVisible ?
               (isNaN(opacity) ? Number(initialAlphas[index]) : opacity) : 0;
            index++;
         }
      }

      public function updateHudMode(param1:Array) : void
      {
         var mode:Object = null;
         var index:int = 0;
         if(hudModeIndex < 0 || param1 == null || hudModeIndex >= param1.length)
         {
            return;
         }
         mode = param1[hudModeIndex];
         if(mode == null)
         {
            return;
         }
         while(index < gameVisibilities.length)
         {
            gameVisibilities[index] = Boolean(mode.bVisible);
            index++;
         }
      }

      public function reapplyPlacement() : void
      {
         var index:int = 0;
         if(layoutEngine == null || targetConfig == null)
         {
            return;
         }
         while(index < targets.length)
         {
            layoutEngine.positionVanilla(DisplayObject(targets[index]),targetConfig);
            index++;
         }
      }

      public function dispose() : void
      {
         var index:int = 0;
         while(index < targets.length)
         {
            DisplayObject(targets[index]).alpha = Number(initialAlphas[index]);
            DisplayObject(targets[index]).visible = Boolean(initialVisibilities[index]);
            DisplayObject(targets[index]).x = Number(initialXs[index]);
            DisplayObject(targets[index]).y = Number(initialYs[index]);
            index++;
         }
         targets = [];
         initialAlphas = [];
         initialVisibilities = [];
         gameVisibilities = [];
         initialXs = [];
         initialYs = [];
         targetConfig = null;
         layoutEngine = null;
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

      private function getHudModeIndex(param1:String) : int
      {
         var targetName:String = normalizeTarget(param1);
         if(targetName == "topcenter")
         {
            return int(HUDUtils.TOP_CENTER_GROUP);
         }
         if(targetName == "bottomleft")
         {
            return int(HUDUtils.BOTTOM_LEFT_GROUP);
         }
         if(targetName == "rightmeters")
         {
            return int(HUDUtils.RIGHT_METERS);
         }
         if(targetName == "socialcommandicons")
         {
            return int(HUDUtils.SOCIAL_COMMAND_ICONS);
         }
         if(targetName == "floatingquestmarkers")
         {
            return int(HUDUtils.FLOATING_QUEST_MARKERS);
         }
         return -1;
      }
   }
}
