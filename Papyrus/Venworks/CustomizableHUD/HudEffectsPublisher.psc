ScriptName Venworks:CustomizableHUD:HudEffectsPublisher Extends Venworks:Canvas:Base:BaseQuest
Import Venworks:Canvas:Registry

; VWHUD-owned implementation of Canvas Example's complete effects.state snapshots.
; Canvas Example is not a runtime or plugin dependency.
Venworks:Canvas:Registry Property Registry Auto Const Mandatory
String Property StatusTopic Auto Const Mandatory
FormList Property BuffEffects Auto Const Mandatory
FormList Property DebuffEffects Auto Const Mandatory
String[] Property BuffLabels Auto Const Mandatory
String[] Property DebuffLabels Auto Const Mandatory

String ModuleName = "CustomizableHUD:HudEffectsPublisher"
Guard EffectSnapshotGuard ProtectsFunctionLogic

; Retained as an inert saved-script field from the former location refresh path.
Bool LocationRefreshPending = False
Bool LocationEventRegistered = False
Bool PlayerLoadEventRegistered = False
Bool MagicEffectEventRegistered = False
Bool EffectRefreshPending = False
Bool EffectForceRefresh = False
Bool EffectChangedDuringPublication = False
Bool EffectSnapshotBuilding = False
Int EffectSourceRevision = 0
; Retained as inert saved-script fields from the multipart effect protocol.
Int EffectSnapshotSequence = 0
Int EffectPacketIndex = 0
Int EffectRetryCount = 0
Int LastActiveEffectCount = 0
Float LastEffectSnapshotAt = 0.0
Float LastHudOpenAt = 0.0
String LastEffectSignature = ""
String PendingEffectSignature = ""
String[] EffectPackets
String PendingEffectPayload = ""
Bool PendingEffectNeedsRecoveryReplay = False
Bool EffectRecoveryRefresh = False
String[] ObservedEffectEntries
MagicEffect[] ActiveSourceEffects
String[] ActiveSourceEffectEntries
ENV_AfflictionScript[] ActiveSourceAfflictions
String[] ActiveSourceAfflictionEntries
Spell[] ActiveSourceSpells
String[] ActiveSourceSpellEntries
String[] PendingEffectRemovals

; Bootstrap menu and player notifications and schedule the first bounded effect scan.
Event OnInit()
  LogUserInformational(ModuleName, "OnInit", "EVENT_TRIGGERED | Registering HUD menus and effect events.")
  RegisterForMenuOpenCloseEvent("HUDMenu")
  RegisterForMenuOpenCloseEvent("SpaceshipHudMenu")
  EnsurePlayerEventRegistrations()
  EnsureMagicEffectRegistrations(True)
  RequestEffectRefresh(True)
EndEvent

; HUD opening schedules a bounded sequence; there is no saved active latch or wait in this event.
Event OnMenuOpenCloseEvent(String menuName, Bool opening)
  LogUserInformational(ModuleName, "OnMenuOpenCloseEvent", "EVENT_TRIGGERED | Menu=" + menuName + " | Opening=" + opening)
  If (opening)
    LastHudOpenAt = Utility.GetCurrentRealTime()
    EnsurePlayerEventRegistrations()
    EnsureMagicEffectRegistrations(True)
      RequestEffectRefresh(True)
    ScheduleActiveEffectCheck()
  EndIf
EndEvent

; Saved registrations from pre-effect Example versions can still dispatch this event; location is no longer published.
Event Actor.OnLocationChange(Actor akSender, Location akOldLoc, Location akNewLoc)
EndEvent

; A saved game can load with effects already active; HUD opening provides a second path when this event is skipped.
Event Actor.OnPlayerLoadGame(Actor akSender)
  LogUserInformational(ModuleName, "Actor.OnPlayerLoadGame", "EVENT_TRIGGERED | Sender=" + akSender)
  EffectSourceRevision += 1
  EffectPackets = None
  EffectPacketIndex = 0
  PendingEffectPayload = ""
  PendingEffectNeedsRecoveryReplay = False
  EffectRecoveryRefresh = False
  EffectSnapshotBuilding = False
  EffectChangedDuringPublication = False
  ObservedEffectEntries = None
  ActiveSourceEffects = None
  ActiveSourceEffectEntries = None
  ActiveSourceAfflictions = None
  ActiveSourceAfflictionEntries = None
  ActiveSourceSpells = None
  ActiveSourceSpellEntries = None
  PendingEffectRemovals = None
  CancelTimer(31)
  CancelTimer(34)
  CancelTimer(35)
  EffectRefreshPending = False
  MagicEffectEventRegistered = False
  EnsureMagicEffectRegistrations(True)
  RequestEffectRefresh(True)
  ScheduleActiveEffectCheck()
EndEvent

; Saved quests enter this path through their existing menu registration after a script update.
Function EnsurePlayerEventRegistrations()
  Actor player = Game.GetPlayer()
  If (player == None)
    LogUserWarning(ModuleName, "EnsurePlayerEventRegistrations", "PLAYER_EVENT_REGISTRATION_DEFERRED | Player=None | Event=OnPlayerLoadGame")
    Return
  EndIf
  If (LocationEventRegistered)
    UnregisterForRemoteEvent(player, "OnLocationChange")
    LocationEventRegistered = False
    LogUserInformational(ModuleName, "EnsurePlayerEventRegistrations", "REMOTE_EVENT_UNREGISTERED | Event=OnLocationChange | Player=" + player)
  EndIf
  If (!PlayerLoadEventRegistered)
    Bool playerLoadRegistrationAccepted = RegisterForRemoteEvent(player, "OnPlayerLoadGame")
    PlayerLoadEventRegistered = playerLoadRegistrationAccepted
    If (playerLoadRegistrationAccepted)
      LogUserInformational(ModuleName, "EnsurePlayerEventRegistrations", "REMOTE_EVENT_REGISTRATION_RESULT | Event=OnPlayerLoadGame | Accepted=true | Player=" + player)
    Else
      LogUserWarning(ModuleName, "EnsurePlayerEventRegistrations", "REMOTE_EVENT_REGISTRATION_RESULT | Event=OnPlayerLoadGame | Accepted=false | Player=" + player)
    EndIf
  Else
    LogUserInformational(ModuleName, "EnsurePlayerEventRegistrations", "REMOTE_EVENT_ALREADY_FLAGGED | Event=OnPlayerLoadGame | Player=" + player)
  EndIf
EndFunction

; Registration, effect refresh, reconciliation, and packet publication use disjoint timer IDs.
Event OnTimer(Int aiTimerID)
  If (aiTimerID == 31 && EffectRefreshPending)
    EffectRefreshPending = False
    PrepareEffectSnapshot()
  ElseIf (aiTimerID == 32)
    CheckActiveEffectSources()
    ScheduleActiveEffectCheck()
  ElseIf (aiTimerID == 33)
    PublishNextEffectPacket()
  ElseIf (aiTimerID == 34)
    RequestEffectRefresh(True)
  ElseIf (aiTimerID == 35)
    EffectRecoveryRefresh = True
    RequestEffectRefresh(True)
  EndIf
EndEvent

; Re-register after each one-shot apply notification, then scan after the effect can become active.
Event OnMagicEffectApply(ObjectReference akTarget, ObjectReference akCaster, MagicEffect akEffect)
  Bool reportApply = akTarget == Game.GetPlayer() && !EffectRefreshPending
  If (reportApply)
    LogUserInformational(ModuleName, "OnMagicEffectApply", "EVENT_TRIGGERED | Target=" + akTarget + " | Effect=" + akEffect)
  EndIf
  MagicEffectEventRegistered = False
  EnsureMagicEffectRegistrations(reportApply)
  If (akTarget == Game.GetPlayer())
    RequestEffectRefresh(False)
  EndIf
EndEvent

; This one-shot registration is unfiltered so newly applied, cataloged effects cannot be missed.
Function EnsureMagicEffectRegistrations(Bool reportRegistration)
  If (MagicEffectEventRegistered)
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None)
    LogUserWarning(ModuleName, "EnsureMagicEffectRegistrations", "EFFECT_EVENT_REGISTRATION_DEFERRED | Player unavailable.")
    Return
  EndIf
  UnregisterForAllMagicEffectApplyEvents(player)
  RegisterForMagicEffectApplyEvent(player)
  MagicEffectEventRegistered = True
  If (reportRegistration)
    LogUserInformational(ModuleName, "EnsureMagicEffectRegistrations", "EFFECT_EVENT_REGISTRATION | Target=Player | Filter=None")
  EndIf
EndFunction

; Coalesces load, HUD-ready, and apply requests while preserving a requested full resend.
Function RequestEffectRefresh(Bool forceSnapshot)
  If (forceSnapshot)
    EffectForceRefresh = True
  EndIf
  If (EffectRefreshPending)
    Return
  EndIf
  EffectRefreshPending = True
  StartTimer(0.5, 31)
EndFunction

; No removal deadline is available from the quest's base-effect event. Check only known-active sources.
Function ScheduleActiveEffectCheck()
  CancelTimer(32)
  If (ObservedEffectEntries != None && ObservedEffectEntries.Length > 0)
    StartTimer(1.0, 32)
  EndIf
EndFunction

; An expiry or cure has no quest-level finish event. Never send a removal from a guessed timer alone.
Function CheckActiveEffectSources()
  Int sourceRevision = EffectSourceRevision
  String[] observedEntries = ObservedEffectEntries
  If (observedEntries == None || observedEntries.Length == 0 || EffectSnapshotBuilding)
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None)
    Return
  EndIf
  String[] stillActive = new String[0]
  Int index = 0
  While (ActiveSourceEffects != None && index < ActiveSourceEffects.Length)
    If (ActiveSourceEffects[index] != None && player.HasMagicEffect(ActiveSourceEffects[index]) && !ContainsEffectEntry(stillActive, ActiveSourceEffectEntries[index]))
      stillActive.Add(ActiveSourceEffectEntries[index])
    EndIf
    index += 1
  EndWhile
  index = 0
  While (ActiveSourceAfflictions != None && index < ActiveSourceAfflictions.Length)
    If (HasAfflictionSpell(player, ActiveSourceAfflictions[index]) && !ContainsEffectEntry(stillActive, ActiveSourceAfflictionEntries[index]))
      stillActive.Add(ActiveSourceAfflictionEntries[index])
    EndIf
    index += 1
  EndWhile
  index = 0
  While (ActiveSourceSpells != None && index < ActiveSourceSpells.Length)
    Bool namedStatusActive = ActiveSourceSpells[index] != None && player.HasSpell(ActiveSourceSpells[index])
    If (namedStatusActive && ActiveSourceSpells[index] == Game.GetFormFromFile(0x08CB51, "Starfield.esm"))
      MagicEffect corrosiveSoak = Game.GetFormFromFile(0x08CB47, "Starfield.esm") as MagicEffect
      namedStatusActive = corrosiveSoak != None && player.HasMagicEffect(corrosiveSoak)
    EndIf
    If (namedStatusActive && !ContainsEffectEntry(stillActive, ActiveSourceSpellEntries[index]))
      stillActive.Add(ActiveSourceSpellEntries[index])
    EndIf
    index += 1
  EndWhile
  String[] remaining = new String[0]
  String[] removedEntries = new String[0]
  index = 0
  While (index < observedEntries.Length)
    String entry = observedEntries[index]
    If (ContainsEffectEntry(stillActive, entry))
      remaining.Add(entry)
    Else
      removedEntries.Add(entry)
    EndIf
    index += 1
  EndWhile
  Bool removed = False
  TryLockGuard EffectSnapshotGuard
    If (!EffectSnapshotBuilding && EffectSourceRevision == sourceRevision && removedEntries.Length > 0)
      ObservedEffectEntries = remaining
      EffectSourceRevision += 1
      removed = True
    EndIf
  EndTryLockGuard
  If (removed)
    RequestEffectRefresh(False)
    LogUserInformational(ModuleName, "CheckActiveEffectSources", "EFFECT_REMOVAL_DETECTED | Remaining=" + remaining.Length)
  EndIf
EndFunction

; Builds one complete state payload; every submitted datagram is independently valid.
Function PrepareEffectSnapshot()
  If (Registry == None || BuffEffects == None || DebuffEffects == None)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_SNAPSHOT_DEFERRED | Registry or catalog unavailable.")
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_SNAPSHOT_DEFERRED | Player unavailable.")
    Return
  EndIf
  Bool snapshotClaimed = False
  Bool snapshotGuardAcquired = False
  TryLockGuard EffectSnapshotGuard
    snapshotGuardAcquired = True
    If (EffectSnapshotBuilding || PendingEffectPayload != "")
      EffectChangedDuringPublication = True
    Else
      EffectSnapshotBuilding = True
      EffectSourceRevision += 1
      snapshotClaimed = True
    EndIf
  EndTryLockGuard
  If (!snapshotClaimed)
    If (!snapshotGuardAcquired)
      RequestEffectRefresh(False)
    EndIf
    Return
  EndIf
  Bool recoveryRefresh = EffectRecoveryRefresh
  EffectRecoveryRefresh = False
  String[] previousEntries = ObservedEffectEntries
  ActiveSourceEffects = new MagicEffect[0]
  ActiveSourceEffectEntries = new String[0]
  ActiveSourceAfflictions = new ENV_AfflictionScript[0]
  ActiveSourceAfflictionEntries = new String[0]
  ActiveSourceSpells = new Spell[0]
  ActiveSourceSpellEntries = new String[0]
  String[] entries = new String[0]
  entries = AppendActiveEffects(entries, player, BuffEffects, BuffLabels, "B")
  Int buffCount = entries.Length
  entries = AppendActiveEffects(entries, player, DebuffEffects, DebuffLabels, "D")
  entries = AppendActiveAfflictions(entries, player)
  entries = AppendActiveEnvironmentalStatuses(entries, player)
  Int debuffCount = entries.Length - buffCount
  LastActiveEffectCount = entries.Length
  If (previousEntries != None)
    Int previousIndex = 0
    While (previousIndex < previousEntries.Length)
      If (!ContainsEffectEntry(entries, previousEntries[previousIndex]))
        EffectForceRefresh = True
      EndIf
      previousIndex += 1
    EndWhile
  EndIf
  ObservedEffectEntries = entries
  ScheduleActiveEffectCheck()
  String signature = ""
  Int index = 0
  While (index < entries.Length)
    signature += entries[index] + ";"
    index += 1
  EndWhile
  Bool entriesChanged = signature != LastEffectSignature
  Float now = Utility.GetCurrentRealTime()
  If (!EffectForceRefresh && !entriesChanged && now >= LastEffectSnapshotAt && now - LastEffectSnapshotAt < 60.0)
    EffectSnapshotBuilding = False
    If (EffectChangedDuringPublication)
      EffectChangedDuringPublication = False
      RequestEffectRefresh(False)
    EndIf
    Return
  EndIf
  Bool forcedRefresh = EffectForceRefresh
  EffectForceRefresh = False
  String payload = buffCount + "|" + debuffCount + "|" + signature
  String datagram = Registry.BuildCanvasDatagramBody("effects.state", 1, "ci-ascii", payload)
  String framedPacket = Registry.BuildCanvasEventPacket(ResolveStatusTopic(), datagram)
  Int framedLength = Registry.GetCharacterCount(framedPacket)
  If (datagram == "" || framedLength > 4096)
    EffectSnapshotBuilding = False
    EffectForceRefresh = True
    PendingEffectNeedsRecoveryReplay = False
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_DATAGRAM_REJECTED | Buffs=" + buffCount + " | Debuffs=" + debuffCount + " | Length=" + framedLength + " | Limit=4096")
    Return
  EndIf
  If (PendingEffectPayload != "")
    EffectChangedDuringPublication = True
    EffectSnapshotBuilding = False
    Return
  EndIf
  ; Publish the payload last, after every field used by the send timer is ready.
  PendingEffectSignature = signature
  EffectRetryCount = 0
  PendingEffectNeedsRecoveryReplay = !recoveryRefresh && (forcedRefresh || entriesChanged)
  PendingEffectPayload = payload
  EffectSnapshotBuilding = False
  LogUserInformational(ModuleName, "PrepareEffectSnapshot", "EFFECT_DATAGRAM_QUEUED | Type=effects.state | Schema=1 | Buffs=" + buffCount + " | Debuffs=" + debuffCount + " | Length=" + framedLength)
  StartTimer(0.1, 33)
EndFunction

; SQ_ENV owns injuries and infections separately from the magic-effect catalog. Its spells
; are the status-menu source of truth even when a console-applied spell did not set Active.
String[] Function AppendActiveAfflictions(String[] entries, Actor player)
  SQ_ENV_AfflictionsScript afflictionQuest = Game.GetFormFromFile(0x00248D20, "Starfield.esm") as SQ_ENV_AfflictionsScript
  If (afflictionQuest == None || afflictionQuest.AfflictionData == None)
    Return entries
  EndIf
  ENV_AfflictionScript[] afflictions = afflictionQuest.AfflictionData
  Int index = 0
  While (index < afflictions.Length)
    ENV_AfflictionScript affliction = afflictions[index]
    If (HasAfflictionSpell(player, affliction))
      String label = ResolveAfflictionLabel(affliction.ID)
      String entry = "D:#" + affliction.GetFormID() + ":" + label
      entries.Add(entry)
      ActiveSourceAfflictions.Add(affliction)
      ActiveSourceAfflictionEntries.Add(entry)
    EndIf
    index += 1
  EndWhile
  Return entries
EndFunction

Bool Function HasAfflictionSpell(Actor player, ENV_AfflictionScript affliction)
  If (player == None || affliction == None || affliction.AfflictionSpellList == None)
    Return False
  EndIf
  FormList spellList = affliction.AfflictionSpellList
  Int index = 0
  While (index < spellList.GetSize())
    Spell rankSpell = spellList.GetAt(index) as Spell
    If (rankSpell != None && player.HasSpell(rankSpell))
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

; Only named source spells are used; shared airborne-hazard effects cannot identify toxic gas.
String[] Function AppendActiveEnvironmentalStatuses(String[] entries, Actor player)
  Spell corrosiveEnvironment = Game.GetFormFromFile(0x08CB51, "Starfield.esm") as Spell
  MagicEffect corrosiveSoak = Game.GetFormFromFile(0x08CB47, "Starfield.esm") as MagicEffect
  Spell corrosiveRain = Game.GetFormFromFile(0x281ECB, "Starfield.esm") as Spell
  Spell toxicGas = Game.GetFormFromFile(0x245B6B, "Starfield.esm") as Spell
  If (corrosiveEnvironment != None && corrosiveSoak != None && player.HasSpell(corrosiveEnvironment) && player.HasMagicEffect(corrosiveSoak))
    String entry = "D:#" + corrosiveEnvironment.GetFormID() + ":Corrosive Environment"
    entries.Add(entry)
    ActiveSourceSpells.Add(corrosiveEnvironment)
    ActiveSourceSpellEntries.Add(entry)
  EndIf
  If (corrosiveRain != None && player.HasSpell(corrosiveRain))
    String entry = "D:#" + corrosiveRain.GetFormID() + ":Corrosive Rain"
    entries.Add(entry)
    ActiveSourceSpells.Add(corrosiveRain)
    ActiveSourceSpellEntries.Add(entry)
  EndIf
  If (toxicGas != None && player.HasSpell(toxicGas))
    String entry = "D:#" + toxicGas.GetFormID() + ":Toxic Gas Hazard"
    entries.Add(entry)
    ActiveSourceSpells.Add(toxicGas)
    ActiveSourceSpellEntries.Add(entry)
  EndIf
  Return entries
EndFunction

; The activator has no Papyrus display-name getter, so keep vanilla IDs and labels paired here.
String Function ResolveAfflictionLabel(String afflictionId)
  If (afflictionId == "BoneInfection")
    Return "Bone Infection"
  ElseIf (afflictionId == "BrainInfection")
    Return "Brain Infection"
  ElseIf (afflictionId == "IntestinalInfection")
    Return "Intestinal Infection"
  ElseIf (afflictionId == "LungInfection")
    Return "Lung Infection"
  ElseIf (afflictionId == "TissueInfection")
    Return "Tissue Infection"
  ElseIf (afflictionId == "BrainInjury")
    Return "Brain Injury"
  ElseIf (afflictionId == "Burns")
    Return "Burns"
  ElseIf (afflictionId == "Concussion")
    Return "Concussion"
  ElseIf (afflictionId == "Contusions")
    Return "Contusions"
  ElseIf (afflictionId == "DislocatedLimb")
    Return "Dislocated Limb"
  ElseIf (afflictionId == "FracturedLimb")
    Return "Fractured Limb"
  ElseIf (afflictionId == "FracturedSkull")
    Return "Fractured Skull"
  ElseIf (afflictionId == "Frostbite")
    Return "Frostbite"
  ElseIf (afflictionId == "Heatstroke")
    Return "Heatstroke"
  ElseIf (afflictionId == "Hernia")
    Return "Hernia"
  ElseIf (afflictionId == "Hypothermia")
    Return "Hypothermia"
  ElseIf (afflictionId == "Lacerations")
    Return "Lacerations"
  ElseIf (afflictionId == "LungDamage")
    Return "Lung Damage"
  ElseIf (afflictionId == "Poisoning")
    Return "Poisoning"
  ElseIf (afflictionId == "PunctureWounds")
    Return "Puncture Wounds"
  ElseIf (afflictionId == "RadiationPoisoning")
    Return "Radiation Poisoning"
  ElseIf (afflictionId == "Sprain")
    Return "Sprain"
  ElseIf (afflictionId == "TornMuscle")
    Return "Torn Muscle"
  EndIf
  Return afflictionId
EndFunction

; Only cataloged statuses are published. Multiple active sustenance modifiers describe one player-facing condition.
String[] Function AppendActiveEffects(String[] entries, Actor player, FormList catalog, String[] labels, String category)
  Int index = 0
  Int catalogSize = catalog.GetSize()
  While (index < catalogSize)
    MagicEffect effect = catalog.GetAt(index) as MagicEffect
    If (effect != None && player.HasMagicEffect(effect))
      String label = ""
      Bool grouped = False
      If (IsSustenanceFoodEffect(effect))
        label = "Malnourished"
        grouped = True
      ElseIf (IsSustenanceDrinkEffect(effect))
        label = "Dehydrated"
        grouped = True
      ElseIf (IsSustenanceHydratedEffect(effect))
        label = "Hydrated"
        grouped = True
      ElseIf (IsSustenanceFedEffect(effect))
        label = "Fed"
        grouped = True
      ElseIf (labels != None && labels.Length == catalogSize && index < labels.Length && labels[index] != "")
        label = labels[index]
      Else
        ; Existing saves can retain the old broad VMAD label arrays after the FormLists are updated.
        label = ResolveKnownBuffLabel(effect)
      EndIf
      If (label == "")
        label = "EFFECT " + effect.GetFormID()
      EndIf
      String entry = category + ":#" + effect.GetFormID() + ":" + label
      If (grouped)
        entry = category + ":" + label
      EndIf
      ; Starfield can retain a negative sustenance modifier while its positive
      ; player-facing state is active. Buffs are assembled first, so keep one
      ; visible state per food or drink family.
      Bool suppressed = IsSuppressedSustenanceEntry(entries, entry)
      If ((!grouped || !ContainsEffectEntry(entries, entry)) && !suppressed)
        entries.Add(entry)
      EndIf
      ActiveSourceEffects.Add(effect)
      ActiveSourceEffectEntries.Add(entry)
    EndIf
    index += 1
  EndWhile
  Return entries
EndFunction

String Function ResolveKnownBuffLabel(MagicEffect effect)
  If (effect == Game.GetFormFromFile(0x05C527, "Starfield.esm"))
    Return "Well Rested"
  ElseIf (effect == Game.GetFormFromFile(0x0738B0, "Starfield.esm"))
    Return "Companion Affinity Increases Faster"
  ElseIf (effect == Game.GetFormFromFile(0x0738B1, "Starfield.esm"))
    Return "Improved Research Crit Chance"
  ElseIf (effect == Game.GetFormFromFile(0x0738B3, "Starfield.esm"))
    Return "Reduced Research Cost"
  ElseIf (effect == Game.GetFormFromFile(0x2D88C4, "Starfield.esm"))
    Return "Fortify Persuasion"
  ElseIf (effect == Game.GetFormFromFile(0x0B92EB, "Starfield.esm"))
    Return "Heart+"
  ElseIf (effect == Game.GetFormFromFile(0x268D36, "Starfield.esm"))
    Return "Addiction Suppression"
  ElseIf (effect == Game.GetFormFromFile(0x29A857, "Starfield.esm"))
    Return "Fortify Jump Height"
  ElseIf (effect == Game.GetFormFromFile(0x237E51, "Starfield.esm"))
    Return "Fortify Movement Speed"
  ElseIf (effect == Game.GetFormFromFile(0x046959, "Starfield.esm"))
    Return "Fortify Carry Weight"
  ElseIf (effect == Game.GetFormFromFile(0x1253D5, "Starfield.esm") || effect == Game.GetFormFromFile(0x16AF61, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D3990, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D3991, "Starfield.esm"))
    Return "Fortify Damage"
  ElseIf (effect == Game.GetFormFromFile(0x2466F6, "Starfield.esm"))
    Return "Fortify Physical Damage Resistance"
  ElseIf (effect == Game.GetFormFromFile(0x04696E, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D398E, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D398F, "Starfield.esm"))
    Return "Fortify Melee Damage"
  ElseIf (effect == Game.GetFormFromFile(0x29A853, "Starfield.esm"))
    Return "Fortify O2"
  ElseIf (effect == Game.GetFormFromFile(0x16AF67, "Starfield.esm"))
    Return "Fortify O2 Recovery Rate"
  ElseIf (effect == Game.GetFormFromFile(0x2AD405, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D398D, "Starfield.esm"))
    Return "Fortify Ranged Damage"
  ElseIf (effect == Game.GetFormFromFile(0x2197C4, "Starfield.esm"))
    Return "Fortify Energy Damage Resistance"
  ElseIf (effect == Game.GetFormFromFile(0x122EB7, "Starfield.esm"))
    Return "Fortify Power Recovery Rate"
  ElseIf (effect == Game.GetFormFromFile(0x2AD404, "Starfield.esm"))
    Return "Reduce Movement Noise"
  ElseIf (effect == Game.GetFormFromFile(0x1FE6B9, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D3992, "Starfield.esm") || effect == Game.GetFormFromFile(0x2D3993, "Starfield.esm"))
    Return "Increased Weapon Accuracy"
  ElseIf (effect == Game.GetFormFromFile(0x21DDB8, "Starfield.esm"))
    Return "Restore Health"
  ElseIf (effect == Game.GetFormFromFile(0x2A34F1, "Starfield.esm"))
    Return "Slow Time"
  EndIf
  Return ""
EndFunction

Bool Function ContainsEffectEntry(String[] entries, String candidate)
  Int index = 0
  While (index < entries.Length)
    If (entries[index] == candidate)
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

Bool Function IsSuppressedSustenanceEntry(String[] entries, String candidate)
  If (candidate == "D:Dehydrated")
    Return ContainsEffectEntry(entries, "B:Hydrated")
  ElseIf (candidate == "D:Malnourished")
    Return ContainsEffectEntry(entries, "B:Fed")
  EndIf
  Return False
EndFunction

Bool Function IsSustenanceFoodEffect(MagicEffect effect)
  Return effect == Game.GetFormFromFile(0x31326D, "Starfield.esm") || effect == Game.GetFormFromFile(0x31326E, "Starfield.esm") || effect == Game.GetFormFromFile(0x31326F, "Starfield.esm")
EndFunction

Bool Function IsSustenanceDrinkEffect(MagicEffect effect)
  Return effect == Game.GetFormFromFile(0x31327B, "Starfield.esm") || effect == Game.GetFormFromFile(0x31329B, "Starfield.esm") || effect == Game.GetFormFromFile(0x2EDFDA, "Starfield.esm")
EndFunction

Bool Function IsSustenanceHydratedEffect(MagicEffect effect)
  Return effect == Game.GetFormFromFile(0x313260, "Starfield.esm") || effect == Game.GetFormFromFile(0x2EDFDC, "Starfield.esm") || effect == Game.GetFormFromFile(0x2EFD74, "Starfield.esm")
EndFunction

Bool Function IsSustenanceFedEffect(MagicEffect effect)
  Return effect == Game.GetFormFromFile(0x2EDFE1, "Starfield.esm") || effect == Game.GetFormFromFile(0x2EDFD5, "Starfield.esm") || effect == Game.GetFormFromFile(0x313251, "Starfield.esm")
EndFunction

; Publishes one complete state datagram. EVENT_SUBMITTED acknowledges native submission only.
Function PublishNextEffectPacket()
  If (Registry == None)
    Return
  EndIf
  If (PendingEffectPayload == "")
    Return
  EndIf
  String payload = PendingEffectPayload
  String signature = PendingEffectSignature
  OperationResult result = Registry.TryPublishCanvasDatagram(ResolveStatusTopic(), "effects.state", 1, "ci-ascii", payload)
  Float elapsed = -1.0
  Float now = Utility.GetCurrentRealTime()
  If (LastHudOpenAt > 0.0 && now >= LastHudOpenAt)
    elapsed = now - LastHudOpenAt
  EndIf
  LogUserInformational(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_ATTEMPT | Type=effects.state | Schema=1 | Length=" + Registry.GetCharacterCount(result.Packet) + " | Status=" + result.Status + " | SinceHudOpen=" + elapsed)
  If (PendingEffectPayload != payload || PendingEffectSignature != signature)
    Return
  EndIf
  If (result.Status == "EVENT_SUBMITTED")
    Bool scheduleRecoveryReplay = PendingEffectNeedsRecoveryReplay
    EffectRetryCount = 0
    LastEffectSignature = signature
    LastEffectSnapshotAt = Utility.GetCurrentRealTime()
    PendingEffectPayload = ""
    PendingEffectNeedsRecoveryReplay = False
    CancelTimer(34)
    StartTimer(60.0, 34)
    If (scheduleRecoveryReplay)
      CancelTimer(35)
      StartTimer(2.0, 35)
    EndIf
    If (EffectChangedDuringPublication)
      EffectChangedDuringPublication = False
      RequestEffectRefresh(False)
    EndIf
  ElseIf (result.Status == "REJECTED_EVENT_INACTIVE")
    LogUserInformational(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_WAITING_FOR_HUD")
    EffectRetryCount += 1
    If (EffectRetryCount <= 20)
      StartTimer(0.5, 33)
    Else
      LogUserWarning(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_RETRY_EXHAUSTED | Status=" + result.Status)
      PendingEffectPayload = ""
      PendingEffectNeedsRecoveryReplay = False
      EffectForceRefresh = True
      CancelTimer(34)
      StartTimer(60.0, 34)
    EndIf
  ElseIf (IsDeferred(result.Status) || result.Status == "EVENT_CANCELLED_ACTIVATION")
    EffectRetryCount += 1
    If (EffectRetryCount <= 20)
      StartTimer(0.5, 33)
    Else
      LogUserWarning(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_RETRY_EXHAUSTED | Status=" + result.Status)
      PendingEffectPayload = ""
      PendingEffectNeedsRecoveryReplay = False
      EffectForceRefresh = True
      CancelTimer(34)
      StartTimer(60.0, 34)
    EndIf
  Else
    LogUserWarning(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_REJECTED | Status=" + result.Status + " | Detail=" + result.Detail)
    PendingEffectPayload = ""
    PendingEffectNeedsRecoveryReplay = False
    EffectForceRefresh = True
  EndIf
EndFunction


String Function ResolveStatusTopic()
  If (StatusTopic == "venworks.vwhud.vwks.status" || StatusTopic == "venworks.vwhud.ta.status" || StatusTopic == "venworks.vwhud.fc.status" || StatusTopic == "venworks.vwhud.cf.status" || StatusTopic == "venworks.vwhud.min.status")
    Return StatusTopic
  EndIf
  Return ""
EndFunction