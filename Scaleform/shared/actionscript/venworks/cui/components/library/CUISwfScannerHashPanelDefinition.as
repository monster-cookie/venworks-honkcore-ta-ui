package venworks.cui.components.library
{
   public final class CUISwfScannerHashPanelDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="root" x="0" y="0" width="900" height="520" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <scannerOverlay id="scanner.overlay" x="0" y="0" width="900" height="520" opacity="1" visible="true"
                                    rotation="0" scaleX="1" scaleY="1" z="0" fieldOfView="90" section="hash" maxTargets="5"
                                    flickerIntervalMs="140" scanningColor="#E8F0F4" gridColor="#9EADB5"
                                    contactColor="#FFFFFF" hostileColor="#FF3C54" backgroundColor="#0D1114" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="root" x="0" y="0" width="900" height="520" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <scannerOverlay id="scanner.overlay" x="0" y="0" width="900" height="520" opacity="1" visible="true"
                                 rotation="0" scaleX="1" scaleY="1" z="0" fieldOfView="90" section="hash" maxTargets="5"
                                 flickerIntervalMs="140" scanningColor="@palette.colors.accent.primary" gridColor="@palette.colors.accent.secondary"
                                 contactColor="@palette.colors.marker.player" hostileColor="@palette.colors.marker.hostile" backgroundColor="@palette.colors.panel.background" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
