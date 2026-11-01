part of '../vendor_screens.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'More & Profile',
      showBack: false,
      bottomNav: true,
      bottomTab: 'vendorProfile',
      body: ListView(children: <Widget>[
        PpCard(
            child: Row(children: <Widget>[
          const CircleAvatar(
              radius: 27,
              backgroundColor: PpColors.soft,
              child: Icon(Icons.storefront_outlined, color: PpColors.forest)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(state.vendorName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(state.vendorCategory,
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
                const SizedBox(height: 6),
                InkWell(
                    onTap: () => state.go('vendorSetup'),
                    child: const Text('Edit details',
                        style: TextStyle(
                            fontSize: 11,
                            color: PpColors.forest,
                            fontWeight: FontWeight.w700)))
              ]))
        ])),
        const SizedBox(height: 8),
        _VendorLink(
            icon: Icons.receipt_long_outlined,
            label: 'Daily Sales & History',
            detail: 'View your recent receipts',
            onTap: () => state.go('vendorSales')),
        _VendorLink(
            icon: Icons.language,
            label: 'Language',
            detail: state.language,
            onTap: () => state.go('language')),
        _VendorLink(
            icon: Icons.print_outlined,
            label: 'Printer (optional)',
            detail: 'Thermal receipt setup',
            onTap: () => state.go('printerSettings')),
        _VendorLink(
            icon: Icons.notifications_none,
            label: 'Notifications',
            detail: 'Bill and app updates',
            onTap: () => state.go('notifications')),
        _VendorLink(
            icon: Icons.support_agent,
            label: 'Help & Customer Care',
            detail: 'FAQs and report an issue',
            onTap: () => state.go('help')),
        _VendorLink(
            icon: Icons.shield_outlined,
            label: 'Privacy & Security',
            detail: 'Receipt sharing and permissions',
            onTap: () => state.go('privacy')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class _VendorLink extends StatelessWidget {
  const _VendorLink(
      {required this.icon,
      required this.label,
      required this.detail,
      required this.onTap});
  final IconData icon;
  final String label, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      dense: true,
      leading: Icon(icon, color: PpColors.forest),
      title: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(detail,
          style: const TextStyle(fontSize: 10, color: PpColors.secondary)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap);
}
