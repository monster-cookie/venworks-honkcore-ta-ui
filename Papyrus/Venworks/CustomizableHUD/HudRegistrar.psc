ScriptName Venworks:CustomizableHUD:HudRegistrar Extends Venworks:CustomizableHUD:HudEffectsPublisher
Import Venworks:Canvas:Registry

String Property ConsumerId Auto Const Mandatory
String Property DisplayName Auto Const Mandatory
String Property NormalMoviePath Auto Const Mandatory
String Property LargeMoviePath Auto Const Mandatory
Int Property DescriptorVersion Auto Const Mandatory
Bool Property ExpectedRegistration Auto Const Mandatory
; Retained for ESM and saved-script compatibility; startup no longer waits on this value.
Float Property InitialDelaySeconds Auto Const Mandatory

String RegistrarModuleName = "CustomizableHUD:HudRegistrar"
Guard AttemptGuard ProtectsFunctionLogic
String ActiveDisplayName
String ActiveNormalMovieUrl
String ActiveLargeMovieUrl
Int ActiveDescriptorVersion = 0
Bool PendingUpdate = False
String PendingDisplayName
String PendingNormalMovieUrl
String PendingLargeMovieUrl
Int PendingDescriptorVersion = 0

Event OnInit()
  Parent.OnInit()
  StartTimer(0.1, 1)
EndEvent

Event OnMenuOpenCloseEvent(String menuName, Bool opening)
  Parent.OnMenuOpenCloseEvent(menuName, opening)
  If (opening)
    StartTimer(0.1, 1)
  EndIf
EndEvent

Event OnTimer(Int aiTimerID)
  If (aiTimerID >= 1 && aiTimerID <= 20)
    ProcessAttempt(aiTimerID)
  Else
    Parent.OnTimer(aiTimerID)
  EndIf
EndEvent

; Compatibility entry point. A positive result acknowledges only the expected Papyrus result, never UI readiness.
Bool Function RegisterWithRetry()
  Return ProcessAttempt(1)
EndFunction

; One attempt followed by diagnostics and optional scheduling, all outside the acquired guards.
Bool Function ProcessAttempt(Int attempt)
  OperationResult result = TryReconcile()
  If (result.Status == "REGISTRATION_UNCHANGED" && !result.UpdateApplied)
    result.UiLoad = "UI_LOAD_ACTIVATION_REPLAY"
  EndIf
  RequestRegisteredUi(result)
  ReportAttempt(result)
  Bool retryUi = IsDeferred(result.UiLoad) && result.UiLoad != "DEFERRED_UI_INACTIVE"
  If (IsDeferred(result.Status) || retryUi)
    If (attempt < 20)
      StartTimer(0.5, attempt + 1)
    Else
      LogUserWarning(RegistrarModuleName, "ProcessAttempt", "REGISTRATION_RETRY_EXHAUSTED | Pending data retained; later HUD opening or explicit request may retry.")
    EndIf
  EndIf
  Return IsRegistrationAccepted(result.Status) || result.Status == "EXPECTED_REGISTRATION_REJECTION"
EndFunction

; Holds AttemptGuard for one non-waiting host transaction. Registry never calls back into a registrar.
OperationResult Function TryReconcile()
  If (Registry != None)
    Registry.EnsureMenuSubscriptions()
  EndIf
  OperationResult result = NewResult("DEFERRED_ATTEMPT_BUSY")
  TryLockGuard AttemptGuard
    EnsureActiveDescriptor()
    If (PendingUpdate)
      result = ApplyPendingUpdateLocked()
    Else
      result = AttemptDescriptorRegistration(ActiveDisplayName, ActiveNormalMovieUrl, ActiveLargeMovieUrl, ActiveDescriptorVersion, ExpectedRegistration)
    EndIf
  EndTryLockGuard
  Return result
EndFunction

; Compatibility Boolean: true means accepted; false may mean deferred. Explicit callers must retain input until accepted.
Bool Function ApplyDescriptorUpdate(String updatedDisplayName, String updatedNormalMovieUrl, String updatedLargeMovieUrl, Int updatedDescriptorVersion)
  OperationResult result = TryApplyDescriptorUpdate(updatedDisplayName, updatedNormalMovieUrl, updatedLargeMovieUrl, updatedDescriptorVersion)
  RequestRegisteredUi(result)
  ReportAttempt(result)
  If (IsDeferred(result.Status) || IsDeferred(result.UiLoad))
    StartTimer(0.5, 1)
  EndIf
  Return IsRegistrationAccepted(result.Status)
EndFunction

; Busy AttemptGuard means input was NOT retained: the caller must resubmit the same request.
; Once acquired, retain the entire pending descriptor before contacting the registry. No waiting/logging inside the guard.
OperationResult Function TryApplyDescriptorUpdate(String updatedDisplayName, String updatedNormalMovieUrl, String updatedLargeMovieUrl, Int updatedDescriptorVersion)
  If (Registry != None)
    Registry.EnsureMenuSubscriptions()
  EndIf
  OperationResult result = NewResult("DEFERRED_ATTEMPT_BUSY")
  TryLockGuard AttemptGuard
    EnsureActiveDescriptor()
    PendingDisplayName = updatedDisplayName
    PendingNormalMovieUrl = updatedNormalMovieUrl
    PendingLargeMovieUrl = updatedLargeMovieUrl
    PendingDescriptorVersion = updatedDescriptorVersion
    PendingUpdate = True
    result = ApplyPendingUpdateLocked()
  EndTryLockGuard
  Return result
EndFunction

; Caller holds AttemptGuard. Commit active state on registration acceptance, regardless of disabled/deferred UI transport.
OperationResult Function ApplyPendingUpdateLocked()
  OperationResult result = AttemptDescriptorRegistration(PendingDisplayName, PendingNormalMovieUrl, PendingLargeMovieUrl, PendingDescriptorVersion, True)
  If (IsRegistrationAccepted(result.Status))
    ActiveDisplayName = PendingDisplayName
    ActiveNormalMovieUrl = PendingNormalMovieUrl
    ActiveLargeMovieUrl = PendingLargeMovieUrl
    ActiveDescriptorVersion = PendingDescriptorVersion
    PendingUpdate = False
    result.UpdateApplied = True
  ElseIf (!IsDeferred(result.Status))
    PendingUpdate = False
  EndIf
  Return result
EndFunction

; Initializes saved active fields only until an explicit accepted update has replaced the VMAD defaults.
Function EnsureActiveDescriptor()
  If (ActiveDescriptorVersion < 1)
    ActiveDisplayName = DisplayName
    ActiveNormalMovieUrl = NormalMoviePath
    ActiveLargeMovieUrl = LargeMoviePath
    ActiveDescriptorVersion = DescriptorVersion
  EndIf
EndFunction

; Compatibility explicit-descriptor entry point: one nonblocking attempt. On false, the caller retains/retries its supplied input.
Bool Function RegisterDescriptorWithRetry(String requestedDisplayName, String requestedNormalMovieUrl, String requestedLargeMovieUrl, Int requestedDescriptorVersion, Bool expectedResult)
  If (Registry != None)
    Registry.EnsureMenuSubscriptions()
  EndIf
  OperationResult result = NewResult("DEFERRED_ATTEMPT_BUSY")
  TryLockGuard AttemptGuard
    result = AttemptDescriptorRegistration(requestedDisplayName, requestedNormalMovieUrl, requestedLargeMovieUrl, requestedDescriptorVersion, expectedResult)
  EndTryLockGuard
  RequestRegisteredUi(result)
  ReportAttempt(result)
  Return IsRegistrationAccepted(result.Status) || result.Status == "EXPECTED_REGISTRATION_REJECTION"
EndFunction

; Caller holds AttemptGuard. All host calls are nonblocking receipts without logging or callbacks.
OperationResult Function AttemptDescriptorRegistration(String requestedDisplayName, String requestedNormalMovieUrl, String requestedLargeMovieUrl, Int requestedDescriptorVersion, Bool expectedResult)
  If (Registry == None)
    Return NewResult("DEFERRED_REGISTRY_UNAVAILABLE")
  EndIf
  String registrationId = ResolveRegistrationId()
  OperationResult result = Registry.TryRegisterConsumer(Self, registrationId, requestedDisplayName, requestedNormalMovieUrl, requestedLargeMovieUrl, requestedDescriptorVersion)
  If (IsDeferred(result.Status))
    Return result
  EndIf
  If (IsRegistrationAccepted(result.Status))
    If (expectedResult)
      result.UiLoad = "UI_LOAD_REQUEST_NEEDED"
    Else
      OperationResult removal = Registry.TryUnregisterConsumer(Self, registrationId)
      If (IsDeferred(removal.Status))
        Return removal
      EndIf
      result.Status = "UNEXPECTED_REGISTRATION_ACCEPTANCE"
      result.Detail = "Negative fixture accepted; cleanup=" + removal.Status
    EndIf
  ElseIf (!expectedResult && (result.Status == "REGISTRATION_REJECTED" || result.Status == "REJECTED_OWNER_MISMATCH"))
    result.Detail = result.Status + " | " + result.Detail
    result.Status = "EXPECTED_REGISTRATION_REJECTION"
  EndIf
  Return result
EndFunction

; An accepted descriptor may defer UI independently; schedule this consumer's own bounded reconciliation.
Function RetryRegisteredUi()
  StartTimer(0.5, 1)
EndFunction

; The consumer's explicit second step. Registration workers only mark intent; invoke outside all guards.
Function RequestRegisteredUi(OperationResult result)
  If (Registry != None && IsRegistrationAccepted(result.Status) && result.UiLoad == "UI_LOAD_REQUEST_NEEDED")
    OperationResult loadResult = Registry.TryRequestUiLoad(Self, result.ConsumerId)
    result.UiLoad = loadResult.Status
    Registry.LogOperation(loadResult)
  EndIf
EndFunction

; Diagnostics consume the per-call receipt only after AttemptGuard and RegistryGuard have both ended.
Function ReportAttempt(OperationResult result)
  If (Registry != None)
    Registry.LogOperation(result)
  EndIf
  If (IsRegistrationAccepted(result.Status))
    LogUserInformational(RegistrarModuleName, "ReportAttempt", "REGISTRATION_ACK | Consumer=" + result.ConsumerId + " | LoadUI=" + result.UiLoad)
    If (result.UpdateApplied)
      LogUserInformational(RegistrarModuleName, "ReportAttempt", "DESCRIPTOR_UPDATE_APPLIED | Version=" + result.DescriptorVersion + " | Retained independently of UI transport.")
    EndIf
  ElseIf (result.Status == "EXPECTED_REGISTRATION_REJECTION")
    LogUserInformational(RegistrarModuleName, "ReportAttempt", "EXPECTED_REGISTRATION_REJECTION | No UI load requested.")
  ElseIf (IsDeferred(result.Status))
    LogUserWarning(RegistrarModuleName, "ReportAttempt", "DESCRIPTOR_UPDATE_PENDING / REGISTRATION_DEFERRED | " + result.Status + " | Busy caller must retain unsubmitted input.")
  Else
    LogUserWarning(RegistrarModuleName, "ReportAttempt", "Unexpected terminal registration result | " + result.Status + " | No automatic retry.")
  EndIf
EndFunction

; Pure identity resolution; a busy host can never become an empty/invalid UUID.
String Function ResolveRegistrationId()
  If (Venworks:Core:Utilities:UUID.IsValid(ConsumerId))
    Return Venworks:Core:Utilities:UUID.Normalize(ConsumerId)
  EndIf
  Return ""
EndFunction
