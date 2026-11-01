part of '../common_screens.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Language',
      backTo: state.role == UserRole.customer
          ? 'settings'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: <Widget>[
        const Text('Choose your preferred language.',
            style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: state.language,
          onChanged: (value) {
            if (value != null) state.setLanguage(value);
          },
          child: Column(children: <Widget>[
            for (final option in <String>[
              'English',
              'हिन्दी (Hindi)',
              'मराठी (Marathi)'
            ])
              Card(
                child: ListTile(
                  title: Text(option,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  trailing: Radio<String>(
                      value: option, activeColor: PpColors.forest),
                  onTap: () => state.setLanguage(option),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        PpPrimaryButton('Save Language', onPressed: () {
          state.lastNotice =
              'Language preference changed to ${state.language}.';
          state.go(state.role == UserRole.customer
              ? 'settings'
              : state.role == UserRole.shopOwner
                  ? 'shopSettings'
                  : 'vendorProfile');
        }),
        const SizedBox(height: 12),
        const PpDemoNotice(
            message:
                'This starter stores the selected language in local state but does not translate every screen yet.'),
      ]));
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'About ParchiPocket',
      backTo: state.role == UserRole.customer
          ? 'customerProfile'
          : state.role == UserRole.shopOwner
              ? 'shopSettings'
              : 'vendorProfile',
      body: ListView(children: const <Widget>[
        SizedBox(height: 20),
        Center(
            child: CircleAvatar(
                radius: 39,
                backgroundColor: PpColors.forest,
                child: Text('P',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800)))),
        SizedBox(height: 12),
        Text('ParchiPocket',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('Version 0.1.0 · Frontend starter',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: PpColors.secondary)),
        SizedBox(height: 22),
        PpDemoNotice(
            message:
                'This is a functional UI starter with local in-memory demo state. Authentication, remote database, secure receipt links, actual QR scanning, PDF export and printer integration remain to be built.'),
        SizedBox(height: 18),
        _PrivacyTile(
            title: 'Purpose',
            detail:
                'Help customers keep small purchase receipts and help small sellers organise bills, sales, expenses and udhaar.'),
        _PrivacyTile(
            title: 'Data shown in this build',
            detail:
                'Sample records are for testing interface and workflow only. Do not use this demo as a business ledger.'),
      ]));
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});
  final AppState state;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController search = TextEditingController();
  String type = 'All';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = widget.state.customerBills
        .where((b) => '${b.store} ${b.id} ${b.displayNumber}'
            .toLowerCase()
            .contains(search.text.toLowerCase()))
        .toList();
    final shops = <String>[
      'Sharma Kirana Store',
      'Gupta General Store',
      'Fresh Mart',
      'Singh Dairy',
      'Raju Vegetables'
    ]
        .where((s) => s.toLowerCase().contains(search.text.toLowerCase()))
        .toList();
    return PpScaffold(
        state: widget.state,
        title: 'Search',
        backTo: 'customerHome',
        bottomNav: true,
        bottomTab: 'customerHome',
        body: Column(children: <Widget>[
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Shop name, item or bill ID')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: <Widget>[
            for (final value in <String>['All', 'Shops', 'Bills'])
              ChoiceChip(
                  label: Text(value),
                  selected: type == value,
                  onSelected: (_) => setState(() => type = value))
          ]),
          const SizedBox(height: 8),
          Expanded(
              child: ListView(children: <Widget>[
            if (type != 'Bills') ...<Widget>[
              const PpSectionTitle('Shops'),
              for (final shop in shops)
                PpTransactionTile(
                    title: shop,
                    subtitle: 'Local shop · Sample directory',
                    trailing: 'Shop',
                    onTap: () {
                      widget.state.lastNotice = shop;
                      widget.state.go('shopDetails');
                    }),
            ],
            if (type != 'Shops') ...<Widget>[
              const SizedBox(height: 8),
              const PpSectionTitle('Bills'),
              for (final bill in bills)
                PpTransactionTile(
                    title: bill.store,
                    subtitle:
                        '${bill.displayNumber} · ${formatShortDate(bill.createdAt)}',
                    trailing: money(bill.total),
                    onTap: () => widget.state.openBill(bill),
                    icon: Icons.receipt_long_outlined),
            ],
            const SizedBox(height: 10),
            const PpDemoNotice(
                message:
                    'Search covers local demo shop and receipt data only.'),
          ])),
        ]));
  }
}
