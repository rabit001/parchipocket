part of '../customer_screens.dart';

class NearbyShopsScreen extends StatefulWidget {
  const NearbyShopsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<NearbyShopsScreen> createState() => _NearbyShopsScreenState();
}

class _NearbyShopsScreenState extends State<NearbyShopsScreen> {
  final TextEditingController search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shops = demoShops
        .where((s) => '${s.name} ${s.category} ${s.address}'
            .toLowerCase()
            .contains(search.text.toLowerCase()))
        .toList();
    return PpScaffold(
        state: widget.state,
        title: 'Nearby shops',
        backTo: 'customerHome',
        bottomNav: true,
        bottomTab: 'customerHome',
        body: Column(children: <Widget>[
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search shops near you')),
          const SizedBox(height: 12),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ujjain · Sample local directory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          Expanded(
              child: ListView.builder(
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return PpTransactionTile(
                        title: shop.name,
                        subtitle: '${shop.distance} · ${shop.category}',
                        trailing: widget.state.savedShops.contains(shop.name)
                            ? '♥'
                            : '♡',
                        icon: Icons.storefront_outlined,
                        onTap: () {
                          widget.state.lastNotice = shop.name;
                          widget.state.go('shopDetails');
                        });
                  })),
          const PpDemoNotice(
              message:
                  'Shop names and distances are sample data. Live location and verified shop listings are sample previews.'),
        ]));
  }
}

class ShopDetailsScreen extends StatelessWidget {
  const ShopDetailsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final shop =
        demoShops.where((s) => s.name == state.lastNotice).firstOrNull ??
            demoShops.first;
    return PpScaffold(
        state: state,
        title: 'Shop details',
        backTo: 'nearbyShops',
        bottomNav: true,
        bottomTab: 'customerHome',
        body: ListView(children: <Widget>[
          PpCard(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: PpColors.soft,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.storefront_outlined,
                        size: 27, color: PpColors.forest)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                      Text(shop.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('${shop.category} · Ujjain',
                          style: const TextStyle(
                              fontSize: 11, color: PpColors.secondary)),
                      const SizedBox(height: 6),
                      Text('${shop.distance} away',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PpColors.forest))
                    ])),
              ])),
          const SizedBox(height: 12),
          PpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                const Text('Address',
                    style: TextStyle(
                        fontSize: 11,
                        color: PpColors.secondary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(shop.address,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Sample directory address.',
                    style: TextStyle(fontSize: 10, color: PpColors.secondary))
              ])),
          const SizedBox(height: 16),
          PpPrimaryButton(
              state.savedShops.contains(shop.name)
                  ? 'Remove Saved Shop'
                  : 'Save Shop',
              icon: Icons.favorite_border, onPressed: () async {
            final success = await state.toggleSavedShop(shop.name);
            if (context.mounted) {
              if (success) {
                final isSavedNow = state.savedShops.contains(shop.name);
                final msg = state.isDemoMode
                    ? (isSavedNow
                        ? 'Shop saved (demo mode).'
                        : 'Shop removed (demo mode).')
                    : (isSavedNow
                        ? 'Shop saved to your cloud profile.'
                        : 'Shop removed from your cloud profile.');
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Failed to update saved shop: ${state.cloudError ?? 'Error'}')));
              }
            }
          }),
          const SizedBox(height: 10),
          if (state.customerBills.isNotEmpty)
            PpSecondaryButton('View a Sample Receipt',
                icon: Icons.receipt_long_outlined,
                onPressed: () => state.openBill(state.customerBills.first)),
          const SizedBox(height: 10),
          PpSecondaryButton('Report shop issue',
              icon: Icons.support_agent, onPressed: () => state.go('support')),
        ]));
  }
}

class SavedShopsScreen extends StatelessWidget {
  const SavedShopsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final shops =
        demoShops.where((s) => state.savedShops.contains(s.name)).toList();
    final modeLabel = state.isDemoMode ? 'local demo' : 'cloud saved';

    return PpScaffold(
        state: state,
        title: 'Saved shops',
        backTo: 'customerProfile',
        bottomNav: true,
        bottomTab: 'customerProfile',
        body: ListView(children: <Widget>[
          Text('Stores you want to find again ($modeLabel).',
              style: const TextStyle(fontSize: 12, color: PpColors.secondary)),
          const SizedBox(height: 12),
          if (shops.isEmpty)
            const PpEmptyState(
                icon: Icons.favorite_border,
                title: 'No saved shops',
                message: 'Save a local shop to find it quickly later.'),
          for (final shop in shops)
            PpTransactionTile(
                title: shop.name,
                subtitle: '${shop.distance} · ${shop.category}',
                trailing: '♥',
                onTap: () {
                  state.lastNotice = shop.name;
                  state.go('shopDetails');
                }),
          const SizedBox(height: 12),
          PpPrimaryButton('Find More Shops',
              onPressed: () => state.go('nearbyShops')),
        ]));
  }
}
