package Shared.Components.ContentLoaders
{
   import flash.display.MovieClip;

   public class SymbolLoaderClip extends MovieClip
   {
      public var onLoadAttemptComplete:Function;

      public function SymbolLoaderClip()
      {
         super();
      }

      public function get symbolInstance() : MovieClip
      {
         return null;
      }

      public function LoadSymbol(param1:String, param2:String = "") : void
      {
      }

      public function Unload() : void
      {
      }
   }
}
