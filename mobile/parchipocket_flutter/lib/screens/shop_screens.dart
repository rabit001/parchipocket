import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

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
    final count = int.tryParse(quantity.text.trim()) ?? 1;
    final parsedPrice = price ?? double.tryParse(unitPrice.text.trim());
    if (item.isEmpty || parsedPrice == null || parsedPrice <= 0 || count < 1) {
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
        final message = widget.state.cloudError ??
            'Bill was not saved. Check your connection and retry. ($error)';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController amount = TextEditingController();
  final TextEditingController note = TextEditingController();
  String category = 'Stock';
  String? error;
  bool _isSubmitting = false;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _saveExpense(double value) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      error = null;
    });
    try {
      final success = await widget.state.addExpense(
        title: note.text.isEmpty ? '$category expense' : note.text,
        category: category,
        amount: value,
      );
      if (!mounted || success) return;
      final message =
          widget.state.cloudError ?? 'Expense was not saved. Please retry.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Expense was not saved. Check your connection and retry. ($exception)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: widget.state,
      title: 'Expenses',
      backTo: 'shopHome',
      bottomNav: true,
      bottomTab: 'shopSettings',
      body: ListView(children: <Widget>[
        PpMetricCard(
            label: 'Expenses recorded',
            value: money(widget.state.expensesTotal),
            subtitle: '${widget.state.expenses.length} sample/local entries',
            color: PpColors.error),
        const SizedBox(height: 18),
        const PpSectionTitle('Add an expense'),
        const SizedBox(height: 8),
        PpField(
            label: 'Amount (₹)',
            controller: amount,
            hint: 'Enter expense amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 13),
        PpField(
            label: 'Note', controller: note, hint: 'e.g. wholesaler payment'),
        const SizedBox(height: 13),
        const Text('Category',
            style: TextStyle(
                fontSize: 11,
                color: PpColors.secondary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Wrap(spacing: 7, children: <Widget>[
          for (final item in <String>['Stock', 'Transport', 'Rent', 'Other'])
            ChoiceChip(
                label: Text(item),
                selected: category == item,
                onSelected: (_) => setState(() => category = item))
        ]),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(error!,
                  style: const TextStyle(color: PpColors.error, fontSize: 11))),
        const SizedBox(height: 15),
        PpPrimaryButton(_isSubmitting ? 'Saving…' : 'Save Expense',
            icon: Icons.save_outlined,
            onPressed: _isSubmitting
                ? null
                : () {
                    final value = double.tryParse(amount.text.trim());
                    if (value == null || value <= 0) {
                      setState(
                          () => error = 'Enter an amount greater than ₹0.');
                      return;
                    }
                    _saveExpense(value);
                  }),
        const SizedBox(height: 19),
        const PpSectionTitle('Recent expenses'),
        const SizedBox(height: 7),
        for (final item in widget.state.expenses.take(5))
          PpTransactionTile(
              title: item.title,
              subtitle: '${item.category} · ${formatDateTime(item.createdAt)}',
              trailing: money(item.amount),
              icon: Icons.payments_outlined,
              onTap: () {}),
        const SizedBox(height: 10),
        const PpDemoNotice(
            message:
                'Expenses remain separate from sales. This demo does not calculate business profit because cost of goods sold is not modelled.'),
      ]));
}

class ExpenseSavedScreen extends StatelessWidget {
  const ExpenseSavedScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final item = state.expenses.isEmpty ? null : state.expenses.first;
    return PpScaffold(
        state: state,
        title: 'Expense saved',
        backTo: 'expenses',
        body: ListView(children: <Widget>[
          const SizedBox(height: 20),
          const Center(
              child: CircleAvatar(
                  radius: 35,
                  backgroundColor: PpColors.soft,
                  child: Icon(Icons.check_rounded,
                      color: PpColors.forest, size: 36))),
          const SizedBox(height: 15),
          const Text('Expense recorded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          if (item != null)
            PpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  const Text('Amount',
                      style:
                          TextStyle(fontSize: 10, color: PpColors.secondary)),
                  const SizedBox(height: 7),
                  Text(money(item.amount),
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: PpColors.error)),
                  const SizedBox(height: 8),
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${item.category} · ${formatDateTime(item.createdAt)}',
                      style: const TextStyle(
                          fontSize: 10, color: PpColors.secondary))
                ])),
          const SizedBox(height: 15),
          PpDemoNotice(
              message: state.isDemoMode
                  ? 'This expense was added to local demo state.'
                  : 'Expense saved to your ParchiPocket cloud account.'),
          const SizedBox(height: 20),
          PpPrimaryButton('Back to Expenses',
              onPressed: () => state.go('expenses')),
          const SizedBox(height: 10),
          PpSecondaryButton('Shop Dashboard',
              onPressed: () => state.go('shopHome')),
        ]));
  }
}

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

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Printer & devices',
      backTo: state.role == UserRole.streetVendor
          ? 'vendorProfile'
          : 'shopSettings',
      body: ListView(children: <Widget>[
        const SizedBox(height: 12),
        const Center(
            child: CircleAvatar(
                radius: 48,
                backgroundColor: PpColors.soft,
                child: Icon(Icons.print_outlined,
                    color: PpColors.forest, size: 42))),
        const SizedBox(height: 16),
        const Text('Thermal receipt printer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        const Text(
            'Pair a compatible Bluetooth thermal printer in the real app to print small receipts.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: PpColors.secondary, height: 1.4)),
        const SizedBox(height: 20),
        const PpCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text('Printer status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Row(children: <Widget>[
                Icon(Icons.bluetooth_disabled, color: PpColors.secondary),
                SizedBox(width: 8),
                Expanded(
                    child: Text('No printer connected',
                        style:
                            TextStyle(fontSize: 12, color: PpColors.secondary)))
              ]),
              SizedBox(height: 8),
              Text(
                  'Bluetooth discovery and actual print commands need platform integration.',
                  style: TextStyle(fontSize: 10, color: PpColors.secondary))
            ])),
        const SizedBox(height: 15),
        PpPrimaryButton('Find nearby printers (Demo)',
            icon: Icons.bluetooth_searching,
            onPressed: () => state.go('printerTest')),
        const SizedBox(height: 9),
        PpSecondaryButton('Print test receipt preview',
            icon: Icons.receipt_long_outlined,
            onPressed: () => state.go('printerTest')),
        const SizedBox(height: 14),
        const PpDemoNotice(
            message:
                'No Bluetooth device is accessed. This screen only previews the future setup flow.'),
      ]));
}

class PrinterTestScreen extends StatelessWidget {
  const PrinterTestScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Test receipt preview',
      backTo: 'printerSettings',
      body: ListView(children: <Widget>[
        const SizedBox(height: 6),
        const Text('Printer setup · Demo only',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: PpColors.secondary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 15),
        PpCard(
            padding: const EdgeInsets.all(18),
            child: Column(children: <Widget>[
              const Text('PARCHIPOCKET',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 6),
              Text(state.activeStoreName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              const Text('SAMPLE TEST RECEIPT',
                  style: TextStyle(fontSize: 10, color: PpColors.secondary)),
              const Divider(height: 26),
              const Row(children: <Widget>[
                Expanded(
                    child:
                        Text('Printer test', style: TextStyle(fontSize: 11))),
                Text('₹0.00', style: TextStyle(fontSize: 11))
              ]),
              const Divider(height: 25),
              const Row(children: <Widget>[
                Expanded(
                    child: Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12))),
                Text('₹0.00',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PpColors.forest,
                        fontSize: 13))
              ]),
              const SizedBox(height: 18),
              const Text('This is a preview, not a real print.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: PpColors.secondary)),
            ])),
        const SizedBox(height: 14),
        const PpDemoNotice(
            message:
                'No physical printer was contacted. Real Bluetooth printing must be implemented and tested on compatible devices.'),
        const SizedBox(height: 18),
        PpPrimaryButton('Back to Printer Settings',
            onPressed: () => state.go('printerSettings')),
        const SizedBox(height: 9),
        PpSecondaryButton('Back to dashboard',
            onPressed: () => state.go(state.role == UserRole.streetVendor
                ? 'vendorHome'
                : 'shopHome')),
      ]));
}
