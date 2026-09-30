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
; Presence bits for the small generic set. This is not a second effects.state payload.
String LastGenericEffectSignature = ""
Spell[] CachedWeatherSpells
String[] CachedWeatherLabels
Bool WeatherSpellsReady = False
Keyword CachedSandstormKeyword
Keyword CachedSnowKeyword
Bool WeatherKeywordsReady = False
Int[] CachedMagicEffectIds
MagicEffect[] CachedMagicEffects
SQ_ENV_AfflictionsScript CachedAfflictionQuest
Bool AfflictionQuestCached = False
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

; Immutable metadata identifies the pending typed arrays. Papyrus structs cannot hold arrays.
Struct EffectSnapshot
  Int Revision
  String Signature
  String Payload
  Bool RecoveryReplay
EndStruct
EffectSnapshot PendingSnapshot
String[] PendingEntries
MagicEffect[] PendingEffects
String[] PendingSourceEffectEntries
ENV_AfflictionScript[] PendingAfflictions
String[] PendingAfflictionEntries
Spell[] PendingSpells
String[] PendingSpellEntries
Bool EffectHeartbeatPending = False

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
  ; Cancel before invalidating ownership, so callbacks that start fresh work after
  ; the guarded reset cannot have their new timers cancelled by this load handler.
  CancelTimer(31)
  CancelTimer(32)
  CancelTimer(33)
  CancelTimer(34)
  CancelTimer(35)
  ; Fence scans and receipts from the previous load without publishing their state.
  LockGuard EffectSnapshotGuard
    EffectSourceRevision += 1
    PendingSnapshot = None
    PendingEntries = None
    PendingEffects = None
    PendingSourceEffectEntries = None
    PendingAfflictions = None
    PendingAfflictionEntries = None
    PendingSpells = None
    PendingSpellEntries = None
    PendingEffectPayload = ""
    PendingEffectSignature = ""
    PendingEffectNeedsRecoveryReplay = False
    EffectRecoveryRefresh = False
    EffectSnapshotBuilding = False
    EffectChangedDuringPublication = False
    EffectRefreshPending = False
    EffectHeartbeatPending = False
    LastGenericEffectSignature = ""
    EffectRetryCount = 0
  EndLockGuard
  WeatherSpellsReady = False
  CachedWeatherSpells = None
  CachedWeatherLabels = None
  WeatherKeywordsReady = False
  CachedSandstormKeyword = None
  CachedSnowKeyword = None
  CachedMagicEffectIds = None
  CachedMagicEffects = None
  AfflictionQuestCached = False
  CachedAfflictionQuest = None
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
  If (aiTimerID == 31)
    Bool scan = False
    LockGuard EffectSnapshotGuard
      scan = EffectRefreshPending
      EffectRefreshPending = False
    EndLockGuard
    If (scan)
      PrepareEffectSnapshot()
    EndIf
  ElseIf (aiTimerID == 32)
    CheckGenericEffectSignature()
    CheckActiveEffectSources()
    ScheduleActiveEffectCheck()
  ElseIf (aiTimerID == 33)
    PublishNextEffectPacket()
  ElseIf (aiTimerID == 34)
    LockGuard EffectSnapshotGuard
      EffectHeartbeatPending = False
      EffectRetryCount = 0
    EndLockGuard
    ; Unchanged rows keep the 60-second signature skip. A real difference still publishes.
    RequestEffectRefresh(False)
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
  Bool schedule = False
  Bool heartbeat = False
  ; Local assignments only: registry calls and timer operations stay outside guards.
  LockGuard EffectSnapshotGuard
    If (!EffectHeartbeatPending)
      EffectHeartbeatPending = True
      heartbeat = True
    EndIf
    If (forceSnapshot)
      EffectForceRefresh = True
    EndIf
    If (EffectSnapshotBuilding || PendingSnapshot != None)
      EffectChangedDuringPublication = True
    ElseIf (!EffectRefreshPending && EffectRetryCount <= 20)
      EffectRefreshPending = True
      schedule = True
    EndIf
  EndLockGuard
  If (heartbeat)
    ; Timer 34 calls this without forcing, so an unchanged list waits out the 60-second skip.
    StartTimer(15.0, 34)
  EndIf
  If (schedule)
    StartTimer(0.5, 31)
  EndIf
EndFunction

; Keep the one-second poll armed while this quest is running, including when no row is published.
Function ScheduleActiveEffectCheck()
  CancelTimer(32)
  StartTimer(1.0, 32)
EndFunction

; An expiry or cure has no quest-level finish event. Never send a removal from a guessed timer alone.
Function CheckActiveEffectSources()
  Int sourceRevision
  String[] observedEntries
  MagicEffect[] effects
  String[] effectEntries
  ENV_AfflictionScript[] afflictions
  String[] afflictionEntries
  Spell[] spells
  String[] spellEntries
  LockGuard EffectSnapshotGuard
    sourceRevision = EffectSourceRevision
    observedEntries = ObservedEffectEntries
    effects = ActiveSourceEffects
    effectEntries = ActiveSourceEffectEntries
    afflictions = ActiveSourceAfflictions
    afflictionEntries = ActiveSourceAfflictionEntries
    spells = ActiveSourceSpells
    spellEntries = ActiveSourceSpellEntries
  EndLockGuard
  If (observedEntries == None || observedEntries.Length == 0 || EffectSnapshotBuilding)
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None)
    Return
  EndIf
  String[] stillActive = new String[0]
  Int index = 0
  While (effects != None && index < effects.Length)
    If (effects[index] != None && player.HasMagicEffect(effects[index]) && !ContainsEffectEntry(stillActive, effectEntries[index]))
      stillActive.Add(effectEntries[index])
    EndIf
    index += 1
  EndWhile
  index = 0
  While (afflictions != None && index < afflictions.Length)
    If (HasAfflictionSpell(player, afflictions[index]) && !ContainsEffectEntry(stillActive, afflictionEntries[index]))
      stillActive.Add(afflictionEntries[index])
    EndIf
    index += 1
  EndWhile
  index = 0
  While (spells != None && index < spells.Length)
    Bool namedStatusActive = spells[index] != None && player.HasSpell(spells[index])
    If (namedStatusActive && !ContainsEffectEntry(stillActive, spellEntries[index]))
      stillActive.Add(spellEntries[index])
    EndIf
    index += 1
  EndWhile
  stillActive = AppendLiveWeatherConditions(stillActive, player)
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
      removed = True
    EndIf
  EndTryLockGuard
  If (removed)
    RequestEffectRefresh(True)
    LogUserInformational(ModuleName, "CheckActiveEffectSources", "EFFECT_REMOVAL_DETECTED | Remaining=" + remaining.Length)
  EndIf
EndFunction

; Builds one complete state payload; every submitted datagram is independently valid.
Function PrepareEffectSnapshot()
  Int expectedRevision = EffectSourceRevision
  If (Registry == None || BuffEffects == None || DebuffEffects == None)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_SNAPSHOT_DEFERRED | Registry or catalog unavailable.")
    RetryEffectBuild(expectedRevision)
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_SNAPSHOT_DEFERRED | Player unavailable.")
    RetryEffectBuild(expectedRevision)
    Return
  EndIf
  EffectSnapshot candidate = new EffectSnapshot
  Bool claimed = False
  Bool forcedRefresh = False
  Bool recoveryRefresh = False
  LockGuard EffectSnapshotGuard
    If (EffectSourceRevision != expectedRevision)
      ; A load or another scan took ownership while prerequisites were queried.
    ElseIf (EffectSnapshotBuilding || PendingSnapshot != None)
      EffectChangedDuringPublication = True
    Else
      EffectSnapshotBuilding = True
      EffectSourceRevision += 1
      candidate.Revision = EffectSourceRevision
      forcedRefresh = EffectForceRefresh
      EffectForceRefresh = False
      recoveryRefresh = EffectRecoveryRefresh
      EffectRecoveryRefresh = False
      claimed = True
    EndIf
  EndLockGuard
  If (!claimed)
    Return
  EndIf
  MagicEffect[] scanEffects = new MagicEffect[0]
  String[] scanEffectEntries = new String[0]
  ENV_AfflictionScript[] scanAfflictions = new ENV_AfflictionScript[0]
  String[] scanAfflictionEntries = new String[0]
  Spell[] scanSpells = new Spell[0]
  String[] scanSpellEntries = new String[0]
  String[] entries = new String[0]
  entries = AppendActiveEffects(entries, player, BuffEffects, BuffLabels, "B", scanEffects, scanEffectEntries)
  entries = AppendDirectGenericBuffs(entries, player, scanEffects, scanEffectEntries)
  Int buffCount = entries.Length
  entries = AppendActiveEffects(entries, player, DebuffEffects, DebuffLabels, "D", scanEffects, scanEffectEntries)
  entries = AppendDirectGenericDebuffs(entries, player, scanEffects, scanEffectEntries)
  entries = AppendActiveAfflictions(entries, player, scanAfflictions, scanAfflictionEntries)
  entries = AppendActiveEnvironmentalStatuses(entries, player, scanSpells, scanSpellEntries)
  Int debuffCount = entries.Length - buffCount
  String signature = ""
  Int index = 0
  While (index < entries.Length)
    signature += entries[index] + ";"
    index += 1
  EndWhile
  Bool entriesChanged = signature != LastEffectSignature
  Float now = Utility.GetCurrentRealTime()
  If (!forcedRefresh && !entriesChanged && now >= LastEffectSnapshotAt && now - LastEffectSnapshotAt < 60.0)
    FinishEffectBuild(candidate, False)
    Return
  EndIf
  String eventTopic = ResolveStatusTopic()
  String payload = buffCount + "|" + debuffCount + "|" + signature
  String datagram = Registry.BuildCanvasDatagramBody("effects.state", 1, "ci-ascii", payload)
  String framedPacket = Registry.BuildCanvasEventPacket(eventTopic, datagram)
  Int framedLength = Registry.GetCharacterCount(framedPacket)
  If (eventTopic == "" || datagram == "" || framedPacket == "" || framedLength > 4096)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_DATAGRAM_REJECTED | Buffs=" + buffCount + " | Debuffs=" + debuffCount + " | Length=" + framedLength + " | Limit=4096")
    FinishEffectBuild(candidate, True)
    Return
  EndIf
  candidate.Signature = signature
  candidate.Payload = payload
  candidate.RecoveryReplay = !recoveryRefresh && (forcedRefresh || entriesChanged)
  Bool queued = False
  LockGuard EffectSnapshotGuard
    If (EffectSnapshotBuilding && EffectSourceRevision == candidate.Revision)
      PendingEntries = entries
      PendingEffects = scanEffects
      PendingSourceEffectEntries = scanEffectEntries
      PendingAfflictions = scanAfflictions
      PendingAfflictionEntries = scanAfflictionEntries
      PendingSpells = scanSpells
      PendingSpellEntries = scanSpellEntries
      PendingSnapshot = candidate
      PendingEffectSignature = signature
      PendingEffectPayload = payload
      PendingEffectNeedsRecoveryReplay = candidate.RecoveryReplay
      EffectSnapshotBuilding = False
      queued = True
    EndIf
  EndLockGuard
  If (queued)
    LogUserInformational(ModuleName, "PrepareEffectSnapshot", "EFFECT_DATAGRAM_QUEUED | Type=effects.state | Schema=1 | Buffs=" + buffCount + " | Debuffs=" + debuffCount + " | Length=" + framedLength)
    StartTimer(0.1, 33)
  EndIf
EndFunction

; Missing prerequisites and rejected builds share the bounded budget; heartbeat survives exhaustion.
Function RetryEffectBuild(Int expectedRevision)
  Bool retry = False
  LockGuard EffectSnapshotGuard
    If (EffectSourceRevision == expectedRevision)
      EffectForceRefresh = True
      EffectRetryCount += 1
      retry = EffectRetryCount <= 20
    EndIf
  EndLockGuard
  If (retry)
    RequestEffectRefresh(True)
  EndIf
EndFunction

Function FinishEffectBuild(EffectSnapshot candidate, Bool rejected)
  Bool retry = False
  Bool refresh = False
  LockGuard EffectSnapshotGuard
    If (EffectSourceRevision == candidate.Revision && EffectSnapshotBuilding)
      EffectSnapshotBuilding = False
      refresh = EffectChangedDuringPublication
      EffectChangedDuringPublication = False
      If (rejected)
        EffectForceRefresh = True
        EffectRetryCount += 1
        retry = EffectRetryCount <= 20
        ; A coalesced request cannot bypass the exhausted retry budget.
        refresh = False
      EndIf
    EndIf
  EndLockGuard
  If (retry || refresh)
    RequestEffectRefresh(rejected)
  EndIf
EndFunction

; SQ_ENV owns injuries and infections separately from the magic-effect catalog. Its spells
; are the status-menu source of truth even when a console-applied spell did not set Active.
String[] Function AppendActiveAfflictions(String[] entries, Actor player, ENV_AfflictionScript[] sources, String[] sourceEntries)
  SQ_ENV_AfflictionsScript afflictionQuest = ResolveAfflictionQuest()
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
      sources.Add(affliction)
      sourceEntries.Add(entry)
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

; Named weather spells are the status-menu rows. Snow and sandstorm are also read from the current weather, because those spells are added after the hazard is already visible.
String[] Function AppendActiveEnvironmentalStatuses(String[] entries, Actor player, Spell[] sources, String[] sourceEntries)
  entries = AppendNamedWeatherStatuses(entries, player, sources, sourceEntries)
  entries = AppendLiveWeatherConditions(entries, player)
  Spell toxicGas = Game.GetFormFromFile(0x245B6B, "Starfield.esm") as Spell
  If (toxicGas != None && player.HasSpell(toxicGas))
    String entry = "D:#" + toxicGas.GetFormID() + ":Toxic Gas Hazard"
    entries.Add(entry)
    sources.Add(toxicGas)
    sourceEntries.Add(entry)
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
String[] Function AppendActiveEffects(String[] entries, Actor player, FormList catalog, String[] labels, String category, MagicEffect[] sources, String[] sourceEntries)
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
      sources.Add(effect)
      sourceEntries.Add(entry)
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
  EffectSnapshot candidate
  LockGuard EffectSnapshotGuard
    candidate = PendingSnapshot
  EndLockGuard
  If (candidate == None)
    Return
  EndIf
  OperationResult result
  If (Registry != None)
    result = Registry.TryPublishCanvasDatagram(ResolveStatusTopic(), "effects.state", 1, "ci-ascii", candidate.Payload)
  EndIf
  String status = "DEFERRED_REGISTRY_UNAVAILABLE"
  If (result != None)
    status = result.Status
  EndIf
  Float now = Utility.GetCurrentRealTime()
  Bool committed = False
  Bool retry = False
  Bool refresh = False
  LockGuard EffectSnapshotGuard
    ; A load or replacement invalidates even an otherwise identical payload receipt.
    If (PendingSnapshot == candidate && EffectSourceRevision == candidate.Revision)
      If (status == "EVENT_SUBMITTED")
        ObservedEffectEntries = PendingEntries
        ActiveSourceEffects = PendingEffects
        ActiveSourceEffectEntries = PendingSourceEffectEntries
        ActiveSourceAfflictions = PendingAfflictions
        ActiveSourceAfflictionEntries = PendingAfflictionEntries
        ActiveSourceSpells = PendingSpells
        ActiveSourceSpellEntries = PendingSpellEntries
        LastEffectSignature = candidate.Signature
        LastActiveEffectCount = PendingEntries.Length
        LastEffectSnapshotAt = now
        EffectRetryCount = 0
        committed = True
        refresh = EffectChangedDuringPublication
        EffectChangedDuringPublication = False
      Else
        EffectForceRefresh = True
        EffectRetryCount += 1
        retry = EffectRetryCount <= 20
      EndIf
      If (committed || !retry)
        PendingSnapshot = None
        PendingEntries = None
        PendingEffects = None
        PendingSourceEffectEntries = None
        PendingAfflictions = None
        PendingAfflictionEntries = None
        PendingSpells = None
        PendingSpellEntries = None
        PendingEffectPayload = ""
        PendingEffectSignature = ""
        PendingEffectNeedsRecoveryReplay = False
      EndIf
    EndIf
  EndLockGuard
  LogUserInformational(ModuleName, "PublishNextEffectPacket", "EFFECT_DATAGRAM_ATTEMPT | Status=" + status + " | Revision=" + candidate.Revision + " | Committed=" + committed + " | Retry=" + retry)
  If (committed)
    ScheduleActiveEffectCheck()
    If (candidate.RecoveryReplay)
      StartTimer(2.0, 35)
    EndIf
    If (refresh)
      RequestEffectRefresh(False)
    EndIf
  ElseIf (retry)
    StartTimer(0.5, 33)
  EndIf
  ; The independent timer 34 remains armed on every failure, including terminal rejection.
EndFunction

; One true check per generic icon. A change wakes one forced snapshot; it does not publish a payload.
Function CheckGenericEffectSignature()
  Actor player = Game.GetPlayer()
  If (player == None)
    Return
  EndIf
  String signature = BuildGenericEffectSignature(player)
  If (signature == LastGenericEffectSignature)
    Return
  EndIf
  LastGenericEffectSignature = signature
  RequestEffectRefresh(True)
EndFunction

String Function BuildGenericEffectSignature(Actor player)
  Bool bleeding = HasAnyMagicEffect(player, 0x23E9BF, 0x2E8148, 0)
  Bool poisoning = False
  Bool radiation = False
  Bool thermal = False
  Bool cold = False
  SQ_ENV_AfflictionsScript afflictionQuest = ResolveAfflictionQuest()
  If (afflictionQuest != None && afflictionQuest.AfflictionData != None)
    ENV_AfflictionScript[] afflictions = afflictionQuest.AfflictionData
    Int index = 0
    While (index < afflictions.Length)
      ENV_AfflictionScript affliction = afflictions[index]
      If (affliction != None)
        String afflictionId = affliction.ID
        If (afflictionId == "Poisoning")
          poisoning = HasAfflictionSpell(player, affliction)
        ElseIf (afflictionId == "RadiationPoisoning")
          radiation = HasAfflictionSpell(player, affliction)
        ElseIf (afflictionId == "Burns" || afflictionId == "Heatstroke")
          If (HasAfflictionSpell(player, affliction))
            thermal = True
          EndIf
        ElseIf (afflictionId == "Frostbite" || afflictionId == "Hypothermia")
          If (HasAfflictionSpell(player, affliction))
            cold = True
          EndIf
        EndIf
      EndIf
      index += 1
    EndWhile
  EndIf
  Bool malnourished = HasAnyMagicEffect(player, 0x31326D, 0x31326E, 0x31326F)
  Bool dehydrated = HasAnyMagicEffect(player, 0x31327B, 0x31329B, 0x2EDFDA)
  Bool fed = HasAnyMagicEffect(player, 0x2EDFE1, 0x2EDFD5, 0x313251)
  Bool hydrated = HasAnyMagicEffect(player, 0x313260, 0x2EDFDC, 0x2EFD74)
  Bool rested = HasAnyMagicEffect(player, 0x05C527, 0, 0)
  String signature = ""
  If (bleeding)
    signature += "D:Bleeding;"
  EndIf
  If (poisoning)
    signature += "D:Poisoning;"
  EndIf
  If (radiation)
    signature += "D:Radiation;"
  EndIf
  If (thermal)
    signature += "D:Thermal;"
  EndIf
  If (cold)
    signature += "D:Cold;"
  EndIf
  If (malnourished)
    signature += "D:Malnourished;"
  EndIf
  If (dehydrated)
    signature += "D:Dehydrated;"
  EndIf
  If (fed)
    signature += "B:Fed;"
  EndIf
  If (hydrated)
    signature += "B:Hydrated;"
  EndIf
  If (rested)
    signature += "B:Well Rested;"
  EndIf
  Return signature + WeatherSignature(player)
EndFunction

Bool Function HasAnyMagicEffect(Actor player, Int formIdA, Int formIdB, Int formIdC)
  Return HasMagicEffectId(player, formIdA) || HasMagicEffectId(player, formIdB) || HasMagicEffectId(player, formIdC)
EndFunction

Bool Function HasMagicEffectId(Actor player, Int formId)
  If (player == None || formId == 0)
    Return False
  EndIf
  MagicEffect effect = ResolveMagicEffect(formId)
  Return effect != None && player.HasMagicEffect(effect)
EndFunction

; Resolved forms are kept for the session. A miss is not cached, so a later load can resolve it.
MagicEffect Function ResolveMagicEffect(Int formId)
  If (formId == 0)
    Return None
  EndIf
  If (CachedMagicEffectIds == None)
    CachedMagicEffectIds = new Int[0]
    CachedMagicEffects = new MagicEffect[0]
  EndIf
  Int index = 0
  While (index < CachedMagicEffectIds.Length)
    If (CachedMagicEffectIds[index] == formId)
      Return CachedMagicEffects[index]
    EndIf
    index += 1
  EndWhile
  MagicEffect effect = Game.GetFormFromFile(formId, "Starfield.esm") as MagicEffect
  If (effect != None)
    CachedMagicEffectIds.Add(formId)
    CachedMagicEffects.Add(effect)
  EndIf
  Return effect
EndFunction

SQ_ENV_AfflictionsScript Function ResolveAfflictionQuest()
  If (!AfflictionQuestCached)
    CachedAfflictionQuest = Game.GetFormFromFile(0x00248D20, "Starfield.esm") as SQ_ENV_AfflictionsScript
    AfflictionQuestCached = CachedAfflictionQuest != None
  EndIf
  Return CachedAfflictionQuest
EndFunction

; These spell records are the named rows on the character status screen.
Function EnsureWeatherSpells()
  If (WeatherSpellsReady)
    Return
  EndIf
  Spell[] spells = new Spell[10]
  String[] labels = new String[10]
  spells[0] = Game.GetFormFromFile(0x001639EB, "Starfield.esm") as Spell
  labels[0] = "Freezing Rain"
  spells[1] = Game.GetFormFromFile(0x00163A02, "Starfield.esm") as Spell
  labels[1] = "Freezing Cold and Snow"
  spells[2] = Game.GetFormFromFile(0x001639F9, "Starfield.esm") as Spell
  labels[2] = "Freezing Vapor"
  spells[3] = Game.GetFormFromFile(0x00281ECD, "Starfield.esm") as Spell
  labels[3] = "Scalding Rain"
  spells[4] = Game.GetFormFromFile(0x00163A03, "Starfield.esm") as Spell
  labels[4] = "Intense Heat"
  spells[5] = Game.GetFormFromFile(0x00163A00, "Starfield.esm") as Spell
  labels[5] = "Scalding Vapor"
  spells[6] = Game.GetFormFromFile(0x00281ECB, "Starfield.esm") as Spell
  labels[6] = "Corrosive Rain"
  spells[7] = Game.GetFormFromFile(0x00163A05, "Starfield.esm") as Spell
  labels[7] = "Corrosive Particulates"
  spells[8] = Game.GetFormFromFile(0x001639F8, "Starfield.esm") as Spell
  labels[8] = "Corrosive Vapor"
  spells[9] = Game.GetFormFromFile(0x00163FE7, "Starfield.esm") as Spell
  labels[9] = "Poor Air Quality"
  CachedWeatherSpells = spells
  CachedWeatherLabels = labels
  Int index = 0
  Bool complete = True
  While (index < spells.Length)
    If (spells[index] == None)
      complete = False
    EndIf
    index += 1
  EndWhile
  WeatherSpellsReady = complete
EndFunction

String Function WeatherSignature(Actor player)
  EnsureWeatherSpells()
  String signature = ""
  Int index = 0
  While (CachedWeatherSpells != None && index < CachedWeatherSpells.Length)
    Spell weatherSpell = CachedWeatherSpells[index]
    If (weatherSpell != None && player.HasSpell(weatherSpell))
      signature += "D:" + CachedWeatherLabels[index] + ";"
    EndIf
    index += 1
  EndWhile
  EnsureWeatherKeywords()
  If (CurrentWeatherHas(CachedSandstormKeyword))
    signature += "D:Sandstorm;"
  EndIf
  If (CurrentWeatherHas(CachedSnowKeyword))
    signature += "D:Snow;"
  EndIf
  If (HasMagicEffectId(player, 0x00302A70))
    signature += "D:ColdDamage;"
  EndIf
  Return signature
EndFunction

String[] Function AppendNamedWeatherStatuses(String[] entries, Actor player, Spell[] sources, String[] sourceEntries)
  EnsureWeatherSpells()
  Int index = 0
  While (CachedWeatherSpells != None && index < CachedWeatherSpells.Length)
    Spell weatherSpell = CachedWeatherSpells[index]
    If (weatherSpell != None && player.HasSpell(weatherSpell))
      String entry = "D:#" + weatherSpell.GetFormID() + ":" + CachedWeatherLabels[index]
      If (!ContainsEffectEntry(entries, entry))
        entries.Add(entry)
        sources.Add(weatherSpell)
        sourceEntries.Add(entry)
      EndIf
    EndIf
    index += 1
  EndWhile
  Return entries
EndFunction

; WeatherName_Sandstorm is 0x00281DF6 and WeatherName_Snow is 0x00281DF7. A miss is not cached.
Function EnsureWeatherKeywords()
  If (WeatherKeywordsReady)
    Return
  EndIf
  CachedSandstormKeyword = Game.GetFormFromFile(0x00281DF6, "Starfield.esm") as Keyword
  CachedSnowKeyword = Game.GetFormFromFile(0x00281DF7, "Starfield.esm") as Keyword
  WeatherKeywordsReady = CachedSandstormKeyword != None && CachedSnowKeyword != None
EndFunction

Bool Function CurrentWeatherHas(Keyword nameKeyword)
  If (nameKeyword == None)
    Return False
  EndIf
  Weather current = Weather.GetCurrentWeather()
  If (current == None)
    Return False
  EndIf
  Return current.HasKeyword(nameKeyword)
EndFunction

; One cold icon is enough once a freezing spell row is already present. Sandstorm stays beside Intense Heat.
String[] Function AppendLiveWeatherConditions(String[] entries, Actor player)
  EnsureWeatherKeywords()
  Weather current = Weather.GetCurrentWeather()
  If (CurrentWeatherHas(CachedSandstormKeyword) && current != None)
    String sandstorm = "D:#" + current.GetFormID() + ":Sandstorm"
    If (!ContainsEffectEntry(entries, sandstorm))
      entries.Add(sandstorm)
    EndIf
  EndIf
  If (!HasNamedColdRow(entries) && (CurrentWeatherHas(CachedSnowKeyword) || HasMagicEffectId(player, 0x00302A70)))
    String coldEntry = ""
    If (CurrentWeatherHas(CachedSnowKeyword) && current != None)
      coldEntry = "D:#" + current.GetFormID() + ":Cold"
    Else
      MagicEffect coldDamage = ResolveMagicEffect(0x00302A70)
      If (coldDamage != None)
        coldEntry = "D:#" + coldDamage.GetFormID() + ":Cold"
      EndIf
    EndIf
    If (coldEntry != "" && !ContainsEffectEntry(entries, coldEntry))
      entries.Add(coldEntry)
    EndIf
  EndIf
  Return entries
EndFunction

Bool Function HasNamedColdRow(String[] entries)
  If (entries == None)
    Return False
  EndIf
  EnsureWeatherSpells()
  Int index = 0
  While (CachedWeatherSpells != None && CachedWeatherLabels != None && index < CachedWeatherSpells.Length && index < CachedWeatherLabels.Length)
    String label = CachedWeatherLabels[index]
    Spell coldSpell = CachedWeatherSpells[index]
    If (coldSpell != None && (label == "Freezing Rain" || label == "Freezing Cold and Snow" || label == "Freezing Vapor"))
      If (ContainsEffectEntry(entries, "D:#" + coldSpell.GetFormID() + ":" + label))
        Return True
      EndIf
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

; Catalog membership is not required. Keys match the rows already published for this set.
String[] Function AppendDirectGenericBuffs(String[] entries, Actor player, MagicEffect[] sources, String[] sourceEntries)
  entries = AppendGroupedMagicEffects(entries, player, sources, sourceEntries, "B:Fed", 0x2EDFE1, 0x2EDFD5, 0x313251)
  entries = AppendGroupedMagicEffects(entries, player, sources, sourceEntries, "B:Hydrated", 0x313260, 0x2EDFDC, 0x2EFD74)
  MagicEffect rested = Game.GetFormFromFile(0x05C527, "Starfield.esm") as MagicEffect
  If (rested != None && player.HasMagicEffect(rested))
    String entry = "B:#" + rested.GetFormID() + ":Well Rested"
    If (!ContainsEffectEntry(entries, entry) && !IsSuppressedSustenanceEntry(entries, entry))
      entries.Add(entry)
    EndIf
    sources.Add(rested)
    sourceEntries.Add(entry)
  EndIf
  Return entries
EndFunction

String[] Function AppendDirectGenericDebuffs(String[] entries, Actor player, MagicEffect[] sources, String[] sourceEntries)
  entries = AppendGroupedMagicEffects(entries, player, sources, sourceEntries, "D:Malnourished", 0x31326D, 0x31326E, 0x31326F)
  entries = AppendGroupedMagicEffects(entries, player, sources, sourceEntries, "D:Dehydrated", 0x31327B, 0x31329B, 0x2EDFDA)
  entries = AppendGroupedMagicEffects(entries, player, sources, sourceEntries, "D:Bleeding", 0x23E9BF, 0x2E8148, 0)
  Return entries
EndFunction

String[] Function AppendGroupedMagicEffects(String[] entries, Actor player, MagicEffect[] sources, String[] sourceEntries, String entry, Int formIdA, Int formIdB, Int formIdC)
  Bool present = RememberMagicEffect(player, sources, sourceEntries, entry, formIdA)
  If (RememberMagicEffect(player, sources, sourceEntries, entry, formIdB))
    present = True
  EndIf
  If (RememberMagicEffect(player, sources, sourceEntries, entry, formIdC))
    present = True
  EndIf
  If (present && !ContainsEffectEntry(entries, entry) && !IsSuppressedSustenanceEntry(entries, entry))
    entries.Add(entry)
  EndIf
  Return entries
EndFunction

Bool Function RememberMagicEffect(Actor player, MagicEffect[] sources, String[] sourceEntries, String entry, Int formId)
  If (player == None || formId == 0)
    Return False
  EndIf
  MagicEffect effect = Game.GetFormFromFile(formId, "Starfield.esm") as MagicEffect
  If (effect == None || !player.HasMagicEffect(effect))
    Return False
  EndIf
  sources.Add(effect)
  sourceEntries.Add(entry)
  Return True
EndFunction

String Function ResolveStatusTopic()
  If (StatusTopic == "venworks.vwhud.vwks.status" || StatusTopic == "venworks.vwhud.ta.status" || StatusTopic == "venworks.vwhud.fc.status" || StatusTopic == "venworks.vwhud.cf.status" || StatusTopic == "venworks.vwhud.min.status")
    Return StatusTopic
  EndIf
  Return ""
EndFunction
