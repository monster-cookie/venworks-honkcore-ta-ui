package venworks.cui.components.library
{
   public final class CUISwfComponentLibrary
   {
      public static const STANDARD_VARIANT:String = "standard";
      public static const MINIMALIST_VARIANT:String = "minimalist";

      public static function contains(param1:String) : Boolean
      {
         return param1 == "player-data-panel" ||
            param1 == "planet-data-panel" ||
            param1 == "equipment-rail" ||
            param1 == "faction-icon" ||
            param1 == "compass" ||
            param1 == "quest-tracker" ||
            param1 == "threat-meter" ||
            param1 == "radar" ||
            param1 == "status-effect-screen" ||
            param1 == "scanner-hash-panel" ||
            param1 == "scanner-data-panel";
      }

      public static function isSupportedVariant(param1:String) : Boolean
      {
         return param1 == STANDARD_VARIANT || param1 == MINIMALIST_VARIANT;
      }

      public static function create(param1:String, param2:String) : XML
      {
         if(!isSupportedVariant(param2))
         {
            throw new Error("Unsupported SWF component variant: " + param2);
         }
         if(param1 == "player-data-panel")
         {
            return CUISwfPlayerDataPanelDefinition.create(param2);
         }
         if(param1 == "planet-data-panel")
         {
            return CUISwfPlanetDataPanelDefinition.create(param2);
         }
         if(param1 == "equipment-rail")
         {
            return CUISwfEquipmentRailDefinition.create(param2);
         }
         if(param1 == "faction-icon")
         {
            return CUISwfFactionIconDefinition.create(param2);
         }
         if(param1 == "compass")
         {
            return CUISwfCompassDefinition.create(param2);
         }
         if(param1 == "quest-tracker")
         {
            return CUISwfQuestTrackerDefinition.create(param2);
         }
         if(param1 == "threat-meter")
         {
            return CUISwfThreatMeterDefinition.create(param2);
         }
         if(param1 == "radar")
         {
            return CUISwfRadarDefinition.create(param2);
         }
         if(param1 == "status-effect-screen")
         {
            return CUISwfStatusEffectScreenDefinition.create(param2);
         }
         if(param1 == "scanner-hash-panel")
         {
            return CUISwfScannerHashPanelDefinition.create(param2);
         }
         if(param1 == "scanner-data-panel")
         {
            return CUISwfScannerDataPanelDefinition.create(param2);
         }
         throw new Error("Unknown SWF component: " + param1);
      }
   }
}
