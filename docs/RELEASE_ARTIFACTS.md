# Android Release Artifacts

APK/AAB files are build outputs, not application source. Do not commit them into the Flutter source tree. The local packaging script writes to the root `release-assets/` directory, which is ignored by Git.

## Published GitHub debug release

The [latest published debug preview](https://github.com/rabit001/parchipocket/releases/latest) is always linked through the Releases page. The preceding published preview was:

- Release: [ParchiPocket v0.1.1 Debug Preview](https://github.com/rabit001/parchipocket/releases/tag/v0.1.1-debug)
- APK asset: [app-debug.apk](https://github.com/rabit001/parchipocket/releases/download/v0.1.1-debug/app-debug.apk)
- APK size: 180,323,122 bytes
- APK SHA-256: `3cf6327ef7f084ec271f407ce1b5b5a594559095442773e65e0aed3278bfa24a`
- Checksum asset: `app-debug.apk.sha256`

This is a debug-signed testing build. It is not a production-signed APK or Play Store release.

The `v0.1.1-debug` release tag was created while the Flutter package metadata still said `0.1.0+1`. This cleanup updates the app package version to `0.1.2+2`; after this change reaches `main` and all checks pass, the next automatic debug release will be tagged `v0.1.2-debug`.

## Standard local layout

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

Run from the repository root after building the app:

```powershell
.\scripts\package-android-artifacts.ps1 -Variant debug -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-debug.apk"

.\scripts\package-android-artifacts.ps1 -Variant release -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-release.apk" -AabPath ".\mobile\parchipocket_flutter\build\app\outputs\bundle\release\app-release.aab"
```

The script copies the supplied files, verifies the copy against the source with SHA-256, and regenerates `android/checksums/SHA256SUMS.txt`. It does not build, sign, or modify an APK/AAB.

## Automatic GitHub publishing

The `ParchiPocket backend validation` workflow builds the debug APK on pushes to `main`. It publishes the APK and a SHA-256 sidecar to a prerelease GitHub Release only after the Flutter tests, Firestore rules harness, and Android emulator integration job all pass.

The release tag is derived from the app version in `mobile/parchipocket_flutter/pubspec.yaml`, followed by `-debug`. Increment both the semantic version and Android build number before preparing the next app release.

Keep production upload keystores and passwords outside the repository. Never commit signing credentials.
