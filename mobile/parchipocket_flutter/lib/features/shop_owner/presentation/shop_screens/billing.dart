part of '../shop_screens.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen(
      {super.key, required this.state, this.vendorMode = false});
  final AppState state;
  final bool vendorMode;
  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final TextEditingController itemName = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController();
  final TextEditingController customerPhone = TextEditingController();
  final List<BillLine> lines = <BillLine>[];
  String paymentMode = 'Cash';
  String? validationError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    itemName.dispose();
    quantity.dispose();
    unitPrice.dispose();
    customerPhone.dispose();
    super.dispose();
  }

  double get total => lines.fold<double>(0, (sum, line) => sum + line.total);

  void addItem({String? name, double? price}) {
    if (_isSubmitting) return;
    if (lines.length >= 10) {
      setState(() => validationError = 'Maximum 10 items allowed per bill.');
      return;
    }
    final item = name ?? itemName.text.trim();
    final count = int.tryParse(quantity.text.trim());
    final parsedPrice = price ?? double.tryParse(unitPrice.text.trim());
    if (item.isEmpty ||
        parsedPrice == null ||
        !parsedPrice.isFinite ||
        parsedPrice <= 0 ||
        count == null ||
        count < 1) {
      setState(() => validationError =
          'Enter an item name, quantity of at least 1 and a price greater than ₹0.');
      return;
    }
    setState(() {
      lines.add(BillLine(name: item, quantity: count, unitPrice: parsedPrice));
      validationError = null;
      itemName.clear();
      quantity.text = '1';
      unitPrice.clear();
    });
  }

  Future<void> _createBill() async {
    if (_isSubmitting) return;
    if (lines.isEmpty) {
      setState(() => validationError =
          'Add at least one item before generating the bill.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      validationError = null;
    });
    try {
      await widget.state.createBill(
        items: lines,
        paymentMode: paymentMode,
        customerPhone: customerPhone.text.trim(),
        vendorMode: widget.vendorMode,
      );
    } catch (error) {
      if (mounted) {
        if (error is ArgumentError) {
          setState(() {
            validationError = error.message?.toString() ??
                'Please check the bill details and try again.';
          });
        } else {
          final message = widget.state.cloudError ??
              'Bill was not saved. Check your connection and retry. ($error)';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.vendorMode ? 'Quick Bill' : 'Create bill';
    final isCloudAuthenticated =
        !widget.state.isDemoMode && widget.state.isAuthenticated;
    return PpScaffold(
        state: widget.state,
        title: title,
        backTo: widget.vendorMode ? 'vendorHome' : 'shopHome',
        bottomNav: true,
        bottomTab: widget.vendorMode ? 'vendorBill' : 'createBill',
        body: ListView(children: <Widget>[
          Text(
              widget.vendorMode
                  ? widget.state.vendorName
                  : widget.state.shopName,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PpColors.secondary)),
          const SizedBox(height: 5),
          Text(
              widget.vendorMode
                  ? 'Add just what you sold. No catalogue required.'
                  : 'Add items, quantity and price to create a receipt.',
              style: const TextStyle(fontSize: 11, color: PpColors.secondary)),
          const SizedBox(height: 15),
          if (!widget.vendorMode) ...<Widget>[
            const PpSectionTitle('Quick items'),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _QuickItemChip(
                  label: 'Maggi · ₹40',
                  onTap: () => addItem(name: 'Maggi', price: 40)),
              _QuickItemChip(
                  label: 'Bread · ₹30',
                  onTap: () => addItem(name: 'Bread', price: 30)),
              _QuickItemChip(
                  label: 'Milk · ₹50',
                  onTap: () => addItem(name: 'Milk', price: 50)),
              _QuickItemChip(
                  label: 'Chips · ₹60',
                  onTap: () => addItem(name: 'Chips', price: 60)),
            ]),
            const SizedBox(height: 16),
          ],
          const PpSectionTitle('Add item'),
          const SizedBox(height: 8),
          PpField(
              label: 'Item name',
              controller: itemName,
              hint: widget.vendorMode
                  ? 'e.g. Tea, vegetables, snacks'
                  : 'e.g. Rice, bread, milk'),
          const SizedBox(height: 12),
          Row(children: <Widget>[
            Expanded(
                flex: 2,
                child: PpField(
                    label: 'Quantity',
                    controller: quantity,
                    hint: '1',
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                flex: 3,
                child: PpField(
                    label: 'Unit price (₹)',
                    controller: unitPrice,
                    hint: 'Enter amount',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 10),
          PpSecondaryButton('Add item to bill',
              icon: Icons.add, onPressed: () => addItem()),
          if (validationError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(validationError!,
                    style:
                        const TextStyle(fontSize: 11, color: PpColors.error))),
          const SizedBox(height: 18),
          PpSectionTitle('Selected items (${lines.length})'),
          const SizedBox(height: 7),
          if (lines.isEmpty)
            const PpCard(
                child: Text(
                    'No items yet. Add an item above or choose a quick item.',
                    style: TextStyle(fontSize: 11, color: PpColors.secondary))),
          for (var index = 0; index < lines.length; index++)
            _BillLineTile(
                line: lines[index],
                onRemove: () => setState(() => lines.removeAt(index))),
          const SizedBox(height: 16),
          PpField(
              label: 'Customer mobile (optional)',
              controller: customerPhone,
              hint: 'Enter only with customer permission',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          const Text('Payment method',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PpColors.secondary)),
          const SizedBox(height: 7),
          Wrap(spacing: 8, children: <Widget>[
            for (final method in <String>['Cash', 'UPI', 'Udhaar'])
              ChoiceChip(
                  label: Text(method),
                  selected: paymentMode == method,
                  onSelected: (_) => setState(() => paymentMode = method)),
          ]),
          const SizedBox(height: 15),
          PpCard(
              child: Row(children: <Widget>[
            const Expanded(
                child: Text('Bill total',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            Text(money(total),
                style: const TextStyle(
                    color: PpColors.forest,
                    fontSize: 21,
                    fontWeight: FontWeight.w800))
          ])),
          const SizedBox(height: 12),
          PpPrimaryButton(
            _isSubmitting
                ? 'Saving bill…'
                : (widget.vendorMode
                    ? 'Generate Simple Bill'
                    : 'Generate Bill'),
            icon: _isSubmitting ? null : Icons.receipt_long_outlined,
            onPressed: _isSubmitting ? null : _createBill,
          ),
          const SizedBox(height: 10),
          PpDemoNotice(
              message: isCloudAuthenticated
                  ? 'Cloud account active. A bill appears in your account only after Firestore confirms the write. Customer number linking is not verified, and no message or printer action is triggered.'
                  : 'This saves a receipt to local demo state. Customer number linking is not verified, and no message or printer action is triggered.'),
        ]));
  }
}

class _QuickItemChip extends StatelessWidget {
  const _QuickItemChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
      label: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: onTap,
      avatar: const Icon(Icons.add, size: 15));
}

class _BillLineTile extends StatelessWidget {
  const _BillLineTile({required this.line, required this.onRemove});
  final BillLine line;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: PpCard(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(children: <Widget>[
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  Text(line.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Qty ${line.quantity} × ${money(line.unitPrice)}',
                      style: const TextStyle(
                          fontSize: 10, color: PpColors.secondary))
                ])),
            Text(money(line.total),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            IconButton(
                tooltip: 'Remove item',
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18, color: PpColors.error)),
          ])));
}

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen(
      {super.key, required this.state, this.vendorMode = false});
  final AppState state;
  final bool vendorMode;
  @override
  Widget build(BuildContext context) {
    final bill = state.selectedBill;
    if (bill == null) {
      return PpScaffold(
          state: state,
          title: 'Bill generated',
          body: const PpEmptyState(
              icon: Icons.receipt,
              title: 'No new bill',
              message: 'Create a bill first.'));
    }
    return PpScaffold(
        state: state,
        title: 'Bill generated',
        backTo: vendorMode ? 'vendorHome' : 'shopHome',
        body: ListView(children: <Widget>[
          const SizedBox(height: 4),
          const Center(
              child: CircleAvatar(
                  radius: 31,
                  backgroundColor: PpColors.soft,
                  child: Icon(Icons.check_rounded,
                      color: PpColors.forest, size: 35))),
          const SizedBox(height: 12),
          const Text('Receipt ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Bill ID: ${bill.displayNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: PpColors.secondary)),
          const SizedBox(height: 18),
          PpCard(
              padding: const EdgeInsets.all(18),
              child: Column(children: <Widget>[
                Text(bill.store.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                Text(formatDateTime(bill.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
                const Divider(height: 24),
                for (final item in bill.items)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: <Widget>[
                        Expanded(
                            child: Text('${item.name} × ${item.quantity}',
                                style: const TextStyle(fontSize: 11))),
                        Text(money(item.total),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700))
                      ])),
                const Divider(height: 24),
                Row(children: <Widget>[
                  const Expanded(
                      child: Text('TOTAL',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800))),
                  Text(money(bill.total),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: PpColors.forest))
                ]),
                const SizedBox(height: 20),
                Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                        color: PpColors.page,
                        border: Border.all(color: PpColors.border),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.qr_code_2,
                        color: PpColors.forest, size: 62)),
                const SizedBox(height: 6),
                const Text('QR receipt placeholder · Demo',
                    style: TextStyle(fontSize: 10, color: PpColors.secondary)),
              ])),
          const SizedBox(height: 16),
          PpPrimaryButton('Share Bill',
              icon: Icons.share_outlined,
              onPressed: () => state.go('shareReceipt')),
          if (!state.isDemoMode) ...<Widget>[
            const SizedBox(height: 9),
            PpSecondaryButton('Create customer claim code',
                icon: Icons.qr_code_2,
                onPressed: () => state.go('issueReceiptClaim')),
          ],
          const SizedBox(height: 9),
          PpSecondaryButton('Print receipt (if configured)',
              icon: Icons.print_outlined,
              onPressed: () => state.go('printerTest')),
          const SizedBox(height: 9),
          PpSecondaryButton(vendorMode ? 'New Quick Bill' : 'Create Next Bill',
              icon: Icons.add,
              onPressed: () =>
                  state.go(vendorMode ? 'vendorBill' : 'createBill')),
          const SizedBox(height: 10),
          const PpDemoNotice(
              message:
                  'The QR is a visual placeholder. Actual QR generation, receipt sharing and Bluetooth printing are not connected.'),
        ]));
  }
}
