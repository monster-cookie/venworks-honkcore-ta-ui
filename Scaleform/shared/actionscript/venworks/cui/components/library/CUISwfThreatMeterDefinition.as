package venworks.cui.components.library
{
   public final class CUISwfThreatMeterDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <shape id="helmet.threat.backing.base" x="253" y="12" width="320" height="24" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-2"
                           shape="rectangle" fillColor="#0D1114" fillOpacity="0.28" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <shape id="helmet.threat.backing.tint" x="253" y="12" width="320" height="24" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-1"
                           shape="rectangle" fillColor="#70CFE0" fillOpacity="0.10" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <threatAlert id="helmet.threat" x="253" y="12" width="320" height="24" opacity="1" visible="true"
                                 rotation="0" scaleX="1" scaleY="1" z="2" backgroundColor="#0D1114"
                                 clearColor="#64E572" cautionColor="#FFD800" dangerColor="#FF7B21" criticalColor="#FF3C54" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <threatAlert id="helmet.threat" x="253" y="12" width="320" height="24" opacity="1" visible="true"
                              rotation="0" scaleX="1" scaleY="1" z="2" backgroundColor="@palette.colors.panel.background"
                              clearColor="@palette.colors.state.clear" cautionColor="@palette.colors.state.caution" dangerColor="@palette.colors.state.danger" criticalColor="@palette.colors.state.critical" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
