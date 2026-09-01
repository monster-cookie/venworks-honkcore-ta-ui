package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getDefinitionByName;

   public final class VenworksCUIDiagnosticEntrypoint extends MovieClip
   {
      public static const CLASS_FINGERPRINT:String = "VENWORKS_CUI_CLASSES_SHA256:________________________________________________________________";

      private static const PLAYER_DATA_PROVIDER:String = "PlayerData";
      private static const PLAYER_NAME_LIMIT:int = 80;
      private static const DIAGNOSTIC_XML_PATH:String = "VenworksCUI/layout.xml";
      private static const DIAGNOSTIC_XML_LIMIT:int = 4096;
      private static const DIAGNOSTIC_TEXT_LIMIT:int = 80;

      private var owner:DisplayObjectContainer = null;
      private var pane:TextField = null;
      private var playerDataStatus:String = "PS5DBG-05 PLAYERDATA NEXT FRAME";
      private var xmlStatus:String = "venworkscui.swf loaded";
      private var dataManager:Object = null;
      private var deferredProbeCallback:Function = null;
      private var deferredXmlRequestCallback:Function = null;
      private var deferredXmlParseCallback:Function = null;
      private var playerDataCallback:Function = null;
      private var playerDataState:String = "idle";
      private var playerName:String = "";
      private var subscriptionPending:Boolean = false;
      private var subscriptionActive:Boolean = false;
      private var xmlLoader:URLLoader = null;
      private var xmlText:String = null;
      private var xmlState:String = "idle";
      private var xmlParseArmed:Boolean = false;
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
         this.xmlStatus = "venworkscui.swf loaded";
         this.renderStatus();
         this.pane.setTextFormat(format);
         addChild(this.pane);
         this.playerDataCallback = this.onPlayerData;
         this.deferredProbeCallback = this.onDeferredProbe;
         this.deferredXmlRequestCallback = this.onDeferredXmlRequest;
         this.deferredXmlParseCallback = this.onDeferredXmlParse;
         this.playerDataState = "scheduled";
         this.xmlState = "idle";
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
         if(this.deferredXmlRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlRequestCallback);
         }
         if(this.deferredXmlParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlParseCallback);
         }
         this.unsubscribePlayerData();
         this.releaseXmlLoader(true);
         if(this.pane != null && this.pane.parent === this)
         {
            removeChild(this.pane);
         }
         this.pane = null;
         this.owner = null;
         this.dataManager = null;
         this.deferredProbeCallback = null;
         this.deferredXmlRequestCallback = null;
         this.deferredXmlParseCallback = null;
         this.playerDataCallback = null;
         this.playerDataState = "disposed";
         this.playerName = "";
         this.playerDataStatus = "PS5DBG-05 PLAYERDATA NEXT FRAME";
         this.xmlStatus = "venworkscui.swf loaded";
         this.xmlText = null;
         this.xmlState = "disposed";
         this.xmlParseArmed = false;
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
         if(this.disposed || this.playerDataState == "failed" || this.xmlState != "idle")
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
            this.xmlState = "scheduled";
            this.setPlayerDataStatus("PS5DBG-OK PLAYERDATA | " + this.playerName);
            this.setXmlStatus("PS5DBG-08 XML LOAD NEXT FRAME");
            addEventListener(Event.ENTER_FRAME,this.deferredXmlRequestCallback,false,0,true);
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

      private function onDeferredXmlRequest(param1:Event) : void
      {
         if(this.deferredXmlRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlRequestCallback);
         }
         if(this.disposed || this.xmlState != "scheduled")
         {
            return;
         }
         try
         {
            this.xmlState = "requesting";
            this.xmlLoader = new URLLoader();
            this.xmlLoader.addEventListener(Event.COMPLETE,this.onXmlLoadComplete,false,0,true);
            this.xmlLoader.addEventListener(IOErrorEvent.IO_ERROR,this.onXmlIoError,false,0,true);
            this.xmlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onXmlSecurityError,false,0,true);
            this.xmlLoader.load(new URLRequest(DIAGNOSTIC_XML_PATH));
            if(!this.disposed && this.xmlState == "requesting" && this.xmlLoader != null)
            {
               this.setXmlStatus("PS5DBG-09 XML LOAD RETURNED");
            }
         }
         catch(param2:Error)
         {
            this.failXml("PS5DBG-ERR XML REQUEST");
         }
      }

      private function onXmlLoadComplete(param1:Event) : void
      {
         if(this.disposed || this.xmlState != "requesting" || this.xmlLoader == null)
         {
            return;
         }
         try
         {
            this.xmlText = String(this.xmlLoader.data);
         }
         catch(param2:Error)
         {
            this.failXml("PS5DBG-ERR XML VALUE");
            return;
         }
         this.releaseXmlLoader(false);
         this.xmlState = "received";
         this.xmlParseArmed = false;
         this.setXmlStatus("PS5DBG-10 XML RECEIVED");
         addEventListener(Event.ENTER_FRAME,this.deferredXmlParseCallback,false,0,true);
      }

      private function onXmlIoError(param1:IOErrorEvent) : void
      {
         this.failXml("PS5DBG-ERR XML IO");
      }

      private function onXmlSecurityError(param1:SecurityErrorEvent) : void
      {
         this.failXml("PS5DBG-ERR XML SECURITY");
      }

      private function onDeferredXmlParse(param1:Event) : void
      {
         var parsedXml:XML = null;
         var rootElements:XMLList = null;
         var diagnosticNodes:XMLList = null;
         var diagnosticValue:String = null;
         if(this.disposed || this.xmlState != "received")
         {
            if(this.deferredXmlParseCallback != null)
            {
               removeEventListener(Event.ENTER_FRAME,this.deferredXmlParseCallback);
            }
            return;
         }
         if(!this.xmlParseArmed)
         {
            this.xmlParseArmed = true;
            this.setXmlStatus("PS5DBG-11 XML PARSE NEXT FRAME");
            return;
         }
         if(this.deferredXmlParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlParseCallback);
         }
         if(this.xmlText == null || this.xmlText.length == 0 || this.xmlText.length > DIAGNOSTIC_XML_LIMIT)
         {
            this.failXml("PS5DBG-ERR XML VALUE");
            return;
         }
         try
         {
            parsedXml = new XML(this.xmlText);
         }
         catch(param2:Error)
         {
            this.failXml("PS5DBG-ERR XML PARSE");
            return;
         }
         rootElements = parsedXml.elements();
         diagnosticNodes = parsedXml.child("diagnosticText");
         if(String(parsedXml.name()) != "venworksCUI" ||
            rootElements.length() != 1 ||
            diagnosticNodes.length() != 1 ||
            String(rootElements[0].name()) != "diagnosticText" ||
            diagnosticNodes[0].elements().length() != 0)
         {
            this.failXml("PS5DBG-ERR XML VALUE");
            return;
         }
         diagnosticValue = this.sanitizeText(diagnosticNodes[0].toString(),DIAGNOSTIC_TEXT_LIMIT);
         if(diagnosticValue.length == 0)
         {
            this.failXml("PS5DBG-ERR XML VALUE");
            return;
         }
         this.xmlText = null;
         this.xmlState = "complete";
         this.setXmlStatus("PS5DBG-OK XML | " + diagnosticValue);
      }

      private function failXml(param1:String) : void
      {
         if(this.deferredXmlRequestCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlRequestCallback);
         }
         if(this.deferredXmlParseCallback != null)
         {
            removeEventListener(Event.ENTER_FRAME,this.deferredXmlParseCallback);
         }
         this.releaseXmlLoader(true);
         this.xmlText = null;
         this.xmlState = "failed";
         this.xmlParseArmed = false;
         if(!this.disposed)
         {
            this.setXmlStatus(param1);
         }
      }

      private function releaseXmlLoader(param1:Boolean) : void
      {
         if(this.xmlLoader == null)
         {
            return;
         }
         this.xmlLoader.removeEventListener(Event.COMPLETE,this.onXmlLoadComplete);
         this.xmlLoader.removeEventListener(IOErrorEvent.IO_ERROR,this.onXmlIoError);
         this.xmlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,this.onXmlSecurityError);
         if(param1)
         {
            try
            {
               this.xmlLoader.close();
            }
            catch(param2:Error)
            {
            }
         }
         this.xmlLoader = null;
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

      private function setXmlStatus(param1:String) : void
      {
         this.xmlStatus = this.sanitizeText(param1,120);
         this.renderStatus();
      }

      private function renderStatus() : void
      {
         if(this.pane == null)
         {
            return;
         }
         this.pane.text = "PLAYERDATA: " + this.playerDataStatus + "\nXML: " + this.xmlStatus;
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
