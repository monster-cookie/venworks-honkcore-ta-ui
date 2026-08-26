@{
  Severity = @(
    'Error'
    'Warning'
  )
  ExcludeRules = @(
    # These scripts deliberately use Write-Host for operator-facing progress,
    # status, and installation output where host formatting is part of the UX.
    'PSAvoidUsingWriteHost'

    # Shared release configuration is dot-sourced and intentionally publishes
    # the variant inventory and load sentinel for repository entry points.
    'PSAvoidGlobalVars'

    # Internal collection helpers use plural nouns to describe plural results.
    'PSUseSingularNouns'

    # Apply-ActionScriptPatch is an internal helper whose established name
    # precisely describes its patching behavior.
    'PSUseApprovedVerbs'

    # State-changing helpers are private implementation details rather than
    # exported commands with user-facing WhatIf and Confirm contracts.
    'PSUseShouldProcessForStateChangingFunctions'

    # Repository text files use UTF-8 without a BOM across PowerShell versions.
    'PSUseBOMForUnicodeEncodedFile'
  )
}
