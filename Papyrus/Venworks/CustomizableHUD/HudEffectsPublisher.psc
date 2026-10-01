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
Spell[] CachedIncomingWeatherSpells
Bool IncomingWeatherSpellsReady = False
; Live weather is sampled at most once every five seconds. The one-second poll reads these flags only.
Float LastWeatherSampleAt = 0.0
Bool WeatherSampleReady = False
Bool CachedSandstormActive = False
Bool CachedSnowActive = False
Bool CachedColdDamageActive = False
Int[] WeatherOffStreaks
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
; The FormList walk is a multi-second VM stall. It runs only after a listed effect can change, a few entries per timer, so HUD registration is not stuck behind it.
Bool CatalogDirty = True
Bool CatalogScanActive = False
Int CatalogScanPhase = 0
Int CatalogScanIndex = 0
Int CatalogSliceRevision = 0
Bool CatalogSliceForced = False
Bool CatalogSliceRecovery = False
String[] CatalogSliceEntries
MagicEffect[] CatalogSliceEffects
String[] CatalogSliceEffectEntries
ENV_AfflictionScript[] CatalogSliceAfflictions
String[] CatalogSliceAfflictionEntries
Spell[] CatalogSliceSpells
String[] CatalogSliceSpellEntries
Int[] IgnoredApplyEffectIds
String LastEffectPayload = ""
Spell CachedToxicGasSpell
Bool ToxicGasSpellResolved = False
EffectSnapshot CatalogSliceCandidate

; Bootstrap menu and player notifications and schedule the first bounded effect scan.
Event OnInit()
  LogUserInformational(ModuleName, "OnInit", "EVENT_TRIGGERED | Registering HUD menus and effect events.")
  RegisterForMenuOpenCloseEvent("HUDMenu")
  RegisterForMenuOpenCloseEvent("SpaceshipHudMenu")
  EnsurePlayerEventRegistrations()
  EnsureMagicEffectRegistrations(True)
  ; CatalogDirty starts true. Force only means publish the finished snapshot; the walk itself yields between slices.
  RequestEffectRefresh(True)
EndEvent

; HUD opening schedules a bounded sequence; there is no saved active latch or wait in this event.
Event OnMenuOpenCloseEvent(String menuName, Bool opening)
  LogUserInformational(ModuleName, "OnMenuOpenCloseEvent", "EVENT_TRIGGERED | Menu=" + menuName + " | Opening=" + opening)
  If (opening)
    LastHudOpenAt = Utility.GetCurrentRealTime()
    EnsurePlayerEventRegistrations()
    EnsureMagicEffectRegistrations(True)
    ; A recreated HUD needs the last payload, not another native catalog walk. The first load has no payload yet and uses the scan OnInit already scheduled.
    If (LastEffectPayload != "" && !CatalogScanActive && !EffectSnapshotBuilding && PendingSnapshot == None)
      RepublishCachedEffects()
    ElseIf (!EffectRefreshPending && !CatalogScanActive && !EffectSnapshotBuilding)
      ; A script update has no cached payload. Scan once, then later opens replay that payload.
      If (LastEffectPayload == "")
        CatalogDirty = True
      EndIf
      RequestEffectRefresh(LastEffectPayload == "")
    EndIf
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
  CancelTimer(36)
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
    LastEffectSignature = ""
    LastEffectSnapshotAt = 0.0
    EffectRetryCount = 0
  EndLockGuard
  WeatherSpellsReady = False
  CachedWeatherSpells = None
  CachedWeatherLabels = None
  WeatherKeywordsReady = False
  CachedSandstormKeyword = None
  CachedSnowKeyword = None
  IncomingWeatherSpellsReady = False
  CachedIncomingWeatherSpells = None
  WeatherSampleReady = False
  LastWeatherSampleAt = 0.0
  CachedSandstormActive = False
  CachedSnowActive = False
  CachedColdDamageActive = False
  WeatherOffStreaks = None
  CachedMagicEffectIds = None
  CachedMagicEffects = None
  AfflictionQuestCached = False
  CachedAfflictionQuest = None
  MagicEffectEventRegistered = False
  CatalogDirty = True
  CatalogScanActive = False
  CatalogScanPhase = 0
  CatalogScanIndex = 0
  CatalogSliceRevision = 0
  CatalogSliceForced = False
  CatalogSliceRecovery = False
  CatalogSliceEntries = None
  CatalogSliceEffects = None
  CatalogSliceEffectEntries = None
  CatalogSliceAfflictions = None
  CatalogSliceAfflictionEntries = None
  CatalogSliceSpells = None
  CatalogSliceSpellEntries = None
  CatalogSliceCandidate = None
  IgnoredApplyEffectIds = None
  LastEffectPayload = ""
  ToxicGasSpellResolved = False
  CachedToxicGasSpell = None
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
    ; Re-arm only while the last payload is inside the 60-second window. Building it again was a full catalog scan with nothing to publish.
    Float heartbeatNow = Utility.GetCurrentRealTime()
    If (LastEffectSnapshotAt <= 0.0 || heartbeatNow < LastEffectSnapshotAt || heartbeatNow - LastEffectSnapshotAt >= 60.0)
      CatalogDirty = True
      RequestEffectRefresh(False)
    Else
      LockGuard EffectSnapshotGuard
        EffectHeartbeatPending = True
      EndLockGuard
      StartTimer(15.0, 34)
    EndIf
  ElseIf (aiTimerID == 35)
    ; The UI may have missed the packet. Resend the cached payload; do not walk the catalogs again.
    RepublishCachedEffects()
  ElseIf (aiTimerID == 36)
    ContinueCatalogScan()
  EndIf
EndEvent

; Re-register after each one-shot apply notification. Repeating ship and environment effects are not catalog rows and must not schedule a scan.
Event OnMagicEffectApply(ObjectReference akTarget, ObjectReference akCaster, MagicEffect akEffect)
  Bool playerTarget = akTarget == Game.GetPlayer()
  Bool catalogApply = playerTarget && EffectMayNeedCatalogScan(akEffect)
  If (catalogApply && !EffectRefreshPending)
    LogUserInformational(ModuleName, "OnMagicEffectApply", "EVENT_TRIGGERED | Target=" + akTarget + " | Effect=" + akEffect)
  EndIf
  MagicEffectEventRegistered = False
  EnsureMagicEffectRegistrations(catalogApply)
  If (catalogApply)
    CatalogDirty = True
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
    ; Timer 34 re-arms this. It only scans after the 60-second window, so an unchanged list is not rebuilt every 15 seconds.
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
  ; Cached flags only. Sampling weather here was a GetCurrentWeather call every second, and a flickering form id looked like a removal.
  stillActive = AppendCachedLiveWeatherRows(stillActive)
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
    RequestEffectRefresh(False)
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
  If (CatalogDirty)
    BeginCatalogScan(player, candidate, forcedRefresh, recoveryRefresh)
    Return
  EndIf
  MagicEffect[] scanEffects = new MagicEffect[0]
  String[] scanEffectEntries = new String[0]
  ENV_AfflictionScript[] scanAfflictions = new ENV_AfflictionScript[0]
  String[] scanAfflictionEntries = new String[0]
  Spell[] scanSpells = new Spell[0]
  String[] scanSpellEntries = new String[0]
  String[] entries = new String[0]
  ; Same order as a catalog scan: buffs, then debuffs, so Fed and Hydrated still suppress Malnourished and Dehydrated.
  entries = AppendStillActiveCatalogSources(entries, player, scanEffects, scanEffectEntries, "B:")
  entries = AppendDirectGenericBuffs(entries, player, scanEffects, scanEffectEntries)
  entries = AppendStillActiveCatalogSources(entries, player, scanEffects, scanEffectEntries, "D:")
  entries = AppendDirectGenericDebuffs(entries, player, scanEffects, scanEffectEntries)
  entries = AppendActiveAfflictions(entries, player, scanAfflictions, scanAfflictionEntries)
  entries = AppendActiveEnvironmentalStatuses(entries, player, scanSpells, scanSpellEntries)
  QueueBuiltSnapshot(candidate, entries, scanEffects, scanEffectEntries, scanAfflictions, scanAfflictionEntries, scanSpells, scanSpellEntries, forcedRefresh, recoveryRefresh)
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

; Named weather spells are the status-menu rows and stay on the one-second poll. Snow and sandstorm use the five-second weather sample, because those spells are added after the hazard is already visible.
String[] Function AppendActiveEnvironmentalStatuses(String[] entries, Actor player, Spell[] sources, String[] sourceEntries)
  entries = AppendNamedWeatherStatuses(entries, player, sources, sourceEntries)
  entries = AppendIncomingWeather(entries, player, sources, sourceEntries)
  entries = AppendLiveWeatherConditions(entries, player)
  Spell toxicGas = ResolveToxicGasSpell()
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
    entries = AppendOneCatalogEffect(entries, player, catalog, labels, category, sources, sourceEntries, index, catalogSize)
    index += 1
  EndWhile
  Return entries
EndFunction

; One catalog slot. The sliced scan and the full walk must publish the same entry text.
String[] Function AppendOneCatalogEffect(String[] entries, Actor player, FormList catalog, String[] labels, String category, MagicEffect[] sources, String[] sourceEntries, Int index, Int catalogSize)
  MagicEffect effect = catalog.GetAt(index) as MagicEffect
  If (effect == None || player == None || !player.HasMagicEffect(effect))
    Return entries
  EndIf
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
  Return effect == ResolveMagicEffect(0x31326D) || effect == ResolveMagicEffect(0x31326E) || effect == ResolveMagicEffect(0x31326F)
EndFunction

Bool Function IsSustenanceDrinkEffect(MagicEffect effect)
  Return effect == ResolveMagicEffect(0x31327B) || effect == ResolveMagicEffect(0x31329B) || effect == ResolveMagicEffect(0x2EDFDA)
EndFunction

Bool Function IsSustenanceHydratedEffect(MagicEffect effect)
  Return effect == ResolveMagicEffect(0x313260) || effect == ResolveMagicEffect(0x2EDFDC) || effect == ResolveMagicEffect(0x2EFD74)
EndFunction

Bool Function IsSustenanceFedEffect(MagicEffect effect)
  Return effect == ResolveMagicEffect(0x2EDFE1) || effect == ResolveMagicEffect(0x2EDFD5) || effect == ResolveMagicEffect(0x313251)
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
        LastEffectPayload = candidate.Payload
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
    CancelTimer(33)
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
  RequestEffectRefresh(False)
EndFunction

String Function BuildGenericEffectSignature(Actor player)
  Bool bleeding = HasAnyMagicEffect(player, 0x23E9BF, 0x2E8148, 0)
  String afflictionSignature = ""
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
      If (affliction != None && HasAfflictionSpell(player, affliction))
        String afflictionId = affliction.ID
        afflictionSignature += afflictionId + ";"
        If (afflictionId == "Poisoning")
          poisoning = True
        ElseIf (afflictionId == "RadiationPoisoning")
          radiation = True
        ElseIf (afflictionId == "Burns" || afflictionId == "Heatstroke")
          thermal = True
        ElseIf (afflictionId == "Frostbite" || afflictionId == "Hypothermia")
          cold = True
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
  Return afflictionSignature + signature + WeatherSignature(player)
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

; Named spell rows stay on the one-second poll. Live weather flags are a five-second sample, and they are omitted when the snapshot would suppress that row.
String Function WeatherSignature(Actor player)
  EnsureWeatherSpells()
  EnsureWeatherSample(player)
  String signature = ""
  Bool namedWeather = False
  Bool namedCold = False
  Int index = 0
  While (CachedWeatherSpells != None && index < CachedWeatherSpells.Length)
    Spell weatherSpell = CachedWeatherSpells[index]
    If (weatherSpell != None && player.HasSpell(weatherSpell))
      String label = CachedWeatherLabels[index]
      signature += "D:" + label + ";"
      namedWeather = True
      If (label == "Freezing Rain" || label == "Freezing Cold and Snow" || label == "Freezing Vapor")
        namedCold = True
      EndIf
    EndIf
    index += 1
  EndWhile
  If (CachedSandstormActive)
    signature += "D:Sandstorm;"
  EndIf
  If (!namedCold && (CachedSnowActive || CachedColdDamageActive))
    signature += "D:Cold;"
  EndIf
  If (!namedWeather && FirstIncomingWeatherSpell(player) != None)
    signature += "D:Incoming Weather;"
  EndIf
  Return signature
EndFunction

; These are the status-menu spells named Incoming Weather. They can be on before the named hazard spell sticks.
Function EnsureIncomingWeatherSpells()
  If (IncomingWeatherSpellsReady)
    Return
  EndIf
  Spell[] spells = new Spell[4]
  spells[0] = Game.GetFormFromFile(0x00281ED2, "Starfield.esm") as Spell
  spells[1] = Game.GetFormFromFile(0x001639EE, "Starfield.esm") as Spell
  spells[2] = Game.GetFormFromFile(0x00281ECF, "Starfield.esm") as Spell
  spells[3] = Game.GetFormFromFile(0x00163FE0, "Starfield.esm") as Spell
  CachedIncomingWeatherSpells = spells
  Int index = 0
  Bool complete = True
  While (index < spells.Length)
    If (spells[index] == None)
      complete = False
    EndIf
    index += 1
  EndWhile
  IncomingWeatherSpellsReady = complete
EndFunction

Spell Function FirstIncomingWeatherSpell(Actor player)
  EnsureIncomingWeatherSpells()
  If (player == None || CachedIncomingWeatherSpells == None)
    Return None
  EndIf
  Int index = 0
  While (index < CachedIncomingWeatherSpells.Length)
    Spell warning = CachedIncomingWeatherSpells[index]
    If (warning != None && player.HasSpell(warning))
      Return warning
    EndIf
    index += 1
  EndWhile
  Return None
EndFunction

Bool Function HasNamedWeatherSpellRow(String[] entries)
  EnsureWeatherSpells()
  If (entries == None || CachedWeatherSpells == None || CachedWeatherLabels == None)
    Return False
  EndIf
  Int index = 0
  While (index < CachedWeatherSpells.Length && index < CachedWeatherLabels.Length)
    Spell weatherSpell = CachedWeatherSpells[index]
    If (weatherSpell != None && ContainsEffectEntry(entries, "D:#" + weatherSpell.GetFormID() + ":" + CachedWeatherLabels[index]))
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

String[] Function AppendIncomingWeather(String[] entries, Actor player, Spell[] sources, String[] sourceEntries)
  Spell warning = FirstIncomingWeatherSpell(player)
  If (warning == None || HasNamedWeatherSpellRow(entries))
    Return entries
  EndIf
  String entry = "D:#" + warning.GetFormID() + ":Incoming Weather"
  If (!ContainsEffectEntry(entries, entry))
    entries.Add(entry)
    sources.Add(warning)
    sourceEntries.Add(entry)
  EndIf
  Return entries
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

; GetCurrentWeather and HasKeyword hitch if they run on the one-second poll. A miss does not clear a row until the next sample agrees.
Function EnsureWeatherSample(Actor player)
  Float now = Utility.GetCurrentRealTime()
  If (WeatherSampleReady && now >= LastWeatherSampleAt && now - LastWeatherSampleAt < 5.0)
    Return
  EndIf
  EnsureWeatherKeywords()
  Weather current = None
  If (CachedSandstormKeyword != None || CachedSnowKeyword != None)
    current = Weather.GetCurrentWeather()
  EndIf
  Bool sandstorm = current != None && CachedSandstormKeyword != None && current.HasKeyword(CachedSandstormKeyword)
  Bool snow = current != None && CachedSnowKeyword != None && current.HasKeyword(CachedSnowKeyword)
  CachedSandstormActive = CommitWeatherActive(CachedSandstormActive, sandstorm, 0)
  CachedSnowActive = CommitWeatherActive(CachedSnowActive, snow, 1)
  CachedColdDamageActive = CommitWeatherActive(CachedColdDamageActive, HasMagicEffectId(player, 0x00302A70), 2)
  LastWeatherSampleAt = now
  WeatherSampleReady = True
EndFunction

Bool Function CommitWeatherActive(Bool active, Bool sampled, Int slot)
  If (WeatherOffStreaks == None || WeatherOffStreaks.Length < 3)
    WeatherOffStreaks = new Int[3]
  EndIf
  If (sampled)
    WeatherOffStreaks[slot] = 0
    Return True
  EndIf
  Int streak = WeatherOffStreaks[slot] + 1
  WeatherOffStreaks[slot] = streak
  If (streak >= 2)
    Return False
  EndIf
  Return active
EndFunction

; One cold icon is enough once a freezing spell row is already present. Sandstorm stays beside Intense Heat.
; Keys stay stable so a different current-weather form cannot look like a new status or a removal.
String[] Function AppendLiveWeatherConditions(String[] entries, Actor player)
  EnsureWeatherSample(player)
  Return AppendCachedLiveWeatherRows(entries)
EndFunction

String[] Function AppendCachedLiveWeatherRows(String[] entries)
  If (entries == None)
    Return entries
  EndIf
  If (CachedSandstormActive && !ContainsEffectEntry(entries, "D:Sandstorm"))
    entries.Add("D:Sandstorm")
  EndIf
  If (!HasNamedColdRow(entries) && (CachedSnowActive || CachedColdDamageActive) && !ContainsEffectEntry(entries, "D:Cold"))
    entries.Add("D:Cold")
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
  MagicEffect rested = ResolveMagicEffect(0x05C527)
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
  MagicEffect effect = ResolveMagicEffect(formId)
  If (effect == None || !player.HasMagicEffect(effect))
    Return False
  EndIf
  If (HasMagicEffectInSources(sources, effect))
    Return True
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

; Repeating ship and environment effects are not catalog rows. Cache their runtime ids after one miss so they cannot schedule a walk.
Bool Function EffectMayNeedCatalogScan(MagicEffect effect)
  If (effect == None)
    Return False
  EndIf
  Int effectId = effect.GetFormID()
  If (HasIgnoredApplyEffect(effectId) || HasActiveSourceEffect(effect))
    Return False
  EndIf
  If (BuffEffects != None && BuffEffects.Find(effect) >= 0)
    Return True
  EndIf
  If (DebuffEffects != None && DebuffEffects.Find(effect) >= 0)
    Return True
  EndIf
  RememberIgnoredApplyEffect(effectId)
  Return False
EndFunction

Bool Function HasIgnoredApplyEffect(Int effectId)
  If (IgnoredApplyEffectIds == None)
    Return False
  EndIf
  Int index = 0
  While (index < IgnoredApplyEffectIds.Length)
    If (IgnoredApplyEffectIds[index] == effectId)
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

Function RememberIgnoredApplyEffect(Int effectId)
  If (IgnoredApplyEffectIds == None)
    IgnoredApplyEffectIds = new Int[0]
  EndIf
  IgnoredApplyEffectIds.Add(effectId)
EndFunction

Bool Function HasActiveSourceEffect(MagicEffect effect)
  If (effect == None || ActiveSourceEffects == None)
    Return False
  EndIf
  Int index = 0
  While (index < ActiveSourceEffects.Length)
    If (ActiveSourceEffects[index] == effect)
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

; The HUD movie may have been recreated. Resend the last payload; do not walk the catalogs.
Function RepublishCachedEffects()
  If (LastEffectPayload == "" || Registry == None || CatalogScanActive || EffectSnapshotBuilding || PendingSnapshot != None)
    Return
  EndIf
  String publishTopic = ResolveStatusTopic()
  If (publishTopic == "")
    Return
  EndIf
  OperationResult result = Registry.TryPublishCanvasDatagram(publishTopic, "effects.state", 1, "ci-ascii", LastEffectPayload)
  String status = "DEFERRED_REGISTRY_UNAVAILABLE"
  If (result != None)
    status = result.Status
  EndIf
  LogUserInformational(ModuleName, "RepublishCachedEffects", "EFFECT_CACHE_REPLAY | Status=" + status)
EndFunction

; Claimed by PrepareEffectSnapshot. Return immediately so HUD registration can run, then walk a few entries per timer.
Function BeginCatalogScan(Actor player, EffectSnapshot candidate, Bool forcedRefresh, Bool recoveryRefresh)
  CatalogDirty = False
  CatalogScanActive = True
  CatalogScanPhase = 0
  CatalogScanIndex = 0
  CatalogSliceRevision = candidate.Revision
  CatalogSliceForced = forcedRefresh
  CatalogSliceRecovery = recoveryRefresh
  CatalogSliceCandidate = candidate
  CatalogSliceEntries = new String[0]
  CatalogSliceEffects = new MagicEffect[0]
  CatalogSliceEffectEntries = new String[0]
  CatalogSliceAfflictions = new ENV_AfflictionScript[0]
  CatalogSliceAfflictionEntries = new String[0]
  CatalogSliceSpells = new Spell[0]
  CatalogSliceSpellEntries = new String[0]
  LogUserInformational(ModuleName, "BeginCatalogScan", "CATALOG_SCAN_STARTED | Revision=" + candidate.Revision + " | Player=" + player)
  CancelTimer(36)
  StartTimer(0.05, 36)
EndFunction

Function ContinueCatalogScan()
  If (!CatalogScanActive)
    Return
  EndIf
  If (EffectSourceRevision != CatalogSliceRevision || CatalogSliceCandidate == None)
    CatalogScanActive = False
    Return
  EndIf
  Actor player = Game.GetPlayer()
  If (player == None || BuffEffects == None || DebuffEffects == None)
    CatalogDirty = True
    CatalogScanActive = False
    FinishEffectBuild(CatalogSliceCandidate, True)
    Return
  EndIf
  Int budget = 6
  If (CatalogScanPhase == 0)
    budget = ConsumeCatalogSlice(player, BuffEffects, BuffLabels, "B", budget)
    If (CatalogScanIndex >= BuffEffects.GetSize())
      CatalogSliceEntries = AppendDirectGenericBuffs(CatalogSliceEntries, player, CatalogSliceEffects, CatalogSliceEffectEntries)
      CatalogScanPhase = 1
      CatalogScanIndex = 0
    EndIf
  EndIf
  If (CatalogScanPhase == 1 && budget > 0)
    budget = ConsumeCatalogSlice(player, DebuffEffects, DebuffLabels, "D", budget)
    If (CatalogScanIndex >= DebuffEffects.GetSize())
      FinishCatalogScan(player)
      Return
    EndIf
  EndIf
  StartTimer(0.05, 36)
EndFunction

Int Function ConsumeCatalogSlice(Actor player, FormList catalog, String[] labels, String category, Int budget)
  If (catalog == None || budget <= 0)
    Return budget
  EndIf
  Int catalogSize = catalog.GetSize()
  While (budget > 0 && CatalogScanIndex < catalogSize)
    CatalogSliceEntries = AppendOneCatalogEffect(CatalogSliceEntries, player, catalog, labels, category, CatalogSliceEffects, CatalogSliceEffectEntries, CatalogScanIndex, catalogSize)
    CatalogScanIndex += 1
    budget -= 1
  EndWhile
  Return budget
EndFunction

Function FinishCatalogScan(Actor player)
  CatalogScanActive = False
  CatalogSliceEntries = AppendDirectGenericDebuffs(CatalogSliceEntries, player, CatalogSliceEffects, CatalogSliceEffectEntries)
  CatalogSliceEntries = AppendActiveAfflictions(CatalogSliceEntries, player, CatalogSliceAfflictions, CatalogSliceAfflictionEntries)
  CatalogSliceEntries = AppendActiveEnvironmentalStatuses(CatalogSliceEntries, player, CatalogSliceSpells, CatalogSliceSpellEntries)
  QueueBuiltSnapshot(CatalogSliceCandidate, CatalogSliceEntries, CatalogSliceEffects, CatalogSliceEffectEntries, CatalogSliceAfflictions, CatalogSliceAfflictionEntries, CatalogSliceSpells, CatalogSliceSpellEntries, CatalogSliceForced, CatalogSliceRecovery)
EndFunction

; Starfield has no StringUtil. Character codes are enough to keep B: and D: rows in scan order.
Bool Function EntryHasPrefix(String entry, String prefix)
  If (entry == "" || prefix == "")
    Return False
  EndIf
  Int[] entryChars = Utility.SplitStringChars(entry)
  Int[] prefixChars = Utility.SplitStringChars(prefix)
  If (entryChars == None || prefixChars == None || entryChars.Length < prefixChars.Length)
    Return False
  EndIf
  Int index = 0
  While (index < prefixChars.Length)
    If (entryChars[index] != prefixChars[index])
      Return False
    EndIf
    index += 1
  EndWhile
  Return True
EndFunction

; Carries catalog rows that are still active so a removal or generic change does not walk both FormLists.
String[] Function AppendStillActiveCatalogSources(String[] entries, Actor player, MagicEffect[] sources, String[] sourceEntries, String prefix)
  If (player == None || ActiveSourceEffects == None || ActiveSourceEffectEntries == None || prefix == "")
    Return entries
  EndIf
  Int index = 0
  While (index < ActiveSourceEffects.Length && index < ActiveSourceEffectEntries.Length)
    MagicEffect effect = ActiveSourceEffects[index]
    String entry = ActiveSourceEffectEntries[index]
    If (effect != None && entry != "" && EntryHasPrefix(entry, prefix) && player.HasMagicEffect(effect))
      Bool suppressed = IsSuppressedSustenanceEntry(entries, entry)
      If (!ContainsEffectEntry(entries, entry) && !suppressed)
        entries.Add(entry)
      EndIf
      If (!HasMagicEffectInSources(sources, effect))
        sources.Add(effect)
        sourceEntries.Add(entry)
      EndIf
    EndIf
    index += 1
  EndWhile
  Return entries
EndFunction

Bool Function HasMagicEffectInSources(MagicEffect[] sources, MagicEffect effect)
  If (sources == None || effect == None)
    Return False
  EndIf
  Int index = 0
  While (index < sources.Length)
    If (sources[index] == effect)
      Return True
    EndIf
    index += 1
  EndWhile
  Return False
EndFunction

Spell Function ResolveToxicGasSpell()
  If (ToxicGasSpellResolved)
    Return CachedToxicGasSpell
  EndIf
  CachedToxicGasSpell = Game.GetFormFromFile(0x245B6B, "Starfield.esm") as Spell
  ToxicGasSpellResolved = CachedToxicGasSpell != None
  Return CachedToxicGasSpell
EndFunction

; Both the fast path and the finished catalog scan publish through this so the payload format stays one implementation.
Function QueueBuiltSnapshot(EffectSnapshot candidate, String[] entries, MagicEffect[] scanEffects, String[] scanEffectEntries, ENV_AfflictionScript[] scanAfflictions, String[] scanAfflictionEntries, Spell[] scanSpells, String[] scanSpellEntries, Bool forcedRefresh, Bool recoveryRefresh)
  Int buffCount = 0
  Int countIndex = 0
  While (entries != None && countIndex < entries.Length)
    If (entries[countIndex] != "" && EntryHasPrefix(entries[countIndex], "B:"))
      buffCount += 1
    EndIf
    countIndex += 1
  EndWhile
  Int debuffCount = 0
  If (entries != None)
    debuffCount = entries.Length - buffCount
  EndIf
  String signature = ""
  Int index = 0
  While (entries != None && index < entries.Length)
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
  String datagram = ""
  String framedPacket = ""
  Int framedLength = 0
  If (Registry != None)
    datagram = Registry.BuildCanvasDatagramBody("effects.state", 1, "ci-ascii", payload)
    framedPacket = Registry.BuildCanvasEventPacket(eventTopic, datagram)
    framedLength = Registry.GetCharacterCount(framedPacket)
  EndIf
  If (eventTopic == "" || datagram == "" || framedPacket == "" || framedLength > 4096)
    LogUserWarning(ModuleName, "PrepareEffectSnapshot", "EFFECT_DATAGRAM_REJECTED | Buffs=" + buffCount + " | Debuffs=" + debuffCount + " | Length=" + framedLength + " | Limit=4096")
    FinishEffectBuild(candidate, True)
    Return
  EndIf
  candidate.Signature = signature
  candidate.Payload = payload
  ; An unchanged forced scan must not schedule another one. Recovery is only for a payload the UI has not seen.
  candidate.RecoveryReplay = !recoveryRefresh && entriesChanged
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
    CancelTimer(33)
    StartTimer(0.1, 33)
  EndIf
EndFunction
