part of '../auth_screens.dart';

class AuthSessionLoadingScreen extends StatelessWidget {
  const AuthSessionLoadingScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PpBrandLogo(height: 58),
                SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(height: 12),
                Text(
                  'Checking your account…',
                  style: TextStyle(
                    fontSize: 12,
                    color: PpColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class ProfileLoadErrorScreen extends StatelessWidget {
  const ProfileLoadErrorScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_outlined,
                      size: 42, color: PpColors.error),
                  const SizedBox(height: 14),
                  const Text(
                    'Could not verify your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.cloudError ?? 'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: PpColors.secondary),
                  ),
                  const SizedBox(height: 20),
                  PpPrimaryButton(
                    'Retry',
                    onPressed: state.isCloudLoading
                        ? null
                        : () => state.retryProfileLoad(),
                  ),
                  const SizedBox(height: 8),
                  PpSecondaryButton('Log Out',
                      onPressed: () => state.go('logout')),
                ],
              ),
            ),
          ),
        ),
      );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const PpBrandLogo(height: 68),
                          const SizedBox(height: 10),
                          const Text('Every small purchase, properly recorded.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: PpColors.secondary, fontSize: 14)),
                          const SizedBox(height: 8),
                          const Text(
                              'Daily household spending, captured by voice or manually.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: PpColors.secondary, fontSize: 12)),
                          const SizedBox(height: 42),
                          PpPrimaryButton('Get Started',
                              onPressed: () => state.go('login')),
                        ])))),
      );
}
