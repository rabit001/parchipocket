# Android Release Artifacts

APK and AAB files are build outputs, not application source. Keep them outside the tracked source tree in the root `release-assets/` directory. The directory is ignored by Git to prevent accidental commits of large binaries.

## Existing preserved artifact

The previously verified local debug APK is retained at:

`release-assets/app-debug.apk`

It is intentionally excluded from GitHub. Its recorded size is 175,285,953 bytes and its expected SHA-256 is:

`5B64D0A55D99DA8AA7B7B5785D6FCD06D463C74F1DB10904A16AA32B5662931D`

Keep this legacy copy unchanged while validating a newer build. New builds use the structured layout below.

## Standard layout

```text
release-assets/
└── android/
    ├── debug/
    │   └── parchipocket-debug.apk
    ├── release/
    │   └── parchipocket-release.apk
    ├── bundles/
    │   └── parchipocket-release.aab
    └── checksums/
        └── SHA256SUMS.txt
```

## Package a build on Windows

Run these commands from the repository root after building the app:

```powershell
.\scripts\package-android-artifacts.ps1 -Variant debug -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-debug.apk"

.\scripts\package-android-artifacts.ps1 -Variant release -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-release.apk" -AabPath ".\mobile\parchipocket_flutter\build\app\outputs\bundle\release\app-release.aab"
```

The script copies the supplied artifacts into the standard folders, verifies each copied file against its source with SHA-256, and rewrites `android/checksums/SHA256SUMS.txt` for the APK/AAB files currently present. It does not build, sign, or modify the source APK/AAB.

Keep production upload keystores and passwords outside the repository and outside this artifact directory. Never commit local signing credentials.
