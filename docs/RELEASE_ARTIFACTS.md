# Android Release Artifacts

APK/AAB files are build outputs, not application source. Do not commit them into the Flutter source tree. Local packaging scripts write to the ignored root-level release-assets directory.

## Latest signed Beta

**ParchiPocket Beta 0.1.5+5**

- Release: [parchipocket-beta-v0.1.5-5](https://github.com/rabit001/parchipocket/releases/tag/parchipocket-beta-v0.1.5-5)
- APK: [parchipocket-release.apk](https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v0.1.5-5/parchipocket-release.apk)
- SHA-256: `0bca2356aa0ba24b14310f7196af8793443045630db819e3007f0128bfadeea2`
- Package ID: `com.parchipocket.app.parchipocket`
- Version name: `0.1.5`
- Android version code: `5`
- Signing certificate SHA-256: `41:26:46:C1:E3:5B:96:22:9F:F4:63:8C:3A:C9:3B:D0:FB:0C:BC:1F:3F:41:27:37:03:B6:CB:90:30:A2:D8:3C`
- Workflow: [GitHub Actions run 43647296051](https://github.com/rabit001/parchipocket/actions/runs/43647296051)

The APK is a signed Beta prerelease. It is not a Play Store production release. The Android package installer still requires user approval. Preserve the existing installation if Android reports a signing conflict; do not uninstall without a data-migration plan.

## Release assets

Each signed Beta prerelease contains:

- parchipocket-release.apk
- parchipocket-release.apk.sha256
- app-update-manifest.json

The manifest declares the Beta channel, Android package ID, version name, version code, APK asset name, SHA-256, release notes, and publication timestamp. The in-app updater checks release metadata, verifies the APK checksum, and hands the verified APK to Android's package installer.

## Standard local layout

~~~text
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
~~~

## Package a local build on Windows

Run from the repository root after building the app:

~~~powershell
.\scripts\package-android-artifacts.ps1 -Variant debug -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-debug.apk"

.\scripts\package-android-artifacts.ps1 -Variant release -ApkPath ".\mobile\parchipocket_flutter\build\app\outputs\flutter-apk\app-release.apk" -AabPath ".\mobile\parchipocket_flutter\build\app\outputs\bundle\release\app-release.aab"
~~~

The script copies supplied files, verifies copies with SHA-256, and regenerates the checksum list. It does not build or sign APK/AAB files.

## Publishing a signed Beta

The workflow is .github/workflows/publish-beta-release.yml. After this repository's integration PR is merged, the workflow is intended to be manually dispatched from main using the protected direct-apk-release environment and its existing signing secrets.

Before dispatch:

1. Increment both the semantic version and Android build number in mobile/parchipocket_flutter/pubspec.yaml.
2. Run Flutter tests, analysis, and relevant Firebase emulator checks.
3. Review release notes and inspect the exact workflow inputs.
4. Supply the already-approved release certificate SHA-256 fingerprint.
5. Dispatch the workflow from main; do not create or reuse a published tag.
6. Verify the package ID, signing certificate, APK checksum, manifest, prerelease status, and published assets.

Never commit the upload keystore, passwords, private keys, or signing environment files. Keep the direct-apk-release environment protected.
