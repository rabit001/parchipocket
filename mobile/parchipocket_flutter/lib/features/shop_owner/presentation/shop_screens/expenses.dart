part of '../shop_screens.dart';

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
                    if (value == null || !value.isFinite || value <= 0) {
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
