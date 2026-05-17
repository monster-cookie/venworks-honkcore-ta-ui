# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# If not loaded already pull in the shared config
if (!$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot\sharedConfig.ps1"
}

If (![System.IO.File]::Exists(".env")) {
  Write-Host -ForegroundColor Red "ERROR: .env file must be created and configured to run this."
  Exit
}

foreach ($variant in $Global:Variants) {
  Write-Host -ForegroundColor Cyan "Validating variant $($variant.VariantName) in $($variant.StagingFolderPath)"

  if (![System.IO.Directory]::Exists($variant.StagingFolderPath)) {
    Write-Host -ForegroundColor Red "$($variant.VariantName) variant Staging folder doesn't exist. Please rerun the setupRepo script."
    Exit
  }

  if ([System.IO.Directory]::Exists("$($variant.StagingFolderPath)")) {
    if ((Get-Item -Path "$($variant.StagingFolderPath)").LinkType -ne "Junction") {
      Write-Host -ForegroundColor Red "$($variant.VariantName) variant Staging folder is no longer a Junction. Please delete it and rerun the setupRepo script."
      Exit
    }
  }
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**           Folder Junctions Valid             **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
