part of '../customer_screens.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final modeLabel = state.isDemoMode
        ? 'Home & Family · Local demo mode'
        : 'Home & Family · Cloud synced';
    final initials = state.customerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return PpScaffold(
        state: state,
        title: 'Profile',
        showBack: false,
        bottomNav: true,
        bottomTab: 'customerProfile',
        body: ListView(children: <Widget>[
          const SizedBox(height: 6),
          Center(child: _ProfilePhotoControl(state: state, initials: initials)),
          const SizedBox(height: 11),
          Center(
              child: Text(state.customerName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Center(
              child: Text(modeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: PpColors.secondary))),
          const SizedBox(height: 14),
          PpSecondaryButton('Edit Profile',
              onPressed: () => state.go('editProfile')),
          const SizedBox(height: 14),
          _ProfileLink(
              icon: Icons.shopping_bag_outlined,
              label: 'Daily Spending Log',
              onTap: () => state.go('householdExpenses')),
          _ProfileLink(
              icon: Icons.receipt_long_outlined,
              label: 'Receipt QR History',
              onTap: () => state.go('bills')),
          _ProfileLink(
              icon: Icons.pie_chart_outline,
              label: 'Spending Insights',
              onTap: () => state.go('insights')),
          _ProfileLink(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => state.go('settings')),
          _ProfileLink(
              icon: Icons.support_agent,
              label: 'Help & Support',
              onTap: () => state.go('help')),
          _ProfileLink(
              icon: Icons.shield_outlined,
              label: 'Privacy & Security',
              onTap: () => state.go('privacy')),
          _ProfileLink(
              icon: Icons.star_border,
              label: 'Rate the App',
              onTap: () => _demoSnack(
                  context, 'App rating will be available after publishing.')),
          _ProfileLink(
              icon: Icons.info_outline,
              label: 'About ParchiPocket',
              onTap: () => state.go('about')),
        ]));
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: PpColors.forest, size: 21),
      title: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      trailing:
          const Icon(Icons.chevron_right, size: 18, color: PpColors.secondary),
      onTap: onTap);
}

void _demoSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name =
      TextEditingController(text: widget.state.customerName);
  late final TextEditingController email =
      TextEditingController(text: widget.state.customerEmail);
  late final TextEditingController city =
      TextEditingController(text: widget.state.city);
  late final TextEditingController mobile = TextEditingController(
    text: widget.state.profileMobileNumber.isNotEmpty
        ? widget.state.profileMobileNumber
        : widget.state.phoneNumber,
  );
  bool _isSubmitting = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    city.dispose();
    mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: widget.state,
      title: 'Edit profile',
      backTo: 'customerProfile',
      body: ListView(children: <Widget>[
        const SizedBox(height: 8),
        Center(
          child: _ProfilePhotoControl(
            state: widget.state,
            initials: widget.state.customerName
                .trim()
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part[0].toUpperCase())
                .join(),
          ),
        ),
        const SizedBox(height: 16),
        PpField(label: 'Full name', controller: name, hint: 'Enter your name'),
        const SizedBox(height: 15),
        const Text('Mobile number',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
          key: const ValueKey('profile-mobile-number'),
          controller: mobile,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 16,
          decoration: const InputDecoration(
            hintText: '+91 98765 43210',
            helperText: 'Optional. This number is not verified by this form.',
          ),
        ),
        const SizedBox(height: 15),
        PpField(
            label: 'Email address (optional)',
            controller: email,
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        PpField(label: 'City', controller: city, hint: 'City, state'),
        const SizedBox(height: 20),
        PpPrimaryButton(_isSubmitting ? 'Saving…' : 'Save Changes',
            onPressed: _isSubmitting
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isSubmitting = true);
                    try {
                      final success = await widget.state.updateProfile(
                        name: name.text,
                        email: email.text,
                        location: city.text,
                        mobileNumber: mobile.text,
                        updateMobileNumber: true,
                        successPage: null,
                      );
                      if (!mounted) return;
                      final msg = success
                          ? (widget.state.isDemoMode
                              ? 'Profile updated (local demo mode).'
                              : 'Profile updated in cloud.')
                          : 'Profile was not saved: ${widget.state.cloudError ?? 'Please wait for other account work to finish and retry.'}';
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                      if (success) {
                        widget.state.popPage(fallback: 'customerProfile');
                      }
                    } catch (error) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                            content: Text(
                                'Profile was not saved. Check your connection and retry. ($error)')),
                      );
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  }),
      ]));
}

class _ProfilePhotoControl extends StatefulWidget {
  const _ProfilePhotoControl({required this.state, required this.initials});

  final AppState state;
  final String initials;

  @override
  State<_ProfilePhotoControl> createState() => _ProfilePhotoControlState();
}

class _ProfilePhotoControlState extends State<_ProfilePhotoControl> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.state.loadProfilePhoto());
  }

  Widget _fallback() => Center(
        child: Text(
          widget.initials.isEmpty ? 'PP' : widget.initials,
          style: const TextStyle(
            color: PpColors.forest,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _photo() {
    final localPath = widget.state.profilePhotoPath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    final photoUrl = widget.state.auth?.currentUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => Column(
          children: [
            ClipOval(
              child: ColoredBox(
                color: PpColors.soft,
                child: SizedBox(width: 70, height: 70, child: _photo()),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('profile-photo-action'),
                  onPressed: widget.state.isProfilePhotoLoading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success =
                              await widget.state.chooseProfilePhoto();
                          if (!mounted || success) return;
                          final message = widget.state.profilePhotoError;
                          if (message != null) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }
                        },
                  icon: widget.state.isProfilePhotoLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined, size: 17),
                  label: Text(widget.state.profilePhotoPath == null
                      ? 'Add photo'
                      : 'Change photo'),
                ),
                if (widget.state.profilePhotoPath != null)
                  TextButton.icon(
                    key: const ValueKey('profile-photo-remove-action'),
                    onPressed: widget.state.isProfilePhotoLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Remove photo'),
                                content: const Text(
                                  'Are you sure you want to remove your custom profile photo from this device?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !mounted) return;
                            final success =
                                await widget.state.removeProfilePhoto();
                            if (!mounted || success) return;
                            final message = widget.state.profilePhotoError;
                            if (message != null) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Remove photo'),
                  ),
              ],
            ),
            const Text(
              'Profile photos are saved on this device only.',
              style: TextStyle(fontSize: 10, color: PpColors.secondary),
            ),
          ],
        ),
      );
}
