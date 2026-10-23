import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final recent = state.customerBills.take(3).toList();
    final modeLabel = state.isDemoMode ? 'Local demo' : 'Cloud synced';

    return PpScaffold(
      state: state,
      title: 'ParchiPocket',
      showBack: false,
      bottomNav: true,
      bottomTab: 'customerHome',
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      trailing: IconButton(onPressed: () => state.go('notifications'), icon: const Icon(Icons.notifications_none_rounded)),
      body: ListView(children: <Widget>[
        const Text('Good afternoon', style: TextStyle(fontSize: 11, color: PpColors.secondary)),
        const SizedBox(height: 7),
        const Text('Your bills, all in one place.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        InkWell(onTap: () => state.go('search'), borderRadius: BorderRadius.circular(12), child: const IgnorePointer(child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search bills or shops')))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: PpColors.forest, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('TOTAL SAVED BILLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 7),
          Text('${state.customerBills.length} receipts ($modeLabel)', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Text(state.isDemoMode ? 'Explore sample features in demo mode.' : 'Your purchases are saved securely in Firestore.', style: const TextStyle(fontSize: 11, color: Colors.white)),
        ])),
        const SizedBox(height: 14),
        Card(child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => state.go('scan'), child: const Padding(padding: EdgeInsets.all(15), child: Row(children: <Widget>[
          CircleAvatar(backgroundColor: PpColors.soft, child: Icon(Icons.qr_code_scanner, color: PpColors.forest)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Scan a receipt QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Save a purchase from a printed receipt', style: TextStyle(fontSize: 10, color: PpColors.secondary))])),
          Icon(Icons.chevron_right),
        ])))),
        const SizedBox(height: 16),
        PpSectionTitle('Recent purchases', action: 'See all', onAction: () => state.go('bills')),
        if (recent.isEmpty) const PpEmptyState(icon: Icons.receipt_long_outlined, title: 'No saved bills yet', message: 'Scan or create a receipt to start your digital bill history.')
        else ...recent.map((bill) => PpTransactionTile(title: bill.store, subtitle: '${formatShortDate(bill.createdAt)} · ${bill.displayNumber}', trailing: money(bill.total), onTap: () => state.openBill(bill))),
      ]),
    );
  }
}

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
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final all = widget.state.customerBills.where((bill) {
      final q = search.text.toLowerCase();
      final matches = bill.store.toLowerCase().contains(q) || bill.id.toLowerCase().contains(q) || bill.displayNumber.toLowerCase().contains(q);
      final now = DateTime.now();
      final dateMatches = filter == 'All' || (filter == 'This Month' && bill.createdAt.year == now.year && bill.createdAt.month == now.month) || (filter == 'This Year' && bill.createdAt.year == now.year);
      return matches && dateMatches;
    }).toList();
    final modeText = widget.state.isDemoMode ? 'local demo receipts' : 'cloud synced receipts';

    return PpScaffold(state: widget.state, title: 'My Bills', showBack: false, bottomNav: true, bottomTab: 'bills', body: Column(children: <Widget>[
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search store or bill ID')),
      const SizedBox(height: 10),
      Row(children: <Widget>[
        for (final value in <String>['All', 'This Month', 'This Year'])
          Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(value), selected: filter == value, onSelected: (_) => setState(() => filter = value)))),
      ]),
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerLeft, child: Text('${all.length} $modeText', style: const TextStyle(fontSize: 11, color: PpColors.secondary, fontWeight: FontWeight.w600))),
      const SizedBox(height: 8),
      Expanded(child: all.isEmpty ? const PpEmptyState(icon: Icons.search_off, title: 'No bills found', message: 'Try another store name or bill ID.') : ListView.builder(itemCount: all.length, itemBuilder: (context, index) { final bill = all[index]; return PpTransactionTile(title: bill.store, subtitle: '${formatDateTime(bill.createdAt)} · ${bill.displayNumber}', trailing: money(bill.total), onTap: () => widget.state.openBill(bill), icon: Icons.receipt_long_outlined); })),
    ]));
  }
}

class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final bill = state.selectedBill;
    if (bill == null) return PpScaffold(state: state, title: 'Bill details', body: const PpEmptyState(icon: Icons.receipt_long, title: 'No receipt selected', message: 'Select a receipt from My Bills or Bill History.'));

    final isSavedInState = bill.isSaved;

    return PpScaffold(
      state: state,
      title: 'Bill details',
      backTo: state.role == UserRole.shopOwner ? 'billHistory' : 'bills',
      bottomNav: state.role == UserRole.customer,
      bottomTab: 'bills',
      body: ListView(children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Container(width: 48, height: 48, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_outlined, color: PpColors.forest)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(bill.store, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 5), Text(formatDateTime(bill.createdAt), style: const TextStyle(fontSize: 10, color: PpColors.secondary)), const SizedBox(height: 4), Text('Bill ID: ${bill.displayNumber}', style: const TextStyle(fontSize: 10, color: PpColors.secondary))])),
        ]),
        const SizedBox(height: 18),
        PpCard(child: Column(children: <Widget>[
          for (final item in bill.items) Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: <Widget>[
            Expanded(flex: 4, child: Text(item.name, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 4, child: Text('${item.quantity} × ${money(item.unitPrice)}', style: const TextStyle(fontSize: 10, color: PpColors.secondary))),
            Expanded(flex: 2, child: Text(money(item.total), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ])),
          const Divider(),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: <Widget>[
            const Expanded(child: Text('Total paid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            Text(money(bill.total), style: const TextStyle(color: PpColors.forest, fontSize: 23, fontWeight: FontWeight.w800)),
          ])),
          Row(children: <Widget>[const Expanded(child: Text('Payment method', style: TextStyle(fontSize: 11, color: PpColors.secondary))), Text(bill.paymentMode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
        ])),
        const SizedBox(height: 18),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snackText)));
            }
          },
        ),
        const SizedBox(height: 9),
        PpSecondaryButton('Download / Share Receipt', icon: Icons.share_outlined, onPressed: () => state.go('shareReceipt')),
        const SizedBox(height: 4),
        TextButton(onPressed: () => state.go('support'), child: const Text('Report an issue with this bill', style: TextStyle(color: PpColors.error))),
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
  final TextEditingController code = TextEditingController(text: 'PP-10482');
  @override
  void dispose() { code.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Scan bill QR', showBack: false, bottomNav: true, bottomTab: 'scan', body: ListView(children: <Widget>[
        const Text('Point the camera at a QR code on the printed receipt.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
        const SizedBox(height: 18),
        Container(height: 265, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: PpColors.border)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Icon(Icons.qr_code_scanner, color: PpColors.forest, size: 84), SizedBox(height: 12), Text('Scanner preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Camera access is a sample feature in this prototype.', style: TextStyle(fontSize: 10, color: PpColors.secondary)),
        ])),
        const SizedBox(height: 22),
        const Text('Enter bill code manually', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        TextField(controller: code, decoration: const InputDecoration(prefixIcon: Icon(Icons.receipt_long_outlined), hintText: 'e.g. PP-10482')),
        const SizedBox(height: 12),
        PpPrimaryButton('Find Receipt', onPressed: () {
      final searchCode = code.text.trim().toLowerCase();
      final found = widget.state.bills.where((bill) => bill.id.toLowerCase() == searchCode || bill.displayNumber.toLowerCase() == searchCode).firstOrNull;
          if (found == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No receipt matched that code.')));
          } else {
            widget.state.openBill(found);
          }
        }),
        const SizedBox(height: 12),
        const PpDemoNotice(message: 'QR camera scanning is a sample preview. The manual bill-code lookup searches your current bills.'),
      ]));
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final total = state.customerBills.fold<double>(0, (sum, bill) => sum + bill.total);
    final categoryValues = <String, double>{'Groceries': total * .45, 'Snacks': total * .20, 'Household': total * .20, 'Other': total * .15};
    final modeNotice = state.isDemoMode ? 'From ${state.customerBills.length} sample receipts (demo mode)' : 'From ${state.customerBills.length} cloud saved receipts';

    return PpScaffold(state: state, title: 'Spending insights', showBack: false, bottomNav: true, bottomTab: 'insights', body: ListView(children: <Widget>[
      const Text('Know where your everyday money goes.', style: TextStyle(fontSize: 12, color: PpColors.secondary)),
      const SizedBox(height: 15),
      PpMetricCard(label: 'Recorded spending', value: money(total), subtitle: modeNotice),
      const SizedBox(height: 20),
      const PpSectionTitle('By category'),
      const SizedBox(height: 9),
      for (final entry in categoryValues.entries) Padding(padding: const EdgeInsets.only(bottom: 17), child: Column(children: <Widget>[
        Row(children: <Widget>[Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), Text(money(entry.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.forest))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: total == 0 ? 0 : entry.value / total, minHeight: 8, color: PpColors.forest, backgroundColor: PpColors.soft)),
      ])),
      const SizedBox(height: 6),
      PpDemoNotice(message: state.isDemoMode ? 'Insights are calculated from local sample receipts.' : 'Insights are calculated from your cloud-saved receipts.'),
    ]));
  }
}

const List<({String name, String category, String distance, String address})> demoShops = <({String name, String category, String distance, String address})>[
  (name: 'Sharma Kirana Store', category: 'Grocery', distance: '0.5 km', address: 'Freeganj, Ujjain'),
  (name: 'Gupta General Store', category: 'General', distance: '1.2 km', address: 'Tower Chowk, Ujjain'),
  (name: 'Fresh Mart', category: 'Supermarket', distance: '1.5 km', address: 'Freeganj, Ujjain'),
  (name: 'Singh Dairy', category: 'Dairy', distance: '2.0 km', address: 'Gopal Mandir, Ujjain'),
  (name: 'Raju Vegetables', category: 'Produce', distance: '2.2 km', address: 'Local market, Ujjain'),
];

class NearbyShopsScreen extends StatefulWidget {
  const NearbyShopsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<NearbyShopsScreen> createState() => _NearbyShopsScreenState();
}
class _NearbyShopsScreenState extends State<NearbyShopsScreen> {
  final TextEditingController search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final shops = demoShops.where((s) => '${s.name} ${s.category} ${s.address}'.toLowerCase().contains(search.text.toLowerCase())).toList();
    return PpScaffold(state: widget.state, title: 'Nearby shops', backTo: 'customerHome', bottomNav: true, bottomTab: 'customerHome', body: Column(children: <Widget>[
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search shops near you')),
      const SizedBox(height: 12),
      const Align(alignment: Alignment.centerLeft, child: Text('Ujjain · Sample local directory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      const SizedBox(height: 8),
      Expanded(child: ListView.builder(itemCount: shops.length, itemBuilder: (context, index) {
        final shop = shops[index];
        return PpTransactionTile(title: shop.name, subtitle: '${shop.distance} · ${shop.category}', trailing: widget.state.savedShops.contains(shop.name) ? '♥' : '♡', icon: Icons.storefront_outlined, onTap: () { widget.state.lastNotice = shop.name; widget.state.go('shopDetails'); });
      })),
      const PpDemoNotice(message: 'Shop names and distances are sample data. Live location and verified shop listings are sample previews.'),
    ]));
  }
}

class ShopDetailsScreen extends StatelessWidget {
  const ShopDetailsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final shop = demoShops.where((s) => s.name == state.lastNotice).firstOrNull ?? demoShops.first;
    return PpScaffold(state: state, title: 'Shop details', backTo: 'nearbyShops', bottomNav: true, bottomTab: 'customerHome', body: ListView(children: <Widget>[
      PpCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(width: 52, height: 52, decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_outlined, size: 27, color: PpColors.forest)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(shop.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('${shop.category} · Ujjain', style: const TextStyle(fontSize: 11, color: PpColors.secondary)), const SizedBox(height: 6), Text('${shop.distance} away', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.forest))])),
      ])),
      const SizedBox(height: 12),
      PpCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('Address', style: TextStyle(fontSize: 11, color: PpColors.secondary, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(shop.address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Sample directory address.', style: TextStyle(fontSize: 10, color: PpColors.secondary))])),
      const SizedBox(height: 16),
      PpPrimaryButton(state.savedShops.contains(shop.name) ? 'Remove Saved Shop' : 'Save Shop', icon: Icons.favorite_border, onPressed: () async {
        final success = await state.toggleSavedShop(shop.name);
        if (context.mounted) {
          if (success) {
            final isSavedNow = state.savedShops.contains(shop.name);
            final msg = state.isDemoMode
                ? (isSavedNow ? 'Shop saved (demo mode).' : 'Shop removed (demo mode).')
                : (isSavedNow ? 'Shop saved to your cloud profile.' : 'Shop removed from your cloud profile.');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update saved shop: ${state.cloudError ?? 'Error'}')));
          }
        }
      }),
      const SizedBox(height: 10),
      if (state.customerBills.isNotEmpty)
        PpSecondaryButton('View a Sample Receipt', icon: Icons.receipt_long_outlined, onPressed: () => state.openBill(state.customerBills.first)),
      const SizedBox(height: 10),
      PpSecondaryButton('Report shop issue', icon: Icons.support_agent, onPressed: () => state.go('support')),
    ]));
  }
}

class SavedShopsScreen extends StatelessWidget {
  const SavedShopsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final shops = demoShops.where((s) => state.savedShops.contains(s.name)).toList();
    final modeLabel = state.isDemoMode ? 'local demo' : 'cloud saved';

    return PpScaffold(state: state, title: 'Saved shops', backTo: 'customerProfile', bottomNav: true, bottomTab: 'customerProfile', body: ListView(children: <Widget>[
      Text('Stores you want to find again ($modeLabel).', style: const TextStyle(fontSize: 12, color: PpColors.secondary)),
      const SizedBox(height: 12),
      if (shops.isEmpty) const PpEmptyState(icon: Icons.favorite_border, title: 'No saved shops', message: 'Save a local shop to find it quickly later.'),
      for (final shop in shops) PpTransactionTile(title: shop.name, subtitle: '${shop.distance} · ${shop.category}', trailing: '♥', onTap: () { state.lastNotice = shop.name; state.go('shopDetails'); }),
      const SizedBox(height: 12),
      PpPrimaryButton('Find More Shops', onPressed: () => state.go('nearbyShops')),
    ]));
  }
}

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final modeLabel = state.isDemoMode ? 'Customer account · Local demo mode' : 'Customer account · Cloud authenticated';

    return PpScaffold(state: state, title: 'Profile', showBack: false, bottomNav: true, bottomTab: 'customerProfile', body: ListView(children: <Widget>[
        const SizedBox(height: 6),
        const Center(child: CircleAvatar(radius: 35, backgroundColor: PpColors.soft, child: Text('RM', style: TextStyle(color: PpColors.forest, fontSize: 22, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 11),
        Center(child: Text(state.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Center(child: Text(modeLabel, style: const TextStyle(fontSize: 11, color: PpColors.secondary))),
        const SizedBox(height: 14),
        PpSecondaryButton('Edit Profile', onPressed: () => state.go('editProfile')),
        const SizedBox(height: 14),
        _ProfileLink(icon: Icons.receipt_long_outlined, label: 'My Purchase History', onTap: () => state.go('bills')),
        _ProfileLink(icon: Icons.favorite_border, label: 'Saved Shops', onTap: () => state.go('savedShops')),
        _ProfileLink(icon: Icons.pie_chart_outline, label: 'Spending Insights', onTap: () => state.go('insights')),
        _ProfileLink(icon: Icons.settings_outlined, label: 'Settings', onTap: () => state.go('settings')),
        _ProfileLink(icon: Icons.support_agent, label: 'Help & Support', onTap: () => state.go('help')),
        _ProfileLink(icon: Icons.shield_outlined, label: 'Privacy & Security', onTap: () => state.go('privacy')),
        _ProfileLink(icon: Icons.star_border, label: 'Rate the App', onTap: () => _demoSnack(context, 'App rating will be available after publishing.')),
        _ProfileLink(icon: Icons.info_outline, label: 'About ParchiPocket', onTap: () => state.go('about')),
      ]));
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4), leading: Icon(icon, color: PpColors.forest, size: 21), title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right, size: 18, color: PpColors.secondary), onTap: onTap);
}

void _demoSnack(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name = TextEditingController(text: widget.state.customerName);
  late final TextEditingController email = TextEditingController(text: widget.state.customerEmail);
  late final TextEditingController city = TextEditingController(text: widget.state.city);
  bool _isSubmitting = false;
  @override
  void dispose() { name.dispose(); email.dispose(); city.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PpScaffold(state: widget.state, title: 'Edit profile', backTo: 'customerProfile', body: ListView(children: <Widget>[
        const SizedBox(height: 8),
        const Center(child: CircleAvatar(radius: 33, backgroundColor: PpColors.soft, child: Icon(Icons.person_outline, color: PpColors.forest, size: 32))),
        const SizedBox(height: 16),
        PpField(label: 'Full name', controller: name, hint: 'Enter your name'),
        const SizedBox(height: 15),
        const Text('Mobile number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: widget.state.phoneNumber.isNotEmpty
                ? widget.state.phoneNumber
                : '+91 Verified Number',
          ),
        ),
        const SizedBox(height: 15),
        PpField(label: 'Email address (optional)', controller: email, hint: 'name@example.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        PpField(label: 'City', controller: city, hint: 'City, state'),
        const SizedBox(height: 20),
        PpPrimaryButton(_isSubmitting ? 'Saving…' : 'Save Changes', onPressed: _isSubmitting ? null : () async {
          final messenger = ScaffoldMessenger.of(context);
          setState(() => _isSubmitting = true);
          try {
            final success = await widget.state.updateProfile(
              name: name.text,
              email: email.text,
              location: city.text,
              successPage: null,
            );
            if (!mounted) return;
            final msg = success
                ? (widget.state.isDemoMode ? 'Profile updated (local demo mode).' : 'Profile updated in cloud.')
                : 'Profile was not saved: ${widget.state.cloudError ?? 'Please wait for other account work to finish and retry.'}';
            messenger.showSnackBar(SnackBar(content: Text(msg)));
            if (success) widget.state.go('customerProfile');
          } catch (error) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text('Profile was not saved. Check your connection and retry. ($error)')),
            );
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        }),
      ]));
}
