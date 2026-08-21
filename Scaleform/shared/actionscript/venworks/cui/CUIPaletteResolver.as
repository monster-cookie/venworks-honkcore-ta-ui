package venworks.cui
{
   import venworks.cui.components.CUISymbol;

   public final class CUIPaletteResolver
   {
      private static const REQUIRED_COLORS:Array = [
         "foreground.primary","foreground.muted","accent.primary","accent.secondary",
         "panel.background","panel.border","state.normal","state.selected","state.disabled",
         "state.clear","state.caution","state.danger","state.critical","meter.health",
         "meter.oxygen","meter.carbondioxide","meter.boost","marker.player","marker.ally",
         "marker.hostile","marker.objective"
      ];
      private static const REQUIRED_TYPOGRAPHY:Array = ["body","label","heading"];
      private static const REQUIRED_OPACITIES:Array = ["opaque","panel","muted"];
      private static const REQUIRED_STROKES:Array = ["panel"];
      private static const REQUIRED_ASSETS:Array = ["faction.logo"];

      private var colors:Object;
      private var typography:Object;
      private var opacities:Object;
      private var strokes:Object;
      private var assets:Object;

      public function CUIPaletteResolver()
      {
         super();
      }

      public function resolve(param1:XML, param2:XML) : XML
      {
         var resolved:XML = null;
         this.parsePalette(param2);
         resolved = param1.copy();
         this.resolveNode(resolved);
         this.requireFullyResolved(resolved);
         delete resolved.@palette;
         return resolved;
      }

      private function parsePalette(param1:XML) : void
      {
         var expectedSections:Array = ["colors","typography","opacities","strokes","assets"];
         var index:int = 0;
         this.requireName(param1,"venworksCUIPalette");
         this.requireAttributes(param1,["schemaVersion"]);
         if(String(param1.@schemaVersion) != "1")
         {
            throw new Error("UNSUPPORTED|Expected palette schemaVersion=1.");
         }
         if(param1.children().length() != expectedSections.length)
         {
            throw new Error("INVALID|Palette sections must be colors, typography, opacities, strokes, and assets.");
         }
         for(index = 0; index < expectedSections.length; ++index)
         {
            if(String(param1.children()[index].name()) != expectedSections[index])
            {
               throw new Error("INVALID|Palette sections must appear in colors, typography, opacities, strokes, assets order.");
            }
            this.requireAttributes(param1.children()[index],[]);
         }
         colors = this.parseColors(param1.colors[0]);
         opacities = this.parseOpacities(param1.opacities[0]);
         typography = this.parseTypography(param1.typography[0]);
         strokes = this.parseStrokes(param1.strokes[0]);
         assets = this.parseAssets(param1.assets[0]);
         this.requireRoles(colors,REQUIRED_COLORS,"color");
         this.requireRoles(typography,REQUIRED_TYPOGRAPHY,"typography");
         this.requireRoles(opacities,REQUIRED_OPACITIES,"opacity");
         this.requireRoles(strokes,REQUIRED_STROKES,"stroke");
         this.requireRoles(assets,REQUIRED_ASSETS,"asset");
      }

      private function parseColors(param1:XML) : Object
      {
         var result:Object = {};
         var node:XML = null;
         var role:String = null;
         this.requireEntryCount(param1,1,64,"colors");
         for each(node in param1.children())
         {
            this.requireName(node,"color");
            this.requireAttributes(node,["role","value"]);
            this.requireEmpty(node,"color");
            role = this.requireRole(node);
            this.requireUnique(result,role,"color");
            if(!/^#[0-9A-Fa-f]{6}$/.test(String(node.@value)))
            {
               throw new Error("INVALID|Palette color must use #RRGGBB: " + role);
            }
            result[role] = String(node.@value).toUpperCase();
         }
         return result;
      }

      private function parseOpacities(param1:XML) : Object
      {
         var result:Object = {};
         var node:XML = null;
         var role:String = null;
         var valueText:String = null;
         var value:Number = NaN;
         this.requireEntryCount(param1,1,32,"opacities");
         for each(node in param1.children())
         {
            this.requireName(node,"opacity");
            this.requireAttributes(node,["role","value"]);
            this.requireEmpty(node,"opacity");
            role = this.requireRole(node);
            this.requireUnique(result,role,"opacity");
            valueText = String(node.@value);
            value = Number(valueText);
            if(!/^(?:0(?:\.[0-9]+)?|1(?:\.0+)?)$/.test(valueText) || !isFinite(value) || value < 0 || value > 1)
            {
               throw new Error("INVALID|Palette opacity must be between 0 and 1: " + role);
            }
            result[role] = valueText;
         }
         return result;
      }

      private function parseTypography(param1:XML) : Object
      {
         var result:Object = {};
         var node:XML = null;
         var role:String = null;
         var font:String = null;
         var colorRole:String = null;
         var fontSizeText:String = null;
         var fontSize:Number = NaN;
         this.requireEntryCount(param1,1,16,"typography");
         for each(node in param1.children())
         {
            this.requireName(node,"style");
            this.requireAttributes(node,["role","font","fontSize","bold","color"]);
            this.requireEmpty(node,"typography style");
            role = this.requireRole(node);
            this.requireUnique(result,role,"typography");
            font = String(node.@font);
            if(font != "$MAIN_Font" && font != "$MAIN_Font_Bold")
            {
               throw new Error("INVALID|Palette typography font is not allowlisted: " + role);
            }
            fontSizeText = String(node.@fontSize);
            fontSize = Number(fontSizeText);
            if(!/^[0-9]+$/.test(fontSizeText) || !isFinite(fontSize) || fontSize % 1 != 0 || fontSize < 1 || fontSize > 128)
            {
               throw new Error("INVALID|Palette typography fontSize must be an integer from 1 through 128: " + role);
            }
            if(String(node.@bold) != "true" && String(node.@bold) != "false")
            {
               throw new Error("INVALID|Palette typography bold must be true or false: " + role);
            }
            colorRole = String(node.@color);
            if(!colors.hasOwnProperty(colorRole))
            {
               throw new Error("INVALID|Palette typography references unknown color role: " + colorRole);
            }
            result[role] = {
               font:font,
               fontSize:fontSizeText,
               bold:String(node.@bold),
               color:String(colors[colorRole])
            };
         }
         return result;
      }

      private function parseStrokes(param1:XML) : Object
      {
         var result:Object = {};
         var node:XML = null;
         var role:String = null;
         var colorRole:String = null;
         var opacityRole:String = null;
         var widthText:String = null;
         var width:Number = NaN;
         this.requireEntryCount(param1,1,32,"strokes");
         for each(node in param1.children())
         {
            this.requireName(node,"stroke");
            this.requireAttributes(node,["role","color","opacity","width"]);
            this.requireEmpty(node,"stroke");
            role = this.requireRole(node);
            this.requireUnique(result,role,"stroke");
            colorRole = String(node.@color);
            opacityRole = String(node.@opacity);
            if(!colors.hasOwnProperty(colorRole))
            {
               throw new Error("INVALID|Palette stroke references unknown color role: " + colorRole);
            }
            if(!opacities.hasOwnProperty(opacityRole))
            {
               throw new Error("INVALID|Palette stroke references unknown opacity role: " + opacityRole);
            }
            widthText = String(node.@width);
            width = Number(widthText);
            if(!/^[0-9]+$/.test(widthText) || !isFinite(width) || width % 1 != 0 || width < 0 || width > 64)
            {
               throw new Error("INVALID|Palette stroke width must be an integer from 0 through 64: " + role);
            }
            result[role] = {
               color:String(colors[colorRole]),
               opacity:String(opacities[opacityRole]),
               width:widthText
            };
         }
         return result;
      }

      private function parseAssets(param1:XML) : Object
      {
         var result:Object = {};
         var node:XML = null;
         var role:String = null;
         var kind:String = null;
         var value:String = null;
         this.requireEntryCount(param1,1,32,"assets");
         for each(node in param1.children())
         {
            this.requireName(node,"asset");
            this.requireAttributes(node,["role","kind","value"]);
            this.requireEmpty(node,"asset");
            role = this.requireRole(node);
            this.requireUnique(result,role,"asset");
            kind = String(node.@kind);
            value = String(node.@value);
            if(kind == "svg")
            {
               if(!/^[A-Za-z0-9][A-Za-z0-9._-]{0,59}\.svg$/.test(value) || value.indexOf("..") >= 0)
               {
                  throw new Error("SECURITY|Palette SVG assets must name one packaged file: " + role);
               }
            }
            else if(kind == "icon")
            {
               if(!CUIIconLibrary.isAllowlisted(value))
               {
                  throw new Error("INVALID|Palette icon asset is not allowlisted: " + value);
               }
            }
            else if(kind == "symbol")
            {
               if(!CUISymbol.isAllowlisted(value))
               {
                  throw new Error("INVALID|Palette embedded symbol is not allowlisted: " + value);
               }
            }
            else
            {
               throw new Error("INVALID|Palette asset kind must be svg, icon, or symbol: " + role);
            }
            result[role] = { kind:kind,value:value };
         }
         return result;
      }

      private function resolveNode(param1:XML) : void
      {
         var attributes:XMLList = null;
         var attribute:XML = null;
         var attributeNodes:Array = [];
         var attributeNames:Array = [];
         var attributeValues:Array = [];
         var children:XMLList = null;
         var child:XML = null;
         var attributeName:String = null;
         var value:String = null;
         var resolvedValue:String = null;
         var index:int = 0;
         attributes = param1.attributes();
         for(index = 0; index < attributes.length(); ++index)
         {
            attribute = attributes[index];
            attributeNodes.push(attribute);
            attributeNames.push(String(attribute.name()));
            attributeValues.push(String(attribute));
         }
         for(index = 0; index < attributeNames.length; ++index)
         {
            attributeName = String(attributeNames[index]);
            value = String(attributeValues[index]);
            attribute = attributeNodes[index];
            if(value.indexOf("@palette.") >= 0)
            {
               if(value.indexOf("@palette.") != 0)
               {
                  throw new Error("INVALID|Palette references must occupy an entire attribute value: " + attributeName);
               }
               resolvedValue = this.resolveReference(value,param1,attributeName);
               attribute.setChildren(resolvedValue);
            }
         }
         children = param1.children();
         for(index = 0; index < children.length(); ++index)
         {
            child = children[index];
            this.resolveNode(child);
         }
      }

      private function requireFullyResolved(param1:XML) : void
      {
         var attribute:XML = null;
         var children:XMLList = null;
         var index:int = 0;
         for each(attribute in param1.attributes())
         {
            if(String(attribute).indexOf("@palette.") >= 0)
            {
               throw new Error("INVALID|Palette resolver left an unresolved reference on " + String(param1.name()) + ".@" + String(attribute.name()) + ".");
            }
         }
         children = param1.children();
         for(index = 0; index < children.length(); ++index)
         {
            this.requireFullyResolved(children[index]);
         }
      }

      private function resolveReference(param1:String, param2:XML, param3:String) : String
      {
         if(param1.indexOf("@palette.colors.") == 0)
         {
            return this.resolveScalar(colors,param1.substring(16),"color",param2,param3,this.isColorAttribute(param2,param3));
         }
         if(param1.indexOf("@palette.opacities.") == 0)
         {
            return this.resolveScalar(opacities,param1.substring(19),"opacity",param2,param3,this.isOpacityAttribute(param3));
         }
         if(param1.indexOf("@palette.typography.") == 0)
         {
            return this.resolveRecord(typography,param1.substring(20),"typography",param2,param3);
         }
         if(param1.indexOf("@palette.strokes.") == 0)
         {
            return this.resolveRecord(strokes,param1.substring(17),"stroke",param2,param3);
         }
         if(param1.indexOf("@palette.assets.") == 0)
         {
            return this.resolveAsset(param1.substring(16),param2,param3);
         }
         throw new Error("INVALID|Unknown palette reference category: " + param1);
      }

      private function resolveScalar(param1:Object, param2:String, param3:String, param4:XML, param5:String, param6:Boolean) : String
      {
         if(!param6)
         {
            throw new Error("INVALID|Palette " + param3 + " reference is incompatible with " + String(param4.name()) + ".@" + param5 + ".");
         }
         if(!param1.hasOwnProperty(param2))
         {
            throw new Error("INVALID|Unknown palette " + param3 + " role: " + param2);
         }
         return String(param1[param2]);
      }

      private function resolveRecord(param1:Object, param2:String, param3:String, param4:XML, param5:String) : String
      {
         var separator:int = param2.lastIndexOf(".");
         var role:String = separator < 0 ? "" : param2.substring(0,separator);
         var field:String = separator < 0 ? "" : param2.substring(separator + 1);
         var entry:Object = null;
         if(role.length == 0 || field.length == 0 || !param1.hasOwnProperty(role))
         {
            throw new Error("INVALID|Unknown palette " + param3 + " role: " + role);
         }
         entry = param1[role];
         if(!entry.hasOwnProperty(field) || !this.isRecordCompatible(param3,field,param4,param5))
         {
            throw new Error("INVALID|Palette " + param3 + " field is incompatible with " + String(param4.name()) + ".@" + param5 + ": " + field);
         }
         return String(entry[field]);
      }

      private function resolveAsset(param1:String, param2:XML, param3:String) : String
      {
         var entry:Object = null;
         var elementName:String = String(param2.name());
         if(!assets.hasOwnProperty(param1))
         {
            throw new Error("INVALID|Unknown palette asset role: " + param1);
         }
         entry = assets[param1];
         if(entry.kind == "svg" && (elementName != "svg" || param3 != "src") ||
            entry.kind == "icon" && (elementName != "icon" || param3 != "name") ||
            entry.kind == "symbol" && (elementName != "symbol" || param3 != "name"))
         {
            throw new Error("INVALID|Palette " + entry.kind + " asset is incompatible with " + elementName + ".@" + param3 + ".");
         }
         return String(entry.value);
      }

      private function isRecordCompatible(param1:String, param2:String, param3:XML, param4:String) : Boolean
      {
         if(param1 == "typography")
         {
            return param2 == param4 && (param2 == "font" || param2 == "fontSize" || param2 == "bold" || param2 == "color") && String(param3.name()) == "text";
         }
         if(param1 == "stroke")
         {
            return param2 == "color" && (param4 == "strokeColor" || String(param3.name()) == "divider" && param4 == "color") ||
                   param2 == "opacity" && param4 == "strokeOpacity" ||
                   param2 == "width" && param4 == "strokeWidth";
         }
         return false;
      }

      private function isColorAttribute(param1:XML, param2:String) : Boolean
      {
         return param2 == "color" || param2.length > 5 && param2.substring(param2.length - 5) == "Color";
      }

      private function isOpacityAttribute(param1:String) : Boolean
      {
         return param1 == "opacity" || param1.length > 7 && param1.substring(param1.length - 7) == "Opacity";
      }

      private function requireRoles(param1:Object, param2:Array, param3:String) : void
      {
         var role:String = null;
         for each(role in param2)
         {
            if(!param1.hasOwnProperty(role))
            {
               throw new Error("INVALID|Palette is missing required " + param3 + " role: " + role);
            }
         }
      }

      private function requireEntryCount(param1:XML, param2:int, param3:int, param4:String) : void
      {
         var count:int = param1.children().length();
         if(count < param2 || count > param3)
         {
            throw new Error("INVALID|Palette " + param4 + " must contain " + param2 + " through " + param3 + " entries.");
         }
      }

      private function requireRole(param1:XML) : String
      {
         var role:String = String(param1.@role);
         if(!/^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)*$/.test(role) || role.length > 64)
         {
            throw new Error("INVALID|Palette roles must be lowercase semantic identifiers of at most 64 characters: " + role);
         }
         return role;
      }

      private function requireUnique(param1:Object, param2:String, param3:String) : void
      {
         if(param1.hasOwnProperty(param2))
         {
            throw new Error("INVALID|Duplicate palette " + param3 + " role: " + param2);
         }
      }

      private function requireEmpty(param1:XML, param2:String) : void
      {
         if(param1.children().length() != 0)
         {
            throw new Error("INVALID|Palette " + param2 + " entries cannot contain child elements.");
         }
      }

      private function requireName(param1:XML, param2:String) : void
      {
         if(String(param1.name()) != param2)
         {
            throw new Error("INVALID|Expected palette element " + param2 + ".");
         }
      }

      private function requireAttributes(param1:XML, param2:Array) : void
      {
         var allowed:Object = {};
         var name:String = null;
         var attribute:XML = null;
         for each(name in param2)
         {
            allowed[name] = true;
            if(param1.attribute(name).length() != 1)
            {
               throw new Error("INVALID|Missing palette attribute " + name + " on " + String(param1.name()) + ".");
            }
         }
         for each(attribute in param1.attributes())
         {
            name = String(attribute.name());
            if(allowed[name] !== true)
            {
               throw new Error("INVALID|Unsupported palette attribute " + name + " on " + String(param1.name()) + ".");
            }
         }
      }
   }
}
