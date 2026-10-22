# Developer Setup Guide

These instructions target Windows with Android Studio and Flutter installed. Setup requirements may vary across machines and Flutter versions.

## 1. Get the source

The Flutter project is checked into this repository at `mobile/parchipocket_flutter/`. Clone the repository and open that folder, the one containing `pubspec.yaml`, in Android Studio.

## 2. Verify tools

Open a terminal at the project root:

```powershell
flutter --version
flutter doctor
```

Resolve any blocking Flutter or Android toolchain issues reported by `flutter doctor`.

## 3. Fetch Dart dependencies

```powershell
flutter pub get
```

## 4. Generate Android platform files only if needed

The archive includes `setup_android.ps1`. If the project does not contain the generated `android/` directory, run the script from the project root:

```powershell
.\setup_android.ps1
```

Do not rerun this unnecessarily if the existing generated Android project is already in place.

## 5. Start a device

Start an Android Virtual Device in Android Studio's Device Manager or connect an Android phone with USB debugging enabled. Verify:

```powershell
flutter devices
```

## 6. Run the app

```powershell
flutter run
```

Demo OTP: `123456`. It is a hard-coded demo value, not real authentication.

## 7. Run tests

```powershell
flutter test
```

The tests are a starting point, not evidence that every workflow or integration is production-ready.

## Troubleshooting

- **Flutter not recognised:** add the Flutter SDK's `bin` directory to Windows PATH, reopen the terminal, and run `flutter doctor`.
- **No device listed:** start the emulator fully or reconnect/authorise the physical device, then run `flutter devices`.
- **Packages missing:** run `flutter pub get` from the directory containing `pubspec.yaml`.
- **Android folder missing:** run `setup_android.ps1` from the project root after verifying the Flutter and Android toolchain.
- **Data disappears on restart:** expected for this starter because the demo state is in memory. Persistent storage is still to be built.
