package venworks.cui.components.library
{
   public final class CUISwfFactionIconDefinition
   {
      public static function create(param1:String) : XML
      {
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="faction-display.cluster" x="0" y="0" width="220" height="226" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0">
             <path id="faction-display.panel" x="0" y="0" width="220" height="226" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0"
                   data="M 0 0 L 220 0 L 220 226 L 18 226 Q 0 226 0 208 Z"
                   viewBoxX="0" viewBoxY="0" viewBoxWidth="220" viewBoxHeight="226"
                   fillColor="@palette.colors.panel.background" fillOpacity="0.70" strokeColor="@palette.colors.panel.border" strokeOpacity="0.70" strokeWidth="2" />
             <svg id="faction-display.crest" x="24" y="18" width="172" height="190" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1"
                  src="@palette.assets.faction.logo" fit="contain" alignX="center" alignY="center" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
