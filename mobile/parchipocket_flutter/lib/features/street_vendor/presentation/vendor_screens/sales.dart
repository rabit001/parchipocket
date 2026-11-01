part of '../vendor_screens.dart';

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
    final bills = widget.state.bills
        .where((bill) => bill.store == widget.state.vendorName)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = bills
        .where((bill) => !bill.isUdhaar)
        .fold<double>(0, (sum, bill) => sum + bill.total);
    return PpScaffold(
        state: widget.state,
        title: 'Sales & history',
        showBack: false,
        bottomNav: true,
        bottomTab: 'vendorSales',
        body: ListView(children: <Widget>[
          PpMetricCard(
              label: 'Recorded sales',
              value: money(total),
              subtitle: '${bills.length} receipts in local demo'),
          const SizedBox(height: 12),
          Wrap(spacing: 7, children: <Widget>[
            for (final value in <String>['Today', '7 days', 'This Month'])
              ChoiceChip(
                  label: Text(value),
                  selected: period == value,
                  onSelected: (_) => setState(() => period = value))
          ]),
          const SizedBox(height: 10),
          if (bills.isEmpty)
            const PpEmptyState(
                icon: Icons.receipt_long,
                title: 'No receipts yet',
                message: 'Create a quick bill to start your sales history.'),
          for (final bill in bills)
            PpTransactionTile(
                title: bill.displayNumber,
                subtitle:
                    '${formatDateTime(bill.createdAt)} · ${bill.paymentMode}',
                trailing: money(bill.total),
                icon: Icons.receipt_long_outlined,
                onTap: () => widget.state.openBill(bill)),
          const SizedBox(height: 8),
          const PpDemoNotice(
              message:
                  'Date chips demonstrate the UI; period-specific filtering will be added with the live data layer.'),
        ]));
  }
}
