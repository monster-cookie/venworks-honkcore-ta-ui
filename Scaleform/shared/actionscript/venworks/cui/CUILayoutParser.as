package venworks.cui
{
   public final class CUILayoutParser
   {
      private var meterStyles:Object;
      private var componentIds:Object;
      private var componentRoot:XML;

      public function CUILayoutParser()
      {
         super();
      }

      public function parse(param1:XML) : void
      {
         meterStyles = {};
         componentIds = {};
         this.requireName(param1,"venworksCUI");
         this.requireAttributes(param1,["schemaVersion","runtimeVersion","designWidth","designHeight","safeLeft","safeTop","safeRight","safeBottom"]);
         if(String(param1.@schemaVersion) != "1" || String(param1.@runtimeVersion) != "1")
         {
            throw new Error("UNSUPPORTED|Expected schemaVersion=1 and runtimeVersion=1.");
         }
         if(Number(param1.@designWidth) != 1920 || Number(param1.@designHeight) != 1080)
         {
            throw new Error("INVALID|Goal 3 requires a 1920x1080 design space.");
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
         if(param1.definitions.length() != 1 || param1.components.length() != 1)
         {
            throw new Error("INVALID|Exactly one definitions and one components element are required.");
         }
         if(param1.children().length() != 2)
         {
            throw new Error("INVALID|Unknown layout root element.");
         }
         if(String(param1.children()[0].name()) != "definitions" ||
            String(param1.children()[1].name()) != "components")
         {
            throw new Error("INVALID|definitions must precede components.");
         }
         this.parseDefinitions(param1.definitions[0]);
         componentRoot = param1.components[0];
         this.requireAttributes(componentRoot,[]);
         this.validateChildren(componentRoot);
      }

      public function get components() : XML
      {
         return componentRoot;
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
         var style:XML = null;
         var id:String = null;
         this.requireAttributes(param1,[]);
         if(param1.children().length() == 0)
         {
            throw new Error("INVALID|At least one meterStyle is required.");
         }
         for each(style in param1.children())
         {
            this.requireName(style,"meterStyle");
            this.requireAttributes(style,["id","renderer","fillColor","emptyColor","fillOpacity","emptyOpacity","segmentCount","gap"]);
            id = this.requireId(style);
            if(meterStyles[id] != null)
            {
               throw new Error("INVALID|Duplicate definition id: " + id);
            }
            if(String(style.@renderer) != "continuous" && String(style.@renderer) != "triangles")
            {
               throw new Error("INVALID|Unsupported meter renderer: " + String(style.@renderer));
            }
            this.requireColor(style,"fillColor");
            this.requireColor(style,"emptyColor");
            this.requireUnitInterval(style,"fillOpacity");
            this.requireUnitInterval(style,"emptyOpacity");
            if(String(style.@renderer) == "triangles")
            {
               this.requirePositiveInteger(style,"segmentCount");
               if(int(style.@segmentCount) > 64)
               {
                  throw new Error("INVALID|Triangle segmentCount must be between 1 and 64.");
               }
               this.requireFiniteNonNegative(style,"gap");
            }
            meterStyles[id] = style;
         }
      }

      private function validateChildren(param1:XML) : void
      {
         var child:XML = null;
         var type:String = null;
         var style:XML = null;
         if(param1.children().length() == 0)
         {
            throw new Error("INVALID|Each component container must have at least one child.");
         }
         for each(child in param1.children())
         {
            type = String(child.name());
            if(type == "group")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z"]);
               this.validateChildren(child);
            }
            else if(type == "text")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z","value","font","fontSize","color","bold","align"]);
               if(String(child.@value).length == 0)
               {
                  throw new Error("INVALID|Text value cannot be empty: " + String(child.@id));
               }
               this.requireNonEmpty(child,"font");
               this.requirePositiveInteger(child,"fontSize");
               this.requireColor(child,"color");
               this.requireOptionalBoolean(child,"bold");
               if(String(child.@align) != "left" && String(child.@align) != "center" && String(child.@align) != "right")
               {
                  throw new Error("INVALID|Text align must be left, center, or right: " + String(child.@id));
               }
            }
            else if(type == "panel")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z","fillColor","fillOpacity","strokeColor","strokeOpacity","strokeWidth"]);
               this.requireColor(child,"fillColor");
               this.requireColor(child,"strokeColor");
               this.requireUnitInterval(child,"fillOpacity");
               this.requireUnitInterval(child,"strokeOpacity");
               this.requireFiniteNonNegative(child,"strokeWidth");
            }
            else if(type == "shape")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z","shape","fillColor","fillOpacity","strokeColor","strokeOpacity","strokeWidth"]);
               if(String(child.@shape) != "rectangle" && String(child.@shape) != "ellipse")
               {
                  throw new Error("INVALID|Unsupported shape: " + String(child.@shape));
               }
               this.requireColor(child,"fillColor");
               this.requireColor(child,"strokeColor");
               this.requireUnitInterval(child,"fillOpacity");
               this.requireUnitInterval(child,"strokeOpacity");
               this.requireFiniteNonNegative(child,"strokeWidth");
            }
            else if(type == "divider")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z","color","strokeOpacity","strokeWidth"]);
               this.requireColor(child,"color");
               this.requireUnitInterval(child,"strokeOpacity");
               this.requirePositive(child,"strokeWidth");
            }
            else if(type == "meter")
            {
               this.validateBase(child,["id","x","y","width","height","opacity","visible","rotation","scaleX","scaleY","z","style","value","max"]);
               style = this.getMeterStyle(String(child.@style));
               this.requireFinite(child,"value");
               this.requireFinite(child,"max");
               if(Number(child.@max) <= 0)
               {
                  throw new Error("INVALID|Meter max must be greater than zero: " + String(child.@id));
               }
            }
            else
            {
               throw new Error("INVALID|Unknown component: " + type);
            }
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
         this.requireOptionalFinite(param1,"rotation");
         this.requireOptionalFinite(param1,"scaleX");
         this.requireOptionalFinite(param1,"scaleY");
         this.requireInteger(param1,"z");
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
         if(!/^[A-Za-z][A-Za-z0-9._-]{0,63}$/.test(id))
         {
            throw new Error("INVALID|Invalid or missing id on " + String(param1.name()) + ".");
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
