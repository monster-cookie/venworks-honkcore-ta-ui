package venworks.cui.components.library
{
   public final class CUISwfQuestTrackerDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="quest-tracker.cluster" x="0" y="0" width="447" height="90" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <shape id="quest-tracker.backing.base" x="0" y="0" width="447" height="90" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-2"
                       shape="rectangle" fillColor="#0D1114" fillOpacity="0.28" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <shape id="quest-tracker.backing.tint" x="0" y="0" width="447" height="90" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-1"
                       shape="rectangle" fillColor="#70CFE0" fillOpacity="0.10" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <divider id="quest.corner.tl.h" x="0" y="0" width="54" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.tl.v" x="0" y="0" width="0" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.tr.h" x="393" y="0" width="54" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.tr.v" x="447" y="0" width="0" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.bl.h" x="0" y="90" width="54" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.bl.v" x="0" y="72" width="0" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.br.h" x="393" y="90" width="54" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <divider id="quest.corner.br.v" x="447" y="72" width="0" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="0" color="#D9E3E8" strokeOpacity="0.70" strokeWidth="2" />
                <text id="quest-tracker.objective" x="18" y="12" width="411" height="66" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="1" source="quest.objective" value=""
                      font="$MAIN_Font_Bold" fontSize="16" color="#FFFFFF" bold="false" multiline="true" wordWrap="true" align="left" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="quest-tracker.cluster" x="0" y="0" width="447" height="90" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <path id="quest-tracker.panel" x="0" y="0" width="447" height="90" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="0"
                   data="M 0 0 L 447 0 L 447 72 Q 447 90 429 90 L 0 90 Z"
                   viewBoxX="0" viewBoxY="0" viewBoxWidth="447" viewBoxHeight="90"
                   fillColor="@palette.colors.panel.background" fillOpacity="0.70" strokeColor="@palette.colors.panel.border" strokeOpacity="0.70" strokeWidth="2" />
             <text id="quest-tracker.objective" x="18" y="12" width="411" height="66" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="1" source="quest.objective" value=""
                   font="$MAIN_Font_Bold" fontSize="16" color="@palette.colors.foreground.primary" bold="false" multiline="true" wordWrap="true" align="left" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
