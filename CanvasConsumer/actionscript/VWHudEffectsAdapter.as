package
{
   public final class VWHudEffectsAdapter
   {
      private static const MESSAGE_TYPE:String = "effects.state";

      private static const SCHEMA_VERSION:int = 1;

      private static const MAX_EFFECTS:int = 2000;

      private var buffs:Array = [];

      private var debuffs:Array = [];

      private var hasSnapshot:Boolean;

      private var committedSignature:String = "";

      private var page:int;

      public function reset() : void
      {
         this.buffs = [];
         this.debuffs = [];
         this.hasSnapshot = false;
         this.committedSignature = "";
         this.page = 0;
      }

      // A true result means one complete datagram changed visible effect state.
      public function acceptDatagram(body:String) : Boolean
      {
         var datagram:Object = null;
         try
         {
            datagram = VWHudDatagramCodec.decode(body);
         }
         catch(datagramError:*)
         {
            return false;
         }
         if(datagram.messageType != MESSAGE_TYPE || int(datagram.schemaVersion) != SCHEMA_VERSION || datagram.encoding != "ci-ascii")
         {
            return false;
         }
         return this.acceptPayload(String(datagram.payload));
      }

      public function advancePage() : Boolean
      {
         var pages:int = this.pageCount();
         if(!this.hasSnapshot || pages < 2)
         {
            return false;
         }
         this.page = (this.page + 1) % pages;
         return true;
      }

      public function view() : Object
      {
         var visibleBuffs:Array = this.slice(this.buffs,this.page * VWHudPresentation.BUFF_COLUMNS,VWHudPresentation.BUFF_COLUMNS);
         var visibleDebuffs:Array = this.slice(this.debuffs,this.page * this.debuffPageSize(),this.debuffPageSize());
         return {
            "waiting":!this.hasSnapshot,
            "empty":this.hasSnapshot && this.buffs.length + this.debuffs.length == 0,
            "hasbuffs":visibleBuffs.length > 0,
            "hasdebuffs":visibleDebuffs.length > 0,
            "buffcount":this.buffs.length,
            "debuffcount":this.debuffs.length,
            "buffrows":visibleBuffs,
            "debuffrows":visibleDebuffs
         };
      }

      private function acceptPayload(payload:String) : Boolean
      {
         var fields:Array = payload.split("|");
         if(fields.length != 3)
         {
            return false;
         }
         var buffCount:int = this.unsigned(String(fields[0]),0,MAX_EFFECTS);
         var debuffCount:int = this.unsigned(String(fields[1]),0,MAX_EFFECTS);
         if(buffCount < 0 || debuffCount < 0 || buffCount + debuffCount > MAX_EFFECTS)
         {
            return false;
         }
         var encodedEntries:String = String(fields[2]);
         if(buffCount + debuffCount == 0 && encodedEntries != "" || buffCount + debuffCount > 0 && (encodedEntries == "" || encodedEntries.charAt(encodedEntries.length - 1) != ";"))
         {
            return false;
         }
         var nextBuffs:Array = [];
         var nextDebuffs:Array = [];
         var keys:Object = {};
         var items:Array = encodedEntries == "" ? [] : encodedEntries.split(";");
         var limit:int = encodedEntries == "" ? 0 : items.length - 1;
         for(var index:int = 0; index < limit; index++)
         {
            var entry:Object = this.parseEntry(String(items[index]));
            if(entry == null || keys.hasOwnProperty("@" + entry.key))
            {
               return false;
            }
            keys["@" + entry.key] = true;
            if(entry.category == "B")
            {
               nextBuffs.push(entry);
            }
            else
            {
               nextDebuffs.push(entry);
            }
            if(nextBuffs.length > buffCount || nextDebuffs.length > debuffCount)
            {
               return false;
            }
         }
         if(nextBuffs.length != buffCount || nextDebuffs.length != debuffCount)
         {
            return false;
         }
         var signature:String = payload.toLowerCase();
         if(this.hasSnapshot && signature == this.committedSignature)
         {
            return false;
         }
         this.buffs = nextBuffs;
         this.debuffs = nextDebuffs;
         this.hasSnapshot = true;
         this.committedSignature = signature;
         this.clampPage();
         return true;
      }

      private function parseEntry(encoded:String) : Object
      {
         if(encoded == null || encoded.length < 3 || encoded.length > 4096 || encoded.charAt(1) != ":" || encoded.indexOf("|") >= 0 || encoded.indexOf(";") >= 0)
         {
            return null;
         }
         var category:String = encoded.charAt(0).toUpperCase();
         if(category != "B" && category != "D")
         {
            return null;
         }
         var label:String = encoded.substring(2);
         if(label.charAt(0) == "#")
         {
            var delimiter:int = label.indexOf(":");
            if(delimiter < 2 || !/^-?[0-9]+$/.test(label.substring(1,delimiter)))
            {
               return null;
            }
            label = label.substring(delimiter + 1);
         }
         return label == "" ? null : {"key":encoded.toLowerCase(),"category":category,"label":label};
      }

      private function debuffPageSize() : int
      {
         return VWHudPresentation.DEBUFF_COLUMNS * VWHudPresentation.DEBUFF_ROWS;
      }

      private function slice(entries:Array, start:int, count:int) : Array
      {
         var visible:Array = [];
         var end:int = Math.min(start + count,entries.length);
         for(var index:int = start; index < end; index++) visible.push({"label":entries[index].label});
         return visible;
      }

      private function pageCount() : int
      {
         var buffPages:int = Math.ceil(this.buffs.length / VWHudPresentation.BUFF_COLUMNS);
         var debuffPages:int = Math.ceil(this.debuffs.length / this.debuffPageSize());
         return Math.max(1,Math.max(buffPages,debuffPages));
      }

      private function clampPage() : void
      {
         if(this.page >= this.pageCount())
         {
            this.page = 0;
         }
      }

      private function unsigned(value:String, minimum:int, maximum:int) : int
      {
         if(value == null || !/^[0-9]+$/.test(value))
         {
            return -1;
         }
         var number:Number = Number(value);
         return isFinite(number) && number >= minimum && number <= maximum ? int(number) : -1;
      }
   }
}
