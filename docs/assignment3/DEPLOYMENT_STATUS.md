# Deployment and Submission Status

## Verified links

- **GitHub source repository:** https://github.com/rabit001/parchipocket
- **Demo video:** Not included by request; to be recorded and uploaded by the student.

## Public app URL

No public Android APK or verified live app URL is recorded in this file. A GitHub repository link is a source-code link, not an installed app or deployment URL. Do not label it as a live deployment.

## Recommended Android verification path

1. Open mobile/parchipocket_flutter/ in Android Studio.
2. Install the Flutter SDK and Android SDK if not already configured.
3. Run flutter pub get, flutter test --reporter compact, and flutter analyze.
4. Start an emulator or connect a test device, then run flutter devices and flutter run.
5. If all checks pass, create a release APK with flutter build apk --release.
6. Test the generated APK on a separate device before sharing it. Keep any Firebase production configuration and secrets out of the repository.
7. Upload the APK to an approved release/download location and record the actual URL here.

## Academic integrity and scope

The repository describes a development-stage project. A deployment URL, device test, peer review, or user interview should only be marked complete when it has actually happened and evidence is available. The browser-prototype test results are documented separately and must not be represented as Android device test results.
