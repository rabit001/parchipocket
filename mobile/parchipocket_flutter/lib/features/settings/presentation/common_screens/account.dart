part of '../common_screens.dart';

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Log out',
      backTo: state.role == UserRole.customer
          ? 'settings'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: <Widget>[
        const SizedBox(height: 25),
        const Center(
            child: CircleAvatar(
                radius: 35,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.logout, color: PpColors.forest, size: 32))),
        const SizedBox(height: 18),
        const Text('Log out of ParchiPocket?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text(
            'You will need to sign in again to access your account in the live app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 22),
        PpDemoNotice(
            message: state.isDemoMode
                ? 'Logging out returns to the welcome screen and clears demo session data.'
                : 'Logging out ends your Firebase session and clears account data from this device.'),
        const SizedBox(height: 21),
        if (state.signOutError != null) ...<Widget>[
          PpCard(
              color: PpColors.errorSoft,
              child: Text(
                state.signOutError!,
                style: const TextStyle(color: PpColors.error, fontSize: 11),
              )),
          const SizedBox(height: 12),
        ],
        PpPrimaryButton(
          state.isSigningOut ? 'Logging out…' : 'Log Out',
          onPressed: state.isSigningOut || state.isCloudLoading
              ? null
              : () async {
                  final success = await state.signOut();
                  if (!context.mounted || success) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.signOutError ??
                            'Could not log out. Please retry.')),
                  );
                },
        ),
        const SizedBox(height: 10),
        PpSecondaryButton(
          'Stay Signed In',
          onPressed: state.isSigningOut || state.isCloudLoading
              ? null
              : () => state.go(state.role == UserRole.customer
                  ? 'settings'
                  : state.role == UserRole.shopOwner
                      ? 'shopSettings'
                      : 'vendorProfile'),
        ),
      ]));
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Privacy & Security',
      backTo: state.role == UserRole.customer
          ? 'settings'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: <Widget>[
        const Text('Keep account access and receipt sharing in your control.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        const _PrivacyTile(
            title: 'Verified phone number',
            detail: 'Used for consent-based receipt linking'),
        const _PrivacyTile(
            title: 'Location access', detail: 'Optional for nearby shops'),
        const _PrivacyTile(
            title: 'Receipt sharing',
            detail: 'Review before sending to another person'),
        const _PrivacyTile(
            title: 'Data and privacy',
            detail: 'Review account data and privacy policy'),
        const SizedBox(height: 12),
        PpCard(
            color: PpColors.errorSoft,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Delete account',
                      style: TextStyle(
                          fontSize: 12,
                          color: PpColors.error,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                      'Permanent action in the live app. Identity re-verification and a final confirmation should be required.',
                      style: TextStyle(fontSize: 10, color: PpColors.ink)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: () => state.go('deleteReview'),
                      child: const Text('Review account deletion'))
                ])),
        const SizedBox(height: 14),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
        const SizedBox(height: 10),
        const PpDemoNotice(
            message:
                'This screen previews privacy options. No personal data is deleted and no remote privacy service is connected.'),
      ]));
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({required this.title, required this.detail});
  final String title, detail;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary))
              ])));
}

class DeleteAccountReviewScreen extends StatelessWidget {
  const DeleteAccountReviewScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Delete account',
      backTo: 'privacy',
      body: ListView(children: <Widget>[
        const SizedBox(height: 10),
        const Icon(Icons.warning_amber_rounded,
            size: 45, color: PpColors.error),
        const SizedBox(height: 10),
        const Text('Review Before Deleting',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
            'Deleting your account is permanent and cannot be undone. All your personal data and account credentials will be permanently erased.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 18),
        const PpCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text('What will be deleted:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Text(
                  '• Your profile information, verified phone number, and authentication login.\n\n'
                  '• All business bills and recorded merchant expenses.\n\n'
                  '• All household expenses, categories, and monthly spending insights.\n\n'
                  '• All saved shop bookmarks and claimed receipt lookup indexes.',
                  style: TextStyle(fontSize: 11, height: 1.35))
            ])),
        const SizedBox(height: 14),
        const PpCard(
            color: PpColors.soft,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text('Important Notice regarding Receipts:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                  '• Merchant Receipts: If you are a seller, digital receipts already claimed by customers are preserved in customer accounts as their independent proof of purchase.\n\n'
                  '• Customer Claims: If you are a customer, your claimed receipt copies will be removed from your account, and your identity unlinked from receipt claims.',
                  style: TextStyle(
                      fontSize: 11, height: 1.35, color: PpColors.secondary))
            ])),
        const SizedBox(height: 18),
        PpPrimaryButton('Proceed to Identity Verification',
            onPressed: () => state.go('deleteConfirm')),
        const SizedBox(height: 9),
        PpSecondaryButton('Cancel and Keep Account',
            onPressed: () => state.go('privacy')),
      ]));
}

class DeleteAccountConfirmScreen extends StatefulWidget {
  const DeleteAccountConfirmScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DeleteAccountConfirmScreen> createState() =>
      _DeleteAccountConfirmScreenState();
}

class _DeleteAccountConfirmScreenState
    extends State<DeleteAccountConfirmScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (state.isDemoMode) {
      return PpScaffold(
        state: state,
        title: 'Demo Session',
        backTo: 'deleteReview',
        body: ListView(
          children: <Widget>[
            const SizedBox(height: 22),
            const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.info_outline_rounded,
                    color: PpColors.secondary, size: 34),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Demo Mode Active',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'You are exploring ParchiPocket in offline demo mode. No remote Firebase cloud account exists for this session.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: PpColors.secondary),
            ),
            const SizedBox(height: 22),
            PpPrimaryButton(
              'Reset Demo Data Locally',
              onPressed: () {
                state.resetDemoData();
                state.go('privacy');
              },
            ),
            const SizedBox(height: 10),
            PpSecondaryButton(
              'Back to Privacy',
              onPressed: () => state.go('privacy'),
            ),
          ],
        ),
      );
    }

    final userPhone =
        state.auth?.currentUser?.phoneNumber ?? state.phoneNumber;
    final maskedPhone = userPhone.length > 4
        ? '${userPhone.substring(0, userPhone.length - 4).replaceAll(RegExp(r'\d'), '*')}${userPhone.substring(userPhone.length - 4)}'
        : userPhone;

    return PpScaffold(
      state: state,
      title: 'Final Confirmation',
      backTo: 'deleteReview',
      body: ListView(
        children: <Widget>[
          const SizedBox(height: 16),
          const Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: PpColors.errorSoft,
              child: Icon(Icons.warning_rounded,
                  color: PpColors.error, size: 34),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Confirm Account Deletion',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'To protect your data, re-verify ownership of registered phone number $maskedPhone via SMS OTP.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: PpColors.secondary),
          ),
          const SizedBox(height: 20),
          if (state.deletionError != null) ...<Widget>[
            PpCard(
              color: PpColors.errorSoft,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline,
                      color: PpColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.deletionError!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: PpColors.error,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_otpSent) ...<Widget>[
            PpPrimaryButton(
              _isSendingOtp
                  ? 'Sending SMS OTP...'
                  : 'Send SMS Verification Code',
              onPressed: _isSendingOtp
                  ? null
                  : () async {
                      setState(() => _isSendingOtp = true);
                      final sent = await state.sendDeletionReauthOtp(
                        onCodeSent: (_) {
                          if (mounted) setState(() => _otpSent = true);
                        },
                      );
                      if (mounted) {
                        setState(() {
                          _isSendingOtp = false;
                          if (sent) _otpSent = true;
                        });
                      }
                    },
            ),
          ] else ...<Widget>[
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '6-digit SMS OTP',
                hintText: 'Enter code received via SMS',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PpPrimaryButton(
              state.isDeletingAccount
                  ? 'Deleting Account & Data...'
                  : 'Permanently Delete Account',
              onPressed: state.isDeletingAccount ||
                      _otpController.text.trim().length != 6
                  ? null
                  : () async {
                      await state.deleteAccountWithOtp(
                        _otpController.text.trim(),
                      );
                    },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.isDeletingAccount
                  ? null
                  : () async {
                      setState(() => _isSendingOtp = true);
                      await state.sendDeletionReauthOtp();
                      if (mounted) setState(() => _isSendingOtp = false);
                    },
              child: const Text('Resend Verification SMS'),
            ),
          ],
          const SizedBox(height: 14),
          PpSecondaryButton(
            'Cancel and Go Back',
            onPressed:
                state.isDeletingAccount ? null : () => state.go('privacy'),
          ),
        ],
      ),
    );
  }
}
