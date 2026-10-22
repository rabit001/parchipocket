# Flutter Source Location and Cross-PC Workflow

**Repository owner:** Rabit Mansuri (@rabit001)

The Flutter source has now been added to this repository at:

```text
mobile/parchipocket_flutter/
```

It includes `pubspec.yaml`, `pubspec.lock`, `lib/`, `test/`, `android/`, and `setup_android.ps1`. The actual app source should be edited in this folder.

## Use the project on another computer

1. Install GitHub Desktop, Flutter, and Android Studio on the other PC.
2. Sign in to GitHub Desktop as `rabit001` and clone `rabit001/parchipocket`.
3. Fetch/pull the latest changes before starting.
4. Open `mobile/parchipocket_flutter/` in Android Studio.
5. Run the following in a terminal whose current directory is that folder:

   ```powershell
   flutter doctor
   flutter pub get
   flutter devices
   flutter run
   ```

Android SDKs and emulator devices are machine-specific, so each PC needs its own Android SDK and emulator setup.

## Safe sync routine

Before stopping on one PC:
1. Review GitHub Desktop's Changes list.
2. Commit the working changes.
3. Push origin.

When switching to another PC:
1. Fetch origin and pull origin.
2. Open the same app folder.
3. Continue coding.

Avoid simultaneously editing the same files on both computers; resolve any merge conflicts before continuing.

The repository's root `.gitignore` is set to exclude common Flutter build outputs and machine-specific Android settings. Before committing, ensure the Changes list does not include passwords, API tokens, signing keys, or `android/local.properties`.
