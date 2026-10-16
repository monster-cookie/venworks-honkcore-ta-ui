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
            consumer.handleCanvasEvent(topic,body("0|1|D:Thermal;"));
            require(first.data.debuffrows[0].label == "Thermal" && first.data.buffcount == 0,"replacement snapshot");
            require(first.data.effectrows[0].label == "Thermal" && first.data.effectrows[0].icon == "assets/effect-thermal.svg","thermal row carries the thermal icon");
            consumer.handleCanvasEvent(topic,body("0|2|D:Thermal;"));
            require(first.data.debuffcount == 1,"invalid counts preserve last state");
            var calls:int = first.calls;
            consumer.handleCanvasEvent("venworks.example.status",body("0|0|"));
            require(first.calls == calls,"foreign namespace ignored");
            consumer.handleLifecycle("ready",detail(second));
            require(second.calls == 1 && second.data.debuffrows[0].label == "Thermal","second ready retains status");
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
         var buffPayload:String = "19|0|";
         for(var buffIndex:int = 1; buffIndex <= 19; buffIndex++) buffPayload += "B:B" + buffIndex + ";";
         require(adapter.acceptDatagram(body(buffPayload)),"paged snapshot accepted");
         require(adapter.view().buffrows.length == 18 && adapter.advancePage() && adapter.view().buffrows.length == 1 && adapter.view().buffrows[0].label == "B19","buffs page one line at a time");
         require(!adapter.acceptDatagram(body("1|0|B:Invalid;B:Extra;")) && adapter.view().buffrows.length == 1 && adapter.view().buffrows[0].label == "B19","rejected snapshot keeps the second buff page");
         require(adapter.acceptDatagram(body("0|0|")) && adapter.view().empty === true && adapter.view().buffrows.length == 0,"empty snapshot clears the paged rows");
         require(adapter.acceptDatagram(body(buffPayload)) && adapter.view().buffrows.length == 18 && adapter.view().buffrows[0].label == "B1","empty snapshot returns to the first buff page");
         var debuffAdapter:VWHudEffectsAdapter = new VWHudEffectsAdapter();
         var debuffPayload:String = "0|37|";
         for(var debuffIndex:int = 1; debuffIndex <= 37; debuffIndex++) debuffPayload += "D:D" + debuffIndex + ";";
         require(debuffAdapter.acceptDatagram(body(debuffPayload)) && debuffAdapter.view().debuffrows.length == 36,"two debuff lines show thirty-six");
         require(debuffAdapter.advancePage() && debuffAdapter.view().debuffrows.length == 1 && debuffAdapter.view().debuffrows[0].label == "D37" && debuffAdapter.view().buffrows.length == 0,"debuffs page after two lines");
         var icons:Object = {buffrows:[{label:"Fortify Carry Weight"},{label:"Uncatalogued Buff"}],debuffrows:[{label:"Bleeding"},{label:"Uncatalogued Debuff"}]};
         VWHudPresentation.update(icons,null,0,false);
         require(icons.effectrows[0].icon == "assets/effect-weight.svg" && icons.effectrows[0].x == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,2,false,0).x : 0) && icons.effectrows[0].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,2,false,0).y : 0),"carry weight uses the weight icon on the buff line");
         require(icons.effectrows[1].icon == "assets/effect-fallbackbuff.svg" && icons.effectrows[1].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(1,2,false,0).y : 0),"unknown buff stays on the buff line");
         require(icons.effectrows[2].icon == "assets/effect-bleed.svg" && icons.effectrows[2].x == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,2,true,0).x : 0) && icons.effectrows[2].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,2,true,0).y : VWHudPresentation.ROW_STRIDE),"bleeding starts the first debuff line");
         require(icons.effectrows[3].icon == "assets/effect-fallbackdebuff.svg" && icons.effectrows[3].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(1,2,true,0).y : VWHudPresentation.ROW_STRIDE),"unknown debuff stays on the debuff line");
         if(VWHudVariant.VISOR)
         {
            require(icons.effectrows[0].x > icons.effectrows[1].x,"buffs run outward on the left arc");
            require(icons.effectrows[2].x < icons.effectrows[3].x,"debuffs run outward on the right arc");
            require(icons.effectrows[0].x + 18 == VWHudPresentation.VISOR_ARC_CENTER - VWHudPresentation.VISOR_ARC_GAP,"buffs start the arc gap left of center");
            require(icons.effectrows[2].x + 18 == VWHudPresentation.VISOR_ARC_CENTER + VWHudPresentation.VISOR_ARC_GAP,"debuffs start the arc gap right of center");
            require(icons.effectrows[0].x + 36 < VWHudPresentation.VISOR_ARC_CENTER - 80 && icons.effectrows[2].x > VWHudPresentation.VISOR_ARC_CENTER + 80,"the two arcs leave the center open");
         }
         var wrapped:Object = {buffrows:[{label:"Fed"}],debuffrows:[]};
         for(var wrapIndex:int = 0; wrapIndex < 19; wrapIndex++) wrapped.debuffrows.push({label:"Injury"});
         VWHudPresentation.update(wrapped,null,0,false);
         require(wrapped.effectrows[0].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,1,false,0).y : 0) && wrapped.effectrows[1].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,18,true,0).y : VWHudPresentation.ROW_STRIDE) && wrapped.effectrows[1].x == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,18,true,0).x : 0),"a buff keeps the top line when debuffs are present");
         require(wrapped.effectrows[19].x == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(8,VWHudPresentation.VISOR_ARC_COLUMNS,true,1).x : 0) && wrapped.effectrows[19].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(8,VWHudPresentation.VISOR_ARC_COLUMNS,true,1).y : VWHudPresentation.ROW_STRIDE * 2),"the nineteenth debuff starts the second debuff line");
         if(VWHudVariant.VISOR) require(wrapped.effectrows[0].x < wrapped.effectrows[1].x && wrapped.effectrows[19].y > wrapped.effectrows[1].y,"the second debuff line stays on the right of the center arc");
         var weather:Object = {buffrows:[],debuffrows:[{label:"FREEZING COLD AND SNOW"},{label:"Dehydrated"},{label:"Malnourished"}]};
         VWHudPresentation.update(weather,null,0,false);
         require(weather.effectrows[0].icon == "assets/effect-cold.svg" && weather.effectrows[0].y == (VWHudVariant.VISOR ? VWHudPresentation.visorArcPoint(0,3,true,0).y : VWHudPresentation.ROW_STRIDE) && weather.effectrows[1].icon == "assets/effect-dehydrated.svg" && weather.effectrows[2].icon == "assets/effect-malnourished.svg","weather and sustenance rows use their class icons on the debuff line");
         var storm:Object = {buffrows:[],debuffrows:[{label:"Sandstorm"},{label:"Cold"}]};
         VWHudPresentation.update(storm,null,0,false);
         require(storm.effectrows[0].icon == "assets/effect-sandstorm.svg" && storm.effectrows[1].icon == "assets/effect-cold.svg","sandstorm and cold use their weather icons");
         var classes:Object = {buffrows:[],debuffrows:[{label:"Radiation"},{label:"Infection"},{label:"Injury"},{label:"Corrosive"},{label:"Gas"}]};
         VWHudPresentation.update(classes,null,0,false);
         require(classes.effectrows[0].icon == "assets/effect-radiation.svg" && classes.effectrows[1].icon == "assets/effect-infection.svg" && classes.effectrows[2].icon == "assets/effect-injury.svg","affliction classes use their icons");
         require(classes.effectrows[3].icon == "assets/effect-corrosive.svg" && classes.effectrows[4].icon == "assets/effect-gas.svg","corrosive and gas use their class icons");
         var namedQuest:Object = {aMissionMarkers:[{strText:"ONE SMALL STEP\nGO TO THE LODGE",bShouldShowText:true}]};
         require(VWHudViewModel.resolveTrackedQuestName(namedQuest) == "ONE SMALL STEP" && VWHudViewModel.resolveTrackedObjective(namedQuest) == "GO TO THE LODGE","a two-line marker keeps the quest name above the waypoint");
         var titledQuest:Object = {sQuestName:"ONE SMALL STEP",aMissionMarkers:[{strText:"GO TO THE LODGE",bShouldShowText:true}]};
         require(VWHudViewModel.resolveTrackedQuestName(titledQuest) == "ONE SMALL STEP" && VWHudViewModel.resolveTrackedObjective(titledQuest) == "GO TO THE LODGE","a quest name field stays with the waypoint");
         var waypointOnly:Object = {aMissionMarkers:[{strText:"GO TO THE LODGE",bShouldShowText:true}]};
         require(VWHudViewModel.resolveTrackedQuestName(waypointOnly) == "" && VWHudViewModel.resolveTrackedObjective(waypointOnly) == "GO TO THE LODGE","a waypoint alone does not invent a quest name");
         var trackedQuest:Object = VWHudViewModel.nextQuestTitle("",null,{QuestUpdatesA:[{uType:1,uQuestID:42,strQuestName:"ONE SMALL STEP"}]});
         require(trackedQuest.name == "ONE SMALL STEP" && trackedQuest.id == 42,"the active quest update supplies the quest title");
         var renamedQuest:Object = VWHudViewModel.nextQuestTitle(trackedQuest.name,trackedQuest.id,{QuestUpdatesA:[{uType:8,uQuestID:42,strQuestName:"THE OLD NEIGHBORHOOD",bActiveQuest:true}]});
         require(renamedQuest.name == "THE OLD NEIGHBORHOOD","a later update for the tracked quest replaces the title");
         var otherQuest:Object = VWHudViewModel.nextQuestTitle(renamedQuest.name,renamedQuest.id,{QuestUpdatesA:[{uType:2,uQuestID:99}]});
         require(otherQuest.name == "THE OLD NEIGHBORHOOD","clearing a different quest leaves the tracked title");
         var clearedQuest:Object = VWHudViewModel.nextQuestTitle(otherQuest.name,otherQuest.id,{QuestUpdatesA:[{uType:2,uQuestID:42}]});
         require(clearedQuest.name == "" && clearedQuest.id == null,"clearing the tracked quest removes the title");
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
