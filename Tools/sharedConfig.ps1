# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

if ([System.IO.Directory]::Exists("./Staging")) {
  if ((Get-Item -Path "./Staging").LinkType -ne "Junction") {
    Write-Host -ForegroundColor Red "Staging is no longer a Junction. Please delete it and rerun the setupRepo script."
    Exit
  }
}

If (![System.IO.File]::Exists(".env")) {
  Write-Host -ForegroundColor Red "ERROR: .env file must be created and configured to run this."
  Exit
}

Write-Host -ForegroundColor Green "Importing ENV Settings from .env file"
Get-Content .env | ForEach-Object {
  $name, $value = $_.split('=')
  $name.trim() | Out-Null
  if (!$name.StartsWith('#') || ![string]::IsNullOrWhitespace($name) || ![string]::IsNullOrWhitespace($value)) {
    $value.trim() | Out-Null
    Set-Item -Path "env:$name" -Value "$value"
  }
}

Write-Host -ForegroundColor Yellow "`nSteam Settings:"
Write-Host -ForegroundColor Yellow "Starfield game folder is set to $ENV:STEAM_GAME_FOLDER."
Write-Host -ForegroundColor Yellow "Starfield data folder is set to $ENV:STEAM_DATA_FOLDER."
Write-Host -ForegroundColor Yellow "`nModule Settings:"
Write-Host -ForegroundColor Yellow "Module Database Folder is $ENV:MODULE_DATABASE_PATH"

$Global:SharedConfigurationLoaded=$true
