# Explicit production rules deployment. This script is interactive and is never used by CI.
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VerifyScript = Join-Path $PSScriptRoot "verify-backend.ps1"

Write-Host "ParchiPocket Firestore rules deployment" -ForegroundColor Yellow
Write-Host "Target Firebase project: parchipocket" -ForegroundColor Red
Write-Host "Preflight uses local demo emulators and requires an online Android emulator."

# Do not reach the confirmation prompt unless unit tests, analysis, rules tests, and
# Android Dart integration tests all pass.
& $VerifyScript -RunAndroidIntegration -DeviceId "emulator-5554"

Write-Host "WARNING: the next command publishes firestore.rules to the live Firebase project." -ForegroundColor Red
$confirmation = Read-Host "Type exactly DEPLOY parchipocket to continue"
if ($confirmation -cne "DEPLOY parchipocket") {
  throw "Deployment cancelled. No live Firebase rules were changed."
}

Push-Location $RepoRoot
try {
  & npx --yes firebase-tools@latest deploy --only firestore:rules --project parchipocket
  if ($LASTEXITCODE -ne 0) {
    throw "Firebase rules deployment failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}

Write-Host "Deployment command completed. Verify the deployed rules and timestamp in Firebase Console." -ForegroundColor Green
