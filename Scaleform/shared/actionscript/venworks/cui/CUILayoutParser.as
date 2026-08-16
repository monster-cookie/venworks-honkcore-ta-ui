package venworks.cui
{
   public final class CUILayoutParser
   {
      private var meterStyles:Object;
      private var templates:Object;
      private var definitionIds:Object;
      private var componentIds:Object;
      private var componentRoot:XML;
      private var vanillaVisibilityRoot:XML;
      private var conditionParser:CUIConditionParser;

      public function CUILayoutParser()
      {
         super();
      }

      public function parse(param1:XML) : void
      {
         meterStyles = {};
         templates = {};
         definitionIds = {};
         componentIds = {};
         conditionParser = new CUIConditionParser();
         vanillaVisibilityRoot = <vanillaVisibility />;
         this.requireName(param1,"venworksCUI");
         if(param1.descendants("include").length() != 0 || param1.descendants("includes").length() != 0)
         {
            throw new Error("INVALID|Layout imports must be resolved before parsing.");
         }
         this.requireAttributes(param1,["schemaVersion","runtimeVersion","designWidth","designHeight","safeLeft","safeTop","safeRight","safeBottom"]);
         if(String(param1.@schemaVersion) != "1" || String(param1.@runtimeVersion) != "1")
         {
            throw new Error("UNSUPPORTED|Expected schemaVersion=1 and runtimeVersion=1.");
         }
         if(Number(param1.@designWidth) != 1920 || Number(param1.@designHeight) != 1080)
         {
            throw new Error("INVALID|The layout design space must be 1920x1080.");
         }
         this.requireFiniteNonNegative(param1,"safeLeft");
         this.requireFiniteNonNegative(param1,"safeTop");
         this.requireFiniteNonNegative(param1,"safeRight");
         this.requireFiniteNonNegative(param1,"safeBottom");
         if(Number(param1.@safeLeft) + Number(param1.@safeRight) > 1920 ||
            Number(param1.@safeTop) + Number(param1.@safeBottom) > 1080)
         {
            throw new Error("INVALID|Safe-area insets exceed the design space.");
         }
         if(param1.definitions.length() != 1 || param1.components.length() != 1 || param1.vanillaVisibility.length() > 1)
         {
            throw new Error("INVALID|Exactly one definitions and one components element are required; vanillaVisibility is optional.");
         }
         if(param1.children().length() != 2 && param1.children().length() != 3)
         {
            throw new Error("INVALID|Unknown layout root element.");
         }
         if(String(param1.children()[0].name()) != "definitions" ||
            String(param1.children()[param1.children().length() - 1].name()) != "components" ||
            param1.children().length() == 3 && String(param1.children()[1].name()) != "vanillaVisibility")
         {
            throw new Error("INVALID|Root order must be definitions, optional vanillaVisibility, then components.");
         }
         this.parseDefinitions(param1.definitions[0]);
         if(param1.vanillaVisibility.length() == 1)
         {
            this.parseVanillaVisibility(param1.vanillaVisibility[0]);
         }
         componentRoot = new CUICompositionResolver(templates).resolve(param1.components[0]);
         componentIds = {};
         this.validateChildren(componentRoot);
      }

      public function get components() : XML
      {
         return componentRoot;
      }

      public function get vanillaVisibility() : XML
      {
         return vanillaVisibilityRoot;
      }

      public function getMeterStyle(param1:String) : XML
      {
         if(meterStyles[param1] == null)
         {
            throw new Error("INVALID|Unknown meter style reference: " + param1);
         }
         return meterStyles[param1] as XML;
      }

      private function parseDefinitions(param1:XML) : void
      {
         var definition:XML = null;
         var templateDefinitions:Array = [];
         var id:String = null;
         var type:String = null;
         this.requireAttributes(param1,[]);
         if(param1.children().length() == 0)
         {
            throw new Error("INVALID|At least one definition is required.");
         }
         for each(definition in param1.children())
         {
            type = String(definition.name());
            if(type != "meterStyle" && type != "template")
            {
               throw new Error("INVALID|Unknown definition: " + type);
            }
            id = this.requireId(definition);
            if(definitionIds[id] != null)
            {
               throw new Error("INVALID|Duplicate definition id: " + id);
            }
            definitionIds[id] = true;
            if(type == "meterStyle")
            {
               this.parseMeterStyle(definition,id);
            }
            else
            {
               templateDefinitions.push(definition);
            }
         }
         if(templateDefinitions.length > 64)
         {
            throw new Error("INVALID|The layout exceeds the 64-template limit.");
         }
         for each(definition in templateDefinitions)
         {
            this.parseTemplate(definition,String(definition.@id));
         }
      }

      private function parseVanillaVisibility(param1:XML) : void
      {
         var target:XML = null;
         var id:String = null;
         var normalized:String = null;
         var targets:Object = {};
         var count:int = 0;
         this.requireAttributes(param1,[]);
         for each(target in param1.children())
         {
            if(String(target.name()) != "target")
            {
               throw new Error("INVALID|vanillaVisibility may contain only target elements.");
            }
            ++count;
            if(count > 16)
            {
               throw new Error("INVALID|vanillaVisibility exceeds the 16-target limit.");
            }
            this.requireAttributes(target,["id","visibleWhen","x","y","anchor"]);
            id = this.requireId(target);
            normalized = CUIVanillaVisibilityAdapter.normalizeTarget(id);
            if(targets[normalized] != null)
            {
               throw new Error("INVALID|Duplicate vanilla visibility target: " + id);
            }
            if(!CUIVanillaVisibilityAdapter.isAllowlisted(id))
            {
               throw new Error("INVALID|Vanilla visibility target is not allowlisted: " + id);
            }
            targets[normalized] = true;
            this.requireCondition(target,"visibleWhen");
            if(target.@x.length() + target.@y.length() + target.@anchor.length() != 0)
            {
               if(target.@x.length() != 1 || target.@y.length() != 1 || target.@anchor.length() != 1)
               {
                  throw new Error("INVALID|Vanilla target placement requires x, y, and anchor together: " + id);
               }
               this.requireFinite(target,"x");
               this.requireFinite(target,"y");
               this.requireOptionalAnchor(target);
            }
            vanillaVisibilityRoot.appendChild(target.copy());
         }
         if(count == 0)
         {
            throw new Error("INVALID|vanillaVisibility requires at least one target.");
         }
      }

      private function parseMeterStyle(param1:XML, param2:String) : void
      {
         var renderer:String = String(param1.@renderer);
         this.requireAttributes(param1,["id","renderer","fillColor","emptyColor","fillOpacity","emptyOpacity",
                                        "segmentCount","gap","direction","partialSegments","trianglePattern",
                                        "startAngle","sweepAngle","clockwise","thickness"]);
         if(renderer != "continuous" && renderer != "triangles" && renderer != "segments" &&
            renderer != "dots" && renderer != "radial")
         {
            throw new Error("INVALID|Unsupported meter renderer: " + renderer);
         }
         this.requireColor(param1,"fillColor");
         this.requireColor(param1,"emptyColor");
         this.requireUnitInterval(param1,"fillOpacity");
         this.requireUnitInterval(param1,"emptyOpacity");
         if(renderer == "continuous")
         {
            this.requireLinearDirection(param1);
            this.rejectMeterAttributes(param1,["segmentCount","gap","partialSegments","trianglePattern",
                                               "startAngle","sweepAngle","clockwise","thickness"]);
         }
         else if(renderer == "radial")
         {
            this.rejectMeterAttributes(param1,["segmentCount","gap","direction","partialSegments","trianglePattern"]);
            this.requirePositive(param1,"thickness");
            if(param1.@startAngle.length() == 1)
            {
               this.requireFinite(param1,"startAngle");
               if(Number(param1.@startAngle) < -360 || Number(param1.@startAngle) > 360)
               {
                  throw new Error("INVALID|Radial startAngle must be between -360 and 360.");
               }
            }
            if(param1.@sweepAngle.length() == 1)
            {
               this.requirePositive(param1,"sweepAngle");
               if(Number(param1.@sweepAngle) > 360)
               {
                  throw new Error("INVALID|Radial sweepAngle must be greater than 0 and no more than 360.");
               }
            }
            this.requireOptionalBoolean(param1,"clockwise");
         }
         else
         {
            this.requirePositiveInteger(param1,"segmentCount");
            if(int(param1.@segmentCount) > 64)
            {
               throw new Error("INVALID|Meter segmentCount must be between 1 and 64.");
            }
            this.requireFiniteNonNegative(param1,"gap");
            this.requireLinearDirection(param1);
            this.requireOptionalBoolean(param1,"partialSegments");
            this.rejectMeterAttributes(param1,["startAngle","sweepAngle","clockwise","thickness"]);
            if(renderer == "triangles")
            {
               if(param1.@trianglePattern.length() == 1 && String(param1.@trianglePattern) != "uniform" &&
                  String(param1.@trianglePattern) != "alternating")
               {
                  throw new Error("INVALID|trianglePattern must be uniform or alternating.");
               }
            }
            else
            {
               this.rejectMeterAttributes(param1,["trianglePattern"]);
            }
         }
         meterStyles[param2] = param1;
      }

      private function requireLinearDirection(param1:XML) : void
      {
         var value:String = null;
         if(param1.@direction.length() == 0)
         {
            return;
         }
         value = String(param1.@direction);
         if(value != "right" && value != "left" && value != "down" && value != "up")
         {
            throw new Error("INVALID|Meter direction must be right, left, down, or up.");
         }
      }

      private function rejectMeterAttributes(param1:XML, param2:Array) : void
      {
         var attributeName:String = null;
         for each(attributeName in param2)
         {
            if(param1.attribute(attributeName).length() == 1)
            {
               throw new Error("INVALID|Meter attribute '" + attributeName + "' does not apply to renderer " +
                               String(param1.@renderer) + ".");
            }
         }
      }

      private function parseTemplate(param1:XML, param2:String) : void
      {
         var savedComponentIds:Object = componentIds;
         var root:XML = null;
         this.requireAttributes(param1,["id"]);
         if(param1.children().length() != 1 || String(param1.children()[0].name()) != "group")
         {
            throw new Error("INVALID|Template " + param2 + " requires exactly one root group.");
         }
         root = param1.children()[0];
         if(root.children().length() == 0)
         {
            throw new Error("INVALID|Template " + param2 + " cannot be empty.");
         }
         componentIds = {};
         this.validateComponent(root);
         componentIds = savedComponentIds;
         templates[param2] = param1;
      }

      private function validateChildren(param1:XML, param2:Boolean = false) : void
      {
         var child:XML = null;
         if(param1.children().length() == 0 && !param2)
         {
            throw new Error("INVALID|Each component container must have at least one child.");
         }
         for each(child in param1.children())
         {
            this.validateComponent(child);
         }
      }

      private function validateComponent(param1:XML) : void
      {
         var type:String = String(param1.name());
         var style:XML = null;
         if(type == "group")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor"]);
            this.validateChildren(param1,true);
         }
         else if(type == "text")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","value","source","format","valueTemplate","font","fontSize","color","bold","align"]);
            if(String(param1.@value).length == 0 && param1.@source.length() == 0 && param1.@valueTemplate.length() == 0)
            {
               throw new Error("INVALID|Text value cannot be empty: " + String(param1.@id));
            }
            this.requireNonEmpty(param1,"font");
            this.requirePositiveInteger(param1,"fontSize");
            this.requireColor(param1,"color");
            this.requireOptionalBoolean(param1,"bold");
            if(String(param1.@align) != "left" && String(param1.@align) != "center" && String(param1.@align) != "right")
            {
               throw new Error("INVALID|Text align must be left, center, or right: " + String(param1.@id));
            }
            if(param1.@source.length() == 1 && param1.@valueTemplate.length() == 1)
            {
               throw new Error("INVALID|Text source and valueTemplate are mutually exclusive: " + String(param1.@id));
            }
            if(param1.@source.length() == 1)
            {
               CUIValueBinding.validateText(param1);
            }
            else if(param1.@valueTemplate.length() == 1)
            {
               if(param1.@format.length() == 1)
               {
                  throw new Error("INVALID|Text valueTemplate uses per-variable formats: " + String(param1.@id));
               }
               CUIValueBinding.validateTextTemplate(param1);
            }
         }
         else if(type == "panel")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","fillColor","fillOpacity","strokeColor","strokeOpacity","strokeWidth"]);
            this.requireColor(param1,"fillColor");
            this.requireColor(param1,"strokeColor");
            this.requireUnitInterval(param1,"fillOpacity");
            this.requireUnitInterval(param1,"strokeOpacity");
            this.requireFiniteNonNegative(param1,"strokeWidth");
         }
         else if(type == "shape")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","shape","fillColor","fillOpacity","strokeColor","strokeOpacity","strokeWidth"]);
            if(String(param1.@shape) != "rectangle" && String(param1.@shape) != "ellipse")
            {
               throw new Error("INVALID|Unsupported shape: " + String(param1.@shape));
            }
            this.requireColor(param1,"fillColor");
            this.requireColor(param1,"strokeColor");
            this.requireUnitInterval(param1,"fillOpacity");
            this.requireUnitInterval(param1,"strokeOpacity");
            this.requireFiniteNonNegative(param1,"strokeWidth");
         }
         else if(type == "divider")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","color","strokeOpacity","strokeWidth"]);
            this.requireColor(param1,"color");
            this.requireUnitInterval(param1,"strokeOpacity");
            this.requirePositive(param1,"strokeWidth");
         }
         else if(type == "contactRadar")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","enemyColor","allyColor","playerColor"]);
            this.requirePositiveBounds(param1);
            this.requireColor(param1,"enemyColor");
            this.requireColor(param1,"allyColor");
            this.requireColor(param1,"playerColor");
         }
         else if(type == "meter")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","style","value","max","source","maxSource"]);
            style = this.getMeterStyle(String(param1.@style));
            this.requireFinite(param1,"value");
            this.requireFinite(param1,"max");
            if(Number(param1.@max) <= 0)
            {
               throw new Error("INVALID|Meter max must be greater than zero: " + String(param1.@id));
            }
            if(param1.@maxSource.length() == 1 && param1.@source.length() == 0)
            {
               throw new Error("INVALID|Meter maxSource requires source: " + String(param1.@id));
            }
            if(param1.@source.length() == 1)
            {
               CUIValueBinding.validateMeter(param1);
            }
            if(String(style.@renderer) == "radial" && Number(style.@thickness) >
               Math.min(Number(param1.@width),Number(param1.@height)))
            {
               throw new Error("INVALID|Radial thickness exceeds meter bounds: " + String(param1.@id));
            }
         }
         else if(type == "svg")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","src","fit","alignX","alignY"]);
            this.requirePositiveBounds(param1);
            this.requireAssetPath(param1);
            this.requireAssetFit(param1);
         }
         else if(type == "path")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","data","viewBoxX","viewBoxY","viewBoxWidth","viewBoxHeight","fillColor","fillOpacity","strokeColor","strokeOpacity","strokeWidth"]);
            this.requirePositiveBounds(param1);
            this.requirePathGeometry(param1);
            this.requireColor(param1,"fillColor");
            this.requireUnitInterval(param1,"fillOpacity");
            this.requireColor(param1,"strokeColor");
            this.requireUnitInterval(param1,"strokeOpacity");
            this.requireFiniteNonNegative(param1,"strokeWidth");
         }
         else if(type == "mask")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","shape","data","viewBoxX","viewBoxY","viewBoxWidth","viewBoxHeight"]);
            this.requirePositiveBounds(param1);
            if(String(param1.@shape) != "rectangle" && String(param1.@shape) != "ellipse" && String(param1.@shape) != "path")
            {
               throw new Error("INVALID|Unsupported mask shape: " + String(param1.@shape));
            }
            if(String(param1.@shape) == "path")
            {
               this.requirePathGeometry(param1);
            }
            else if(param1.@data.length() != 0 || param1.@viewBoxX.length() != 0 || param1.@viewBoxY.length() != 0 ||
                    param1.@viewBoxWidth.length() != 0 || param1.@viewBoxHeight.length() != 0)
            {
               throw new Error("INVALID|Path geometry applies only to path masks: " + String(param1.@id));
            }
            this.validateChildren(param1);
         }
         else if(type == "icon")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","name","color","fit","alignX","alignY"]);
            this.requirePositiveBounds(param1);
            this.requireSymbolKey(param1,"name");
            if(!CUIIconLibrary.isAllowlisted(String(param1.@name)))
            {
               throw new Error("INVALID|Built-in icon is not allowlisted: " + String(param1.@name));
            }
            if(param1.@color.length() == 1)
            {
               this.requireColor(param1,"color");
            }
            this.requireAssetFit(param1);
         }
         else if(type == "providerSymbol")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","source","color","fit","alignX","alignY"]);
            this.requirePositiveBounds(param1);
            CUIValueBinding.validateProviderSymbol(param1);
            if(param1.@color.length() == 1)
            {
               this.requireColor(param1,"color");
            }
            this.requireAssetFit(param1);
         }
         else if(type == "symbol")
         {
            this.validateBase(param1,["id","x","y","width","height","opacity","visible","visibleWhen","rotation","scaleX","scaleY","z","anchor","name","color","fit","alignX","alignY"]);
            this.requirePositiveBounds(param1);
            this.requireSymbolKey(param1,"name");
            if(!venworks.cui.components.CUISymbol.isAllowlisted(String(param1.@name)))
            {
               throw new Error("INVALID|Embedded symbol is not allowlisted: " + String(param1.@name));
            }
            if(param1.@color.length() == 1)
            {
               this.requireColor(param1,"color");
            }
            this.requireAssetFit(param1);
         }
         else
         {
            throw new Error("INVALID|Unknown component: " + type);
         }
      }

      private function validateBase(param1:XML, param2:Array) : void
      {
         var id:String = null;
         this.requireAttributes(param1,param2);
         id = this.requireId(param1);
         if(componentIds[id] != null)
         {
            throw new Error("INVALID|Duplicate component id: " + id);
         }
         componentIds[id] = true;
         this.requireFinite(param1,"x");
         this.requireFinite(param1,"y");
         this.requireFiniteNonNegative(param1,"width");
         this.requireFiniteNonNegative(param1,"height");
         if(param1.@opacity.length() == 1)
         {
            this.requireUnitInterval(param1,"opacity");
         }
         this.requireOptionalBoolean(param1,"visible");
         if(param1.@visibleWhen.length() == 1)
         {
            this.requireCondition(param1,"visibleWhen");
         }
         this.requireOptionalFinite(param1,"rotation");
         this.requireOptionalFinite(param1,"scaleX");
         this.requireOptionalFinite(param1,"scaleY");
         this.requireInteger(param1,"z");
         this.requireOptionalAnchor(param1);
      }

      private function requirePositiveBounds(param1:XML) : void
      {
         if(Number(param1.@width) <= 0 || Number(param1.@height) <= 0)
         {
            throw new Error("INVALID|Component width and height must be positive: " + String(param1.@id));
         }
      }

      private function requireAssetPath(param1:XML) : void
      {
         var value:String = String(param1.@src);
         var lowerValue:String = value.toLowerCase();
         var rootDescription:String = "Interface/VenworksCUI/Assets";
         var segments:Array = null;
         var segment:String = null;
         if(param1.@src.length() != 1 || value.length < 5 || value.length > 128 ||
            !/^[A-Za-z0-9][A-Za-z0-9._\/-]*$/.test(value) || value.indexOf("//") >= 0 ||
            value.indexOf(":") >= 0 || value.indexOf("\\") >= 0 || value.charAt(0) == "/")
         {
            throw new Error("INVALID|Asset path must be a relative path below " + rootDescription + ".");
         }
         segments = value.split("/");
         for each(segment in segments)
         {
            if(segment == "" || segment == "." || segment == "..")
            {
               throw new Error("INVALID|Asset path traversal is prohibited: " + value);
            }
         }
         if(lowerValue.substr(-4) != ".svg")
         {
            throw new Error("INVALID|SVG assets must use .svg: " + value);
         }
      }

      private function requireSymbolKey(param1:XML, param2:String) : String
      {
         var value:String = String(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || !/^[a-z][a-z0-9-]{0,63}$/.test(value))
         {
            throw new Error("INVALID|" + param2 + " must be a lowercase symbol key on symbol.");
         }
         return value;
      }

      private function requireAssetFit(param1:XML) : void
      {
         var fit:String = param1.@fit.length() == 1 ? String(param1.@fit) : "contain";
         var alignX:String = param1.@alignX.length() == 1 ? String(param1.@alignX) : "center";
         var alignY:String = param1.@alignY.length() == 1 ? String(param1.@alignY) : "center";
         if(fit != "contain" && fit != "cover" && fit != "stretch" && fit != "none")
         {
            throw new Error("INVALID|Asset fit must be contain, cover, stretch, or none.");
         }
         if(alignX != "left" && alignX != "center" && alignX != "right")
         {
            throw new Error("INVALID|Asset alignX must be left, center, or right.");
         }
         if(alignY != "top" && alignY != "center" && alignY != "bottom")
         {
            throw new Error("INVALID|Asset alignY must be top, center, or bottom.");
         }
      }

      private function requirePathGeometry(param1:XML) : void
      {
         this.requireNonEmpty(param1,"data");
         if(String(param1.@data).length > 8192)
         {
            throw new Error("INVALID|SVG path data exceeds the 8192-character limit.");
         }
         this.requireFinite(param1,"viewBoxX");
         this.requireFinite(param1,"viewBoxY");
         this.requirePositive(param1,"viewBoxWidth");
         this.requirePositive(param1,"viewBoxHeight");
         CUISvgPathParser.validate(String(param1.@data));
      }

      private function requireOptionalAnchor(param1:XML) : void
      {
         var value:String = null;
         if(param1.@anchor.length() == 0)
         {
            return;
         }
         value = String(param1.@anchor);
         if(value != "top-left" && value != "top-center" && value != "top-right" &&
            value != "center-left" && value != "center" && value != "center-right" &&
            value != "bottom-left" && value != "bottom-center" && value != "bottom-right")
         {
            throw new Error("INVALID|Unsupported component anchor: " + value);
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

      private function requireName(param1:XML, param2:String) : void
      {
         if(String(param1.name()) != param2)
         {
            throw new Error("INVALID|Expected " + param2 + ".");
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

      private function requireColor(param1:XML, param2:String) : void
      {
         if(!/^#[0-9A-Fa-f]{6}$/.test(String(param1.attribute(param2))))
         {
            throw new Error("INVALID|" + param2 + " must use #RRGGBB.");
         }
      }

      private function requireNonEmpty(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() != 1 || String(param1.attribute(param2)).replace(/^\s+|\s+$/g,"").length == 0)
         {
            throw new Error("INVALID|" + param2 + " cannot be empty.");
         }
      }

      private function requireCondition(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() != 1)
         {
            throw new Error("INVALID|Missing " + param2 + " on " + String(param1.name()) + ".");
         }
         conditionParser.compile(String(param1.attribute(param2)));
      }

      private function requireOptionalBoolean(param1:XML, param2:String) : void
      {
         var value:String = null;
         if(param1.attribute(param2).length() == 0)
         {
            return;
         }
         value = String(param1.attribute(param2)).toLowerCase();
         if(value != "true" && value != "false")
         {
            throw new Error("INVALID|" + param2 + " must be true or false.");
         }
      }

      private function requireInteger(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() != 1 || !/^-?[0-9]+$/.test(String(param1.attribute(param2))))
         {
            throw new Error("INVALID|" + param2 + " must be an integer.");
         }
      }

      private function requirePositiveInteger(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() != 1 || !/^[0-9]+$/.test(String(param1.attribute(param2))) || int(param1.attribute(param2)) < 1)
         {
            throw new Error("INVALID|" + param2 + " must be a positive integer.");
         }
      }

      private function requirePositive(param1:XML, param2:String) : void
      {
         this.requireFinite(param1,param2);
         if(Number(param1.attribute(param2)) <= 0)
         {
            throw new Error("INVALID|" + param2 + " must be greater than zero.");
         }
      }

      private function requireUnitInterval(param1:XML, param2:String) : void
      {
         this.requireFinite(param1,param2);
         if(Number(param1.attribute(param2)) < 0 || Number(param1.attribute(param2)) > 1)
         {
            throw new Error("INVALID|" + param2 + " must be between 0 and 1.");
         }
      }

      private function requireFiniteNonNegative(param1:XML, param2:String) : void
      {
         this.requireFinite(param1,param2);
         if(Number(param1.attribute(param2)) < 0)
         {
            throw new Error("INVALID|" + param2 + " cannot be negative.");
         }
      }

      private function requireOptionalFinite(param1:XML, param2:String) : void
      {
         if(param1.attribute(param2).length() == 1)
         {
            this.requireFinite(param1,param2);
         }
      }

      private function requireFinite(param1:XML, param2:String) : void
      {
         var value:Number = Number(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || isNaN(value) || !isFinite(value))
         {
            throw new Error("INVALID|" + param2 + " must be a finite number.");
         }
      }
   }
}
