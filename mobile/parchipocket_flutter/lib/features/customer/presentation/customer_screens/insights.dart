part of '../customer_screens.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.monthlyHouseholdExpenses;
    final total = state.spentThisMonth;
    final categoryValues = <String, double>{};
    for (final entry in entries) {
      categoryValues.update(entry.category, (value) => value + entry.amount,
          ifAbsent: () => entry.amount);
    }
    final sortedCategories = categoryValues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final modeNotice = state.isDemoMode
        ? 'Calculated from local demo household entries'
        : 'Calculated from your saved household entries';

    return PpScaffold(
      state: state,
      title: 'Spending insights',
      showBack: false,
      bottomNav: true,
      bottomTab: 'insights',
      body: RefreshIndicator(
        onRefresh: () => state.refreshCurrentMonthExpenses(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
        const Text('See where your household money goes.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 15),
        PpMetricCard(
            label: 'THIS MONTH',
            value: money(total),
            subtitle: '${entries.length} entries · $modeNotice'),
        const SizedBox(height: 20),
        const PpSectionTitle('Spending by category'),
        const SizedBox(height: 9),
        if (sortedCategories.isEmpty)
          PpEmptyState(
            icon: Icons.pie_chart_outline,
            title: 'Not enough data yet',
            message:
                'Add a few purchases to see the category breakdown for this month.',
            actionLabel: 'Add a purchase',
            onAction: () => state.go('householdExpenseEntry'),
          )
        else
          for (final entry in sortedCategories)
            Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: Column(children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700))),
                    Text(money(entry.value),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PpColors.forest)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                          value: total == 0 ? 0 : entry.value / total,
                          minHeight: 8,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? PpColors.forestLight
                              : PpColors.forest,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2C392F)
                                  : PpColors.soft)),
                ])),
        const SizedBox(height: 6),
        TextButton.icon(
            onPressed: () => state.go('householdExpenses'),
            icon: const Icon(Icons.history),
            label: const Text('View daily log')),
      ]),
    ),);
  }
}

const List<({String name, String category, String distance, String address})>
    demoShops =
    <({String name, String category, String distance, String address})>[
  (
    name: 'Sharma Kirana Store',
    category: 'Grocery',
    distance: '0.5 km',
    address: 'Freeganj, Ujjain'
  ),
  (
    name: 'Gupta General Store',
    category: 'General',
    distance: '1.2 km',
    address: 'Tower Chowk, Ujjain'
  ),
  (
    name: 'Fresh Mart',
    category: 'Supermarket',
    distance: '1.5 km',
    address: 'Freeganj, Ujjain'
  ),
  (
    name: 'Singh Dairy',
    category: 'Dairy',
    distance: '2.0 km',
    address: 'Gopal Mandir, Ujjain'
  ),
  (
    name: 'Raju Vegetables',
    category: 'Produce',
    distance: '2.2 km',
    address: 'Local market, Ujjain'
  ),
];
