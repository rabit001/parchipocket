part of '../shop_screens.dart';

class UdhaarScreen extends StatelessWidget {
  const UdhaarScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Udhaar & pending',
      showBack: false,
      bottomNav: true,
      bottomTab: 'udhaar',
      body: ListView(children: <Widget>[
        PpMetricCard(
            label: 'Outstanding total',
            value: money(state.outstandingTotal),
            subtitle: '${state.udhaarBills.length} unpaid demo bills',
            color: PpColors.error),
        const SizedBox(height: 12),
        const PpDemoNotice(
            message:
                'Mark a bill settled only after verifying that payment was received. This is not a ledger shared with customers.'),
        const SizedBox(height: 14),
        if (state.udhaarBills.isEmpty)
          const PpEmptyState(
              icon: Icons.check_circle_outline,
              title: 'No pending udhaar',
              message: 'Outstanding demo bills will appear here.'),
        for (final bill in state.udhaarBills)
          Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: PpCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(
                          child: Text(
                              bill.customerPhone.isEmpty
                                  ? 'Walk-in Customer'
                                  : 'Customer ${bill.customerPhone}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800))),
                      Text(money(bill.total),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: PpColors.error))
                    ]),
                    const SizedBox(height: 5),
                    Text(
                        '${bill.displayNumber} · ${formatShortDate(bill.createdAt)}',
                        style: const TextStyle(
                            fontSize: 10, color: PpColors.secondary)),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                            onPressed: () {
                              state.selectedBill = bill;
                              state.go('confirmSettlement');
                            },
                            child: const Text('Mark settled'))),
                  ]))),
      ]));
}

class ConfirmSettlementScreen extends StatefulWidget {
  const ConfirmSettlementScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ConfirmSettlementScreen> createState() =>
      _ConfirmSettlementScreenState();
}

class _ConfirmSettlementScreenState extends State<ConfirmSettlementScreen> {
  bool _isSubmitting = false;

  Future<void> _confirmSettlement(DemoBill bill) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final success = await widget.state.markSettled(bill);
      if (!mounted) return;
      if (success) {
        final message = widget.state.isDemoMode
            ? 'Marked settled (local demo mode).'
            : 'Settlement updated in cloud.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        widget.state.go('udhaar');
      } else {
        final message = widget.state.cloudError ??
            'Settlement was not updated. Please retry.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Settlement was not updated. Check your connection and retry. ($error)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.state.selectedBill;
    return PpScaffold(
        state: widget.state,
        title: 'Confirm settlement',
        backTo: 'udhaar',
        body: ListView(children: <Widget>[
          const SizedBox(height: 9),
          const Text('Confirm payment received?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text(
              'Only mark a bill as settled after verifying that the customer has paid.',
              style: TextStyle(fontSize: 12, color: PpColors.secondary)),
          const SizedBox(height: 17),
          if (bill != null)
            PpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  const Text('SAMPLE RECORD',
                      style: TextStyle(
                          fontSize: 10,
                          color: PpColors.secondary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                      bill.customerPhone.isEmpty
                          ? 'Walk-in Customer'
                          : 'Customer ${bill.customerPhone}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      '${bill.displayNumber} · ${formatShortDate(bill.createdAt)}',
                      style: const TextStyle(
                          fontSize: 10, color: PpColors.secondary)),
                  const SizedBox(height: 15),
                  Row(children: <Widget>[
                    const Expanded(
                        child: Text('Outstanding amount',
                            style: TextStyle(
                                fontSize: 11, color: PpColors.secondary))),
                    Text(money(bill.total),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: PpColors.error))
                  ])
                ])),
          const SizedBox(height: 17),
          const PpDemoNotice(
              message:
                  'Confirmation updates settlement status. No real payment or bank account is changed.'),
          const SizedBox(height: 18),
          PpPrimaryButton(
            _isSubmitting ? 'Updating…' : 'Confirm Settlement',
            onPressed: bill == null || _isSubmitting
                ? null
                : () => _confirmSettlement(bill),
          ),
          const SizedBox(height: 9),
          PpSecondaryButton('Cancel',
              onPressed:
                  _isSubmitting ? null : () => widget.state.go('udhaar')),
        ]));
  }
}
