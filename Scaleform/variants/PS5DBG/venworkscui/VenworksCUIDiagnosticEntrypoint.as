package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getDefinitionByName;

   public final class VenworksCUIDiagnosticEntrypoint extends MovieClip
   {
      public static const CLASS_FINGERPRINT:String = "VENWORKS_CUI_CLASSES_SHA256:________________________________________________________________";

      private static const PLAYER_DATA_PROVIDER:String = "PlayerData";
      private static const PLAYER_NAME_LIMIT:int = 80;

      private var owner:DisplayObjectContainer = null;
      private var pane:TextField = null;
      private var dataManager:Object = null;
      private var deferredProbeCallback:Function = null;
      private var playerDataCallback:Function = null;
      private var playerDataState:String = "idle";
      private var subscriptionPending:Boolean = false;
      private var subscriptionActive:Boolean = false;
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
         this.pane.x = 760;
         this.pane.y = 160;
         this.pane.width = 400;
         this.pane.height = 72;
         this.pane.background = true;
         this.pane.backgroundColor = 2631720;
         this.pane.border = true;
         this.pane.borderColor = 65535;
         this.pane.textColor = 16777215;
         this.pane.embedFonts = true;
         this.pane.defaultTextFormat = format;
         this.pane.multiline = true;
         this.pane.wordWrap = true;
         this.pane.selectable = false;
         this.pane.mouseEnabled = false;
         this.pane.text = "venworkscui.swf loaded\nPS5DBG-05 PLAYERDATA NEXT FRAME";
         this.pane.setTextFormat(format);
         addChild(this.pane);
         this.playerDataCallback = this.onPlayerData;
         this.deferredProbeCallback = this.onDeferredProbe;
         this.playerDataState = "scheduled";
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
         this.unsubscribePlayerData();
         if(this.pane != null && this.pane.parent === this)
         {
            removeChild(this.pane);
         }
         this.pane = null;
         this.owner = null;
         this.dataManager = null;
         this.deferredProbeCallback = null;
         this.playerDataCallback = null;
         this.playerDataState = "disposed";
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
            this.setStatus("PS5DBG-06 PLAYERDATA REQUEST");
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
               this.setStatus("PS5DBG-07 PLAYERDATA WAITING");
            }
         }
         catch(param2:Error)
         {
            failure = param2;
            this.unsubscribePlayerData();
            if(!this.disposed)
            {
               this.playerDataState = "failed";
               this.setStatus("PS5DBG-ERR PLAYERDATA | " + this.sanitizeText(failure,PLAYER_NAME_LIMIT));
            }
         }
      }

      private function onPlayerData(param1:Object) : void
      {
         var playerName:String = null;
         if(this.disposed || this.playerDataState == "failed")
         {
            return;
         }
         try
         {
            if(param1 == null || param1.data == null || param1.data.sName === undefined || param1.data.sName === null)
            {
               playerName = "<missing sName>";
            }
            else
            {
               playerName = this.sanitizeText(param1.data.sName,PLAYER_NAME_LIMIT);
               if(playerName.length == 0)
               {
                  playerName = "<empty sName>";
               }
            }
            this.playerDataState = "received";
            this.setStatus("PS5DBG-OK PLAYERDATA | " + playerName);
         }
         catch(param2:Error)
         {
            this.unsubscribePlayerData();
            if(!this.disposed)
            {
               this.playerDataState = "failed";
               this.setStatus("PS5DBG-ERR PLAYERDATA | " + this.sanitizeText(param2,PLAYER_NAME_LIMIT));
            }
         }
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

      private function setStatus(param1:String) : void
      {
         if(this.pane == null)
         {
            return;
         }
         this.pane.text = this.sanitizeText(param1,160);
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
