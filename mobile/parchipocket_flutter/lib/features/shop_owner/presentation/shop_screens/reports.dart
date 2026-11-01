part of '../shop_screens.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final bills = state.shopBills;
    final paid = bills
        .where((bill) => !bill.isUdhaar)
        .fold<double>(0, (sum, bill) => sum + bill.total);
    final count = bills.length;
    return PpScaffold(
        state: state,
        title: 'Sales reports',
        backTo: 'shopHome',
        bottomNav: true,
        bottomTab: 'shopHome',
        body: ListView(children: <Widget>[
          Text(state.shopName,
              style: const TextStyle(fontSize: 12, color: PpColors.secondary)),
          const SizedBox(height: 12),
          PpMetricCard(
              label: 'Recorded sales',
              value: money(paid),
              subtitle: '$count recorded bills'),
          const SizedBox(height: 13),
          Row(children: <Widget>[
            Expanded(
                child: PpMetricCard(
                    label: 'Expenses recorded',
                    value: money(state.expensesTotal),
                    color: PpColors.error)),
            const SizedBox(width: 9),
            Expanded(
                child: PpMetricCard(
                    label: 'Udhaar outstanding',
                    value: money(state.outstandingTotal),
                    color: PpColors.error))
          ]),
          const SizedBox(height: 12),
          Row(children: <Widget>[
            Expanded(
                child: PpMetricCard(
                    label: 'Paid bills',
                    value: '${bills.where((b) => !b.isUdhaar).length}')),
            const SizedBox(width: 9),
            Expanded(
                child: PpMetricCard(
                    label: 'Pending bills',
                    value: '${state.udhaarBills.length}',
                    color: PpColors.error))
          ]),
          const SizedBox(height: 16),
          const PpSectionTitle('Recent sales'),
          const SizedBox(height: 6),
          for (final bill in bills.take(5))
            PpTransactionTile(
                title: bill.displayNumber,
                subtitle:
                    '${bill.paymentMode} · ${formatShortDate(bill.createdAt)}',
                trailing: money(bill.total),
                onTap: () => state.openBill(bill)),
          const SizedBox(height: 12),
          PpSecondaryButton('Export Report (Demo)',
              icon: Icons.file_download_outlined,
              onPressed: () => state.go('exportPreview')),
          const SizedBox(height: 10),
          const PpDemoNotice(
              message:
                  'Sample report only. Sales and expenses are separate, and no profit is inferred. Actual CSV/PDF export is a future integration.'),
        ]));
  }
}

class ExportReportPreviewScreen extends StatelessWidget {
  const ExportReportPreviewScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Export report',
      backTo: 'salesReports',
      body: ListView(children: <Widget>[
        Text(state.shopName,
            style: const TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 14),
        PpCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              const Text('PARCHIPOCKET · SALES REPORT',
                  style: TextStyle(
                      fontSize: 10,
                      color: PpColors.secondary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Current demo records',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _ReportRow(
                  label: 'Recorded sales', value: money(state.recordedSales)),
              const Divider(),
              _ReportRow(
                  label: 'Expenses recorded',
                  value: money(state.expensesTotal),
                  color: PpColors.error),
              const Divider(),
              _ReportRow(
                  label: 'Udhaar outstanding',
                  value: money(state.outstandingTotal)),
              const Divider(),
              _ReportRow(
                  label: 'Bills recorded', value: '${state.shopBills.length}'),
            ])),
        const SizedBox(height: 15),
        const PpDemoNotice(
            message:
                'Export preview only. CSV/PDF file generation is not connected and no file has been downloaded.'),
        const SizedBox(height: 18),
        PpPrimaryButton('Back to Sales Reports',
            onPressed: () => state.go('salesReports')),
        const SizedBox(height: 9),
        PpSecondaryButton('Shop Dashboard',
            onPressed: () => state.go('shopHome')),
      ]));
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(
      {required this.label, required this.value, this.color = PpColors.ink});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: <Widget>[
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color))
      ]));
}

class CustomerDirectoryScreen extends StatelessWidget {
  const CustomerDirectoryScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Customers',
      backTo: 'shopSettings',
      bottomNav: true,
      bottomTab: 'shopSettings',
      body: ListView(children: <Widget>[
        Text(state.shopName,
            style: const TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        const PpMetricCard(
            label: 'Customer directory',
            value: 'Demo',
            subtitle: 'Customer records will come from the backend'),
        const SizedBox(height: 14),
        for (final bill in state.udhaarBills)
          PpTransactionTile(
              title: bill.customerPhone.isEmpty
                  ? 'Walk-in Customer'
                  : 'Customer ${bill.customerPhone}',
              subtitle: '${bill.displayNumber} · Pending udhaar',
              trailing: money(bill.total),
              icon: Icons.person_outline,
              onTap: () {
                state.selectedBill = bill;
                state.go('confirmSettlement');
              }),
        const SizedBox(height: 10),
        const PpDemoNotice(
            message:
                'Customer identity and phone details shown here are demo placeholders. In the live app, store and use contact information only with permission.'),
      ]));
}
