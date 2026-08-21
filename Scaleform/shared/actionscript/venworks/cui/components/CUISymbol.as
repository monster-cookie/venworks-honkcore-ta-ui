package venworks.cui.components
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.InteractiveObject;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.geom.Rectangle;
   import flash.utils.getDefinitionByName;
   import venworks.cui.CUIPaletteResolver;

   public class CUISymbol extends CUIImage
   {
      private static const SYMBOLS:Object = {
         "environment-alert":{
            classes:["HUDMenu_fla.envAlertIcon_174","HUDMenu_LRG_fla.envAlertIcon_174"],
            initialFrame:1
         },
         "quest-door-marker":{
            classes:["QuestDoorMarker"],
            initialFrame:1
         },
         "boost-fill":{
            classes:["HUDMenu_fla.BoostBarFill_mc_139","HUDMenu_LRG_fla.BoostBarFill_mc_139"],
            initialFrame:1
         },
         "vehicle-exit-prompt":{
            classes:["HUDVehicle"],
            child:"GetUpButton_mc",
            glyphChildren:["PCButton_mc","ConsoleButton_mc"],
            presentationOnly:true
         }
      };

      public function CUISymbol(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,createEmbeddedSymbol(param2 == null ? String(param1.@name) :
            param2.resolveAttribute(param1,"name")),param2);
      }

      public static function isAllowlisted(param1:String) : Boolean
      {
         return SYMBOLS[param1] != null;
      }

      private static function createEmbeddedSymbol(param1:String) : DisplayObject
      {
         var definition:Object = null;
         var className:String = null;
         var symbolClass:Class = null;
         var result:DisplayObject = null;
         var extractedChild:DisplayObject = null;
         if(!isAllowlisted(param1))
         {
            throw new Error("INVALID|Embedded symbol is not allowlisted: " + param1);
         }
         definition = SYMBOLS[param1];
         for each(className in definition.classes)
         {
            try
            {
               symbolClass = getDefinitionByName(className) as Class;
               if(symbolClass != null)
               {
                  result = new symbolClass() as DisplayObject;
               }
            }
            catch(param2:Error)
            {
               result = null;
            }
            if(result != null)
            {
               break;
            }
         }
         if(result == null)
         {
            throw new Error("INVALID|Embedded symbol is unavailable in this HUD movie: " + param1);
         }
         if(definition.child != null)
         {
            extractedChild = Object(result)[String(definition.child)] as DisplayObject;
            if(extractedChild == null)
            {
               throw new Error("INVALID|Embedded symbol child is unavailable: " + param1);
            }
            result = extractedChild;
         }
         if(definition.glyphChildren != null)
         {
            result = createBoundedChildViewport(result,definition.glyphChildren,param1);
         }
         if(result is MovieClip && definition.initialFrame != null)
         {
            MovieClip(result).gotoAndStop(int(definition.initialFrame));
         }
         if(Boolean(definition.presentationOnly))
         {
            if(result is InteractiveObject)
            {
               InteractiveObject(result).mouseEnabled = false;
            }
            if(result is DisplayObjectContainer)
            {
               DisplayObjectContainer(result).mouseChildren = false;
            }
         }
         return result;
      }

      private static function createBoundedChildViewport(param1:DisplayObject, param2:Array, param3:String) : DisplayObject
      {
         var container:DisplayObjectContainer = param1 as DisplayObjectContainer;
         var childName:String = null;
         var child:DisplayObject = null;
         var childBounds:Rectangle = null;
         var bounds:Rectangle = null;
         var viewport:Sprite = null;
         if(container == null)
         {
            throw new Error("INVALID|Embedded symbol child is not a container: " + param3);
         }
         for each(childName in param2)
         {
            child = Object(container)[childName] as DisplayObject;
            if(child == null)
            {
               throw new Error("INVALID|Embedded symbol glyph child is unavailable: " + param3);
            }
            childBounds = child.getBounds(container);
            bounds = bounds == null ? childBounds.clone() : bounds.union(childBounds);
         }
         if(bounds == null || bounds.width <= 0 || bounds.height <= 0)
         {
            throw new Error("INVALID|Embedded symbol glyph region has no renderable dimensions: " + param3);
         }
         param1.x = -bounds.x;
         param1.y = -bounds.y;
         viewport = new Sprite();
         viewport.addChild(param1);
         viewport.scrollRect = new Rectangle(0,0,bounds.width,bounds.height);
         return viewport;
      }
   }
}
