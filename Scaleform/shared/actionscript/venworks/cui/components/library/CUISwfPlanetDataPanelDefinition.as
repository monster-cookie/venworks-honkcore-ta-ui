package venworks.cui.components.library
{
   public final class CUISwfPlanetDataPanelDefinition
   {
      public static function create(param1:String) : XML
      {
         if(param1 == "minimalist")
         {
            return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
              <group id="root" x="0" y="0" width="360" height="254" opacity="1" visible="true"
                     rotation="0" scaleX="1" scaleY="1" z="0">
                <shape id="environmental-hazard.backing.base" x="0" y="0" width="360" height="254" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-2"
                       shape="rectangle" fillColor="#0D1114" fillOpacity="0.28" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <shape id="environmental-hazard.backing.tint" x="0" y="0" width="360" height="254" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="-1"
                       shape="rectangle" fillColor="#70CFE0" fillOpacity="0.10" strokeColor="#D9E3E8" strokeOpacity="0" strokeWidth="0" />
                <text id="planet.title" x="12" y="6" width="156" height="22" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" value="PLANET DATA"
                      font="$MAIN_Font_Bold" fontSize="13" color="#E8F0F4" bold="false" align="left" />
                <text id="planet.time.label" x="214" y="8" width="68" height="22" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" value="LOCAL"
                      font="$MAIN_Font_Bold" fontSize="8" color="#C6D0D6" bold="false" align="right" />
                <text id="planet.time" x="288" y="6" width="58" height="22" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" source="environment.localTime" format="time24"
                      value="--:--" font="$MAIN_Font_Bold" fontSize="10" color="#FFFFFF" bold="false" align="right" />

                <divider id="planet.corner.tl.h" x="8" y="32" width="42" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.tl.v" x="8" y="32" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.tr.h" x="310" y="32" width="42" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.tr.v" x="352" y="32" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.bl.h" x="8" y="92" width="42" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.bl.v" x="8" y="78" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.br.h" x="310" y="92" width="42" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <divider id="planet.corner.br.v" x="352" y="78" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.55" strokeWidth="1" />
                <text id="planet.name" x="14" y="34" width="332" height="22" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" source="location.name" format="raw"
                      value="LOCATION WAITING" font="$MAIN_Font_Bold" fontSize="10" color="#FFFFFF" bold="false" align="left" />
                <text id="planet.solar-transition" x="14" y="52" width="332" height="22" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" source="environment.solarTransitionCountdown" format="raw"
                      value="" font="$MAIN_Font_Bold" fontSize="8" color="#FFFFFF" bold="true" align="left" />
                <divider id="planet.metrics.line" x="14" y="70" width="332" height="0" opacity="1" visible="true"
                         rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <text id="planet.oxygen.label" x="14" y="70" width="20" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" value="O2" font="$MAIN_Font_Bold" fontSize="9" color="#C6D0D6" bold="false" align="left" />
                <text id="planet.oxygen" x="36" y="70" width="48" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" source="environment.oxygenPercentage" format="percent" value="--%" font="$MAIN_Font_Bold" fontSize="9" color="#FFFFFF" bold="false" align="left" />
                <text id="planet.temperature.label" x="94" y="70" width="36" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" value="TEMP" font="$MAIN_Font_Bold" fontSize="9" color="#C6D0D6" bold="false" align="left" />
                <text id="planet.temperature" x="132" y="70" width="58" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" source="environment.temperature" format="temperature" value="--°" font="$MAIN_Font_Bold" fontSize="9" color="#FFFFFF" bold="false" align="left" />
                <text id="planet.gravity.label" x="200" y="70" width="36" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" value="GRAV" font="$MAIN_Font_Bold" fontSize="9" color="#C6D0D6" bold="false" align="left" />
                <text id="planet.gravity" x="238" y="70" width="72" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" source="environment.gravity" format="gravity" value="--.--g" font="$MAIN_Font_Bold" fontSize="9" color="#FFFFFF" bold="false" align="left" />

                <text id="title" x="12" y="98" width="336" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" value="ENVIRONMENTAL HAZARDS" font="$MAIN_Font_Bold" fontSize="13" color="#E8F0F4" bold="false" align="left" />
                <divider id="header.line" x="8" y="119" width="344" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#E8F0F4" strokeOpacity="0.68" strokeWidth="1" />

                <divider id="protection.corner.tl.h" x="8" y="125" width="34" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.tl.v" x="8" y="125" width="0" height="10" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.tr.h" x="318" y="125" width="34" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.tr.v" x="352" y="125" width="0" height="10" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.bl.h" x="8" y="161" width="34" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.bl.v" x="8" y="151" width="0" height="10" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.br.h" x="318" y="161" width="34" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <divider id="protection.corner.br.v" x="352" y="151" width="0" height="10" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.45" strokeWidth="1" />
                <text id="protection.label" x="14" y="126" width="106" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" value="SUIT PROTECTION" font="$MAIN_Font_Bold" fontSize="9" color="#E8F0F4" bold="false" align="left" />
                <text id="protection.status" x="122" y="126" width="166" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" source="environment.protectionStatus" format="raw" value="PROVIDER WAITING" font="$MAIN_Font_Bold" fontSize="8" color="#FFD800" bold="false" align="right" />
                <text id="protection.value" x="292" y="125" width="54" height="22" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" source="environment.protectionPercentage" format="percent" value="--%" font="$MAIN_Font_Bold" fontSize="11" color="#FFFFFF" bold="false" align="right" />
                <meter id="protection.meter" x="14" y="148" width="332" height="8" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" style="environment.protection" value="0" max="1" source="environment.protectionLevel" />

                <divider id="channels.corner.tl.h" x="8" y="167" width="38" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.tl.v" x="8" y="167" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.tr.h" x="314" y="167" width="38" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.tr.v" x="352" y="167" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.bl.h" x="8" y="246" width="38" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.bl.v" x="8" y="232" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.br.h" x="314" y="246" width="38" height="0" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channels.corner.br.v" x="352" y="232" width="0" height="14" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1" color="#D9E3E8" strokeOpacity="0.35" strokeWidth="1" />
                <divider id="channel.column1" x="94" y="171" width="0" height="71" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" color="#D9E3E8" strokeOpacity="0.3" strokeWidth="1" />
                <divider id="channel.column2" x="178" y="171" width="0" height="71" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" color="#D9E3E8" strokeOpacity="0.3" strokeWidth="1" />
                <divider id="channel.column3" x="262" y="171" width="0" height="71" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2" color="#D9E3E8" strokeOpacity="0.3" strokeWidth="1" />

                <text id="airwater.label" x="12" y="169" width="80" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" value="AIR / WATER" font="$MAIN_Font_Bold" fontSize="8" color="#E8F0F4" bold="false" align="center" />
                <text id="airwater.status" x="12" y="186" width="80" height="20" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.airWaterShortStatus" format="raw" value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="#FFFFFF" bold="false" align="center" />
                <meter id="airwater.exposure" x="30" y="208" width="44" height="34" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" style="environment.air" value="0" max="1" source="environment.hazard.airWaterExposureLevel" />
                <text id="thermal.label" x="96" y="169" width="80" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" value="THERMAL" font="$MAIN_Font_Bold" fontSize="8" color="#FFD800" bold="false" align="center" />
                <text id="thermal.status" x="96" y="186" width="80" height="20" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.thermalShortStatus" format="raw" value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="#FFFFFF" bold="false" align="center" />
                <meter id="thermal.exposure" x="114" y="208" width="44" height="34" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" style="environment.thermal" value="0" max="1" source="environment.hazard.thermalExposureLevel" />
                <text id="corrosive.label" x="180" y="169" width="80" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" value="CORROSIVE" font="$MAIN_Font_Bold" fontSize="8" color="#FFD800" bold="false" align="center" />
                <text id="corrosive.status" x="180" y="186" width="80" height="20" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.corrosiveShortStatus" format="raw" value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="#FFFFFF" bold="false" align="center" />
                <meter id="corrosive.exposure" x="198" y="208" width="44" height="34" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" style="environment.corrosive" value="0" max="1" source="environment.hazard.corrosiveExposureLevel" />
                <text id="radiation.label" x="264" y="169" width="80" height="18" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" value="RADIATION" font="$MAIN_Font_Bold" fontSize="8" color="#FF3C54" bold="false" align="center" />
                <text id="radiation.status" x="264" y="186" width="80" height="20" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.radiationShortStatus" format="raw" value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="#FFFFFF" bold="false" align="center" />
                <meter id="radiation.exposure" x="282" y="208" width="44" height="34" opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="3" style="environment.radiation" value="0" max="1" source="environment.hazard.radiationExposureLevel" />
              </group>
            </venworksCUIFragment>;
         }
         return <venworksCUIFragment schemaVersion="1" runtimeVersion="1">
           <group id="root" x="0" y="0" width="360" height="254" opacity="1" visible="true"
                  rotation="0" scaleX="1" scaleY="1" z="0">
             <text id="planet.title" x="12" y="6" width="156" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="PLANET DATA"
                   font="$MAIN_Font_Bold" fontSize="13" color="@palette.colors.accent.primary" bold="false" align="left" />
             <text id="planet.time.label" x="214" y="8" width="68" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="LOCAL"
                   font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.foreground.muted" bold="false" align="right" />
             <text id="planet.time" x="288" y="6" width="58" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.localTime" format="time24"
                   value="--:--" font="$MAIN_Font_Bold" fontSize="10" color="@palette.colors.foreground.primary" bold="false" align="right" />
             <text id="planet.solar-transition" x="14" y="52" width="332" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.solarTransitionCountdown" format="raw"
                   value="" font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.foreground.primary" bold="true" align="right" />
             <panel id="planet.panel" x="8" y="32" width="344" height="60" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="1"
                    fillColor="@palette.colors.panel.background" fillOpacity="0.58" strokeColor="@palette.colors.panel.border" strokeOpacity="0.35" strokeWidth="1" />
             <text id="planet.name" x="14" y="34" width="332" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="location.name" format="raw"
                   value="LOCATION WAITING" font="$MAIN_Font_Bold" fontSize="10" color="@palette.colors.foreground.primary" bold="false" align="left" />
             <text id="planet.oxygen.label" x="14" y="70" width="20" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="O2"
                   font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.muted" bold="false" align="left" />
             <text id="planet.oxygen" x="36" y="70" width="48" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.oxygenPercentage" format="percent"
                   value="--%" font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.primary" bold="false" align="left" />
             <text id="planet.temperature.label" x="94" y="70" width="36" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="TEMP"
                   font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.muted" bold="false" align="left" />
             <text id="planet.temperature" x="132" y="70" width="58" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.temperature" format="temperature"
                   value="--°" font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.primary" bold="false" align="left" />
             <text id="planet.gravity.label" x="200" y="70" width="36" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="GRAV"
                   font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.muted" bold="false" align="left" />
             <text id="planet.gravity" x="238" y="70" width="72" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.gravity" format="gravity"
                   value="--.--g" font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.foreground.primary" bold="false" align="left" />

             <text id="title" x="12" y="98" width="336" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="ENVIRONMENTAL HAZARDS"
                   font="$MAIN_Font_Bold" fontSize="13" color="@palette.colors.accent.primary" bold="false" align="left" />
             <divider id="header.line" x="8" y="119" width="344" height="0" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="1" color="@palette.colors.accent.primary" strokeOpacity="0.68" strokeWidth="1" />

             <panel id="protection.panel" x="8" y="125" width="344" height="36" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="1"
                    fillColor="@palette.colors.panel.background" fillOpacity="0.72" strokeColor="@palette.colors.panel.border" strokeOpacity="0.45" strokeWidth="1" />
             <text id="protection.label" x="14" y="126" width="106" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" value="SUIT PROTECTION"
                   font="$MAIN_Font_Bold" fontSize="9" color="@palette.colors.accent.primary" bold="false" align="left" />
             <text id="protection.status" x="122" y="126" width="166" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.protectionStatus" format="raw"
                   value="PROVIDER WAITING" font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.state.caution" bold="false" align="right" />
             <text id="protection.value" x="292" y="125" width="54" height="22" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="2" source="environment.protectionPercentage" format="percent"
                   value="--%" font="$MAIN_Font_Bold" fontSize="11" color="@palette.colors.foreground.primary" bold="false" align="right" />
             <meter id="protection.meter" x="14" y="148" width="332" height="8" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="2" style="environment.protection"
                    value="0" max="1" source="environment.protectionLevel" />

             <panel id="channels.panel" x="8" y="167" width="344" height="79" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="1"
                    fillColor="@palette.colors.panel.background" fillOpacity="0.48" strokeColor="@palette.colors.panel.border" strokeOpacity="0.3" strokeWidth="1" />
             <divider id="channel.column1" x="94" y="171" width="0" height="71" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" color="@palette.colors.panel.border" strokeOpacity="0.3" strokeWidth="1" />
             <divider id="channel.column2" x="178" y="171" width="0" height="71" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" color="@palette.colors.panel.border" strokeOpacity="0.3" strokeWidth="1" />
             <divider id="channel.column3" x="262" y="171" width="0" height="71" opacity="1" visible="true"
                      rotation="0" scaleX="1" scaleY="1" z="2" color="@palette.colors.panel.border" strokeOpacity="0.3" strokeWidth="1" />

             <text id="airwater.label" x="12" y="169" width="80" height="18" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" value="AIR / WATER"
                   font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.accent.primary" bold="false" align="center" />
             <text id="airwater.status" x="12" y="186" width="80" height="20" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.airWaterShortStatus" format="raw"
                   value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="@palette.colors.foreground.primary" bold="false" align="center" />
             <meter id="airwater.exposure" x="30" y="208" width="44" height="34" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="3" style="environment.air"
                    value="0" max="1" source="environment.hazard.airWaterExposureLevel" />

             <text id="thermal.label" x="96" y="169" width="80" height="18" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" value="THERMAL"
                   font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.state.caution" bold="false" align="center" />
             <text id="thermal.status" x="96" y="186" width="80" height="20" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.thermalShortStatus" format="raw"
                   value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="@palette.colors.foreground.primary" bold="false" align="center" />
             <meter id="thermal.exposure" x="114" y="208" width="44" height="34" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="3" style="environment.thermal"
                    value="0" max="1" source="environment.hazard.thermalExposureLevel" />

             <text id="corrosive.label" x="180" y="169" width="80" height="18" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" value="CORROSIVE"
                   font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.state.caution" bold="false" align="center" />
             <text id="corrosive.status" x="180" y="186" width="80" height="20" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.corrosiveShortStatus" format="raw"
                   value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="@palette.colors.foreground.primary" bold="false" align="center" />
             <meter id="corrosive.exposure" x="198" y="208" width="44" height="34" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="3" style="environment.corrosive"
                    value="0" max="1" source="environment.hazard.corrosiveExposureLevel" />

             <text id="radiation.label" x="264" y="169" width="80" height="18" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" value="RADIATION"
                   font="$MAIN_Font_Bold" fontSize="8" color="@palette.colors.state.critical" bold="false" align="center" />
             <text id="radiation.status" x="264" y="186" width="80" height="20" opacity="1" visible="true"
                   rotation="0" scaleX="1" scaleY="1" z="3" source="environment.hazard.radiationShortStatus" format="raw"
                   value="WAITING" font="$MAIN_Font_Bold" fontSize="7" color="@palette.colors.foreground.primary" bold="false" align="center" />
             <meter id="radiation.exposure" x="282" y="208" width="44" height="34" opacity="1" visible="true"
                    rotation="0" scaleX="1" scaleY="1" z="3" style="environment.radiation"
                    value="0" max="1" source="environment.hazard.radiationExposureLevel" />
           </group>
         </venworksCUIFragment>;
      }
   }
}
