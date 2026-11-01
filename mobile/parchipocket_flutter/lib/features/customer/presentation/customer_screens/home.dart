part of '../customer_screens.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final entries = state.activeHouseholdExpenses.toList();
    final month = state.monthlyHouseholdExpenses;
    final today = month
        .where((e) =>
            e.effectiveDate.year == now.year &&
            e.effectiveDate.month == now.month &&
            e.effectiveDate.day == now.day)
        .toList();
    final todayTotal = state.spentToday;
    final monthTotal = state.spentThisMonth;
    final parts = state.customerName.trim().split(RegExp(r'\s+'));
    final firstName =
        parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthLabel = months[now.month - 1];

    return PpScaffold(
      state: state,
      title: 'ParchiPocket',
      showBack: false,
      bottomNav: true,
      bottomTab: 'customerHome',
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      trailing: IconButton(
        tooltip: 'Profile',
        onPressed: () => state.go('customerProfile'),
        icon: CircleAvatar(
          radius: 15,
          backgroundColor: PpColors.forest,
          child: Text(
            parts.isEmpty || parts.first.isEmpty
                ? 'U'
                : parts.first.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshHouseholdExpenses(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Builder(
            builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Text('$greeting, $firstName',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink));
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Here’s how your household is doing.',
            style:
                TextStyle(fontSize: 12, color: PpColors.secondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(children: <Widget>[
            const Icon(Icons.calendar_month_outlined,
                size: 15, color: PpColors.forest),
            const SizedBox(width: 6),
            Text('$monthLabel ${now.year}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PpColors.secondary)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: PpColors.forest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('TOTAL HOUSEHOLD SPEND',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: .55)),
                const SizedBox(height: 8),
                Text(money(monthTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 31,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 7),
                Text('Across your household · ${month.length} purchases',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: <Widget>[
            Expanded(
                child: _HomeStatCard(
              label: 'SPENT TODAY',
              value: money(todayTotal),
              detail: 'Today’s total',
              icon: Icons.currency_rupee_rounded,
              iconBackground: PpColors.soft,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _HomeStatCard(
              label: 'PURCHASES TODAY',
              value: '${today.length}',
              detail: today.length == 1 ? 'purchase entry' : 'purchase entries',
              icon: Icons.receipt_long_outlined,
              iconBackground: const Color(0xFFEAF0E7),
            )),
          ]),
          const SizedBox(height: 18),
          Builder(
            builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Text('Add a purchase',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink));
            },
          ),
          const SizedBox(height: 4),
          const Text('Choose what feels easiest.',
              style: TextStyle(fontSize: 11, color: PpColors.secondary)),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            Expanded(
                child: _HomeQuickAction(
              title: 'Speak',
              detail: 'Say item + amount',
              icon: Icons.mic_none_rounded,
              primary: true,
              onTap: () => state.go('householdExpenseEntry'),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _HomeQuickAction(
              title: 'Type manually',
              detail: 'Enter details',
              icon: Icons.edit_outlined,
              primary: false,
              onTap: () => state.go('householdExpenseEntryManual'),
            )),
          ]),
          const SizedBox(height: 18),
          PpSectionTitle(
            'Recent purchases',
            action: 'View all',
            onAction: () => state.go('householdExpenses'),
          ),
          const SizedBox(height: 7),
          if (entries.isEmpty)
            PpEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No purchases recorded yet',
              message:
                  'Add your first purchase by speaking or typing the details.',
              actionLabel: 'Add a purchase',
              onAction: () => state.go('householdExpenseEntry'),
            )
          else
            for (final entry in entries.take(3))
              PpTransactionTile(
                title: entry.title,
                subtitle:
                    '${entry.category} · ${formatShortDate(entry.effectiveDate)} · ${entry.source == 'voice' ? 'Voice' : 'Manual'}${entry.history.isNotEmpty ? ' · Edited' : ''}',
                trailing: money(entry.amount),
                icon: Icons.shopping_bag_outlined,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => HouseholdExpenseDetailDialog(
                    state: state,
                    expense: entry,
                  ),
                ),
              ),
          if (entries.isNotEmpty)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => state.go('householdExpenses'),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('Open daily spending log'),
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => state.go('scan'),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan a shop receipt QR'),
          ),
          if (state.isDemoMode)
            const PpDemoNotice(
              message:
                  'Demo mode uses sample entries in memory. Sign in to keep your own household records in the cloud.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.iconBackground,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PpColors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: PpColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              CircleAvatar(
                radius: 15,
                backgroundColor: iconBackground,
                child: Icon(icon, size: 16, color: PpColors.forest),
              ),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: PpColors.secondary))),
            ]),
            const SizedBox(height: 10),
            Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? const Color(0xFFE8EDE9) : PpColors.ink));
              },
            ),
            const SizedBox(height: 3),
            Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 9.5, color: PpColors.secondary)),
          ],
        ),
      );
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.title,
    required this.detail,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A221C) : PpColors.card;
    final cardBorder = isDark ? const Color(0xFF2C392F) : PpColors.border;
    final avatarBg = isDark ? const Color(0xFF243026) : PpColors.soft;
    final titleColor = primary
        ? Colors.white
        : (isDark ? const Color(0xFFE8EDE9) : PpColors.ink);

    return Material(
      color: primary ? PpColors.forest : cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: primary ? PpColors.forest : cardBorder),
          ),
          child: Row(children: <Widget>[
            CircleAvatar(
              radius: 17,
              backgroundColor: primary ? PpColors.forestLight : avatarBg,
              child: Icon(icon,
                  size: 18, color: primary ? Colors.white : PpColors.forest),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        color: primary ? Colors.white : PpColors.secondary)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatExpenseDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final monthName =
      (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
  return '${date.day.toString().padLeft(2, '0')} $monthName ${date.year}';
}

const List<String> kHouseholdExpenseCategories = <String>[
  'Groceries',
  'Vegetables',
  'Dairy',
  'Food & Dining',
  'Household',
  'Transport',
  'Utilities',
  'Health',
  'Education',
  'Other',
];
