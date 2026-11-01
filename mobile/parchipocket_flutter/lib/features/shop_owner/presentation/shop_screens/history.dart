part of '../shop_screens.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key, required this.state});
  final AppState state;
  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  final TextEditingController search = TextEditingController();
  String filter = 'All';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = widget.state.shopBills.where((bill) {
      final q = search.text.toLowerCase();
      final matches = bill.id.toLowerCase().contains(q) ||
          bill.displayNumber.toLowerCase().contains(q) ||
          bill.customerPhone.toLowerCase().contains(q) ||
          bill.store.toLowerCase().contains(q);
      final paymentMatches = filter == 'All' ||
          (filter == 'Paid' && !bill.isUdhaar) ||
          (filter == 'Udhaar' && bill.isUdhaar);
      return matches && paymentMatches;
    }).toList();
    return PpScaffold(
        state: widget.state,
        title: 'Bill history',
        showBack: false,
        bottomNav: true,
        bottomTab: 'billHistory',
        body: Column(children: <Widget>[
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search receipt or customer')),
          const SizedBox(height: 10),
          Wrap(spacing: 7, children: <Widget>[
            for (final value in <String>['All', 'Paid', 'Udhaar'])
              ChoiceChip(
                  label: Text(value),
                  selected: filter == value,
                  onSelected: (_) => setState(() => filter = value))
          ]),
          const SizedBox(height: 8),
          Expanded(
              child: bills.isEmpty
                  ? const PpEmptyState(
                      icon: Icons.receipt_long,
                      title: 'No bills found',
                      message: 'Create a bill or change your search.')
                  : ListView.builder(
                      itemCount: bills.length,
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        return PpTransactionTile(
                            title: bill.displayNumber,
                            subtitle:
                                '${bill.store} · ${formatDateTime(bill.createdAt)} · ${bill.paymentMode}',
                            trailing: money(bill.total),
                            icon: Icons.receipt_long_outlined,
                            onTap: () => widget.state.openBill(bill));
                      })),
        ]));
  }
}
