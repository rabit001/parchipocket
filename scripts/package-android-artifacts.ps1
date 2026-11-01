param(
    [ValidateSet("debug", "release")]
    [string]$Variant = "debug",

    [string]$ApkPath,

    [string]$AabPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = Join-Path $repoRoot "release-assets"
$androidRoot = Join-Path $artifactRoot "android"
$packaged = [System.Collections.Generic.List[string]]::new()

function Copy-VerifiedArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$ExpectedExtension
    )

    $resolvedSource = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $resolvedSource -PathType Leaf)) {
        throw "Artifact is not a file: $SourcePath"
    }

    if ([System.IO.Path]::GetExtension($resolvedSource).ToLowerInvariant() -ne $ExpectedExtension) {
        throw "Expected a $ExpectedExtension artifact: $SourcePath"
    }

    $destinationDirectory = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $resolvedSource -Destination $DestinationPath -Force

    $sourceHash = (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash
    $copiedHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $copiedHash) {
        throw "SHA-256 verification failed after copying: $DestinationPath"
    }

    $packaged.Add($DestinationPath)
    Write-Host ("Verified {0}  {1}" -f $copiedHash, $DestinationPath)
}

if ([string]::IsNullOrWhiteSpace($ApkPath) -and [string]::IsNullOrWhiteSpace($AabPath)) {
    throw "Pass -ApkPath, -AabPath, or both. No build is started by this packaging script."
}

if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $apkName = if ($Variant -eq "debug") { "parchipocket-debug.apk" } else { "parchipocket-release.apk" }
    $apkDirectory = Join-Path $androidRoot $Variant
    Copy-VerifiedArtifact -SourcePath $ApkPath -DestinationPath (Join-Path $apkDirectory $apkName) -ExpectedExtension ".apk"
}

if (-not [string]::IsNullOrWhiteSpace($AabPath)) {
    if ($Variant -ne "release") {
        throw "Android App Bundles are release artifacts. Use -Variant release when passing -AabPath."
    }
    $bundleDirectory = Join-Path $androidRoot "bundles"
    Copy-VerifiedArtifact -SourcePath $AabPath -DestinationPath (Join-Path $bundleDirectory "parchipocket-release.aab") -ExpectedExtension ".aab"
}

$checksumDirectory = Join-Path $androidRoot "checksums"
New-Item -ItemType Directory -Path $checksumDirectory -Force | Out-Null
$checksumFile = Join-Path $checksumDirectory "SHA256SUMS.txt"
$allArtifacts = Get-ChildItem -LiteralPath $androidRoot -Recurse -File |
    Where-Object { $_.Extension -in @(".apk", ".aab") } |
    Sort-Object FullName

$lines = foreach ($file in $allArtifacts) {
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $relativePath = $file.FullName.Substring($repoRoot.Length + 1).Replace("\\", "/")
    "{0} *{1}" -f $hash, $relativePath
}
[System.IO.File]::WriteAllLines($checksumFile, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Android artifacts packaged and SHA-256 checksums written:"
Write-Host "  $checksumFile"
