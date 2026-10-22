# Add the Flutter Source to This Repository

**Repository owner:** Rabit Mansuri (@rabit001)

The documentation is already stored in this repository. The working Flutter project currently lives in a local folder on the development PC, so it must be copied into the cloned repository and pushed once.

## 1. Find the working Flutter project

In Android Studio, open the project folder that contains all of the following:

- `pubspec.yaml`
- `lib/`
- `test/`
- `setup_android.ps1`

Use the project root, not just the `lib/` folder and not the downloaded ZIP file. Close the app or stop the emulator before copying, to avoid copying actively generated files.

## 2. Clone this repository

1. Install and open GitHub Desktop: https://desktop.github.com/
2. Sign in to the GitHub account `rabit001`.
3. Choose **File → Clone Repository**.
4. Select `rabit001/parchipocket`.
5. Choose a local path, for example `Documents/GitHub/parchipocket`, then click **Clone**.

The repository already contains project documentation and a `.gitignore`. Clone it first; do not create a new repository or initialise another Git history.

## 3. Copy the app into the repository

In File Explorer, copy the **whole** local Flutter project folder (the one containing `pubspec.yaml`) into the cloned repository, using this destination:

```text
parchipocket/
└── mobile/
    └── parchipocket_flutter/
        ├── pubspec.yaml
        ├── lib/
        ├── test/
        ├── setup_android.ps1
        └── ...
```

Create the `mobile` folder if it does not already exist. Keep the project folder name `parchipocket_flutter` so the documentation matches.

Do not copy local build caches or secret/signing files. The repository's `.gitignore` excludes common Flutter and Android build outputs and local settings, including `.dart_tool/`, `build/`, `android/local.properties`, and signing files. Check the GitHub Desktop Changes list before committing; do not commit passwords, API tokens, keystores, or other credentials.

## 4. Commit and push

1. Return to GitHub Desktop.
2. Open **Changes** and review the listed files.
3. Enter the summary `Add ParchiPocket Flutter source`.
4. Click **Commit to main**.
5. Click **Push origin**.

After the push, open https://github.com/rabit001/parchipocket and confirm that `mobile/parchipocket_flutter/lib/` and `pubspec.yaml` are visible.

## 5. Continue from another PC

1. Install Flutter, Android Studio, and GitHub Desktop on the other PC.
2. Sign into GitHub Desktop as `rabit001` and clone `rabit001/parchipocket`.
3. Before starting work, click **Fetch origin** and then **Pull origin** if updates are available.
4. Open `mobile/parchipocket_flutter/` in Android Studio.
5. In the Android Studio terminal at that folder, run:

   ```powershell
   flutter doctor
   flutter pub get
   flutter devices
   flutter run
   ```

The Android SDK, emulator, and Flutter SDK are machine-specific tools. They must be installed/configured separately on each PC. Code sync through GitHub does not copy an emulator or SDK installation.
