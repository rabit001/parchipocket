part of '../common_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;

  void _showThemeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Choose theme',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: const Text('System default'),
              trailing: state.themeMode == ThemeMode.system
                  ? const Icon(Icons.check_rounded, color: PpColors.forest)
                  : null,
              onTap: () {
                state.setThemeMode(ThemeMode.system);
                Navigator.of(dialogCtx).pop();
              },
            ),
            ListTile(
              title: const Text('Light theme'),
              trailing: state.themeMode == ThemeMode.light
                  ? const Icon(Icons.check_rounded, color: PpColors.forest)
                  : null,
              onTap: () {
                state.setThemeMode(ThemeMode.light);
                Navigator.of(dialogCtx).pop();
              },
            ),
            ListTile(
              title: const Text('Dark theme'),
              trailing: state.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check_rounded, color: PpColors.forest)
                  : null,
              onTap: () {
                state.setThemeMode(ThemeMode.dark);
                Navigator.of(dialogCtx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Settings',
      backTo: 'customerProfile',
      body: ListView(children: <Widget>[
        _SettingRow(
            icon: Icons.person_outline,
            title: 'Account',
            subtitle: 'Edit your profile and city',
            onTap: () => state.go('editProfile')),
        _SettingRow(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: switch (state.themeMode) {
              ThemeMode.system => 'System default',
              ThemeMode.light => 'Light theme',
              ThemeMode.dark => 'Dark theme',
            },
            onTap: () => _showThemeDialog(context)),
        _SettingRow(
            icon: Icons.language,
            title: 'Language',
            subtitle: state.language,
            onTap: () => state.go('language')),
        _SettingRow(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Bills and account updates',
            onTap: () => state.go('notifications')),
        _SettingRow(
            icon: Icons.shield_outlined,
            title: 'Privacy & Security',
            subtitle: 'Permissions and account data',
            onTap: () => state.go('privacy')),
        _SettingRow(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'FAQs and customer care',
            onTap: () => state.go('help')),
        _SettingRow(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 0.1.0 · Demo',
            onTap: () => state.go('about')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class ShopSettingsScreen extends StatelessWidget {
  const ShopSettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => PpScaffold(
      state: state,
      title: 'Shop settings',
      showBack: false,
      bottomNav: true,
      bottomTab: 'shopSettings',
      body: ListView(children: <Widget>[
        PpCard(
            child: Row(children: <Widget>[
          Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: PpColors.soft,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_outlined,
                  color: PpColors.forest, size: 25)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(state.shopName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${state.shopCategory} · ${state.shopAddress}',
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
                const SizedBox(height: 6),
                InkWell(
                    onTap: () => state.go('shopSetup'),
                    child: const Text('Edit shop details',
                        style: TextStyle(
                            fontSize: 11,
                            color: PpColors.forest,
                            fontWeight: FontWeight.w700)))
              ]))
        ])),
        const SizedBox(height: 10),
        _SettingRow(
            icon: Icons.store_outlined,
            title: 'Shop details',
            subtitle: 'Name, category and address',
            onTap: () => state.go('shopSetup')),
        _SettingRow(
            icon: Icons.print_outlined,
            title: 'Printer & devices',
            subtitle: 'Bluetooth printer and test receipt',
            onTap: () => state.go('printerSettings')),
        _SettingRow(
            icon: Icons.payments_outlined,
            title: 'Payment methods',
            subtitle: 'Cash, UPI and udhaar',
            onTap: () => state.go('createBill')),
        _SettingRow(
            icon: Icons.category_outlined,
            title: 'Expense categories',
            subtitle: 'Labels used in expense tracking',
            onTap: () => state.go('expenses')),
        _SettingRow(
            icon: Icons.people_outline,
            title: 'Customers',
            subtitle: 'Customer directory and pending bills',
            onTap: () => state.go('customers')),
        _SettingRow(
            icon: Icons.bar_chart_outlined,
            title: 'Sales reports',
            subtitle: 'Sales, expenses and outstanding records',
            onTap: () => state.go('salesReports')),
        _SettingRow(
            icon: Icons.support_agent,
            title: 'Help & Support',
            subtitle: 'Billing and printer support',
            onTap: () => state.go('help')),
        const SizedBox(height: 12),
        PpSecondaryButton('Log Out', onPressed: () => state.go('logout')),
      ]));
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF243026) : PpColors.soft,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: isDark ? PpColors.forestLight : PpColors.forest, size: 20)),
        title: Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 10, color: PpColors.secondary)),
        trailing: const Icon(Icons.chevron_right,
            size: 18, color: PpColors.secondary),
        onTap: onTap,
      );
  }
}
