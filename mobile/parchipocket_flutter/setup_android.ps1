$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Temp = Join-Path $env:TEMP 'parchipocket_flutter_android_scaffold'

Write-Host 'Generating Android platform files with your installed Flutter SDK...'
if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
flutter create --platforms=android --org com.parchipocket.app --project-name parchipocket $Temp

if (-not (Test-Path (Join-Path $Temp 'android'))) {
  throw 'Flutter did not create an android/ directory. Check `flutter doctor` and try again.'
}
Copy-Item (Join-Path $Temp 'android') (Join-Path $Root 'android') -Recurse -Force
if (Test-Path (Join-Path $Temp '.metadata')) { Copy-Item (Join-Path $Temp '.metadata') (Join-Path $Root '.metadata') -Force }
if (Test-Path (Join-Path $Temp '.gitignore')) { Copy-Item (Join-Path $Temp '.gitignore') (Join-Path $Root '.gitignore') -Force }
Remove-Item $Temp -Recurse -Force

Set-Location $Root
Write-Host 'Android project files added. Fetching packages...'
flutter pub get
Write-Host ''
Write-Host 'Setup complete. Start an emulator or connect an Android phone, then run:'
Write-Host '  flutter run'
