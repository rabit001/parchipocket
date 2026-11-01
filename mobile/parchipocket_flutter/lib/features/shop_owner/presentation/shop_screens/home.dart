part of '../shop_screens.dart';

class ShopHomeScreen extends StatelessWidget {
  const ShopHomeScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final isCloudAuthenticated = !state.isDemoMode && state.isAuthenticated;
    final todayBills = state.shopBills.where((b) => !b.isUdhaar).toList();
    final todaySales = todayBills.fold<double>(0, (sum, b) => sum + b.total);
    return PpScaffold(
        state: state,
        title: state.shopName,
        showBack: false,
        bottomNav: true,
        bottomTab: 'shopHome',
        trailing: IconButton(
            onPressed: () => state.go('shopSettings'),
            icon: const Icon(Icons.more_horiz)),
        body: ListView(children: <Widget>[
          Text(
              isCloudAuthenticated
                  ? 'Shop owner account · Signed in to cloud'
                  : 'Shop owner account · Demo mode',
              style: const TextStyle(fontSize: 11, color: PpColors.secondary)),
          const SizedBox(height: 13),
          Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                  color: PpColors.forest,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('RECORDED SALES',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 10)),
                    const SizedBox(height: 7),
                    Text(money(todaySales),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                        isCloudAuthenticated
                            ? '${todayBills.length} recorded bills in your account'
                            : '${todayBills.length} recorded bills in this demo',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => state.go('salesReports'),
                            child: const Text('View report  →',
                                style: TextStyle(color: Colors.white)))),
                  ])),
          const SizedBox(height: 17),
          const PpSectionTitle('Quick actions'),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Expanded(
                child: _ActionCard(
                    title: 'Create Bill',
                    detail: 'Itemised receipt',
                    icon: Icons.add_circle_outline,
                    onTap: () => state.go('createBill'))),
            const SizedBox(width: 10),
            Expanded(
                child: _ActionCard(
                    title: 'View Bills',
                    detail: 'Search receipts',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => state.go('billHistory'))),
          ]),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(
                child: _ActionCard(
                    title: 'Expenses',
                    detail: 'Record costs',
                    icon: Icons.payments_outlined,
                    onTap: () => state.go('expenses'))),
            const SizedBox(width: 10),
            Expanded(
                child: _ActionCard(
                    title: 'Udhaar',
                    detail: 'Pending amounts',
                    icon: Icons.currency_rupee,
                    onTap: () => state.go('udhaar'))),
          ]),
          const SizedBox(height: 17),
          PpSectionTitle('Recent bills',
              action: 'See all', onAction: () => state.go('billHistory')),
          const SizedBox(height: 5),
          for (final bill in state.shopBills.take(3))
            PpTransactionTile(
                title: bill.displayNumber,
                subtitle: '${bill.store} · ${formatDateTime(bill.createdAt)}',
                trailing: money(bill.total),
                onTap: () => state.openBill(bill),
                icon: Icons.receipt_long_outlined),
          const SizedBox(height: 10),
          PpDemoNotice(
              message: isCloudAuthenticated
                  ? 'Your cloud account is active. New bills appear here after Firestore confirms the save. Sales exclude Udhaar and are not a profit calculation.'
                  : 'Figures are based on sample/local records. This is not a profit calculation and is not synced to a server.'),
        ]));
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.title,
      required this.detail,
      required this.icon,
      required this.onTap});
  final String title, detail;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                        width: 37,
                        height: 37,
                        decoration: BoxDecoration(
                            color: PpColors.soft,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: PpColors.forest, size: 21)),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(detail,
                        style: const TextStyle(
                            fontSize: 10, color: PpColors.secondary)),
                  ]))));
}
