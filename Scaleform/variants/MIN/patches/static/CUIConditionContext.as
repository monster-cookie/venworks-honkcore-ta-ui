package venworks.cui
{
   public final class CUIConditionContext
   {
      public function CUIConditionContext()
      {
         super();
      }

      public function start() : void
      {
      }

      public function get lastDisposalError() : String
      {
         return "";
      }

      public function dispose() : void
      {
      }

      public static function normalizeName(param1:String) : String
      {
         return param1.replace(/_/g,"").toLowerCase();
      }

      public static function getKind(param1:String) : String
      {
         var name:String = normalizeName(param1);
         if(/^favorite(0[1-9]|1[0-2])(active|populated|power|weapon|item)$/.test(name))
         {
            return "boolean";
         }
         if(name == "always" || name == "never" || name == "firstperson" || name == "thirdperson" ||
            name == "incombat" || name == "inscanner" || name == "issneaking" ||
            name == "weaponaiming" || name == "weaponhasammo" || name == "weaponhasexplosive" ||
            name == "weaponexplosiveismine" || name == "boostactive" || name == "invehicle" ||
            name == "digipicksavailable" || name == "hudvisible" || name == "criticalhealth")
         {
            return "boolean";
         }
         if(name == "hudopacitypercentage")
         {
            return "number";
         }
         if(name == "hascombateffect" || name == "hasenvironmenteffect")
         {
            return "unavailable-function";
         }
         return "unknown";
      }

      public function getValue(param1:String) : Object
      {
         var name:String = normalizeName(param1);
         if(name == "always")
         {
            return { known:true, value:true };
         }
         if(name == "hudopacitypercentage")
         {
            return { known:false, value:null };
         }
         return { known:true, value:false };
      }

      public function updateCriticalHealth(param1:Object) : void
      {
      }

      public function get hudOpacity() : Number
      {
         return NaN;
      }
   }
}
