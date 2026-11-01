part of '../common_screens.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Notifications',
      backTo: state.role == UserRole.customer
          ? 'customerProfile'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: <Widget>[
        const Text('Choose which updates matter to you.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.notificationsEnabled,
            activeThumbColor: PpColors.forest,
            title: const Text('Bill and account alerts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Security and receipt updates',
                style: TextStyle(fontSize: 10, color: PpColors.secondary)),
            onChanged: state.setNotificationsEnabled),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.spendingSummaryEnabled,
            activeThumbColor: PpColors.forest,
            title: const Text('Spending summary',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Weekly and monthly overview',
                style: TextStyle(fontSize: 10, color: PpColors.secondary)),
            onChanged: state.setSpendingSummaryEnabled),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.productUpdatesEnabled,
            activeThumbColor: PpColors.forest,
            title: const Text('Product news and updates',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            subtitle: const Text('Optional announcements',
                style: TextStyle(fontSize: 10, color: PpColors.secondary)),
            onChanged: state.setProductUpdatesEnabled),
        const SizedBox(height: 14),
        PpPrimaryButton('Save Preferences', onPressed: () {
          state.lastNotice = 'Notification preferences saved locally.';
          state.go(state.role == UserRole.customer
              ? 'settings'
              : state.role == UserRole.shopOwner
                  ? 'shopSettings'
                  : 'vendorProfile');
        }),
        const SizedBox(height: 12),
        const PpDemoNotice(
            message:
                'Preferences are stored only in memory during this app session. Push notification delivery is not connected.'),
      ]));
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Help & Support',
      backTo: state.role == UserRole.customer
          ? 'customerProfile'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: <Widget>[
        const Text('How can we help you?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _SettingRow(
            icon: Icons.quiz_outlined,
            title: 'Frequently Asked Questions',
            subtitle: 'Common questions about bills',
            onTap: () => state.go('faqs')),
        _SettingRow(
            icon: Icons.support_agent,
            title: 'Contact Customer Care',
            subtitle: 'Send a support request',
            onTap: () => state.go('support')),
        _SettingRow(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Report an Issue',
            subtitle: 'Incorrect bill, login or app problem',
            onTap: () => state.go('support')),
        _SettingRow(
            icon: Icons.shield_outlined,
            title: 'Privacy & Security',
            subtitle: 'Permissions and personal data',
            onTap: () => state.go('privacy')),
        if (state.role != UserRole.customer)
          _SettingRow(
              icon: Icons.print_outlined,
              title: 'Printer Help',
              subtitle: 'Preview printer setup',
              onTap: () => state.go('printerSettings')),
        const SizedBox(height: 14),
        const PpDemoNotice(
            message:
                'Customer care is a visual flow in this starter. There is no support mailbox, phone line or ticket service connected.'),
      ]));
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, required this.state});
  final AppState state;
  static const List<({String question, String answer})> questions =
      <({String question, String answer})>[
    (
      question: 'How do I save a receipt?',
      answer:
          'Scan a receipt QR or enter its bill code, then review the shop and total before saving.'
    ),
    (
      question: 'Can I use ParchiPocket without an account?',
      answer:
          'A shared receipt may be opened via a link in a future build. Saving a private bill history will require sign-in.'
    ),
    (
      question: 'How can a shop print bills?',
      answer:
          'A shop owner can pair a supported thermal printer once Bluetooth and printer support have been implemented.'
    ),
    (
      question: 'Can I correct an incorrect bill?',
      answer:
          'Report the bill and contact the seller. The app should not silently change the original seller receipt.'
    ),
    (
      question: 'How are expenses recorded?',
      answer:
          'Shop owners record expenses separately from sales. These records alone are not a full profit calculation.'
    ),
    (
      question: 'Is the demo data real?',
      answer: 'No. The current app uses sample records held in local memory.'
    ),
  ];
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'FAQs',
      backTo: 'help',
      body: ListView(children: <Widget>[
        const Text('Quick answers to common questions.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 10),
        for (final item in questions)
          Card(
              child: ExpansionTile(
                  title: Text(item.question,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: <Widget>[
                Text(item.answer,
                    style: const TextStyle(
                        fontSize: 11, color: PpColors.secondary, height: 1.4))
              ])),
        const SizedBox(height: 12),
        PpPrimaryButton('Contact Customer Care',
            onPressed: () => state.go('support')),
      ]));
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.state});
  final AppState state;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController billId = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController contact = TextEditingController();
  String issueType = 'Incorrect bill';
  String? error;
  @override
  void dispose() {
    billId.dispose();
    description.dispose();
    contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: widget.state,
      title: 'Report an issue',
      backTo: 'help',
      body: ListView(children: <Widget>[
        const Text(
            'Tell us what went wrong. Never include passwords, OTPs or payment PINs.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 16),
        const Text('Issue type',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PpColors.secondary)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
            initialValue: issueType,
            items: const <String>[
              'Incorrect bill',
              'Can’t access a bill',
              'Login or account',
              'App problem',
              'Printer issue',
              'Other'
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => issueType = v ?? 'Other')),
        const SizedBox(height: 13),
        PpField(
            label: 'Bill ID (optional)',
            controller: billId,
            hint: 'e.g. PP-10482'),
        const SizedBox(height: 13),
        PpField(
            label: 'Description',
            controller: description,
            hint: 'Describe the problem',
            maxLines: 4),
        const SizedBox(height: 13),
        PpField(
            label: 'Contact (optional)',
            controller: contact,
            hint: 'Email or mobile number'),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!,
                  style: const TextStyle(color: PpColors.error, fontSize: 11))),
        const SizedBox(height: 15),
        PpPrimaryButton('Submit Support Request', onPressed: () {
          if (description.text.trim().isEmpty) {
            setState(() => error = 'Add a short description of the issue.');
            return;
          }
          widget.state.submitSupport();
        }),
        const SizedBox(height: 12),
        const PpDemoNotice(
            message:
                'Submitting creates a local demo confirmation only. It does not send the information to customer care.'),
      ]));
}

class SupportSubmittedScreen extends StatelessWidget {
  const SupportSubmittedScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Request submitted',
      backTo: 'help',
      body: ListView(children: <Widget>[
        const SizedBox(height: 26),
        const Center(
            child: CircleAvatar(
                radius: 38,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.check_rounded,
                    size: 38, color: PpColors.forest))),
        const SizedBox(height: 18),
        const Text('Support request created',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Text('Reference ID: ${state.supportReference}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                color: PpColors.forest,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const PpDemoNotice(
            message:
                'This reference is for the local prototype. There is no real ticket in a support system yet.'),
        const SizedBox(height: 22),
        PpPrimaryButton('Back to Help & Support',
            onPressed: () => state.go('help')),
        const SizedBox(height: 10),
        PpSecondaryButton('Back to Profile',
            onPressed: () => state.go(state.role == UserRole.customer
                ? 'customerProfile'
                : state.role == UserRole.shopOwner
                    ? 'shopSettings'
                    : 'vendorProfile')),
      ]));
}
