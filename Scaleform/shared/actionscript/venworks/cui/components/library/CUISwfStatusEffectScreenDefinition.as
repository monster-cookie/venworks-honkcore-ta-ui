package venworks.cui.components.library
{
   public final class CUISwfStatusEffectScreenDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <statusEffectBar id="helmet.status-effects" x="53" y="76" width="720" height="56" opacity="1" visible="true"
                                     rotation="0" scaleX="1" scaleY="1" z="1" maxItems="16"
                                     debuffColor="#FF3C54" sustenanceColor="#E8F0F4" neutralColor="#FFFFFF"
                                     backgroundColor="#0D1114" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <statusEffectBar id="helmet.status-effects" x="53" y="76" width="720" height="56" opacity="1" visible="true"
                                  rotation="0" scaleX="1" scaleY="1" z="1" maxItems="16"
                                  debuffColor="@palette.colors.state.critical" sustenanceColor="@palette.colors.accent.primary" neutralColor="@palette.colors.foreground.primary"
                                  backgroundColor="@palette.colors.panel.background" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
