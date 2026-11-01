part of '../vendor_screens.dart';

class VendorHomeScreen extends StatelessWidget {
  const VendorHomeScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final isCloudAuthenticated = !state.isDemoMode && state.isAuthenticated;
    final bills =
        state.bills.where((bill) => bill.store == state.vendorName).toList();
    final sales = bills
        .where((bill) => !bill.isUdhaar)
        .fold<double>(0, (sum, bill) => sum + bill.total);
    return PpScaffold(
        state: state,
        title: 'ParchiPocket',
        showBack: false,
        bottomNav: true,
        bottomTab: 'vendorHome',
        body: ListView(children: <Widget>[
          Text(
            isCloudAuthenticated
                ? 'Street vendor account · Signed in to cloud'
                : 'Quick mode · Street vendor · Demo mode',
            style: const TextStyle(fontSize: 11, color: PpColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(state.vendorName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70)),
                    const SizedBox(height: 7),
                    Text(money(sales),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(
                        isCloudAuthenticated
                            ? '${bills.length} recorded receipts in your account'
                            : '${bills.length} demo receipts',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                  ])),
          const SizedBox(height: 16),
          PpPrimaryButton('Create Quick Bill',
              icon: Icons.add, onPressed: () => state.go('vendorBill')),
          const SizedBox(height: 10),
          PpCard(
              child: InkWell(
                  onTap: () => state.go('vendorSales'),
                  child: const Row(children: <Widget>[
                    CircleAvatar(
                        backgroundColor: PpColors.soft,
                        child: Icon(Icons.receipt_long_outlined,
                            color: PpColors.forest)),
                    SizedBox(width: 11),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                          Text('View today’s bills',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Receipts generated in quick mode',
                              style: TextStyle(
                                  fontSize: 10, color: PpColors.secondary))
                        ])),
                    Icon(Icons.chevron_right),
                  ]))),
          const SizedBox(height: 10),
          PpCard(
              child: InkWell(
                  onTap: () => state.go('printerSettings'),
                  child: const Row(children: <Widget>[
                    CircleAvatar(
                        backgroundColor: PpColors.soft,
                        child:
                            Icon(Icons.print_outlined, color: PpColors.forest)),
                    SizedBox(width: 11),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                          Text('Printer (optional)',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Preview thermal receipt setup',
                              style: TextStyle(
                                  fontSize: 10, color: PpColors.secondary))
                        ])),
                    Icon(Icons.chevron_right),
                  ]))),
          const SizedBox(height: 16),
          PpDemoNotice(
              message: isCloudAuthenticated
                  ? 'Your cloud account is active. Receipts appear here after Firestore confirms the save. Quick billing does not require a stock catalogue.'
                  : 'Designed for a fast sale entry with no mandatory stock catalogue. Figures are demo/local data only.'),
        ]));
  }
}
