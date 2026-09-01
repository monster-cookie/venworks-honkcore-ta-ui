package venworks.cui.components.library
{
   public final class CUISwfCompassDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <shape id="helmet.compass.backing.base" x="0" y="-58" width="826" height="48" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-2"
                           shape="rectangle" fillColor="#0D1114" fillOpacity="0.28" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <shape id="helmet.compass.backing.tint" x="0" y="-58" width="826" height="48" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-1"
                           shape="rectangle" fillColor="#70CFE0" fillOpacity="0.10" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <compassTape id="helmet.compass" x="0" y="-58" width="826" height="48" opacity="1" visible="true"
                                 rotation="0" scaleX="1" scaleY="1" z="3" fieldOfView="120"
                                 tickColor="#E8F0F4" headingColor="#FFFFFF" centerColor="#FFFFFF" fallbackColor="#FFFFFF" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="root" x="0" y="0" width="826" height="132" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <compassTape id="helmet.compass" x="0" y="-58" width="826" height="48" opacity="1" visible="true"
                              rotation="0" scaleX="1" scaleY="1" z="3" fieldOfView="120"
                              tickColor="@palette.colors.accent.primary" headingColor="@palette.colors.foreground.primary" centerColor="@palette.colors.marker.player" fallbackColor="@palette.colors.foreground.primary" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
