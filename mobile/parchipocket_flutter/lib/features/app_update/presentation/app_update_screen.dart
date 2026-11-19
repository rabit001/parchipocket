import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ui.dart';
import '../domain/update_release.dart';
import 'app_update_manager.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({
    super.key,
    required this.state,
    required this.manager,
  });

  final AppState state;
  final AppUpdateManager manager;

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.manager.checkForUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.manager.onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.manager,
    builder: (context, _) {
      final manager = widget.manager;
      final release = manager.availableRelease;
      return PpScaffold(
        state: widget.state,
        title: 'App updates',
        backTo: 'settings',
        body: ListView(
          children: <Widget>[
            if (manager.status == AppUpdateStatus.checking)
              const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Current version: ${manager.installedVersion?.name ?? 'Checking…'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            _statusContent(manager, release),
            if (manager.errorMessage case final message?) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                message,
                key: const ValueKey<String>('update-error-message'),
                style: const TextStyle(color: PpColors.error, fontSize: 12),
              ),
            ],
            if (manager.status == AppUpdateStatus.available) ...<Widget>[
              const SizedBox(height: 14),
              PpPrimaryButton(
                'Download & Install',
                onPressed:
                    manager.isDownloading ? null : manager.downloadAndInstall,
              ),
            ],
            if (manager.status == AppUpdateStatus.downloading) ...<Widget>[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: manager.downloadProgress?.fraction,
                key: const ValueKey<String>('update-download-progress'),
              ),
              const SizedBox(height: 8),
              Text(
                manager.downloadProgress == null
                    ? 'Downloading update…'
                    : 'Downloaded ${_formatBytes(manager.downloadProgress!.receivedBytes)}'
                        '${manager.downloadProgress!.totalBytes == null ? '' : ' of ${_formatBytes(manager.downloadProgress!.totalBytes!)}'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (manager.status ==
                AppUpdateStatus.permissionRequired) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                'Android needs your permission to install apps downloaded outside Google Play. Allow ParchiPocket as an installation source, then return here. Android will still ask you to confirm the installation.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              PpPrimaryButton(
                'Open installation settings',
                onPressed: manager.openInstallPermissionSettings,
              ),
            ],
            if (manager.status ==
                AppUpdateStatus.waitingForInstaller) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Confirm the update in Android’s installer. ParchiPocket will verify the installed version when you return.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: manager.onAppResumed,
                child: const Text('Check installation status'),
              ),
            ],
            if (manager.status ==
                AppUpdateStatus.installationIncomplete) ...<Widget>[
              const SizedBox(height: 12),
              PpPrimaryButton(
                'Try installation again',
                onPressed: manager.installVerifiedUpdate,
              ),
            ],
            if (manager.status == AppUpdateStatus.installed) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'The updated version is installed.',
                key: ValueKey<String>('update-installed-confirmation'),
                style: TextStyle(
                  color: PpColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (manager.status == AppUpdateStatus.upToDate ||
                manager.status == AppUpdateStatus.error ||
                manager.status == AppUpdateStatus.unsupported) ...<Widget>[
              const SizedBox(height: 12),
              PpPrimaryButton(
                manager.canInstall ? 'Try installation again' : 'Retry check',
                onPressed:
                    manager.canInstall
                        ? manager.installVerifiedUpdate
                        : manager.checkForUpdates,
              ),
            ],
            if (manager.status == AppUpdateStatus.idle) ...<Widget>[
              const SizedBox(height: 12),
              PpPrimaryButton(
                'Check for updates',
                onPressed: manager.checkForUpdates,
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _statusContent(AppUpdateManager manager, BetaRelease? release) {
    if (manager.status == AppUpdateStatus.checking) {
      return const Text('Checking for a published Beta update…');
    }
    if (manager.status == AppUpdateStatus.available && release != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Version ${release.versionName} is available',
                key: const ValueKey<String>('update-available-version'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Beta release', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 12),
              Text(
                release.releaseNotes,
                key: const ValueKey<String>('update-release-notes'),
              ),
            ],
          ),
        ),
      );
    }
    if (manager.status == AppUpdateStatus.upToDate) {
      return const Text('ParchiPocket is up to date.');
    }
    if (manager.status == AppUpdateStatus.unsupported) {
      return const Text(
        'In-app updates are available for Android installations.',
      );
    }
    if (manager.status == AppUpdateStatus.installed) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AppUpdatePromptHost extends StatefulWidget {
  const AppUpdatePromptHost({
    super.key,
    required this.manager,
    required this.navigationReady,
    required this.onOpenUpdates,
    required this.child,
  });

  final AppUpdateManager manager;
  final bool navigationReady;
  final VoidCallback onOpenUpdates;
  final Widget child;

  @override
  State<AppUpdatePromptHost> createState() => _AppUpdatePromptHostState();
}

class _AppUpdatePromptHostState extends State<AppUpdatePromptHost> {
  bool _automaticCheckCompleted = false;
  bool _dialogOpen = false;
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onManagerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutomaticCheck());
  }

  @override
  void didUpdateWidget(covariant AppUpdatePromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.removeListener(_onManagerChanged);
      widget.manager.addListener(_onManagerChanged);
    }
    _maybePrompt();
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  Future<void> _startAutomaticCheck() async {
    if (!mounted) return;
    final performed = await widget.manager.checkAutomatically();
    if (!mounted) return;
    _automaticCheckCompleted = performed;
    _maybePrompt();
  }

  void _onManagerChanged() => _maybePrompt();

  void _maybePrompt() {
    if (!_automaticCheckCompleted ||
        !widget.navigationReady ||
        widget.manager.status != AppUpdateStatus.available ||
        _dialogOpen ||
        _promptShown ||
        widget.manager.isPromptDismissedForSession ||
        !mounted) {
      return;
    }
    setState(() {
      _promptShown = true;
      _dialogOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
  }

  Future<void> _showPrompt() async {
    if (!mounted || !widget.navigationReady) {
      _dialogOpen = false;
      _promptShown = false;
      return;
    }
    if (!widget.manager.shouldShowAutomaticPrompt || !mounted) {
      _dialogOpen = false;
      return;
    }
    final release = widget.manager.availableRelease;
    if (release == null) {
      _dialogOpen = false;
      return;
    }
    final startUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('ParchiPocket ${release.versionName} is available'),
            content: SingleChildScrollView(child: Text(release.releaseNotes)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Download & Install'),
              ),
            ],
          ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (startUpdate == true) {
      widget.onOpenUpdates();
    } else {
      await widget.manager.deferAutomaticPrompt();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
