part of '../customer_screens.dart';

class _DateChoiceChip extends StatelessWidget {
  const _DateChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? const Color(0xFF1D2821) : PpColors.soft;
    final selectedBorder = isDark ? PpColors.forestLight : PpColors.forest;
    final unselectedBorder = isDark ? const Color(0xFF2C392F) : PpColors.border;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? selectedBorder : unselectedBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon,
                    size: 13,
                    color: selected ? PpColors.forest : PpColors.secondary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? PpColors.forest : PpColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseDateSelector extends StatelessWidget {
  const _ExpenseDateSelector({
    required this.selectedDate,
    required this.onDateSelected,
    this.enabled = true,
    this.allowOlderThanOneYear = false,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool enabled;
  final bool allowOlderThanOneYear;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = isSameCalendarDay(selectedDate, today);
    final isYesterday = isSameCalendarDay(selectedDate, yesterday);
    final isCustom = !isToday && !isYesterday;

    Future<void> pickCustomDate() async {
      if (!enabled) return;
      final DateTime firstDate;
      if (allowOlderThanOneYear) {
        final minYear = selectedDate.year < now.year - 10
            ? selectedDate.year - 1
            : now.year - 10;
        firstDate = DateTime(minYear, 1, 1);
      } else {
        firstDate = DateTime(now.year - 1, now.month, now.day);
      }
      DateTime initialDate = selectedDate;
      if (initialDate.isAfter(today)) {
        initialDate = today;
      } else if (initialDate.isBefore(firstDate)) {
        initialDate = firstDate;
      }
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: today,
        helpText: 'Select expense date',
      );
      if (picked != null) {
        onDateSelected(DateTime(picked.year, picked.month, picked.day));
      }
    }

    String formattedText;
    if (isToday) {
      formattedText = 'Today · ${formatShortDate(selectedDate)}';
    } else if (isYesterday) {
      formattedText = 'Yesterday · ${formatShortDate(selectedDate)}';
    } else {
      formattedText = formatExpenseDate(selectedDate);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A221C) : PpColors.card;
    final cardBorder = isDark ? const Color(0xFF2C392F) : PpColors.border;
    final textFg = isDark ? const Color(0xFFE8EDE9) : PpColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.calendar_today_outlined,
                  size: 16,
                  color: isDark ? PpColors.forestLight : PpColors.forest),
              const SizedBox(width: 8),
              Text(
                'Expense date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textFg,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: enabled ? pickCustomDate : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Text(
                        formattedText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PpColors.forest,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_calendar_outlined,
                          size: 14, color: PpColors.forest),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _DateChoiceChip(
                label: 'Today',
                selected: isToday,
                onTap: enabled ? () => onDateSelected(today) : null,
              ),
              const SizedBox(width: 8),
              _DateChoiceChip(
                label: 'Yesterday',
                selected: isYesterday,
                onTap: enabled ? () => onDateSelected(yesterday) : null,
              ),
              const SizedBox(width: 8),
              _DateChoiceChip(
                label: isCustom ? formatShortDate(selectedDate) : 'Other date…',
                selected: isCustom,
                icon: Icons.calendar_month_outlined,
                onTap: enabled ? pickCustomDate : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HouseholdExpensesScreen extends StatefulWidget {
  const HouseholdExpensesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<HouseholdExpensesScreen> createState() =>
      _HouseholdExpensesScreenState();
}

class _HouseholdExpensesScreenState extends State<HouseholdExpensesScreen> {
  bool _showVoided = false;

  @override
  Widget build(BuildContext context) {
    final allEntries = widget.state.householdExpenses.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final activeEntries = allEntries.where((e) => !e.isVoided).toList();
    final visibleEntries = _showVoided ? allEntries : activeEntries;
    final total =
        activeEntries.fold<double>(0, (sum, entry) => sum + entry.amount);
    final voidedCount = allEntries.where((e) => e.isVoided).length;

    return PpScaffold(
      state: widget.state,
      title: 'Daily Log',
      showBack: false,
      bottomNav: true,
      bottomTab: 'householdExpenses',
      body: RefreshIndicator(
        onRefresh: () => widget.state.refreshHouseholdExpenses(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
        PpMetricCard(
          label: 'Recorded household spending',
          value: money(total),
          subtitle:
              '${activeEntries.length} purchase entries${_showVoided && voidedCount > 0 ? ' · $voidedCount voided' : ''}',
        ),
        const SizedBox(height: 14),
        PpPrimaryButton('Add a purchase',
            icon: Icons.add_rounded,
            onPressed: () => widget.state.go('householdExpenseEntry')),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Text(
                    'All entries',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink,
                    ),
                  );
                },
              ),
            ),
            FilterChip(
              label: Text(
                _showVoided ? 'Showing voided' : 'Show voided entries',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _showVoided ? FontWeight.w700 : FontWeight.w500,
                  color: _showVoided ? PpColors.forest : PpColors.secondary,
                ),
              ),
              selected: _showVoided,
              onSelected: (val) => setState(() => _showVoided = val),
              selectedColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF243026)
                  : PpColors.soft,
              checkmarkColor: Theme.of(context).brightness == Brightness.dark
                  ? PpColors.forestLight
                  : PpColors.forest,
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (visibleEntries.isEmpty)
          PpEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Your daily log is empty',
            message: _showVoided
                ? 'No voided purchases found in your log.'
                : 'Your saved purchases will appear here.',
            actionLabel: _showVoided ? null : 'Add a purchase',
            onAction: _showVoided
                ? null
                : () => widget.state.go('householdExpenseEntry'),
          )
        else
          for (final entry in visibleEntries)
            PpTransactionTile(
              title: entry.title,
              subtitle:
                  '${entry.category} · ${formatShortDate(entry.effectiveDate)} · ${entry.source == 'voice' ? 'Voice' : 'Manual'}${entry.history.isNotEmpty ? ' · Edited' : ''}${entry.isVoided ? ' · Voided' : ''}',
              trailing: money(entry.amount),
              icon: entry.isVoided
                  ? Icons.block_rounded
                  : Icons.shopping_bag_outlined,
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => HouseholdExpenseDetailDialog(
                  state: widget.state,
                  expense: entry,
                ),
              ),
            ),
        if (widget.state.hasMoreHouseholdExpenses) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: widget.state.isLoadingMoreHouseholdExpenses
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: () => widget.state.loadMoreHouseholdExpenses(),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: const Text('Load older purchases'),
                  ),
          ),
        ],
      ]),
    ),);
  }
}

class HouseholdExpenseDetailDialog extends StatelessWidget {
  const HouseholdExpenseDetailDialog({
    super.key,
    required this.state,
    required this.expense,
  });

  final AppState state;
  final HouseholdExpense expense;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Text(
                  expense.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink,
                  ),
                );
              },
            ),
          ),
          if (expense.isVoided)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PpColors.errorSoft,
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: PpColors.error.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'VOIDED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: PpColors.error,
                  letterSpacing: 0.5,
                ),
              ),
            )
          else if (expense.history.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: PpColors.soft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PpColors.border),
              ),
              child: Text(
                'Edited (${expense.history.length})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: PpColors.forest,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (expense.isVoided) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PpColors.errorSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: PpColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.block_rounded,
                              size: 15, color: PpColors.error),
                          const SizedBox(width: 6),
                          Text(
                            expense.voidedAt != null
                                ? 'Voided on ${formatDateTime(expense.voidedAt!)}'
                                : 'Voided entry',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PpColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (expense.voidReason != null &&
                          expense.voidReason!.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${expense.voidReason}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: PpColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildDetailRow('Amount', money(expense.amount), bold: true),
              const SizedBox(height: 8),
              _buildDetailRow('Category', expense.category),
              const SizedBox(height: 8),
              _buildDetailRow(
                  'Expense Date', formatExpenseDate(expense.effectiveDate)),
              const SizedBox(height: 8),
              _buildDetailRow(
                  'Recorded On', formatDateTime(expense.createdAt)),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Source',
                expense.source == 'voice' ? 'Voice entry' : 'Manual entry',
              ),
              if (expense.updatedAt != null) ...<Widget>[
                const SizedBox(height: 8),
                _buildDetailRow(
                    'Last Edited', formatDateTime(expense.updatedAt!)),
              ],
              if (expense.history.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  'Correction History (${expense.history.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PpColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < expense.history.length; i++) ...<Widget>[
                  _buildHistoryItem(
                    index: i + 1,
                    snapshot: expense.history[i],
                  ),
                  if (i < expense.history.length - 1)
                    const SizedBox(height: 6),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!expense.isVoided) ...<Widget>[
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: PpColors.error),
            label: const Text('Void',
                style: TextStyle(color: PpColors.error)),
            onPressed: () async {
              Navigator.of(context).pop();
              await showDialog<bool>(
                context: context,
                builder: (ctx) => VoidExpenseConfirmationDialog(
                  state: state,
                  expense: expense,
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            onPressed: () async {
              Navigator.of(context).pop();
              await showDialog<bool>(
                context: context,
                builder: (ctx) => EditHouseholdExpenseDialog(
                  state: state,
                  expense: expense,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: PpColors.secondary),
        ),
        Builder(
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final regularColor = isDark ? const Color(0xFFE8EDE9) : PpColors.ink;
            return Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? (isDark ? PpColors.forestLight : PpColors.forest) : regularColor,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem({
    required int index,
    required ExpenseCorrectionSnapshot snapshot,
  }) {
    final dateStr = snapshot.expenseDate != null
        ? formatShortDate(snapshot.expenseDate!)
        : 'Original date';
    final modStr = snapshot.modifiedAt != null
        ? formatDateTime(snapshot.modifiedAt!)
        : 'Prior version';
    return Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E18) : PpColors.soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Version $index: ${snapshot.title}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink,
                    ),
                  ),
              Text(
                money(snapshot.amount),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PpColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${snapshot.category} · $dateStr · $modStr',
            style: const TextStyle(fontSize: 10, color: PpColors.secondary),
          ),
        ],
      ),
    );
      },
    );
  }
}

class EditHouseholdExpenseDialog extends StatefulWidget {
  const EditHouseholdExpenseDialog({
    super.key,
    required this.state,
    required this.expense,
  });

  final AppState state;
  final HouseholdExpense expense;

  @override
  State<EditHouseholdExpenseDialog> createState() =>
      _EditHouseholdExpenseDialogState();
}

class _EditHouseholdExpenseDialogState
    extends State<EditHouseholdExpenseDialog> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final List<String> _availableCategories;
  late String _category;
  late DateTime _expenseDate;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.expense.title);
    _amount = TextEditingController(
      text: widget.expense.amount
          .toStringAsFixed(widget.expense.amount % 1 == 0 ? 0 : 2),
    );
    final rawCategory = widget.expense.category.trim();
    if (rawCategory.isNotEmpty &&
        !kHouseholdExpenseCategories.contains(rawCategory)) {
      _availableCategories = <String>[rawCategory, ...kHouseholdExpenseCategories];
      _category = rawCategory;
    } else {
      _availableCategories = kHouseholdExpenseCategories;
      _category = rawCategory.isEmpty ? 'Other' : rawCategory;
    }
    _expenseDate = widget.expense.effectiveDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (title != widget.expense.title.trim()) return true;
    if (_category != widget.expense.category) return true;
    if (amount != widget.expense.amount) return true;
    if (!isSameCalendarDay(_expenseDate, widget.expense.effectiveDate)) {
      return true;
    }
    return false;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));

    if (title.isEmpty || title.length > 100) {
      setState(() => _error = 'Enter a title between 1 and 100 characters.');
      return;
    }
    if (_category.trim().isEmpty || _category.trim().length > 50) {
      setState(() => _error = 'Select a valid category.');
      return;
    }
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 10000000) {
      setState(() =>
          _error = 'Enter a valid amount greater than ₹0 up to ₹1,00,00,000.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = widget.expense.copyWith(
        title: title,
        category: _category,
        amount: amount,
        expenseDate: _expenseDate,
      );
      final success = await widget.state.updateHouseholdExpense(updated);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = widget.state.cloudError ??
              'The expense could not be updated. Please retry.';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = widget.state.cloudError ??
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('StateError: ', '')
                  .replaceAll('ArgumentError: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Text(
            'Edit expense',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink,
            ),
          );
        },
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _title,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                enabled: !_isSaving,
                onChanged: (_) => setState(() => _error = null),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. Vegetables',
                  counterText: '',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      textInputAction: TextInputAction.done,
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() => _error = null),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        hintText: 'e.g. 250',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _availableCategories
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _category = value;
                                  _error = null;
                                });
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ExpenseDateSelector(
                selectedDate: _expenseDate,
                enabled: !_isSaving,
                allowOlderThanOneYear: true,
                onDateSelected: (newDate) {
                  setState(() {
                    _expenseDate = newDate;
                    _error = null;
                  });
                },
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PpColors.errorSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline,
                          size: 16, color: PpColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: PpColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isSaving || !_hasChanges) ? null : _handleSave,
          child: Text(_isSaving ? 'Saving…' : 'Save changes'),
        ),
      ],
    );
  }
}

class VoidExpenseConfirmationDialog extends StatefulWidget {
  const VoidExpenseConfirmationDialog({
    super.key,
    required this.state,
    required this.expense,
  });

  final AppState state;
  final HouseholdExpense expense;

  @override
  State<VoidExpenseConfirmationDialog> createState() =>
      _VoidExpenseConfirmationDialogState();
}

class _VoidExpenseConfirmationDialogState
    extends State<VoidExpenseConfirmationDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isVoiding = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleVoid() async {
    if (_isVoiding) return;
    final reason = _reasonController.text.trim();
    if (reason.length > 200) {
      setState(() => _error = 'Void reason cannot exceed 200 characters.');
      return;
    }

    setState(() {
      _isVoiding = true;
      _error = null;
    });

    try {
      final success = await widget.state.voidHouseholdExpense(
        widget.expense.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = widget.state.cloudError ??
              'The expense could not be voided. Please retry.';
          _isVoiding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = widget.state.cloudError ??
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('StateError: ', '')
                  .replaceAll('ArgumentError: ', '');
          _isVoiding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Text(
            'Void this expense?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink,
            ),
          );
        },
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A221C) : PpColors.soft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF2C392F)
                              : PpColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.expense.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFFE8EDE9)
                                : PpColors.ink,
                          ),
                        ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.expense.category} · ${money(widget.expense.amount)} · ${formatShortDate(widget.expense.effectiveDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PpColors.forest,
                      ),
                    ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: PpColors.errorSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: PpColors.error.withValues(alpha: 0.25)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: PpColors.error),
                        SizedBox(width: 6),
                        Text(
                          'Important audit information',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: PpColors.error,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• This expense will be excluded from Dashboard and Insights totals.\n'
                      '• The original document remains preserved for audit purposes.\n'
                      '• Voiding cannot be reversed through the app.',
                      style: TextStyle(
                        fontSize: 11,
                        color: PpColors.error,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                enabled: !_isVoiding,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reason for voiding (optional)',
                  hintText: 'e.g. Accidental duplicate, wrong amount',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PpColors.errorSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline,
                          size: 16, color: PpColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: PpColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isVoiding ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: PpColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: _isVoiding ? null : _handleVoid,
          child: Text(_isVoiding ? 'Voiding…' : 'Void Expense'),
        ),
      ],
    );
  }
}

class HouseholdExpenseEntryScreen extends StatefulWidget {
  const HouseholdExpenseEntryScreen({
    super.key,
    required this.state,
    this.initialMode = 'voice',
  });
  final AppState state;
  final String initialMode;

  @override
  State<HouseholdExpenseEntryScreen> createState() =>
      _HouseholdExpenseEntryScreenState();
}

class _HouseholdExpenseEntryScreenState
    extends State<HouseholdExpenseEntryScreen>
    with WidgetsBindingObserver {
  static const List<String> _categories = kHouseholdExpenseCategories;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _category = 'Groceries';
  late String _entryMode;
  late DateTime _expenseDate;
  String _source = 'manual';
  String _localeId = 'hi_IN';
  String _transcript = '';
  String? _error;
  bool _voiceDraftReviewed = false;
  bool _speechAvailable = false;
  bool _initializingSpeech = false;
  bool _isListening = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entryMode = widget.initialMode;
    final now = DateTime.now();
    _expenseDate = DateTime(now.year, now.month, now.day);
    unawaited(_initializeSpeech());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _amount.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed &&
        !_speechAvailable &&
        _entryMode == 'voice') {
      unawaited(_initializeSpeech());
    }
  }

  Future<void> _initializeSpeech() async {
    if (_initializingSpeech || _speechAvailable) return;
    setState(() => _initializingSpeech = true);
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _error = 'Voice recognition error: ${error.errorMsg}';
            });
          }
        },
      );
      var localeId = 'hi_IN';
      if (available) {
        final locales = await _speech.locales();
        if (!locales.any((locale) => locale.localeId == 'hi_IN')) {
          if (locales.any((locale) => locale.localeId == 'en_IN')) {
            localeId = 'en_IN';
          } else if (locales.isNotEmpty) {
            localeId = locales.first.localeId;
          }
        }
      }
      final hasPerm = await _speech.hasPermission;
      if (!mounted) return;
      setState(() {
        _speechAvailable = available;
        _localeId = localeId;
        if (!available) {
          _error = !hasPerm
              ? 'Microphone permission is required for voice entry. Enable microphone access in settings or switch to manual entry.'
              : 'Speech recognition is unavailable on this device. You can still type the entry.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _speechAvailable = false;
          _error =
              'Could not start speech recognition. You can still type the entry.';
        });
      }
    } finally {
      if (mounted) setState(() => _initializingSpeech = false);
    }
  }

  void _onSpeechResult(String recognizedWords) {
    final heard = recognizedWords.trim();
    if (heard.isEmpty || !mounted) return;
    final parsed = parseHouseholdExpense(heard);
    setState(() {
      _transcript = heard;
      _source = 'voice';
      _voiceDraftReviewed = false;
      _title.text = parsed.title == 'Purchase' ? heard : parsed.title;
      if (parsed.amount != null) {
        _amount.text =
            parsed.amount!.toStringAsFixed(parsed.amount! % 1 == 0 ? 0 : 2);
        _error = null;
      } else {
        _amount.clear();
        _error =
            'I heard the purchase but could not find its price. Enter the amount before saving.';
      }
      _category =
          _categories.contains(parsed.category) ? parsed.category : 'Other';
    });
  }

  Future<void> _toggleListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      await _initializeSpeech();
      if (!_speechAvailable) return;
    }
    setState(() {
      _error = null;
      _transcript = '';
    });
    try {
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result.recognizedWords),
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 4),
          partialResults: false,
        ),
      );
      if (mounted) setState(() => _isListening = true);
    } catch (_) {
      final hasPerm = await _speech.hasPermission;
      if (mounted) {
        setState(() {
          _isListening = false;
          _error = !hasPerm
              ? 'Microphone permission denied. Grant permission in app settings or switch to manual entry.'
              : 'Could not start the microphone. Check its permission and retry.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_isListening) {
      setState(() =>
          _error = 'Stop listening and review the purchase before saving.');
      return;
    }
    if (_source == 'voice' && !_voiceDraftReviewed) {
      setState(() => _error =
          'Review the voice transcript and purchase details before saving.');
      return;
    }
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (title.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error =
          'Enter the purchase name and a valid amount greater than ₹0.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final success = await widget.state.addHouseholdExpense(
        title: title,
        category: _category,
        amount: amount,
        source: _source,
        expenseDate: _expenseDate,
      );
      if (!mounted) return;
      if (!success) {
        setState(() {
          _error = widget.state.cloudError ??
              'The entry was not saved. Retry after checking the details.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The entry was not saved. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modeSelectedBg = isDark ? const Color(0xFF1A221C) : PpColors.card;
    final modeSelectedBorder = isDark ? const Color(0xFF2C392F) : PpColors.border;

    Widget modeOption({
      required String label,
      required String value,
      required IconData icon,
    }) {
      final selected = _entryMode == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            if (value == 'manual' && _speech.isListening) {
              unawaited(_speech.stop());
            }
            setState(() {
              _entryMode = value;
              if (value == 'manual') {
                if (_transcript.isEmpty) _source = 'manual';
                _isListening = false;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? modeSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: selected ? Border.all(color: modeSelectedBorder) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    size: 16,
                    color: selected ? PpColors.forest : PpColors.secondary),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? PpColors.forest
                                : PpColors.secondary))),
              ],
            ),
          ),
        ),
      );
    }

    return PpScaffold(
      state: widget.state,
      title: 'Add a purchase',
      backTo: 'customerHome',
      bottomNav: true,
      bottomTab: 'householdExpenseEntry',
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              children: <Widget>[
                const Text('Capture it now. Understand it later.',
                    style: TextStyle(
                        fontSize: 13, color: PpColors.secondary, height: 1.4)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161E18) : PpColors.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: <Widget>[
                    modeOption(
                        label: 'Speak',
                        value: 'voice',
                        icon: Icons.mic_none_rounded),
                    modeOption(
                        label: 'Type manually',
                        value: 'manual',
                        icon: Icons.edit_outlined),
                  ]),
                ),
                if (_entryMode == 'voice') ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A221C) : const Color(0xFFF0F7F0),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF2C392F)
                              : PpColors.soft),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 29,
                              backgroundColor: PpColors.forest,
                              child: Icon(
                                _isListening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.mic_none_rounded,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _isListening
                                      ? 'Listening…'
                                      : _initializingSpeech
                                          ? 'Preparing voice input'
                                          : 'Voice input ready',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: PpColors.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isListening
                                      ? 'Speak one purchase and its amount.'
                                      : 'Tap the mic and speak naturally.',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: PpColors.secondary,
                                      height: 1.35),
                                ),
                              ],
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Example: “Aaj 250 rupaye ki sabzi li.”',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: PpColors.forest)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving || _initializingSpeech
                                ? null
                                : _toggleListening,
                            icon: Icon(_isListening
                                ? Icons.stop_circle_outlined
                                : Icons.mic_rounded),
                            label: Text(_isListening
                                ? 'Stop listening'
                                : _initializingSpeech
                                    ? 'Preparing microphone…'
                                    : 'Start voice entry'),
                          ),
                        ),
                        if (!_speechAvailable && !_initializingSpeech)
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Text(
                              'Voice needs a compatible Android speech service. Manual entry is always available.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: PpColors.secondary,
                                  height: 1.35),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_transcript.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  PpCard(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        const Expanded(
                            child: Text('VOICE TRANSCRIPT',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: PpColors.secondary))),
                        TextButton(
                          onPressed: () => setState(() {
                            _voiceDraftReviewed = true;
                            _entryMode = 'manual';
                            _error = null;
                          }),
                          child: const Text('Review fields',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text('“$_transcript”',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PpColors.ink)),
                    ],
                  )),
                ],
                const SizedBox(height: 16),
                Text('Review details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFE8EDE9)
                            : PpColors.ink)),
                const SizedBox(height: 4),
                const Text('Check the item, category and amount before saving.',
                    style: TextStyle(
                        fontSize: 11, color: PpColors.secondary, height: 1.35)),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {
                    _error = null;
                    if (_source == 'voice') _voiceDraftReviewed = true;
                  }),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Vegetables',
                    counterText: '',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                        child: TextField(
                      controller: _amount,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {
                        _error = null;
                        if (_source == 'voice') _voiceDraftReviewed = true;
                      }),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        hintText: 'e.g. 250',
                      ),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                            if (_source == 'voice') _voiceDraftReviewed = true;
                          });
                        }
                      },
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                _ExpenseDateSelector(
                  selectedDate: _expenseDate,
                  enabled: !_isSaving,
                  onDateSelected: (newDate) {
                    setState(() {
                      _expenseDate = newDate;
                      _error = null;
                      if (_source == 'voice') _voiceDraftReviewed = true;
                    });
                  },
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: PpColors.errorSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.error_outline,
                                size: 17, color: PpColors.error),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: PpColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_entryMode == 'voice') ...<Widget>[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                              ),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 14, color: PpColors.forest),
                              label: const Text(
                                'Switch to typing',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PpColors.forest,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _entryMode = 'manual';
                                  _error = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const PpDemoNotice(
                  message:
                      'Voice creates a draft only. Review the details above, then save the purchase.',
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PpPrimaryButton(
            _isSaving ? 'Saving…' : 'Save purchase',
            icon: Icons.check_rounded,
            onPressed: _isSaving ||
                    _isListening ||
                    (_source == 'voice' && !_voiceDraftReviewed)
                ? null
                : _save,
          ),
          const SizedBox(height: 4),
          const Text(
            'Your Daily Log and Insights use saved purchases.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: PpColors.secondary),
          ),
        ],
      ),
    );
  }
}
