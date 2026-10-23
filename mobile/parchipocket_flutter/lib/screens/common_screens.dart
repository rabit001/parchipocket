import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Settings', backTo: 'customerProfile', body: ListView(children: <Widget>[
        _SettingRow(icon: Icons.person_outline, title: 'Account', subtitle: 'Edit your profile and city', onTap: () => state.go('editProfile')),
        _SettingRow(icon: Icons.language, title: 'Language', subtitle: state.language, onTap: () => state.go('language')),
        _SettingRow(icon: Icons.notifications_none, title: 'Notifications', subtitle: 'Bills and account updates', onTap: () => state.go('notifications')),
        _SettingRow(icon: Icons.shield_outlined, title: 'Privacy & Security', subtitle: 'Permissions and account data', onTap: () => state.go('privacy')),
        _SettingRow(icon: Icons.help_outline, title: 'Help & Support', subtitle: 'FAQs and customer care', onTap: () => state.go('help')),
        _SettingRow(icon: Icons.info_outline, title: 'About', subtitle: 'Version 0.1.0 · Demo', onTap: () => state.go('about')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class ShopSettingsScreen extends StatelessWidget {
  const ShopSettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Shop settings', showBack: false, bottomNav: true, bottomTab: 'shopSettings', body: ListView(children: <Widget>[
        PpCard(child: Row(children: <Widget>[Container(width: 50, height: 50, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_outlined, color: PpColors.forest, size: 25)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(state.shopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${state.shopCategory} · ${state.shopAddress}', style: const TextStyle(fontSize: 10, color: PpColors.secondary)), const SizedBox(height: 6), InkWell(onTap: () => state.go('shopSetup'), child: const Text('Edit shop details', style: TextStyle(fontSize: 11, color: PpColors.forest, fontWeight: FontWeight.w700)))]))])),
        const SizedBox(height: 10),
        _SettingRow(icon: Icons.store_outlined, title: 'Shop details', subtitle: 'Name, category and address', onTap: () => state.go('shopSetup')),
        _SettingRow(icon: Icons.print_outlined, title: 'Printer & devices', subtitle: 'Bluetooth printer and test receipt', onTap: () => state.go('printerSettings')),
        _SettingRow(icon: Icons.payments_outlined, title: 'Payment methods', subtitle: 'Cash, UPI and udhaar', onTap: () => state.go('createBill')),
        _SettingRow(icon: Icons.category_outlined, title: 'Expense categories', subtitle: 'Labels used in expense tracking', onTap: () => state.go('expenses')),
        _SettingRow(icon: Icons.people_outline, title: 'Customers', subtitle: 'Customer directory and pending bills', onTap: () => state.go('customers')),
        _SettingRow(icon: Icons.bar_chart_outlined, title: 'Sales reports', subtitle: 'Sales, expenses and outstanding records', onTap: () => state.go('salesReports')),
        _SettingRow(icon: Icons.support_agent, title: 'Help & Support', subtitle: 'Billing and printer support', onTap: () => state.go('help')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: PpColors.forest, size: 20)),
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: PpColors.secondary)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: PpColors.secondary),
        onTap: onTap,
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Notifications', backTo: state.role == UserRole.customer ? 'customerProfile' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: <Widget>[
        const Text('Choose which updates matter to you.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: state.notificationsEnabled, activeThumbColor: PpColors.forest, title: const Text('Bill and account alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: const Text('Security and receipt updates', style: TextStyle(fontSize: 10, color: PpColors.secondary)), onChanged: state.setNotificationsEnabled),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: state.spendingSummaryEnabled, activeThumbColor: PpColors.forest, title: const Text('Spending summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: const Text('Weekly and monthly overview', style: TextStyle(fontSize: 10, color: PpColors.secondary)), onChanged: state.setSpendingSummaryEnabled),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: state.productUpdatesEnabled, activeThumbColor: PpColors.forest, title: const Text('Product news and updates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: const Text('Optional announcements', style: TextStyle(fontSize: 10, color: PpColors.secondary)), onChanged: state.setProductUpdatesEnabled),
        const SizedBox(height: 14),
        PpPrimaryButton('Save Preferences', onPressed: () { state.lastNotice = 'Notification preferences saved locally.'; state.go(state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile'); }),
        const SizedBox(height: 12),
        const PpDemoNotice(message: 'Preferences are stored only in memory during this app session. Push notification delivery is not connected.'),
      ]));
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Help & Support', backTo: state.role == UserRole.customer ? 'customerProfile' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: <Widget>[
        const Text('How can we help you?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _SettingRow(icon: Icons.quiz_outlined, title: 'Frequently Asked Questions', subtitle: 'Common questions about bills', onTap: () => state.go('faqs')),
        _SettingRow(icon: Icons.support_agent, title: 'Contact Customer Care', subtitle: 'Send a support request', onTap: () => state.go('support')),
        _SettingRow(icon: Icons.report_gmailerrorred_outlined, title: 'Report an Issue', subtitle: 'Incorrect bill, login or app problem', onTap: () => state.go('support')),
        _SettingRow(icon: Icons.shield_outlined, title: 'Privacy & Security', subtitle: 'Permissions and personal data', onTap: () => state.go('privacy')),
        if (state.role != UserRole.customer) _SettingRow(icon: Icons.print_outlined, title: 'Printer Help', subtitle: 'Preview printer setup', onTap: () => state.go('printerSettings')),
        const SizedBox(height: 14),
        const PpDemoNotice(message: 'Customer care is a visual flow in this starter. There is no support mailbox, phone line or ticket service connected.'),
      ]));
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, required this.state});
  final AppState state;
  static const List<({String question, String answer})> questions = <({String question, String answer})>[
    (question: 'How do I save a receipt?', answer: 'Scan a receipt QR or enter its bill code, then review the shop and total before saving.'),
    (question: 'Can I use ParchiPocket without an account?', answer: 'A shared receipt may be opened via a link in a future build. Saving a private bill history will require sign-in.'),
    (question: 'How can a shop print bills?', answer: 'A shop owner can pair a supported thermal printer once Bluetooth and printer support have been implemented.'),
    (question: 'Can I correct an incorrect bill?', answer: 'Report the bill and contact the seller. The app should not silently change the original seller receipt.'),
    (question: 'How are expenses recorded?', answer: 'Shop owners record expenses separately from sales. These records alone are not a full profit calculation.'),
    (question: 'Is the demo data real?', answer: 'No. The current app uses sample records held in local memory.'),
  ];
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'FAQs', backTo: 'help', body: ListView(children: <Widget>[
        const Text('Quick answers to common questions.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 10),
        for (final item in questions) Card(child: ExpansionTile(title: Text(item.question, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: <Widget>[Text(item.answer, style: const TextStyle(fontSize: 11, color: PpColors.secondary, height: 1.4))])),
        const SizedBox(height: 12),
        PpPrimaryButton('Contact Customer Care', onPressed: () => state.go('support')),
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
  void dispose() { billId.dispose(); description.dispose(); contact.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Report an issue', backTo: 'help', body: ListView(children: <Widget>[
        const Text('Tell us what went wrong. Never include passwords, OTPs or payment PINs.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 16),
        const Text('Issue type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(initialValue: issueType, items: const <String>['Incorrect bill', 'Can’t access a bill', 'Login or account', 'App problem', 'Printer issue', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => issueType = v ?? 'Other')),
        const SizedBox(height: 13),
        PpField(label: 'Bill ID (optional)', controller: billId, hint: 'e.g. PP-10482'),
        const SizedBox(height: 13),
        PpField(label: 'Description', controller: description, hint: 'Describe the problem', maxLines: 4),
        const SizedBox(height: 13),
        PpField(label: 'Contact (optional)', controller: contact, hint: 'Email or mobile number'),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: PpColors.error, fontSize: 11))),
        const SizedBox(height: 15),
        PpPrimaryButton('Submit Support Request', onPressed: () {
          if (description.text.trim().isEmpty) { setState(() => error = 'Add a short description of the issue.'); return; }
          widget.state.submitSupport();
        }),
        const SizedBox(height: 12),
        const PpDemoNotice(message: 'Submitting creates a local demo confirmation only. It does not send the information to customer care.'),
      ]));
}

class SupportSubmittedScreen extends StatelessWidget {
  const SupportSubmittedScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Request submitted', backTo: 'help', body: ListView(children: <Widget>[
        const SizedBox(height: 26),
        const Center(child: CircleAvatar(radius: 38, backgroundColor: PpColors.soft, child: Icon(Icons.check_rounded, size: 38, color: PpColors.forest))),
        const SizedBox(height: 18),
        const Text('Support request created', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Text('Reference ID: ${state.supportReference}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: PpColors.forest, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const PpDemoNotice(message: 'This reference is for the local prototype. There is no real ticket in a support system yet.'),
        const SizedBox(height: 22),
        PpPrimaryButton('Back to Help & Support', onPressed: () => state.go('help')),
        const SizedBox(height: 10),
        PpSecondaryButton('Back to Profile', onPressed: () => state.go(state.role == UserRole.customer ? 'customerProfile' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile')),
      ]));
}

class ShareReceiptScreen extends StatelessWidget {
  const ShareReceiptScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final bill = state.selectedBill;
    return PpScaffold(state: state, title: 'Share receipt', backTo: bill == null ? 'customerHome' : 'billDetail', body: ListView(children: <Widget>[
        PpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text((bill?.store ?? state.activeStoreName).toUpperCase(), style: const TextStyle(fontSize: 10, color: PpColors.secondary, fontWeight: FontWeight.w700)), const SizedBox(height: 7),
          Text('Bill ${bill?.id ?? 'Sample'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 5),
          Text(bill == null ? 'Sample receipt preview' : formatDateTime(bill.createdAt), style: const TextStyle(fontSize: 10, color: PpColors.secondary)), const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text(money(bill?.total ?? 0), style: const TextStyle(color: PpColors.forest, fontSize: 22, fontWeight: FontWeight.w800))),
        ])),
        const SizedBox(height: 18),
        const PpSectionTitle('Choose how to share'),
        const SizedBox(height: 9),
        PpPrimaryButton('Share via WhatsApp (Demo)', icon: Icons.chat_outlined, onPressed: () { state.lastNotice = 'WhatsApp share'; state.go('sharePreview'); }),
        const SizedBox(height: 10),
        PpSecondaryButton('Copy receipt link (Demo)', icon: Icons.link, onPressed: () { state.lastNotice = 'Copy receipt link'; state.go('sharePreview'); }),
        const SizedBox(height: 10),
        PpSecondaryButton('Download PDF (Demo)', icon: Icons.download_outlined, onPressed: () { state.lastNotice = 'PDF export'; state.go('sharePreview'); }),
        const SizedBox(height: 16),
        const PpDemoNotice(message: 'These options preview the workflow only. No WhatsApp window opens, no clipboard is changed, and no PDF is created.'),
      ]));
  }
}

class SharePreviewScreen extends StatelessWidget {
  const SharePreviewScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Receipt action preview', backTo: 'shareReceipt', body: ListView(children: <Widget>[
        const SizedBox(height: 25),
        const Center(child: CircleAvatar(radius: 35, backgroundColor: PpColors.soft, child: Icon(Icons.receipt_long, color: PpColors.forest, size: 36))),
        const SizedBox(height: 17),
        const Text('Receipt action ready', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(state.lastNotice.isEmpty ? 'Share receipt' : state.lastNotice, textAlign: TextAlign.center, style: const TextStyle(color: PpColors.forest, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const PpDemoNotice(message: 'This prototype does not open external apps, copy links, or generate a PDF. Those platform actions will be wired into the Android app.'),
        const SizedBox(height: 22),
        PpPrimaryButton('Done', onPressed: () => state.go('shareReceipt')),
      ]));
}

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Log out', backTo: state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: <Widget>[
        const SizedBox(height: 25),
        const Center(child: CircleAvatar(radius: 35, backgroundColor: PpColors.soft, child: Icon(Icons.logout, color: PpColors.forest, size: 32))),
        const SizedBox(height: 18),
        const Text('Log out of ParchiPocket?', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('You will need to sign in again to access your account in the live app.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 22),
        const PpDemoNotice(message: 'This is a demo session with no real authentication. Logging out only returns to the welcome screen.'),
        const SizedBox(height: 21),
        PpPrimaryButton('Log Out', onPressed: () => state.go('splash')),
        const SizedBox(height: 10),
        PpSecondaryButton('Stay Signed In', onPressed: () => state.go(state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile')),
      ]));
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Privacy & Security', backTo: state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: <Widget>[
        const Text('Keep account access and receipt sharing in your control.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        const _PrivacyTile(title: 'Verified phone number', detail: 'Used for consent-based receipt linking'),
        const _PrivacyTile(title: 'Location access', detail: 'Optional for nearby shops'),
        const _PrivacyTile(title: 'Receipt sharing', detail: 'Review before sending to another person'),
        const _PrivacyTile(title: 'Data and privacy', detail: 'Review account data and privacy policy'),
        const SizedBox(height: 12),
        PpCard(color: PpColors.errorSoft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('Delete account', style: TextStyle(fontSize: 12, color: PpColors.error, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Permanent action in the live app. Identity re-verification and a final confirmation should be required.', style: TextStyle(fontSize: 10, color: PpColors.ink)), const SizedBox(height: 8), OutlinedButton(onPressed: () => state.go('deleteReview'), child: const Text('Review account deletion'))])),
        const SizedBox(height: 14),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
        const SizedBox(height: 10),
        const PpDemoNotice(message: 'This screen previews privacy options. No personal data is deleted and no remote privacy service is connected.'),
      ]));
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({required this.title, required this.detail});
  final String title, detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(detail, style: const TextStyle(fontSize: 10, color: PpColors.secondary))])));
}

class DeleteAccountReviewScreen extends StatelessWidget {
  const DeleteAccountReviewScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Delete account', backTo: 'privacy', body: ListView(children: <Widget>[
        const SizedBox(height: 10),
        const Icon(Icons.warning_amber_rounded, size: 45, color: PpColors.error),
        const SizedBox(height: 10),
        const Text('Review before deleting', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Deleting an account is permanent in the live app and should require identity re-verification.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 18),
        const PpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Before continuing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 9), Text('• Explain which profile and saved records will be removed.\n\n• Explain which records need to be retained.\n\n• Re-verify the user identity.\n\n• Ask for a final confirmation.', style: TextStyle(fontSize: 11, height: 1.3))])),
        const SizedBox(height: 12),
        const PpDemoNotice(message: 'Figma/Flutter starter only. No account or data will actually be deleted from this screen.'),
        const SizedBox(height: 18),
        PpPrimaryButton('Review Final Confirmation', onPressed: () => state.go('deleteConfirm')),
        const SizedBox(height: 9),
        PpSecondaryButton('Cancel', onPressed: () => state.go('privacy')),
      ]));
}

class DeleteAccountConfirmScreen extends StatelessWidget {
  const DeleteAccountConfirmScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Final confirmation', backTo: 'deleteReview', body: ListView(children: <Widget>[
        const SizedBox(height: 22),
        const Center(child: CircleAvatar(radius: 34, backgroundColor: PpColors.errorSoft, child: Icon(Icons.warning_rounded, color: PpColors.error, size: 34))),
        const SizedBox(height: 16),
        const Text('Final deletion step', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('A real app should show the account-specific deletion summary and request verified confirmation here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 22),
        const PpDemoNotice(message: 'No data has been deleted. A secure backend deletion workflow is not part of this starter.'),
        const SizedBox(height: 22),
        PpPrimaryButton('Back to Privacy & Security', onPressed: () => state.go('privacy')),
      ]));
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'Language', backTo: state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: <Widget>[
        const Text('Choose your preferred language.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        for (final option in <String>['English', 'हिन्दी (Hindi)', 'मराठी (Marathi)']) Card(child: ListTile(title: Text(option, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), trailing: Radio<String>(value: option, groupValue: state.language, activeColor: PpColors.forest, onChanged: (v) { if (v != null) { state.setLanguage(v); } }), onTap: () => state.setLanguage(option))),
        const SizedBox(height: 14),
        PpPrimaryButton('Save Language', onPressed: () { state.lastNotice = 'Language preference changed to ${state.language}.'; state.go(state.role == UserRole.customer ? 'settings' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile'); }),
        const SizedBox(height: 12),
        const PpDemoNotice(message: 'This starter stores the selected language in local state but does not translate every screen yet.'),
      ]));
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'About ParchiPocket', backTo: state.role == UserRole.customer ? 'customerProfile' : state.role == UserRole.shopOwner ? 'shopSettings' : 'vendorProfile', body: ListView(children: const <Widget>[
        SizedBox(height: 20),
        Center(child: CircleAvatar(radius: 39, backgroundColor: PpColors.forest, child: Text('P', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)))),
        SizedBox(height: 12),
        Text('ParchiPocket', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('Version 0.1.0 · Frontend starter', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: PpColors.secondary)),
        SizedBox(height: 22),
        PpDemoNotice(message: 'This is a functional UI starter with local in-memory demo state. Authentication, remote database, secure receipt links, actual QR scanning, PDF export and printer integration remain to be built.'),
        SizedBox(height: 18),
        _PrivacyTile(title: 'Purpose', detail: 'Help customers keep small purchase receipts and help small sellers organise bills, sales, expenses and udhaar.'),
        _PrivacyTile(title: 'Data shown in this build', detail: 'Sample records are for testing interface and workflow only. Do not use this demo as a business ledger.'),
      ]));
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});
  final AppState state;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController search = TextEditingController();
  String type = 'All';
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final bills = widget.state.customerBills.where((b) => '${b.store} ${b.id}'.toLowerCase().contains(search.text.toLowerCase())).toList();
    final shops = <String>['Sharma Kirana Store', 'Gupta General Store', 'Fresh Mart', 'Singh Dairy', 'Raju Vegetables'].where((s) => s.toLowerCase().contains(search.text.toLowerCase())).toList();
    return PpScaffold(state: widget.state, title: 'Search', backTo: 'customerHome', bottomNav: true, bottomTab: 'customerHome', body: Column(children: <Widget>[
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Shop name, item or bill ID')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: <Widget>[for (final value in <String>['All', 'Shops', 'Bills']) ChoiceChip(label: Text(value), selected: type == value, onSelected: (_) => setState(() => type = value))]),
      const SizedBox(height: 8),
      Expanded(child: ListView(children: <Widget>[
        if (type != 'Bills') ...<Widget>[
          const PpSectionTitle('Shops'),
          for (final shop in shops) PpTransactionTile(title: shop, subtitle: 'Local shop · Sample directory', trailing: 'Shop', onTap: () { widget.state.lastNotice = shop; widget.state.go('shopDetails'); }),
        ],
        if (type != 'Shops') ...<Widget>[
          const SizedBox(height: 8),
          const PpSectionTitle('Bills'),
          for (final bill in bills) PpTransactionTile(title: bill.store, subtitle: '${bill.id} · ${formatShortDate(bill.createdAt)}', trailing: money(bill.total), onTap: () => widget.state.openBill(bill), icon: Icons.receipt_long_outlined),
        ],
        const SizedBox(height: 10),
        const PpDemoNotice(message: 'Search covers local demo shop and receipt data only.'),
      ])),
    ]));
  }
}
