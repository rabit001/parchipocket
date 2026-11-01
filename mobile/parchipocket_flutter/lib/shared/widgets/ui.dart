import 'package:flutter/material.dart';
import '../../core/state/app_state.dart';
import '../theme/theme.dart';

class PpScaffold extends StatelessWidget {
  const PpScaffold({
    super.key,
    required this.state,
    required this.title,
    required this.body,
    this.backTo,
    this.showBack = true,
    this.bottomTab,
    this.trailing,
    this.bottomNav = false,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 22),
  });

  final AppState state;
  final String title;
  final Widget body;
  final String? backTo;
  final bool showBack;
  final String? bottomTab;
  final Widget? trailing;
  final bool bottomNav;
  final EdgeInsets padding;

  String get _homePage => 'customerHome';

  // Shop Owner and Street Vendor navigation is paused while the app focuses
  // on daily household spending. Their legacy screens and data remain in the
  // repository, but they are not reachable from the current navigation.
  List<({String label, IconData icon, String route})> get _tabs => const [
        (label: 'Home', icon: Icons.home_outlined, route: 'customerHome'),
        (
          label: 'Daily Log',
          icon: Icons.receipt_long_outlined,
          route: 'householdExpenses'
        ),
        (
          label: 'Add',
          icon: Icons.add_circle_outline,
          route: 'householdExpenseEntry'
        ),
        (label: 'Insights', icon: Icons.pie_chart_outline, route: 'insights'),
        (
          label: 'Profile',
          icon: Icons.person_outline,
          route: 'customerProfile'
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final hasError = state.cloudError != null && state.cloudError!.isNotEmpty;
    final isLoading = state.isCloudLoading;

    return Scaffold(
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => state.go(backTo ?? _homePage),
              )
            : null,
        title: Text(title),
        actions: trailing == null ? null : <Widget>[trailing!],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            children: <Widget>[
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (hasError)
                Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    final bannerBg =
                        isDark ? const Color(0xFF2C1E1E) : Colors.red.shade50;
                    final bannerBorder =
                        isDark ? const Color(0xFF5C2D2D) : Colors.red.shade200;
                    final bannerFg =
                        isDark ? const Color(0xFFFF9B9B) : Colors.red.shade800;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bannerBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: bannerBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.error_outline, size: 16, color: bannerFg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.cloudError!,
                              style: TextStyle(fontSize: 11, color: bannerFg),
                            ),
                          ),
                          Semantics(
                            button: true,
                            excludeSemantics: true,
                            label: 'Dismiss error message',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => state.clearCloudError(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded,
                                    size: 15, color: bannerFg),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (state.isOffline)
                Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    final bannerBg = isDark
                        ? const Color(0xFF2C2416)
                        : const Color(0xFFFFF8E1);
                    final bannerBorder = isDark
                        ? const Color(0xFF5C4720)
                        : const Color(0xFFFFE082);
                    final bannerFg = isDark
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF7F5200);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bannerBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: bannerBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.wifi_off_rounded,
                              size: 16, color: bannerFg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline mode: showing cached records.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: bannerFg),
                            ),
                          ),
                          Semantics(
                            button: true,
                            excludeSemantics: true,
                            label: 'Retry connection',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => state.retryConnection(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: bannerFg,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomNav
          ? NavigationBar(
              height: 68,
              selectedIndex: _tabs
                  .indexWhere((tab) => tab.route == (bottomTab ?? state.page))
                  .clamp(0, _tabs.length - 1)
                  .toInt(),
              onDestinationSelected: (index) => state.go(_tabs[index].route),
              destinations: _tabs
                  .map((tab) => NavigationDestination(
                      icon: Icon(tab.icon), label: tab.label))
                  .toList(growable: false),
            )
          : null,
    );
  }
}

class PpPrimaryButton extends StatelessWidget {
  const PpPrimaryButton(this.label,
      {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: icon == null
              ? Text(label)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, textAlign: TextAlign.center)),
                    ]),
        ),
      );
}

class PpSecondaryButton extends StatelessWidget {
  const PpSecondaryButton(this.label,
      {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          child: icon == null
              ? Text(label)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, textAlign: TextAlign.center)),
                    ]),
        ),
      );
}

class PpCard extends StatelessWidget {
  const PpCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        color: color ?? Theme.of(context).cardTheme.color,
        child: Padding(padding: padding, child: child),
      );
}

class PpSectionTitle extends StatelessWidget {
  const PpSectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE8EDE9) : PpColors.ink))),
        if (action != null)
          TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class PpDemoNotice extends StatelessWidget {
  const PpDemoNotice(
      {super.key,
      this.message =
          'Demo mode. Data is stored locally in this running app only.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D2821) : PpColors.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF2C392F)
                  : PpColors.border.withValues(alpha: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline,
              size: 18, color: isDark ? PpColors.forestLight : PpColors.forest),
          const SizedBox(width: 9),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? const Color(0xFFDEEFE3) : PpColors.ink))),
        ],
      ),
    );
  }
}

class PpMetricCard extends StatelessWidget {
  const PpMetricCard(
      {super.key,
      required this.label,
      required this.value,
      this.subtitle,
      this.color = PpColors.forest});
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => PpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: PpColors.secondary)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 5),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 10, color: PpColors.secondary)),
              ],
            ]),
      );
}

String money(num value) => '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
String formatShortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} ${_month(value.month)}';
String formatDateTime(DateTime value) =>
    '${formatShortDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _month(int month) => const <String>[
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
      'Dec'
    ][month - 1];

class PpTransactionTile extends StatelessWidget {
  const PpTransactionTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.trailing,
      required this.onTap,
      this.icon = Icons.storefront_outlined});
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF243026) : PpColors.soft;
    final textFg = isDark ? const Color(0xFFE8EDE9) : PpColors.ink;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: '$title, $subtitle, $trailing',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(children: <Widget>[
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon,
                      size: 20,
                      color: isDark ? PpColors.forestLight : PpColors.forest)),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textFg)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: PpColors.secondary)),
                  ])),
              const SizedBox(width: 8),
              Text(trailing,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textFg)),
            ]),
          ),
        ),
      ),
    );
  }
}

class PpField extends StatelessWidget {
  const PpField(
      {super.key,
      required this.label,
      required this.controller,
      this.hint,
      this.keyboardType,
      this.readOnly = false,
      this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PpColors.secondary)),
        const SizedBox(height: 7),
        TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint)),
      ]);
}

class PpEmptyState extends StatelessWidget {
  const PpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: PpColors.soft, shape: BoxShape.circle),
                child: Icon(icon, color: PpColors.forest, size: 28)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 7),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: PpColors.secondary, height: 1.4)),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
              ),
            ],
          ]),
        ),
      );
}

extension PpFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
