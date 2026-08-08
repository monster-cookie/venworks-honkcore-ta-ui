package venworks.cui
{
   public final class CUICompositionResolver
   {
      private static const MAX_RESOLVED_COMPONENTS:int = 512;
      private static const MAX_REPEATER_ITEMS:int = 64;
      private static const MAX_STATE_OPTIONS:int = 16;

      private var templates:Object;
      private var resolvedComponentCount:int;

      public function CUICompositionResolver(param1:Object)
      {
         super();
         templates = param1;
      }

      public function resolve(param1:XML) : XML
      {
         var result:XML = <components />;
         var child:XML = null;
         resolvedComponentCount = 0;
         this.requireAttributes(param1,[]);
         for each(child in param1.children())
         {
            this.resolveNode(child,result);
         }
         if(result.children().length() == 0)
         {
            throw new Error("INVALID|The resolved layout must contain at least one component.");
         }
         return result;
      }

      private function resolveNode(param1:XML, param2:XML) : void
      {
         var type:String = String(param1.name());
         var copy:XML = null;
         var child:XML = null;
         if(type == "group")
         {
            copy = param1.copy();
            copy.setChildren(new XMLList());
            param2.appendChild(copy);
            this.addResolvedComponents(1);
            for each(child in param1.children())
            {
               this.resolveNode(child,copy);
            }
            return;
         }
         if(type == "text" || type == "panel" || type == "shape" || type == "divider" || type == "meter")
         {
            if(param1.children().length() != 0)
            {
               throw new Error("INVALID|Component " + String(param1.@id) + " cannot contain child elements.");
            }
            param2.appendChild(param1.copy());
            this.addResolvedComponents(1);
            return;
         }
         if(type == "instance")
         {
            this.resolveInstance(param1,param2);
            return;
         }
         if(type == "repeater")
         {
            this.resolveRepeater(param1,param2);
            return;
         }
         if(type == "state")
         {
            this.resolveState(param1,param2);
            return;
         }
         throw new Error("INVALID|Unknown component: " + type);
      }

      private function resolveInstance(param1:XML, param2:XML) : void
      {
         this.requireAttributes(param1,["id","template","x","y","anchor","visible","z"]);
         this.validatePlacement(param1,true);
         var instance:XML = this.createTemplateInstance(
            String(param1.@template),
            String(param1.@id),
            param1,
            param1
         );
         param2.appendChild(instance);
         this.addResolvedComponents(this.countComponents(instance));
      }

      private function resolveRepeater(param1:XML, param2:XML) : void
      {
         var repeaterId:String = null;
         var templateId:String = null;
         var template:XML = null;
         var flow:String = null;
         var gapX:Number = NaN;
         var gapY:Number = NaN;
         var columns:int = 1;
         var itemWidth:Number = NaN;
         var itemHeight:Number = NaN;
         var repeaterWidth:Number = NaN;
         var repeaterHeight:Number = NaN;
         var declaredCount:int = 0;
         var visibleIndex:int = 0;
         var itemIds:Object = {};
         var item:XML = null;
         var itemId:String = null;
         var itemVisible:Boolean = true;
         var column:int = 0;
         var row:int = 0;
         var itemX:Number = NaN;
         var itemY:Number = NaN;
         var placement:XML = null;
         var instance:XML = null;
         var container:XML = <group />;

         this.requireAttributes(param1,["id","template","x","y","width","height","anchor","visible","z","flow","gapX","gapY","columns"]);
         this.validatePlacement(param1,true);
         this.requireFiniteNonNegative(param1,"width");
         this.requireFiniteNonNegative(param1,"height");
         this.requireFiniteNonNegative(param1,"gapX");
         this.requireFiniteNonNegative(param1,"gapY");
         repeaterId = String(param1.@id);
         templateId = String(param1.@template);
         flow = this.requireAttribute(param1,"flow");
         if(flow != "vertical" && flow != "horizontal" && flow != "grid")
         {
            throw new Error("INVALID|Unsupported repeater flow: " + flow);
         }
         if(flow == "grid")
         {
            this.requirePositiveInteger(param1,"columns");
            columns = int(param1.@columns);
            if(columns > 16)
            {
               throw new Error("INVALID|Grid columns must be between 1 and 16: " + repeaterId);
            }
         }
         else if(param1.@columns.length() == 1)
         {
            this.requirePositiveInteger(param1,"columns");
            if(int(param1.@columns) != 1)
            {
               throw new Error("INVALID|Non-grid repeaters require columns=1: " + repeaterId);
            }
         }
         template = this.requireTemplate(templateId);
         itemWidth = Number(template.children()[0].@width);
         itemHeight = Number(template.children()[0].@height);
         repeaterWidth = Number(param1.@width);
         repeaterHeight = Number(param1.@height);
         gapX = Number(param1.@gapX);
         gapY = Number(param1.@gapY);

         container.@id = repeaterId;
         container.@x = String(param1.@x);
         container.@y = String(param1.@y);
         container.@width = String(param1.@width);
         container.@height = String(param1.@height);
         container.@z = String(param1.@z);
         this.copyOptionalAttribute(param1,container,"anchor");
         this.copyOptionalAttribute(param1,container,"visible");

         for each(item in param1.children())
         {
            if(String(item.name()) != "item")
            {
               throw new Error("INVALID|Repeater " + repeaterId + " may contain only item elements.");
            }
            ++declaredCount;
            if(declaredCount > MAX_REPEATER_ITEMS)
            {
               throw new Error("INVALID|Repeater " + repeaterId + " exceeds the 64-item limit.");
            }
            this.requireAttributes(item,["id","visible"]);
            itemId = this.requireId(item);
            if(itemIds[itemId] != null)
            {
               throw new Error("INVALID|Duplicate repeater item id: " + itemId);
            }
            itemIds[itemId] = true;
            itemVisible = this.readOptionalBoolean(item,"visible",true);
            this.validateOverrides(templateId,item);
            if(!itemVisible)
            {
               continue;
            }
            if(flow == "horizontal")
            {
               column = visibleIndex;
               row = 0;
            }
            else if(flow == "grid")
            {
               column = visibleIndex % columns;
               row = int(visibleIndex / columns);
            }
            else
            {
               column = 0;
               row = visibleIndex;
            }
            itemX = column * (itemWidth + gapX);
            itemY = row * (itemHeight + gapY);
            if(itemX + itemWidth > repeaterWidth || itemY + itemHeight > repeaterHeight)
            {
               throw new Error("INVALID|Repeater " + repeaterId + " content exceeds its configured bounds.");
            }
            placement = <instance />;
            placement.@id = repeaterId + "." + itemId;
            placement.@template = templateId;
            placement.@x = itemX;
            placement.@y = itemY;
            placement.@z = visibleIndex;
            instance = this.createTemplateInstance(
               templateId,
               String(placement.@id),
               placement,
               item
            );
            container.appendChild(instance);
            ++visibleIndex;
         }
         if(declaredCount == 0)
         {
            throw new Error("INVALID|Repeater " + repeaterId + " requires at least one item.");
         }
         param2.appendChild(container);
         this.addResolvedComponents(this.countComponents(container));
      }

      private function resolveState(param1:XML, param2:XML) : void
      {
         var stateId:String = null;
         var selected:String = null;
         var optionNames:Object = {};
         var optionCount:int = 0;
         var option:XML = null;
         var optionName:String = null;
         var templateId:String = null;
         var selectedOption:XML = null;
         var instance:XML = null;
         this.requireAttributes(param1,["id","selected","x","y","anchor","visible","z"]);
         this.validatePlacement(param1,false);
         stateId = String(param1.@id);
         selected = this.requireAttribute(param1,"selected");
         for each(option in param1.children())
         {
            if(String(option.name()) != "option")
            {
               throw new Error("INVALID|State " + stateId + " may contain only option elements.");
            }
            ++optionCount;
            if(optionCount > MAX_STATE_OPTIONS)
            {
               throw new Error("INVALID|State " + stateId + " exceeds the 16-option limit.");
            }
            this.requireAttributes(option,["name","template"]);
            optionName = this.requireNamedValue(option,"name");
            if(optionNames[optionName] != null)
            {
               throw new Error("INVALID|Duplicate state option name: " + optionName);
            }
            optionNames[optionName] = true;
            templateId = this.requireAttribute(option,"template");
            this.requireTemplate(templateId);
            this.validateOverrides(templateId,option);
            if(optionName == selected)
            {
               selectedOption = option;
            }
         }
         if(optionCount == 0)
         {
            throw new Error("INVALID|State " + stateId + " requires at least one option.");
         }
         if(selectedOption == null)
         {
            throw new Error("INVALID|State " + stateId + " selects unknown option: " + selected);
         }
         instance = this.createTemplateInstance(
            String(selectedOption.@template),
            stateId,
            param1,
            selectedOption
         );
         param2.appendChild(instance);
         this.addResolvedComponents(this.countComponents(instance));
      }

      private function createTemplateInstance(param1:String, param2:String, param3:XML, param4:XML) : XML
      {
         var template:XML = this.requireTemplate(param1);
         var root:XML = template.children()[0].copy();
         this.applyOverrides(root,param4);
         root.@id = param2;
         root.@x = String(param3.@x);
         root.@y = String(param3.@y);
         root.@z = String(param3.@z);
         if(param3.@anchor.length() == 1)
         {
            root.@anchor = String(param3.@anchor);
         }
         else
         {
            delete root.@anchor;
         }
         if(param3.@visible.length() == 1)
         {
            root.@visible = String(param3.@visible).toLowerCase();
         }
         this.prefixDescendantIds(root,param2);
         return root;
      }

      private function validateOverrides(param1:String, param2:XML) : void
      {
         var template:XML = this.requireTemplate(param1);
         var root:XML = template.children()[0].copy();
         this.applyOverrides(root,param2);
      }

      private function applyOverrides(param1:XML, param2:XML) : void
      {
         var nodes:Object = {};
         var applied:Object = {};
         var override:XML = null;
         var target:String = null;
         var targetNode:XML = null;
         var modificationCount:int = 0;
         this.collectLocalIds(param1,nodes);
         for each(override in param2.children())
         {
            if(String(override.name()) != "override")
            {
               throw new Error("INVALID|" + String(param2.name()) + " may contain only override elements.");
            }
            this.requireAttributes(override,["target","text","meterValue","visible"]);
            target = this.requireNamedValue(override,"target");
            targetNode = nodes[target] as XML;
            if(targetNode == null)
            {
               throw new Error("INVALID|Unknown template override target: " + target);
            }
            modificationCount = 0;
            if(override.@text.length() == 1)
            {
               if(String(targetNode.name()) != "text")
               {
                  throw new Error("INVALID|The text override target is not a text component: " + target);
               }
               this.recordOverride(applied,target,"text");
               targetNode.@value = String(override.@text);
               ++modificationCount;
            }
            if(override.@meterValue.length() == 1)
            {
               if(String(targetNode.name()) != "meter")
               {
                  throw new Error("INVALID|The meterValue override target is not a meter component: " + target);
               }
               this.requireFinite(override,"meterValue");
               this.recordOverride(applied,target,"meterValue");
               targetNode.@value = String(override.@meterValue);
               ++modificationCount;
            }
            if(override.@visible.length() == 1)
            {
               this.readOptionalBoolean(override,"visible",true);
               this.recordOverride(applied,target,"visible");
               targetNode.@visible = String(override.@visible).toLowerCase();
               ++modificationCount;
            }
            if(modificationCount == 0)
            {
               throw new Error("INVALID|Override for " + target + " does not change an approved property.");
            }
         }
      }

      private function collectLocalIds(param1:XML, param2:Object) : void
      {
         var id:String = this.requireId(param1);
         var child:XML = null;
         if(param2[id] != null)
         {
            throw new Error("INVALID|Duplicate local template component id: " + id);
         }
         param2[id] = param1;
         for each(child in param1.children())
         {
            this.collectLocalIds(child,param2);
         }
      }

      private function prefixDescendantIds(param1:XML, param2:String) : void
      {
         var child:XML = null;
         for each(child in param1.children())
         {
            child.@id = param2 + "." + String(child.@id);
            this.prefixDescendantIds(child,param2);
         }
      }

      private function validatePlacement(param1:XML, param2:Boolean) : void
      {
         this.requireId(param1);
         if(param2)
         {
            this.requireTemplate(this.requireAttribute(param1,"template"));
         }
         this.requireFinite(param1,"x");
         this.requireFinite(param1,"y");
         this.requireInteger(param1,"z");
         this.requireOptionalAnchor(param1);
         this.readOptionalBoolean(param1,"visible",true);
      }

      private function requireTemplate(param1:String) : XML
      {
         if(templates[param1] == null)
         {
            throw new Error("INVALID|Unknown template reference: " + param1);
         }
         return templates[param1] as XML;
      }

      private function copyOptionalAttribute(param1:XML, param2:XML, param3:String) : void
      {
         if(param1.attribute(param3).length() == 1)
         {
            if(param3 == "anchor")
            {
               param2.@anchor = String(param1.@anchor);
            }
            else if(param3 == "visible")
            {
               param2.@visible = String(param1.@visible).toLowerCase();
            }
         }
      }

      private function recordOverride(param1:Object, param2:String, param3:String) : void
      {
         var key:String = param2 + "." + param3;
         if(param1[key] != null)
         {
            throw new Error("INVALID|Duplicate template override: " + key);
         }
         param1[key] = true;
      }

      private function countComponents(param1:XML) : int
      {
         var result:int = 1;
         var child:XML = null;
         for each(child in param1.children())
         {
            ++result;
            result += this.countDescendants(child);
         }
         return result;
      }

      private function countDescendants(param1:XML) : int
      {
         var result:int = 0;
         var child:XML = null;
         for each(child in param1.children())
         {
            ++result;
            result += this.countDescendants(child);
         }
         return result;
      }

      private function addResolvedComponents(param1:int) : void
      {
         resolvedComponentCount += param1;
         if(resolvedComponentCount > MAX_RESOLVED_COMPONENTS)
         {
            throw new Error("INVALID|The resolved layout exceeds the 512-component limit.");
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

      private function requireAttribute(param1:XML, param2:String) : String
      {
         var value:String = String(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || value.length == 0)
         {
            throw new Error("INVALID|Missing or empty " + param2 + " on " + String(param1.name()) + ".");
         }
         return value;
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

      private function requireNamedValue(param1:XML, param2:String) : String
      {
         var value:String = String(param1.attribute(param2));
         if(param1.attribute(param2).length() != 1 || !/^[A-Za-z][A-Za-z0-9._-]{0,63}$/.test(value))
         {
            throw new Error("INVALID|Invalid or missing " + param2 + " on " + String(param1.name()) + ".");
         }
         return value;
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
            throw new Error("INVALID|" + param2 + " must be true or false.");
         }
         return value == "true";
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

      private function requireFiniteNonNegative(param1:XML, param2:String) : void
      {
         this.requireFinite(param1,param2);
         if(Number(param1.attribute(param2)) < 0)
         {
            throw new Error("INVALID|" + param2 + " cannot be negative.");
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
