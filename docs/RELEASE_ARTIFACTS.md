# Android Release Artifacts

APK and AAB files are build outputs, not application source. Keep them outside the tracked source tree in the root `release-assets/` directory. The directory is ignored by Git to prevent accidental commits of large binaries.

## Existing preserved artifact

The existing local debug APK remains at:

`release-assets/app-debug.apk`

It is intentionally excluded from GitHub. Its previously verified size is 175,285,953 bytes and its expected SHA-256 is:

`5B64D0A55D99DA8AA7B7B5785D6FCD06D463C74F1DB10904A16AA32B5662931D`

Do not overwrite this file when producing new builds.

## Recommended layout for future builds

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

Keep production upload keystores and passwords outside the repository and outside this artifact directory. Never commit local signing credentials.
