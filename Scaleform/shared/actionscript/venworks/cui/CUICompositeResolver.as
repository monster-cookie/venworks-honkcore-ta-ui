package venworks.cui
{
   public final class CUICompositeResolver
   {
      private static const MAX_QUICK_BAR_BUTTONS:int = 16;
      private static const MAX_INFORMATION_ROWS:int = 12;
      private static const MAX_INFORMATION_ITEMS:int = 20;

      private var usePalette:Boolean;

      public function CUICompositeResolver(param1:Boolean = false)
      {
         super();
         usePalette = param1;
      }

      public function isComposite(param1:String) : Boolean
      {
         return param1 == "button" || param1 == "quickBar" ||
            param1 == "informationPanel" || param1 == "warning";
      }

      public function resolve(param1:XML) : XML
      {
         var type:String = String(param1.name());
         if(type == "button")
         {
            return this.createButton(param1);
         }
         if(type == "quickBar")
         {
            return this.createQuickBar(param1);
         }
         if(type == "informationPanel")
         {
            return this.createInformationPanel(param1);
         }
         if(type == "warning")
         {
            return this.createWarning(param1);
         }
         throw new Error("INVALID|Unknown composite component: " + type);
      }

      private function createButton(param1:XML) : XML
      {
         var id:String = null;
         var label:String = null;
         var iconName:String = null;
         var key:String = null;
         var state:String = null;
         var width:int = 0;
         var height:int = 0;
         var labelX:int = 14;
         var labelWidth:int = 0;
         var panelFill:String = null;
         var panelStroke:String = null;
         var foreground:String = null;
         var accent:String = null;
         var result:XML = null;

         this.requireAttributes(param1,this.commonAttributes().concat(["label","icon","key","state"]));
         this.validatePlacement(param1,160,48);
         id = this.requireId(param1);
         label = this.requireText(param1,"label");
         iconName = this.optionalIcon(param1,"icon");
         key = this.optionalText(param1,"key");
         state = this.requireButtonState(param1);
         width = int(param1.@width);
         height = int(param1.@height);

         panelFill = this.paletteColor("panel.background","#0B202B");
         panelStroke = this.paletteStroke("panel","color","#35E6E6");
         foreground = this.paletteColor("state.normal","#F7FCFF");
         accent = this.paletteColor("accent.primary","#35E6E6");
         if(state == "selected")
         {
            panelFill = this.paletteColor("panel.background","#123C47");
            panelStroke = this.paletteColor("state.selected","#35E6E6");
            foreground = this.paletteColor("state.selected","#35E6E6");
            accent = this.paletteColor("state.selected","#35E6E6");
         }
         else if(state == "disabled")
         {
            panelFill = this.paletteColor("panel.background","#111820");
            panelStroke = this.paletteColor("state.disabled","#63727A");
            foreground = this.paletteColor("state.disabled","#87959C");
            accent = this.paletteColor("state.disabled","#87959C");
         }
         else if(state == "warning")
         {
            panelFill = this.paletteColor("panel.background","#3A2714");
            panelStroke = this.paletteColor("state.caution","#FFB51B");
            foreground = this.paletteColor("state.caution","#FFCB45");
            accent = this.paletteColor("state.caution","#FFB51B");
         }

         result = this.createRoot(param1);
         result.appendChild(this.makePanel(this.childId(id,"background"),0,0,width,height,0,panelFill,
            this.paletteOpacity("panel","0.92"),panelStroke,this.paletteStroke("panel","opacity","1"),
            this.paletteStroke("panel","width","2")));
         if(iconName.length > 0)
         {
            result.appendChild(this.makeIcon(this.childId(id,"icon"),14,int((height - 26) / 2),26,26,1,iconName,accent));
            labelX = 50;
         }
         labelWidth = width - labelX - 14;
         if(key.length > 0)
         {
            labelWidth -= 48;
            result.appendChild(this.makePanel(this.childId(id,"keyBackground"),width - 46,int((height - 30) / 2),32,30,1,
               this.paletteColor("panel.background","#07141B"),this.paletteOpacity("muted","0.85"),panelStroke,
               this.paletteOpacity("muted","0.7"),this.paletteStroke("panel","width","1")));
            result.appendChild(this.makeText(this.childId(id,"key"),width - 44,int((height - 20) / 2),28,20,2,key,
               "label",12,foreground,"true","center"));
         }
         if(labelWidth <= 0)
         {
            throw new Error("INVALID|Button " + id + " is too narrow for its configured content.");
         }
         result.appendChild(this.makeText(this.childId(id,"label"),labelX,int((height - 22) / 2),labelWidth,22,2,label,
            "label",14,foreground,"true","left"));
         return result;
      }

      private function createQuickBar(param1:XML) : XML
      {
         var id:String = null;
         var width:int = 0;
         var height:int = 0;
         var buttonHeight:int = 0;
         var gap:int = 0;
         var declaredCount:int = 0;
         var visibleIndex:int = 0;
         var childIds:Object = {};
         var child:XML = null;
         var childId:String = null;
         var y:int = 0;
         var synthetic:XML = null;
         var result:XML = null;

         this.requireAttributes(param1,this.commonAttributes().concat(["buttonHeight","gap"]));
         this.validatePlacement(param1,160,48);
         id = this.requireId(param1);
         width = int(param1.@width);
         height = int(param1.@height);
         buttonHeight = this.requirePositiveInteger(param1,"buttonHeight");
         gap = this.requireNonNegativeInteger(param1,"gap");
         if(buttonHeight < 48)
         {
            throw new Error("INVALID|Quick bar buttonHeight must be at least 48: " + id);
         }

         result = this.createRoot(param1);
         for each(child in param1.children())
         {
            if(String(child.name()) != "button")
            {
               throw new Error("INVALID|Quick bar " + id + " may contain only button elements.");
            }
            ++declaredCount;
            if(declaredCount > MAX_QUICK_BAR_BUTTONS)
            {
               throw new Error("INVALID|Quick bar " + id + " exceeds the 16-button limit.");
            }
            this.requireAttributes(child,["id","label","icon","key","state","visible","visibleWhen"]);
            childId = this.requireId(child);
            if(childIds["$" + childId] != null)
            {
               throw new Error("INVALID|Duplicate quick bar button id: " + childId);
            }
            childIds["$" + childId] = true;
            this.requireText(child,"label");
            this.optionalIcon(child,"icon");
            this.optionalText(child,"key");
            this.requireButtonState(child);
            if(!this.readOptionalBoolean(child,"visible",true))
            {
               continue;
            }
            y = visibleIndex * (buttonHeight + gap);
            if(y + buttonHeight > height)
            {
               throw new Error("INVALID|Quick bar " + id + " content exceeds its configured bounds.");
            }
            synthetic = <button />;
            synthetic.@id = this.childId(id,childId);
            synthetic.@x = 0;
            synthetic.@y = y;
            synthetic.@width = width;
            synthetic.@height = buttonHeight;
            synthetic.@opacity = this.paletteOpacity("opaque","1");
            synthetic.@visible = "true";
            synthetic.@rotation = 0;
            synthetic.@scaleX = 1;
            synthetic.@scaleY = 1;
            synthetic.@z = visibleIndex;
            synthetic.@label = String(child.@label);
            synthetic.@state = String(child.@state).toLowerCase();
            this.copyOptionalAttribute(child,synthetic,"icon");
            this.copyOptionalAttribute(child,synthetic,"key");
            this.copyOptionalAttribute(child,synthetic,"visibleWhen");
            result.appendChild(this.createButton(synthetic));
            ++visibleIndex;
         }
         if(declaredCount == 0)
         {
            throw new Error("INVALID|Quick bar " + id + " requires at least one button.");
         }
         if(visibleIndex == 0)
         {
            throw new Error("INVALID|Quick bar " + id + " must contain at least one visible button.");
         }
         return result;
      }

      private function createInformationPanel(param1:XML) : XML
      {
         var id:String = null;
         var title:String = null;
         var titleIcon:String = null;
         var body:String = null;
         var width:int = 0;
         var height:int = 0;
         var contentY:int = 62;
         var titleX:int = 16;
         var rowCount:int = 0;
         var itemCount:int = 0;
         var child:XML = null;
         var childType:String = null;
         var childId:String = null;
         var itemHeight:int = 0;
         var result:XML = null;

         this.requireAttributes(param1,this.commonAttributes().concat(["title","icon","body"]));
         this.validatePlacement(param1,300,150);
         id = this.requireId(param1);
         title = this.requireText(param1,"title");
         titleIcon = this.optionalIcon(param1,"icon");
         body = this.optionalText(param1,"body");
         width = int(param1.@width);
         height = int(param1.@height);
         result = this.createRoot(param1);
         result.appendChild(this.makePanel(this.childId(id,"background"),0,0,width,height,0,
            this.paletteColor("panel.background","#091C27"),this.paletteOpacity("panel","0.92"),
            this.paletteStroke("panel","color","#35E6E6"),this.paletteStroke("panel","opacity","1"),
            this.paletteStroke("panel","width","2")));
         if(titleIcon.length > 0)
         {
            result.appendChild(this.makeIcon(this.childId(id,"titleIcon"),16,14,28,28,2,titleIcon,
               this.paletteColor("accent.primary","#35E6E6")));
            titleX = 52;
         }
         result.appendChild(this.makeText(this.childId(id,"title"),titleX,14,width - titleX - 16,28,2,title,
            "heading",18,this.paletteTypography("heading","color","#F7FCFF"),"true","left"));
         result.appendChild(this.makeDivider(this.childId(id,"headerDivider"),16,50,width - 32,1,1,
            this.paletteColor("accent.primary","#35E6E6"),this.paletteOpacity("panel","0.9"),
            this.paletteStroke("panel","width","1")));
         if(body.length > 0)
         {
            result.appendChild(this.makeText(this.childId(id,"body"),16,contentY,width - 32,42,1,body,
               "body",13,this.paletteTypography("body","color","#C8DCE4"),"false","left"));
            contentY += 50;
         }

         for each(child in param1.children())
         {
            childType = String(child.name());
            if(childType != "row" && childType != "meter" && childType != "divider")
            {
               throw new Error("INVALID|Information panel " + id + " contains unsupported child: " + childType);
            }
            ++itemCount;
            if(itemCount > MAX_INFORMATION_ITEMS)
            {
               throw new Error("INVALID|Information panel " + id + " exceeds the 20-item limit.");
            }
            if(childType == "row")
            {
               ++rowCount;
               if(rowCount > MAX_INFORMATION_ROWS)
               {
                  throw new Error("INVALID|Information panel " + id + " exceeds the 12-row limit.");
               }
            }
            if(!this.readOptionalBoolean(child,"visible",true))
            {
               this.validateInformationChild(child,childType);
               continue;
            }
            childId = this.requireId(child);
            if(childType == "row")
            {
               itemHeight = 30;
            }
            else if(childType == "meter")
            {
               itemHeight = 48;
            }
            else
            {
               itemHeight = 14;
            }
            if(contentY + itemHeight + 12 > height)
            {
               throw new Error("INVALID|Information panel " + id + " content exceeds its configured bounds.");
            }
            if(childType == "row")
            {
               result.appendChild(this.createInformationRow(id,child,contentY,width));
            }
            else if(childType == "meter")
            {
               result.appendChild(this.createInformationMeter(id,child,contentY,width));
            }
            else
            {
               result.appendChild(this.createInformationDivider(id,child,contentY,width));
            }
            contentY += itemHeight;
         }
         if(body.length == 0 && itemCount == 0)
         {
            throw new Error("INVALID|Information panel " + id + " requires body text or at least one content item.");
         }
         return result;
      }

      private function validateInformationChild(param1:XML, param2:String) : void
      {
         if(param2 == "row")
         {
            this.requireAttributes(param1,["id","label","value","icon","visible","visibleWhen"]);
            this.requireId(param1);
            this.requireText(param1,"label");
            this.requireText(param1,"value");
            this.optionalIcon(param1,"icon");
         }
         else if(param2 == "meter")
         {
            this.requireAttributes(param1,["id","label","style","value","max","icon","visible","visibleWhen"]);
            this.requireId(param1);
            this.optionalText(param1,"label");
            this.requireNamedValue(param1,"style");
            this.requireFinite(param1,"value");
            if(this.requireFinite(param1,"max") <= 0)
            {
               throw new Error("INVALID|Information panel meter max must be greater than zero: " + String(param1.@id));
            }
            this.optionalIcon(param1,"icon");
         }
         else
         {
            this.requireAttributes(param1,["id","visible","visibleWhen"]);
            this.requireId(param1);
         }
      }

      private function createInformationRow(param1:String, param2:XML, param3:int, param4:int) : XML
      {
         var localId:String = String(param2.@id);
         var iconName:String = null;
         var labelX:int = 0;
         var result:XML = <group />;
         this.validateInformationChild(param2,"row");
         this.setBase(result,this.childId(param1,localId),16,param3,param4 - 32,30,1);
         this.copyChildVisibility(param2,result);
         iconName = this.optionalIcon(param2,"icon");
         labelX = 0;
         if(iconName.length > 0)
         {
            result.appendChild(this.makeIcon(this.childId(String(result.@id),"icon"),0,5,20,20,1,iconName,
               this.paletteColor("accent.primary","#35E6E6")));
            labelX = 28;
         }
         result.appendChild(this.makeText(this.childId(String(result.@id),"label"),labelX,4,int((param4 - 32) * 0.52) - labelX,22,1,
            String(param2.@label),"label",13,this.paletteTypography("label","color","#C8DCE4"),"false","left"));
         result.appendChild(this.makeText(this.childId(String(result.@id),"value"),int((param4 - 32) * 0.52),4,
            int((param4 - 32) * 0.48),22,1,String(param2.@value),"body",13,
            this.paletteTypography("body","color","#F7FCFF"),"true","right"));
         return result;
      }

      private function createInformationMeter(param1:String, param2:XML, param3:int, param4:int) : XML
      {
         var localId:String = String(param2.@id);
         var iconName:String = null;
         var label:String = null;
         var labelX:int = 0;
         var result:XML = <group />;
         this.validateInformationChild(param2,"meter");
         this.setBase(result,this.childId(param1,localId),16,param3,param4 - 32,48,1);
         this.copyChildVisibility(param2,result);
         iconName = this.optionalIcon(param2,"icon");
         label = this.optionalText(param2,"label");
         labelX = 0;
         if(iconName.length > 0)
         {
            result.appendChild(this.makeIcon(this.childId(String(result.@id),"icon"),0,0,20,20,1,iconName,
               this.paletteColor("accent.primary","#35E6E6")));
            labelX = 28;
         }
         if(label.length > 0)
         {
            result.appendChild(this.makeText(this.childId(String(result.@id),"label"),labelX,0,param4 - 32 - labelX,20,1,label,
               "label",12,this.paletteTypography("label","color","#C8DCE4"),"true","left"));
         }
         result.appendChild(this.makeMeter(this.childId(String(result.@id),"meter"),0,25,param4 - 32,16,1,String(param2.@style),String(param2.@value),String(param2.@max)));
         return result;
      }

      private function createInformationDivider(param1:String, param2:XML, param3:int, param4:int) : XML
      {
         var result:XML = <group />;
         this.validateInformationChild(param2,"divider");
         this.setBase(result,this.childId(param1,String(param2.@id)),16,param3,param4 - 32,14,1);
         this.copyChildVisibility(param2,result);
         result.appendChild(this.makeDivider(this.childId(String(result.@id),"line"),0,6,param4 - 32,1,1,
            this.paletteColor("accent.primary","#35E6E6"),this.paletteOpacity("muted","0.55"),
            this.paletteStroke("panel","width","1")));
         return result;
      }

      private function createWarning(param1:XML) : XML
      {
         var id:String = null;
         var severity:String = null;
         var iconName:String = null;
         var title:String = null;
         var message:String = null;
         var width:int = 0;
         var height:int = 0;
         var fillColor:String = null;
         var strokeColor:String = null;
         var accentColor:String = null;
         var result:XML = null;

         this.requireAttributes(param1,this.commonAttributes().concat(["severity","icon","title","message"]));
         this.validatePlacement(param1,320,100);
         id = this.requireId(param1);
         severity = String(param1.@severity).toLowerCase();
         if(severity != "info" && severity != "warning" && severity != "danger" && severity != "critical")
         {
            throw new Error("INVALID|Unsupported warning severity: " + severity);
         }
         iconName = this.optionalIcon(param1,"icon");
         if(iconName.length == 0)
         {
            iconName = severity == "info" ? "shield" : "warning";
         }
         title = this.requireText(param1,"title");
         message = this.requireText(param1,"message");
         width = int(param1.@width);
         height = int(param1.@height);
         fillColor = this.paletteColor("panel.background","#08242C");
         strokeColor = this.paletteColor("accent.primary","#35E6E6");
         accentColor = this.paletteColor("accent.primary","#35E6E6");
         if(severity == "warning")
         {
            fillColor = this.paletteColor("panel.background","#332412");
            strokeColor = this.paletteColor("state.caution","#FFB51B");
            accentColor = this.paletteColor("state.caution","#FFCB45");
         }
         else if(severity == "danger")
         {
            fillColor = this.paletteColor("panel.background","#351B16");
            strokeColor = this.paletteColor("state.danger","#FF6B4A");
            accentColor = this.paletteColor("state.danger","#FF8A70");
         }
         else if(severity == "critical")
         {
            fillColor = this.paletteColor("panel.background","#350F12");
            strokeColor = this.paletteColor("state.critical","#FF4545");
            accentColor = this.paletteColor("state.critical","#FF6868");
         }

         result = this.createRoot(param1);
         result.appendChild(this.makePanel(this.childId(id,"background"),0,0,width,height,0,fillColor,
            this.paletteOpacity("panel","0.94"),strokeColor,this.paletteStroke("panel","opacity","1"),
            this.paletteStroke("panel","width","2")));
         result.appendChild(this.makeIcon(this.childId(id,"icon"),18,int((height - 40) / 2),40,40,1,iconName,accentColor));
         result.appendChild(this.makeText(this.childId(id,"title"),72,16,width - 90,25,2,title,
            "heading",17,accentColor,"true","left"));
         result.appendChild(this.makeText(this.childId(id,"message"),72,46,width - 90,height - 58,2,message,
            "body",13,this.paletteTypography("body","color","#F7FCFF"),"false","left"));
         return result;
      }

      private function createRoot(param1:XML) : XML
      {
         var result:XML = <group />;
         this.setBase(result,String(param1.@id),Number(param1.@x),Number(param1.@y),int(param1.@width),int(param1.@height),int(param1.@z));
         result.@opacity = param1.@opacity.length() == 1 ? String(param1.@opacity) : this.paletteOpacity("opaque","1");
         result.@visible = param1.@visible.length() == 1 ? String(param1.@visible).toLowerCase() : "true";
         result.@rotation = param1.@rotation.length() == 1 ? String(param1.@rotation) : "0";
         result.@scaleX = param1.@scaleX.length() == 1 ? String(param1.@scaleX) : "1";
         result.@scaleY = param1.@scaleY.length() == 1 ? String(param1.@scaleY) : "1";
         this.copyOptionalAttribute(param1,result,"anchor");
         this.copyOptionalAttribute(param1,result,"visibleWhen");
         return result;
      }

      private function setBase(param1:XML, param2:String, param3:Number, param4:Number, param5:int, param6:int, param7:int) : void
      {
         param1.@id = param2;
         param1.@x = param3;
         param1.@y = param4;
         param1.@width = param5;
         param1.@height = param6;
         param1.@opacity = this.paletteOpacity("opaque","1");
         param1.@visible = "true";
         param1.@rotation = 0;
         param1.@scaleX = 1;
         param1.@scaleY = 1;
         param1.@z = param7;
      }

      private function makePanel(param1:String, param2:int, param3:int, param4:int, param5:int, param6:int, param7:String, param8:String, param9:String, param10:String, param11:String) : XML
      {
         var result:XML = <panel />;
         this.setBase(result,param1,param2,param3,param4,param5,param6);
         result.@fillColor = param7;
         result.@fillOpacity = param8;
         result.@strokeColor = param9;
         result.@strokeOpacity = param10;
         result.@strokeWidth = param11;
         return result;
      }

      private function makeText(param1:String, param2:int, param3:int, param4:int, param5:int, param6:int, param7:String, param8:String, param9:int, param10:String, param11:String, param12:String) : XML
      {
         var result:XML = <text />;
         this.setBase(result,param1,param2,param3,param4,param5,param6);
         result.@value = param7;
         result.@font = this.paletteTypography(param8,"font","$MAIN_Font_Bold");
         result.@fontSize = this.paletteTypography(param8,"fontSize",String(param9));
         result.@color = param10;
         result.@bold = this.paletteTypography(param8,"bold",param11);
         result.@align = param12;
         return result;
      }

      private function makeIcon(param1:String, param2:int, param3:int, param4:int, param5:int, param6:int, param7:String, param8:String) : XML
      {
         var result:XML = <icon />;
         this.setBase(result,param1,param2,param3,param4,param5,param6);
         result.@name = param7;
         result.@color = param8;
         result.@fit = "contain";
         result.@alignX = "center";
         result.@alignY = "center";
         return result;
      }

      private function makeDivider(param1:String, param2:int, param3:int, param4:int, param5:int, param6:int, param7:String, param8:String, param9:String) : XML
      {
         var result:XML = <divider />;
         this.setBase(result,param1,param2,param3,param4,param5,param6);
         result.@color = param7;
         result.@strokeOpacity = param8;
         result.@strokeWidth = param9;
         return result;
      }

      private function makeMeter(param1:String, param2:int, param3:int, param4:int, param5:int, param6:int, param7:String, param8:String, param9:String) : XML
      {
         var result:XML = <meter />;
         this.setBase(result,param1,param2,param3,param4,param5,param6);
         result.@style = param7;
         result.@value = param8;
         result.@max = param9;
         return result;
      }

      private function paletteColor(param1:String, param2:String) : String
      {
         return usePalette ? "@palette.colors." + param1 : param2;
      }

      private function paletteOpacity(param1:String, param2:String) : String
      {
         return usePalette ? "@palette.opacities." + param1 : param2;
      }

      private function paletteStroke(param1:String, param2:String, param3:String) : String
      {
         return usePalette ? "@palette.strokes." + param1 + "." + param2 : param3;
      }

      private function paletteTypography(param1:String, param2:String, param3:String) : String
      {
         return usePalette ? "@palette.typography." + param1 + "." + param2 : param3;
      }

      private function commonAttributes() : Array
      {
         return ["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor"];
      }

      private function validatePlacement(param1:XML, param2:int, param3:int) : void
      {
         this.requireId(param1);
         this.requireFinite(param1,"x");
         this.requireFinite(param1,"y");
         this.requireInteger(param1,"z");
         if(this.requireNonNegativeInteger(param1,"width") < param2 || this.requireNonNegativeInteger(param1,"height") < param3)
         {
            throw new Error("INVALID|" + String(param1.name()) + " " + String(param1.@id) + " must be at least " + param2 + "x" + param3 + ".");
         }
         this.requireOptionalFinite(param1,"opacity");
         this.requireOptionalFinite(param1,"rotation");
         this.requireOptionalFinite(param1,"scaleX");
         this.requireOptionalFinite(param1,"scaleY");
         this.readOptionalBoolean(param1,"visible",true);
         if(param1.@anchor.length() == 1 && ["top-left","top-center","top-right","center-left","center","center-right","bottom-left","bottom-center","bottom-right"].indexOf(String(param1.@anchor)) < 0)
         {
            throw new Error("INVALID|Unsupported anchor on " + String(param1.@id) + ": " + String(param1.@anchor));
         }
      }

      private function requireAttributes(param1:XML, param2:Array) : void
      {
         var attribute:XML = null;
         var name:String = null;
         for each(attribute in param1.attributes())
         {
            name = String(attribute.name());
            if(param2.indexOf(name) < 0)
            {
               throw new Error("INVALID|Unknown attribute '" + name + "' on " + String(param1.name()) + ".");
            }
         }
      }

      private function requireId(param1:XML) : String
      {
         var id:String = String(param1.@id);
         var componentType:String = String(param1.name());
         if(param1.@id.length() != 1 || id.length == 0)
         {
            throw new Error("INVALID|Missing id on " + componentType + ".");
         }
         if(id.length > 64)
         {
            throw new Error("INVALID|Id on " + componentType + " exceeds the 64-character limit (" + id.length.toString() + "): " + id);
         }
         if(!/^[A-Za-z][A-Za-z0-9._-]*$/.test(id))
         {
            throw new Error("INVALID|Id on " + componentType + " contains unsupported characters: " + id);
         }
         return id;
      }

      private function childId(param1:String, param2:String) : String
      {
         var result:String = param1 + "." + param2;
         if(result.length > 64 || !/^[A-Za-z][A-Za-z0-9._-]{0,63}$/.test(result))
         {
            throw new Error("INVALID|Generated composite id exceeds the 64-character limit: " + result);
         }
         return result;
      }

      private function requireNamedValue(param1:XML, param2:String) : String
      {
         var value:String = String(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || !/^[A-Za-z][A-Za-z0-9._-]{0,63}$/.test(value))
         {
            throw new Error("INVALID|Invalid or missing " + param2 + " on " + String(param1.name()) + ".");
         }
         return value;
      }

      private function requireText(param1:XML, param2:String) : String
      {
         var value:String = String(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || value.replace(/^\s+|\s+$/g,"").length == 0)
         {
            throw new Error("INVALID|Missing or empty " + param2 + " on " + String(param1.name()) + ".");
         }
         return value;
      }

      private function optionalText(param1:XML, param2:String) : String
      {
         if(param1.attribute(param2).length() == 0)
         {
            return "";
         }
         return this.requireText(param1,param2);
      }

      private function optionalIcon(param1:XML, param2:String) : String
      {
         var value:String = "";
         var role:String = null;
         if(param1.attribute(param2).length() == 0)
         {
            return value;
         }
         value = String(param1.attribute(param2));
         if(usePalette && value.indexOf("@palette.assets.") == 0)
         {
            role = value.substring(16);
            if(/^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)*$/.test(role) && role.length <= 64)
            {
               return value;
            }
         }
         value = value.toLowerCase();
         if(!/^[a-z][a-z0-9-]{0,63}$/.test(value))
         {
            throw new Error("INVALID|Invalid icon key on " + String(param1.name()) + ": " + value);
         }
         return value;
      }

      private function requireButtonState(param1:XML) : String
      {
         var value:String = String(param1.@state).toLowerCase();
         if(param1.@state.length() != 1 || (value != "normal" && value != "selected" && value != "disabled" && value != "warning"))
         {
            throw new Error("INVALID|Unsupported button state: " + value);
         }
         return value;
      }

      private function readOptionalBoolean(param1:XML, param2:String, param3:Boolean) : Boolean
      {
         var value:String = null;
         if(param1.attribute(param2).length() == 0)
         {
            return param3;
         }
         value = String(param1.attribute(param2)).toLowerCase();
         if(value != "true" && value != "false")
         {
            throw new Error("INVALID|" + param2 + " must be true or false on " + String(param1.name()) + ".");
         }
         return value == "true";
      }

      private function requireInteger(param1:XML, param2:String) : int
      {
         if(param1.attribute(param2).length() != 1 || !/^-?[0-9]+$/.test(String(param1.attribute(param2))))
         {
            throw new Error("INVALID|" + param2 + " must be an integer on " + String(param1.name()) + ".");
         }
         return int(param1.attribute(param2));
      }

      private function requirePositiveInteger(param1:XML, param2:String) : int
      {
         if(param1.attribute(param2).length() != 1 || !/^[0-9]+$/.test(String(param1.attribute(param2))) || int(param1.attribute(param2)) < 1)
         {
            throw new Error("INVALID|" + param2 + " must be a positive integer on " + String(param1.name()) + ".");
         }
         return int(param1.attribute(param2));
      }

      private function requireNonNegativeInteger(param1:XML, param2:String) : int
      {
         if(param1.attribute(param2).length() != 1 || !/^[0-9]+$/.test(String(param1.attribute(param2))))
         {
            throw new Error("INVALID|" + param2 + " must be a non-negative integer on " + String(param1.name()) + ".");
         }
         return int(param1.attribute(param2));
      }

      private function requireFinite(param1:XML, param2:String) : Number
      {
         var value:Number = Number(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || isNaN(value) || !isFinite(value))
         {
            throw new Error("INVALID|" + param2 + " must be a finite number on " + String(param1.name()) + ".");
         }
         return value;
      }

      private function requireOptionalFinite(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() == 1)
         {
            this.requireFinite(param1,param2);
         }
      }

      private function copyOptionalAttribute(param1:XML, param2:XML, param3:String) : void
      {
         if(param1.attribute(param3).length() == 0)
         {
            return;
         }
         if(param3 == "anchor")
         {
            param2.@anchor = String(param1.@anchor);
         }
         else if(param3 == "visibleWhen")
         {
            param2.@visibleWhen = String(param1.@visibleWhen);
         }
         else if(param3 == "icon")
         {
            param2.@icon = String(param1.@icon).toLowerCase();
         }
         else if(param3 == "key")
         {
            param2.@key = String(param1.@key);
         }
      }

      private function copyChildVisibility(param1:XML, param2:XML) : void
      {
         param2.@visible = param1.@visible.length() == 1 ? String(param1.@visible).toLowerCase() : "true";
         this.copyOptionalAttribute(param1,param2,"visibleWhen");
      }
   }
}
