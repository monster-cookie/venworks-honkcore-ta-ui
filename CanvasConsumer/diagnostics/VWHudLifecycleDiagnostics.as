package
{
   import flash.display.MovieClip;
   import flash.text.TextField;

   // Compile separately with a variant source path. Never shipped in a theme package.
   public final class VWHudLifecycleDiagnostics extends MovieClip
   {
      public function VWHudLifecycleDiagnostics()
      {
         var output:TextField = new TextField();
         output.width = 1200; output.height = 900;
         addChild(output);
         try { output.text = run(); }
         catch(error:*) { output.text = "FAIL: " + error; throw error; }
      }

      public static function run() : String
      {
         var consumer:VWHudConsumer = new VWHudConsumer();
         var topic:String = VWHudVariant.NAMESPACE + ".status";
         var first:Object = {data:null,calls:0};
         var second:Object = {data:null,calls:0};
         try
         {
            consumer.handleCanvasEvent(topic,body("1|0|B:Hydrated;"));
            consumer.handleCanvasEvent(topic,body("1|0|B:Fed;"));
            consumer.handleCanvasEvent(topic,"malformed");
            consumer.handleLifecycle("ready",detail(first));
            require(first.calls == 1 && first.data.waiting === false && first.data.buffrows[0].label == "Fed","valid pre-ready snapshot survives malformed event");
            require(first.data.effectrows[0].label == "Fed" && first.data.effectrows[0].icon == "assets/effect-fed.svg","fed row carries its icon");
            consumer.handleCanvasEvent(topic,body("0|1|D:Burns;"));
            require(first.data.debuffrows[0].label == "Burns" && first.data.buffcount == 0,"replacement snapshot");
            require(first.data.effectrows[0].label == "Burns" && first.data.effectrows[0].icon == "assets/effect-thermal.svg","burns row carries the thermal icon");
            consumer.handleCanvasEvent(topic,body("0|2|D:Burns;"));
            require(first.data.debuffcount == 1,"invalid counts preserve last state");
            var calls:int = first.calls;
            consumer.handleCanvasEvent("venworks.example.status",body("0|0|"));
            require(first.calls == calls,"foreign namespace ignored");
            consumer.handleLifecycle("ready",detail(second));
            require(second.calls == 1 && second.data.debuffrows[0].label == "Burns","second ready retains status");
            consumer.handleCanvasEvent(topic,body("0|0|"));
            require(second.data.empty === true && first.calls == calls,"new bridge receives empty state exclusively");
            consumer.handleLifecycle("unload",null);
            consumer.handleCanvasEvent(topic,body("1|0|B:Fed;"));
            var fresh:Object = {data:null,calls:0};
            consumer.handleLifecycle("ready",detail(fresh));
            require(fresh.data.waiting === true,"unload resets status and ignores late events");
         }
         finally { consumer.dispose(); }

         var adapter:VWHudEffectsAdapter = new VWHudEffectsAdapter();
         require(adapter.acceptDatagram(body("9|0|B:One;B:Two;B:Three;B:Four;B:Five;B:Six;B:Seven;B:Eight;B:Nine;")),"paged snapshot accepted");
         require(adapter.view().buffrows.length == 8 && adapter.advancePage() && adapter.view().buffrows[0].label == "Nine","eight entries per page");
         require(!adapter.acceptDatagram(body("1|0|B:Invalid;B:Extra;")) && adapter.view().page == 2,"rejected snapshot preserves page");
         require(adapter.acceptDatagram(body("0|0|")) && adapter.view().empty === true && adapter.view().page == 1,"empty snapshot resets page");
         var icons:Object = {buffrows:[{label:"Fortify Carry Weight"},{label:"Uncatalogued Buff"}],debuffrows:[{label:"Bleeding"},{label:"Uncatalogued Debuff"}]};
         VWHudPresentation.update(icons,null,0,false);
         require(icons.effectrows[0].icon == "assets/effect-weight.svg" && icons.effectrows[0].x == 0,"carry weight uses the weight icon");
         require(icons.effectrows[1].icon == "assets/effect-fallbackbuff.svg","unknown buff uses the fallback icon");
         require(icons.effectrows[2].icon == "assets/effect-bleed.svg","bleeding uses the bleed icon");
         require(icons.effectrows[3].icon == "assets/effect-fallbackdebuff.svg","unknown debuff uses the fallback icon");
         var weather:Object = {buffrows:[],debuffrows:[{label:"FREEZING COLD AND SNOW"},{label:"Dehydrated"},{label:"Malnourished"}]};
         VWHudPresentation.update(weather,null,0,false);
         require(weather.effectrows[0].icon == "assets/effect-cold.svg" && weather.effectrows[1].icon == "assets/effect-dehydrated.svg" && weather.effectrows[2].icon == "assets/effect-malnourished.svg","weather and sustenance rows use their class icons");
         var storm:Object = {buffrows:[],debuffrows:[{label:"Sandstorm"},{label:"Cold"}]};
         VWHudPresentation.update(storm,null,0,false);
         require(storm.effectrows[0].icon == "assets/effect-sandstorm.svg" && storm.effectrows[1].icon == "assets/effect-cold.svg","sandstorm and cold use their weather icons");
         return "PASS: VWHUD consumer lifecycle and effects adapter assertions";
      }

      private static function detail(capture:Object) : Object
      {
         return {features:["htmlRendering"],html:{setData:function(data:Object):void { capture.data = data; capture.calls++; }}};
      }

      private static function body(payload:String) : String
      {
         return VWHudDatagramCodec.encode("effects.state",1,"ci-ascii",payload);
      }

      private static function require(condition:Boolean, message:String) : void
      {
         if(!condition) throw new Error(message);
      }
   }
}
