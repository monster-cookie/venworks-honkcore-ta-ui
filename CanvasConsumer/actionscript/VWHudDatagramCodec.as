package
{
   public final class VWHudDatagramCodec
   {
      private static const PREFIX:String = "VWDG/1|";

      private static const MAX_BODY_CHARACTERS:int = 4096;

      private static const MAX_MESSAGE_TYPE_CHARACTERS:int = 96;

      private static const MAX_ENCODING_CHARACTERS:int = 24;

      private static const MAX_SCHEMA_VERSION:int = 9999;

      public static function encode(messageType:String, schemaVersion:int, encoding:String, payload:String) : String
      {
         if(payload == null)
         {
            payload = "";
         }
         var body:String = PREFIX + frame(messageType) + frame(String(schemaVersion)) + frame(encoding) + frame(payload);
         decode(body);
         return body;
      }

      public static function decode(body:String) : Object
      {
         if(body == null || body.length < PREFIX.length || body.length > MAX_BODY_CHARACTERS || !/^[\x20-\x7E]+$/.test(body))
         {
            throw new Error("invalid datagram size or characters");
         }
         if(body.substr(0,PREFIX.length).toLowerCase() != PREFIX.toLowerCase())
         {
            throw new Error("unsupported datagram envelope");
         }
         var cursor:int = PREFIX.length;
         var typeFrame:Object = readFrame(body,cursor,MAX_MESSAGE_TYPE_CHARACTERS);
         cursor = int(typeFrame.next);
         var schemaFrame:Object = readFrame(body,cursor,4);
         cursor = int(schemaFrame.next);
         var encodingFrame:Object = readFrame(body,cursor,MAX_ENCODING_CHARACTERS);
         cursor = int(encodingFrame.next);
         var payloadFrame:Object = readFrame(body,cursor,MAX_BODY_CHARACTERS);
         cursor = int(payloadFrame.next);
         if(cursor != body.length)
         {
            throw new Error("trailing datagram data");
         }
         var messageType:String = String(typeFrame.value).toLowerCase();
         if(!isMessageTypeValid(messageType))
         {
            throw new Error("invalid datagram message type");
         }
         var schemaVersion:int = parseUnsigned(String(schemaFrame.value),1,MAX_SCHEMA_VERSION);
         var encoding:String = String(encodingFrame.value).toLowerCase();
         if(encoding != "ci-ascii")
         {
            throw new Error("unsupported datagram encoding");
         }
         return {
            "envelopeVersion":1,
            "messageType":messageType,
            "schemaVersion":schemaVersion,
            "encoding":encoding,
            "payload":String(payloadFrame.value)
         };
      }

      private static function frame(value:String) : String
      {
         if(value == null)
         {
            throw new Error("datagram frame is null");
         }
         return value.length + ":" + value;
      }

      private static function readFrame(source:String, cursor:int, maximum:int) : Object
      {
         if(cursor < 0 || cursor >= source.length)
         {
            throw new Error("missing datagram frame");
         }
         var delimiter:int = source.indexOf(":",cursor);
         if(delimiter < 0 || delimiter == cursor || delimiter - cursor > 6)
         {
            throw new Error("invalid datagram frame length");
         }
         var lengthValue:int = parseUnsigned(source.substring(cursor,delimiter),0,maximum);
         var valueStart:int = delimiter + 1;
         var valueEnd:int = valueStart + lengthValue;
         if(valueEnd > source.length)
         {
            throw new Error("truncated datagram frame");
         }
         return {"value":source.substring(valueStart,valueEnd),"next":valueEnd};
      }

      private static function parseUnsigned(value:String, minimum:int, maximum:int) : int
      {
         if(value == null || !/^[0-9]+$/.test(value))
         {
            throw new Error("invalid datagram integer");
         }
         var number:Number = Number(value);
         if(!isFinite(number) || number < minimum || number > maximum || number != Math.floor(number))
         {
            throw new Error("datagram integer out of range");
         }
         return int(number);
      }

      private static function isMessageTypeValid(value:String) : Boolean
      {
         if(value == null || value.length < 3 || value.length > MAX_MESSAGE_TYPE_CHARACTERS || !/^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?(\.[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?)+$/.test(value))
         {
            return false;
         }
         return value.substr(0,7) != "canvas.";
      }
   }
}
