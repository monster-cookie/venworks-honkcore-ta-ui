package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLLoaderDataFormat;
   import flash.net.URLRequest;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getDefinitionByName;

   public final class VenworksCUIDiagnosticEntrypoint extends MovieClip
   {
      public static const CLASS_FINGERPRINT:String = "VENWORKS_CUI_CLASSES_SHA256:________________________________________________________________";

      private static const PLAYER_DATA_PROVIDER:String = "PlayerData";
      private static const PLAYER_NAME_LIMIT:int = 80;
      private static const DIAGNOSTIC_LAYOUT_PATH:String = "VenworksCUI/layout.xml";
      private static const DIAGNOSTIC_LAYOUT_LIMIT:int = 4096;
      private static const XHTML_TEXT_LIMIT:int = 80;
      private static const XHTML_DECLARATION:String = "<?xml version=\"1.0\" encoding=\"utf-8\"?>";

      private var owner:DisplayObjectContainer = null;
      private var pane:TextField = null;
      private var xhtmlPane:TextField = null;
      private var playerDataStatus:String = "PS5DBG-05 PLAYERDATA NEXT FRAME";
      private var xhtmlStatus:String = "venworkscui.swf loaded";
      private var dataManager:Object = null;
      private var deferredProbeCallback:Function = null;
      private var deferredLayoutRequestCallback:Function = null;
      private var deferredLayoutParseCallback:Function = null;
      private var playerDataCallback:Function = null;
      private var playerDataState:String = "idle";
      private var playerName:String = "";
      private var subscriptionPending:Boolean = false;
      private var subscriptionActive:Boolean = false;
      private var layoutLoader:URLLoader = null;
      private var layoutText:String = null;
      private var layoutState:String = "idle";
      private var layoutParseArmed:Boolean = false;
      private var disposed:Boolean = true;

      public function VenworksCUIDiagnosticEntrypoint()
      {
         super();
      }

      public function initialize(param1:DisplayObjectContainer) : void
      {
         var format:TextFormat = new TextFormat("$MAIN_Font_Bold",18,16777215,true);
         if(this.owner === param1 && this.pane != null)
         {
            return;
         }
         this.dispose();
         this.owner = param1;
         if(this.owner == null)
         {
            this.disposed = true;
            return;
         }
         this.disposed = false;
         this.pane = new TextField();
         this.pane.name = "VenworksCUIDiagnosticPane";
         this.pane.x = 600;
         this.pane.y = 160;
         this.pane.width = 720;
         this.pane.height = 96;
         this.pane.background = true;
         this.pane.backgroundColor = 2631720;
         this.pane.border = true;
         this.pane.borderColor = 65535;
         this.pane.textColor = 16777215;
         this.pane.embedFonts = true;
         this.pane.defaultTextFormat = format;
         this.pane.multiline = true;
         this.pane.wordWrap = false;
         this.pane.selectable = false;
         this.pane.mouseEnabled = false;
         this.playerDataStatus = "PS5DBG-05 PLAYERDATA NEXT FRAME";
         this.xhtmlStatus = "venworkscui.swf loaded";
         this.renderStatus();
         this.pane.setTextFormat(format);
         addChild(this.pane);
         this.playerDataCallback = this.onPlayerData;
         this.deferredProbeCallback = this.onDeferredProbe;
         this.deferredLayoutRequestCallback = this.onDeferredLayoutRequest;
         this.deferredLayoutParseCallback = this.onDeferredLayoutParse;
         this.playerDataState = "scheduled";
         this.layoutState = "idle";
         addEventListener(Event.ENTER_FRAME,this.deferredProbeCallback,false,0,true);
      }

      public function reapplyVanillaPlacements() : void
      {
      }

      public function updateVanillaHudModeVisibility(param1:Array) : void
      {
      }

      public function dispose() : void
      {
         this.disposed = true;
         if(this.deferredProbeCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredProbeCallback);
         }
         if(this.deferredLayoutRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutRequestCallback);
         }
         if(this.deferredLayoutParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutParseCallback);
         }
         this.unsubscribePlayerData();
         this.releaseLayoutLoader(true);
         this.removeBasicXhtmlPane();
         if(this.pane != null && this.pane.parent === this)
         {
            removeChild(this.pane);
         }
         this.pane = null;
         this.owner = null;
         this.dataManager = null;
         this.deferredProbeCallback = null;
         this.deferredLayoutRequestCallback = null;
         this.deferredLayoutParseCallback = null;
         this.playerDataCallback = null;
         this.playerDataState = "disposed";
         this.playerName = "";
         this.playerDataStatus = "PS5DBG-05 PLAYERDATA NEXT FRAME";
         this.xhtmlStatus = "venworkscui.swf loaded";
         this.layoutText = null;
         this.layoutState = "disposed";
         this.layoutParseArmed = false;
      }

      private function onDeferredProbe(param1:Event) : void
      {
         var failure:Error = null;
         if(this.deferredProbeCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredProbeCallback);
         }
         if(this.disposed)
         {
            return;
         }
         try
         {
            this.setPlayerDataStatus("PS5DBG-06 PLAYERDATA REQUEST");
            this.dataManager = getDefinitionByName("Shared.AS3.Data.BSUIDataManager");
            if(this.dataManager == null)
            {
               throw new Error("BSUIDataManager definition was null.");
            }
            this.playerDataState = "subscribing";
            this.dataManager.GetDataFromClient(PLAYER_DATA_PROVIDER,true);
            this.subscriptionPending = true;
            this.dataManager.Subscribe(PLAYER_DATA_PROVIDER,this.playerDataCallback);
            this.subscriptionPending = false;
            this.subscriptionActive = true;
            if(this.playerDataState == "subscribing")
            {
               this.playerDataState = "waiting";
               this.setPlayerDataStatus("PS5DBG-07 PLAYERDATA WAITING");
            }
         }
         catch(param2:Error)
         {
            failure = param2;
            this.unsubscribePlayerData();
            if(!this.disposed)
            {
               this.playerDataState = "failed";
               this.setPlayerDataStatus("PS5DBG-ERR PLAYERDATA | " + this.sanitizeText(failure,PLAYER_NAME_LIMIT));
            }
         }
      }

      private function onPlayerData(param1:Object) : void
      {
         if(this.disposed || this.playerDataState == "failed" || this.layoutState != "idle")
         {
            return;
         }
         try
         {
            if(param1 == null || param1.data == null || param1.data.sName === undefined || param1.data.sName === null)
            {
               this.playerName = "<missing sName>";
            }
            else
            {
               this.playerName = this.sanitizeText(param1.data.sName,PLAYER_NAME_LIMIT);
               if(this.playerName.length == 0)
               {
                  this.playerName = "<empty sName>";
               }
            }
            this.playerDataState = "received";
            this.layoutState = "scheduled";
            this.setPlayerDataStatus("PS5DBG-OK PLAYERDATA | " + this.playerName);
            this.setXhtmlStatus("PS5DBG-08 XHTML TEXT LOAD NEXT FRAME");
            addEventListener(Event.ENTER_FRAME,this.deferredLayoutRequestCallback,false,0,true);
         }
         catch(param2:Error)
         {
            this.unsubscribePlayerData();
            if(!this.disposed)
            {
               this.playerDataState = "failed";
               this.setPlayerDataStatus("PS5DBG-ERR PLAYERDATA | " + this.sanitizeText(param2,PLAYER_NAME_LIMIT));
            }
         }
      }

      private function onDeferredLayoutRequest(param1:Event) : void
      {
         if(this.deferredLayoutRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutRequestCallback);
         }
         if(this.disposed || this.layoutState != "scheduled")
         {
            return;
         }
         try
         {
            this.layoutState = "requesting";
            this.layoutLoader = new URLLoader();
            this.layoutLoader.dataFormat = URLLoaderDataFormat.TEXT;
            this.layoutLoader.addEventListener(Event.COMPLETE,this.onLayoutLoadComplete,false,0,true);
            this.layoutLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onLayoutIoError,false,0,true);
            this.layoutLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onLayoutSecurityError,false,0,true);
            this.layoutLoader.load(new URLRequest(DIAGNOSTIC_LAYOUT_PATH));
            if(!this.disposed && this.layoutState == "requesting" && this.layoutLoader != null)
            {
               this.setXhtmlStatus("PS5DBG-09 XHTML LOAD RETURNED");
            }
         }
         catch(param2:Error)
         {
            this.failLayout("PS5DBG-ERR XHTML REQUEST");
         }
      }

      private function onLayoutLoadComplete(param1:Event) : void
      {
         if(this.disposed || this.layoutState != "requesting" || this.layoutLoader == null)
         {
            return;
         }
         try
         {
            this.layoutText = String(this.layoutLoader.data);
         }
         catch(param2:Error)
         {
            this.failLayout("PS5DBG-ERR XHTML TEXT");
            return;
         }
         this.releaseLayoutLoader(false);
         this.layoutState = "received";
         this.layoutParseArmed = false;
         this.setXhtmlStatus("PS5DBG-10 XHTML TEXT RECEIVED");
         addEventListener(Event.ENTER_FRAME,this.deferredLayoutParseCallback,false,0,true);
      }

      private function onLayoutIoError(param1:IOErrorEvent) : void
      {
         this.failLayout("PS5DBG-ERR XHTML IO");
      }

      private function onLayoutSecurityError(param1:SecurityErrorEvent) : void
      {
         this.failLayout("PS5DBG-ERR XHTML SECURITY");
      }

      private function onDeferredLayoutParse(param1:Event) : void
      {
         var parsedLayout:Object = null;
         if(this.disposed || this.layoutState != "received")
         {
            if(this.deferredLayoutParseCallback != null)
            {
               removeEventListener(Event.ENTER_FRAME,this.deferredLayoutParseCallback);
            }
            return;
         }
         if(!this.layoutParseArmed)
         {
            this.layoutParseArmed = true;
            this.setXhtmlStatus("PS5DBG-11 XHTML PARSE NEXT FRAME");
            return;
         }
         if(this.deferredLayoutParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutParseCallback);
         }
         if(this.layoutText == null || this.layoutText.length == 0)
         {
            this.failLayout("PS5DBG-ERR XHTML TEXT");
            return;
         }
         if(this.layoutText.length > DIAGNOSTIC_LAYOUT_LIMIT)
         {
            this.failLayout("PS5DBG-ERR XHTML SIZE");
            return;
         }
         try
         {
            parsedLayout = this.parseBoundedXhtml(this.layoutText);
         }
         catch(param2:Error)
         {
            this.failLayout("PS5DBG-ERR XHTML PARSE");
            return;
         }
         if(parsedLayout == null)
         {
            this.failLayout("PS5DBG-ERR XHTML PARSE");
            return;
         }
         this.setXhtmlStatus("PS5DBG-12 BASIC XHTML RENDER");
         try
         {
            this.renderBasicXhtml(String(parsedLayout.heading),String(parsedLayout.paragraph));
         }
         catch(param3:Error)
         {
            this.failLayout("PS5DBG-ERR XHTML RENDER");
            return;
         }
         this.layoutText = null;
         this.layoutState = "complete";
         this.setXhtmlStatus("PS5DBG-OK XHTML | html/head/title/body/section/h1/p");
      }

      private function parseBoundedXhtml(param1:String) : Object
      {
         var cursor:Object = {"position":0};
         var title:String = null;
         var heading:String = null;
         var paragraph:String = null;
         if(!this.expectLayoutLiteral(param1,cursor,XHTML_DECLARATION))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<html>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<head>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<title>"))
         {
            return null;
         }
         title = this.readLayoutText(param1,cursor,"</title>");
         if(title == null || !this.expectLayoutLiteral(param1,cursor,"</title>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"</head>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<body>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<section>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<h1>"))
         {
            return null;
         }
         heading = this.readLayoutText(param1,cursor,"</h1>");
         if(heading == null || !this.expectLayoutLiteral(param1,cursor,"</h1>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"<p>"))
         {
            return null;
         }
         paragraph = this.readLayoutText(param1,cursor,"</p>");
         if(paragraph == null || !this.expectLayoutLiteral(param1,cursor,"</p>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"</section>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"</body>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(!this.expectLayoutLiteral(param1,cursor,"</html>"))
         {
            return null;
         }
         this.skipLayoutWhitespace(param1,cursor);
         if(int(cursor.position) != param1.length)
         {
            return null;
         }
         return {"title":title,"heading":heading,"paragraph":paragraph};
      }

      private function skipLayoutWhitespace(param1:String, param2:Object) : void
      {
         var position:int = int(param2.position);
         while(position < param1.length && this.isLayoutWhitespace(param1.charCodeAt(position)))
         {
            position++;
         }
         param2.position = position;
      }

      private function expectLayoutLiteral(param1:String, param2:Object, param3:String) : Boolean
      {
         var position:int = int(param2.position);
         if(position + param3.length > param1.length || param1.substr(position,param3.length) != param3)
         {
            return false;
         }
         param2.position = position + param3.length;
         return true;
      }

      private function readLayoutText(param1:String, param2:Object, param3:String) : String
      {
         var position:int = int(param2.position);
         var end:int = param1.indexOf(param3,position);
         var value:String = null;
         var index:int = 0;
         var code:Number = 0;
         if(end <= position || end - position > XHTML_TEXT_LIMIT)
         {
            return null;
         }
         value = param1.substring(position,end);
         if(this.isLayoutWhitespace(value.charCodeAt(0)) || this.isLayoutWhitespace(value.charCodeAt(value.length - 1)))
         {
            return null;
         }
         for(index = 0; index < value.length; index++)
         {
            code = value.charCodeAt(index);
            if(code == 38 || code == 60 || code == 9 || code == 10 || code == 13)
            {
               return null;
            }
         }
         param2.position = end;
         return value;
      }

      private function isLayoutWhitespace(param1:Number) : Boolean
      {
         return param1 == 32 || param1 == 9 || param1 == 10 || param1 == 13;
      }

      private function renderBasicXhtml(param1:String, param2:String) : void
      {
         var headingFormat:TextFormat = new TextFormat("$MAIN_Font_Bold",24,65280,true);
         var paragraphFormat:TextFormat = new TextFormat("$MAIN_Font_Bold",18,16777215,false);
         var headingEnd:int = param1.length;
         this.removeBasicXhtmlPane();
         this.xhtmlPane = new TextField();
         this.xhtmlPane.name = "VenworksCUIBasicXhtmlPane";
         this.xhtmlPane.x = 600;
         this.xhtmlPane.y = 285;
         this.xhtmlPane.width = 720;
         this.xhtmlPane.height = 150;
         this.xhtmlPane.background = true;
         this.xhtmlPane.backgroundColor = 1577000;
         this.xhtmlPane.border = true;
         this.xhtmlPane.borderColor = 65535;
         this.xhtmlPane.embedFonts = true;
         this.xhtmlPane.defaultTextFormat = paragraphFormat;
         this.xhtmlPane.multiline = true;
         this.xhtmlPane.wordWrap = true;
         this.xhtmlPane.selectable = false;
         this.xhtmlPane.mouseEnabled = false;
         this.xhtmlPane.text = param1 + "\n" + param2;
         this.xhtmlPane.setTextFormat(headingFormat,0,headingEnd);
         this.xhtmlPane.setTextFormat(paragraphFormat,headingEnd + 1,this.xhtmlPane.text.length);
         addChild(this.xhtmlPane);
      }

      private function removeBasicXhtmlPane() : void
      {
         if(this.xhtmlPane != null && this.xhtmlPane.parent === this)
         {
            removeChild(this.xhtmlPane);
         }
         this.xhtmlPane = null;
      }

      private function failLayout(param1:String) : void
      {
         if(this.deferredLayoutRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutRequestCallback);
         }
         if(this.deferredLayoutParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredLayoutParseCallback);
         }
         this.releaseLayoutLoader(true);
         this.removeBasicXhtmlPane();
         this.layoutText = null;
         this.layoutState = "failed";
         this.layoutParseArmed = false;
         if(!this.disposed)
         {
            this.setXhtmlStatus(param1);
         }
      }

      private function releaseLayoutLoader(param1:Boolean) : void
      {
         if(this.layoutLoader == null)
         {
            return;
         }
         this.layoutLoader.removeEventListener(Event.COMPLETE,this.onLayoutLoadComplete);
         this.layoutLoader.removeEventListener(IOErrorEvent.IO_ERROR,this.onLayoutIoError);
         this.layoutLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onLayoutSecurityError);
         if(param1)
         {
            try
            {
               this.layoutLoader.close();
            }
            catch(param2:Error)
            {
            }
         }
         this.layoutLoader = null;
      }

      private function unsubscribePlayerData() : void
      {
         if((this.subscriptionPending || this.subscriptionActive) && this.dataManager != null && this.playerDataCallback != null)
         {
            try
            {
               this.dataManager.Unsubscribe(PLAYER_DATA_PROVIDER,this.playerDataCallback);
            }
            catch(param1:Error)
            {
            }
         }
         this.subscriptionPending = false;
         this.subscriptionActive = false;
      }

      private function setPlayerDataStatus(param1:String) : void
      {
         this.playerDataStatus = this.sanitizeText(param1,120);
         this.renderStatus();
      }

      private function setXhtmlStatus(param1:String) : void
      {
         this.xhtmlStatus = this.sanitizeText(param1,120);
         this.renderStatus();
      }

      private function renderStatus() : void
      {
         if(this.pane == null)
         {
            return;
         }
         this.pane.text = "PLAYERDATA: " + this.playerDataStatus + "\nXHTML: " + this.xhtmlStatus;
      }

      private function sanitizeText(param1:Object, param2:int) : String
      {
         var value:String = param1 === null ? "" : String(param1);
         value = value.replace(/[\r\n\t]+/g," ");
         value = value.replace(/\s{2,}/g," ");
         value = value.replace(/^\s+|\s+$/g,"");
         if(value.length > param2)
         {
            value = value.substr(0,param2 - 3) + "...";
         }
         return value;
      }
   }
}
