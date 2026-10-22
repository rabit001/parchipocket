import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class VendorHomeScreen extends StatelessWidget {
  const VendorHomeScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final bills = state.bills.where((bill) => bill.store == state.vendorName).toList();
    final sales = bills.where((bill) => !bill.isUdhaar).fold<double>(0, (sum, bill) => sum + bill.total);
    return PpScaffold(state: state, title: 'ParchiPocket', showBack: false, bottomNav: true, bottomTab: 'vendorHome', body: ListView(children: <Widget>[
      const Text('Quick mode · Street vendor', style: TextStyle(fontSize: 11, color: PpColors.secondary)),
      const SizedBox(height: 8),
      Text(state.vendorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: PpColors.forest, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('RECORDED SALES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
        const SizedBox(height: 7), Text(money(sales), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 5), Text('${bills.length} demo receipts', style: const TextStyle(fontSize: 11, color: Colors.white)),
      ])),
      const SizedBox(height: 16),
      PpPrimaryButton('Create Quick Bill', icon: Icons.add, onPressed: () => state.go('vendorBill')),
      const SizedBox(height: 10),
      PpCard(child: InkWell(onTap: () => state.go('vendorSales'), child: const Row(children: <Widget>[
        CircleAvatar(backgroundColor: PpColors.soft, child: Icon(Icons.receipt_long_outlined, color: PpColors.forest)), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('View today’s bills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Receipts generated in quick mode', style: TextStyle(fontSize: 10, color: PpColors.secondary))])), Icon(Icons.chevron_right),
      ]))),
      const SizedBox(height: 10),
      PpCard(child: InkWell(onTap: () => state.go('printerSettings'), child: const Row(children: <Widget>[
        CircleAvatar(backgroundColor: PpColors.soft, child: Icon(Icons.print_outlined, color: PpColors.forest)), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Printer (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Preview thermal receipt setup', style: TextStyle(fontSize: 10, color: PpColors.secondary))])), Icon(Icons.chevron_right),
      ]))),
      const SizedBox(height: 16),
      const PpDemoNotice(message: 'Designed for a fast sale entry with no mandatory stock catalogue. Figures are demo/local data only.'),
    ]));
  }
}

class VendorSalesScreen extends StatefulWidget {
  const VendorSalesScreen({super.key, required this.state});
  final AppState state;
  @override
  State<VendorSalesScreen> createState() => _VendorSalesScreenState();
}
class _VendorSalesScreenState extends State<VendorSalesScreen> {
  String period = 'Today';
  @override
  Widget build(BuildContext context) {
    final bills = widget.state.bills.where((bill) => bill.store == widget.state.vendorName).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = bills.where((bill) => !bill.isUdhaar).fold<double>(0, (sum, bill) => sum + bill.total);
    return PpScaffold(state: widget.state, title: 'Sales & history', showBack: false, bottomNav: true, bottomTab: 'vendorSales', body: ListView(children: <Widget>[
      PpMetricCard(label: 'Recorded sales', value: money(total), subtitle: '${bills.length} receipts in local demo'),
      const SizedBox(height: 12),
      Wrap(spacing: 7, children: <Widget>[for (final value in <String>['Today', '7 days', 'This Month']) ChoiceChip(label: Text(value), selected: period == value, onSelected: (_) => setState(() => period = value))]),
      const SizedBox(height: 10),
      if (bills.isEmpty) const PpEmptyState(icon: Icons.receipt_long, title: 'No receipts yet', message: 'Create a quick bill to start your sales history.'),
      for (final bill in bills) PpTransactionTile(title: bill.id, subtitle: '${formatDateTime(bill.createdAt)} · ${bill.paymentMode}', trailing: money(bill.total), icon: Icons.receipt_long_outlined, onTap: () => widget.state.openBill(bill)),
      const SizedBox(height: 8),
      const PpDemoNotice(message: 'Date chips demonstrate the UI; period-specific filtering will be added with the live data layer.'),
    ]));
  }
}

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(state: state, title: 'More & Profile', showBack: false, bottomNav: true, bottomTab: 'vendorProfile', body: ListView(children: <Widget>[
        PpCard(child: Row(children: <Widget>[const CircleAvatar(radius: 27, backgroundColor: PpColors.soft, child: Icon(Icons.storefront_outlined, color: PpColors.forest)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(state.vendorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(state.vendorCategory, style: const TextStyle(fontSize: 10, color: PpColors.secondary)), const SizedBox(height: 6), InkWell(onTap: () => state.go('vendorSetup'), child: const Text('Edit details', style: TextStyle(fontSize: 11, color: PpColors.forest, fontWeight: FontWeight.w700)))]))])),
        const SizedBox(height: 8),
        _VendorLink(icon: Icons.receipt_long_outlined, label: 'Daily Sales & History', detail: 'View your recent receipts', onTap: () => state.go('vendorSales')),
        _VendorLink(icon: Icons.language, label: 'Language', detail: state.language, onTap: () => state.go('language')),
        _VendorLink(icon: Icons.print_outlined, label: 'Printer (optional)', detail: 'Thermal receipt setup', onTap: () => state.go('printerSettings')),
        _VendorLink(icon: Icons.notifications_none, label: 'Notifications', detail: 'Bill and app updates', onTap: () => state.go('notifications')),
        _VendorLink(icon: Icons.support_agent, label: 'Help & Customer Care', detail: 'FAQs and report an issue', onTap: () => state.go('help')),
        _VendorLink(icon: Icons.shield_outlined, label: 'Privacy & Security', detail: 'Receipt sharing and permissions', onTap: () => state.go('privacy')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class _VendorLink extends StatelessWidget {
  const _VendorLink({required this.icon, required this.label, required this.detail, required this.onTap});
  final IconData icon;
  final String label, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(dense: true, leading: Icon(icon, color: PpColors.forest), title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: Text(detail, style: const TextStyle(fontSize: 10, color: PpColors.secondary)), trailing: const Icon(Icons.chevron_right, size: 18), onTap: onTap);
}
