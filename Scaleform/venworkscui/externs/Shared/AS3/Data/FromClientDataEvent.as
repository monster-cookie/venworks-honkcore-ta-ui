package Shared.AS3.Data
{
   import flash.events.Event;

   public final class FromClientDataEvent extends Event
   {
      public function FromClientDataEvent()
      {
         super(Event.CHANGE);
      }

      public function get data() : Object
      {
         return null;
      }
   }
}
