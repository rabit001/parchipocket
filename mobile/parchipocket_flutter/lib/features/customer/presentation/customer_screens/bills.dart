part of '../customer_screens.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final TextEditingController search = TextEditingController();
  String filter = 'All';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.state.customerBills.where((bill) {
      final q = search.text.toLowerCase();
      final matches = bill.store.toLowerCase().contains(q) ||
          bill.id.toLowerCase().contains(q) ||
          bill.displayNumber.toLowerCase().contains(q);
      final now = DateTime.now();
      final dateMatches = filter == 'All' ||
          (filter == 'This Month' &&
              bill.createdAt.year == now.year &&
              bill.createdAt.month == now.month) ||
          (filter == 'This Year' && bill.createdAt.year == now.year);
      return matches && dateMatches;
    }).toList();
    final modeText = widget.state.isDemoMode
        ? 'local demo receipts'
        : 'cloud synced receipts';

    return PpScaffold(
        state: widget.state,
        title: 'My Bills',
        showBack: false,
        bottomNav: true,
        bottomTab: 'bills',
        body: Column(children: <Widget>[
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search store or bill ID')),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            for (final value in <String>['All', 'This Month', 'This Year'])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                          label: Text(value),
                          selected: filter == value,
                          onSelected: (_) => setState(() => filter = value)))),
          ]),
          const SizedBox(height: 4),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('${all.length} $modeText',
                  style: const TextStyle(
                      fontSize: 11,
                      color: PpColors.secondary,
                      fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          Expanded(
              child: all.isEmpty && widget.state.claimedReceipts.isEmpty
                  ? const PpEmptyState(
                      icon: Icons.search_off,
                      title: 'No bills found',
                      message: 'Try another store name or bill ID.')
                  : ListView(children: <Widget>[
                      for (final bill in all)
                        PpTransactionTile(
                            title: bill.store,
                            subtitle:
                                '${formatDateTime(bill.createdAt)} · ${bill.displayNumber}',
                            trailing: money(bill.total),
                            onTap: () => widget.state.openBill(bill),
                            icon: Icons.receipt_long_outlined),
                      if (widget.state.claimedReceipts.isNotEmpty) ...<Widget>[
                        const Padding(
                            padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
                            child: Text('Claimed receipts (read-only)',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800))),
                        for (final claimed
                            in widget.state.claimedReceipts.where((entry) {
                          final query = search.text.toLowerCase();
                          return '${entry.bill.store} ${entry.bill.id} ${entry.bill.displayNumber}'
                              .toLowerCase()
                              .contains(query);
                        }))
                          PpTransactionTile(
                              title: claimed.bill.store,
                              subtitle:
                                  '${formatDateTime(claimed.bill.createdAt)} · ${claimed.bill.displayNumber} · claimed',
                              trailing: money(claimed.bill.total),
                              onTap: () =>
                                  widget.state.openClaimedReceipt(claimed),
                              icon: Icons.verified_outlined),
                      ],
                    ])),
        ]));
  }
}

class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final claimedReceipt = state.selectedClaimedReceipt;
    final bill = state.selectedBill ?? claimedReceipt?.bill;
    if (bill == null) {
      return PpScaffold(
          state: state,
          title: 'Bill details',
          body: const PpEmptyState(
              icon: Icons.receipt_long,
              title: 'No receipt selected',
              message: 'Select a receipt from My Bills or Bill History.'));
    }

    final isSavedInState = bill.isSaved;

    return PpScaffold(
      state: state,
      title: 'Bill details',
      backTo: state.role == UserRole.shopOwner ? 'billHistory' : 'bills',
      bottomNav: state.role == UserRole.customer,
      bottomTab: 'bills',
      body: ListView(children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: PpColors.soft,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_outlined,
                  color: PpColors.forest)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(bill.store,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 5),
                Text(formatDateTime(bill.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
                const SizedBox(height: 4),
                Text('Bill ID: ${bill.displayNumber}',
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary))
              ])),
        ]),
        const SizedBox(height: 18),
        PpCard(
            child: Column(children: <Widget>[
          for (final item in bill.items)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: <Widget>[
                  Expanded(
                      flex: 4,
                      child: Text(item.name,
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                      flex: 4,
                      child: Text('${item.quantity} × ${money(item.unitPrice)}',
                          style: const TextStyle(
                              fontSize: 10, color: PpColors.secondary))),
                  Expanded(
                      flex: 2,
                      child: Text(money(item.total),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12))),
                ])),
          const Divider(),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: <Widget>[
                const Expanded(
                    child: Text('Total paid',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13))),
                Text(money(bill.total),
                    style: const TextStyle(
                        color: PpColors.forest,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
              ])),
          Row(children: <Widget>[
            const Expanded(
                child: Text('Payment method',
                    style: TextStyle(fontSize: 11, color: PpColors.secondary))),
            Text(bill.paymentMode,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
          ]),
        ])),
        const SizedBox(height: 18),
        if (claimedReceipt != null)
          const PpDemoNotice(
              message:
                  'This is a read-only receipt copy claimed from the seller. The original receipt remains under the seller’s account.'),
        if (claimedReceipt == null)
          PpPrimaryButton(
            isSavedInState ? 'Saved to My Bills' : 'Save to My Bills',
            icon: Icons.bookmark_add_outlined,
            onPressed: () async {
              final success = await state.saveSelectedBill();
              if (context.mounted) {
                final snackText = success
                    ? (state.isDemoMode
                        ? 'Saved to My Bills (local demo mode).'
                        : 'Receipt saved to your cloud account.')
                    : 'Failed to save: ${state.cloudError ?? 'Cloud error'}';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(snackText)));
              }
            },
          ),
        if (claimedReceipt == null) ...<Widget>[
          const SizedBox(height: 9),
          PpSecondaryButton('Download / Share Receipt',
              icon: Icons.share_outlined,
              onPressed: () => state.go('shareReceipt')),
          const SizedBox(height: 4),
          TextButton(
              onPressed: () => state.go('support'),
              child: const Text('Report an issue with this bill',
                  style: TextStyle(color: PpColors.error))),
        ],
        if (claimedReceipt == null &&
            state.role != UserRole.customer &&
            !state.isDemoMode) ...<Widget>[
          PpSecondaryButton('Create customer claim code',
              icon: Icons.qr_code_2,
              onPressed: () => state.go('issueReceiptClaim')),
          const SizedBox(height: 8),
        ],
        if (claimedReceipt == null)
          PpDemoNotice(
            message: state.isDemoMode
                ? 'Receipt data in demo mode is sample data. Sign in with your phone number to save and sync receipts securely in Firestore.'
                : 'Receipt synced to your ParchiPocket cloud account under users/${state.auth?.currentUser?.uid ?? 'me'}/bills/${bill.id}.',
          ),
      ]),
    );
  }
}

class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  final TextEditingController code = TextEditingController();
  bool _claiming = false;
  bool _scanHandled = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming) return;
    if (widget.state.isDemoMode || !widget.state.isAuthenticated) {
      final searchCode = code.text.trim().toLowerCase();
      final found = widget.state.bills
          .where((bill) =>
              bill.id.toLowerCase() == searchCode ||
              bill.displayNumber.toLowerCase() == searchCode)
          .firstOrNull;
      if (found != null) {
        widget.state.openBill(found);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Demo mode only opens sample bill numbers. Sign in as a customer to claim a secure receipt code.'),
        ));
      }
      return;
    }
    setState(() => _claiming = true);
    try {
      final receipt =
          await widget.state.claimReceipt(code.text.trim().toLowerCase());
      if (mounted) widget.state.openClaimedReceipt(receipt);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not claim receipt: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _claiming = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanHandled || _claiming) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) return;
    _scanHandled = true;
    code.text = value.trim().toLowerCase();
    _claim();
  }

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: widget.state,
      title: 'Claim a receipt',
      showBack: false,
      bottomNav: true,
      bottomTab: 'scan',
      body: ListView(children: <Widget>[
        const Text(
            'Scan the seller’s one-time QR code or enter its claim code.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child:
              SizedBox(height: 265, child: MobileScanner(onDetect: _onDetect)),
        ),
        const SizedBox(height: 22),
        const Text('Enter claim code manually',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        TextField(
            controller: code,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                hintText: '32-character one-time code')),
        const SizedBox(height: 12),
        PpPrimaryButton(_claiming ? 'Claiming receipt…' : 'Claim Receipt',
            onPressed: _claiming ? null : _claim),
        if (_scanHandled) ...<Widget>[
          const SizedBox(height: 8),
          PpSecondaryButton('Scan another code',
              icon: Icons.qr_code_scanner,
              onPressed: () => setState(() => _scanHandled = false)),
        ],
        const SizedBox(height: 12),
        const PpDemoNotice(
            message:
                'The code expires within 24 hours and can be claimed by one authenticated customer account. The receipt copy is read-only. Demo mode can still open sample bill numbers.'),
      ]));
}
