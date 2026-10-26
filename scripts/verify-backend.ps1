param(
  [switch]$RunAndroidIntegration,
  [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$FlutterRoot = Join-Path $RepoRoot "mobile\parchipocket_flutter"
$EmulatorProjectId = "demo-parchipocket-phase4"
$PreviousProjectId = $env:FIRESTORE_EMULATOR_PROJECT_ID
$env:FIRESTORE_EMULATOR_PROJECT_ID = $EmulatorProjectId

function Invoke-Checked {
  param(
    [string]$Program,
    [string[]]$Arguments,
    [string]$Label
  )
  Write-Host ("== " + $Label + " ==") -ForegroundColor Cyan
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

try {
  Push-Location $FlutterRoot
  try {
    Invoke-Checked "flutter" @("pub", "get") "Resolve Flutter dependencies"
    Invoke-Checked "flutter" @("test", "--reporter", "compact") "Flutter unit/widget tests"
    Invoke-Checked "flutter" @("analyze") "Flutter static analysis"
  } finally {
    Pop-Location
  }

  Invoke-Checked "node" @("--check", (Join-Path $RepoRoot "test_rules.js")) "Check rules harness syntax"
  Invoke-Checked "npx" @(
    "--yes", "firebase-tools@latest", "emulators:exec",
    "--only", "firestore,auth",
    "--project", $EmulatorProjectId,
    "node test_rules.js"
  ) "Firestore/Auth rules harness on local emulators"

  if ($RunAndroidIntegration) {
    Push-Location $FlutterRoot
    try {
      $devicesJson = & flutter devices --machine
      if ($LASTEXITCODE -ne 0) {
        throw "Could not query Flutter devices."
      }
      $devices = $devicesJson | ConvertFrom-Json
      $device = $devices | Where-Object { $_.id -eq $DeviceId -and $_.emulator -eq $true } | Select-Object -First 1
      if (-not $device) {
        throw "Android emulator '$DeviceId' is not online. Check 'flutter devices' first."
      }
    } finally {
      Pop-Location
    }

    $command = 'cd /d "' + $FlutterRoot + '" && flutter test integration_test\firestore_service_emulator_test.dart -d ' + $DeviceId + ' --reporter compact'
    Invoke-Checked "npx" @(
      "--yes", "firebase-tools@latest", "emulators:exec",
      "--only", "firestore,auth",
      "--project", $EmulatorProjectId,
      $command
    ) "Dart Firestore/Auth integration tests on Android emulator"
  }

  Write-Host "Backend verification completed successfully." -ForegroundColor Green
} finally {
  if ($null -eq $PreviousProjectId) {
    Remove-Item Env:FIRESTORE_EMULATOR_PROJECT_ID -ErrorAction SilentlyContinue
  } else {
    $env:FIRESTORE_EMULATOR_PROJECT_ID = $PreviousProjectId
  }
}
