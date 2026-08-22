package venworks.cui.components
{
   import Shared.Components.ContentLoaders.SymbolLoaderClip;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.geom.Rectangle;
   import venworks.cui.CUIPaletteResolver;

   public final class CUIProviderSymbol extends CUIComponent
   {
      private static const CREATION_CLUB_PREFIX:String = "CCSUP";
      private static const VANILLA_WEAPON_LIBRARY:String = "WeaponIcons";

      private var config:XML;
      private var loader:SymbolLoaderClip;
      private var currentSymbol:String = "";

      public function CUIProviderSymbol(param1:XML, param2:CUIPaletteResolver)
      {
         super(param1,param2);
         config = param1;
         loader = new SymbolLoaderClip();
         loader.visible = false;
         loader.onLoadAttemptComplete = this.onLoadAttemptComplete;
         addChild(loader);
         scrollRect = new Rectangle(0,0,componentWidth,componentHeight);
      }

      public function setSymbol(param1:String) : void
      {
         var symbol:String = param1 == null ? "" : param1.replace(/^\s+|\s+$/g,"");
         var library:String = "";
         if(symbol == currentSymbol)
         {
            return;
         }
         currentSymbol = symbol;
         loader.visible = false;
         loader.Unload();
         if(symbol.length == 0)
         {
            return;
         }
         library = symbol.substr(0,CREATION_CLUB_PREFIX.length) == CREATION_CLUB_PREFIX ?
            symbol : VANILLA_WEAPON_LIBRARY;
         loader.LoadSymbol(symbol,library);
      }

      private function onLoadAttemptComplete() : void
      {
         var content:MovieClip = loader.symbolInstance;
         if(content == null)
         {
            loader.visible = false;
            return;
         }
         try
         {
            content.scaleX = 1;
            content.scaleY = 1;
            content.x = 0;
            content.y = 0;
            content.transform.colorTransform = new ColorTransform();
            if(content.width <= 0 || content.height <= 0)
            {
               loader.visible = false;
               return;
            }
            this.applyTint(content);
            this.fitContent(content);
            loader.visible = true;
         }
         catch(param1:Error)
         {
            loader.visible = false;
         }
      }

      private function applyTint(param1:MovieClip) : void
      {
         var color:uint = 0;
         if(config.@color.length() == 0)
         {
            return;
         }
         color = this.readColor(config,"color",16777215);
         param1.transform.colorTransform = new ColorTransform(
            0,0,0,1,
            color >> 16 & 255,
            color >> 8 & 255,
            color & 255,
            0
         );
      }

      private function fitContent(param1:MovieClip) : void
      {
         var fit:String = config.@fit.length() == 1 ? String(config.@fit) : "contain";
         var originalWidth:Number = param1.width;
         var originalHeight:Number = param1.height;
         var scale:Number = 1;
         if(fit == "stretch")
         {
            param1.scaleX = componentWidth / originalWidth;
            param1.scaleY = componentHeight / originalHeight;
         }
         else if(fit == "contain" || fit == "cover")
         {
            scale = fit == "contain" ?
               Math.min(componentWidth / originalWidth,componentHeight / originalHeight) :
               Math.max(componentWidth / originalWidth,componentHeight / originalHeight);
            param1.scaleX = scale;
            param1.scaleY = scale;
         }
         this.alignContent(param1);
      }

      private function alignContent(param1:MovieClip) : void
      {
         var alignX:String = config.@alignX.length() == 1 ? String(config.@alignX) : "center";
         var alignY:String = config.@alignY.length() == 1 ? String(config.@alignY) : "center";
         if(alignX == "right")
         {
            param1.x = componentWidth - param1.width;
         }
         else if(alignX == "center")
         {
            param1.x = (componentWidth - param1.width) / 2;
         }
         if(alignY == "bottom")
         {
            param1.y = componentHeight - param1.height;
         }
         else if(alignY == "center")
         {
            param1.y = (componentHeight - param1.height) / 2;
         }
      }
   }
}
