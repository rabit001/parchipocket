import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'screens/auth_screens.dart';
import 'screens/common_screens.dart';
import 'screens/customer_screens.dart';
import 'screens/shop_screens.dart';
import 'screens/vendor_screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ParchiPocketApp());
}

class ParchiPocketApp extends StatefulWidget {
  const ParchiPocketApp({super.key});

  @override
  State<ParchiPocketApp> createState() => _ParchiPocketAppState();
}

class _ParchiPocketAppState extends State<ParchiPocketApp> {
  late final AppState state = AppState();

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  Widget _screenForCurrentPage() => switch (state.page) {
        'splash' => SplashScreen(state: state),
        'login' => LoginScreen(state: state),
        'phoneLogin' => PhoneLoginScreen(state: state),
        'verifyOtp' => OtpScreen(state: state),
        'roleSelection' => RoleSelectionScreen(state: state),
        'customerSetup' => CustomerSetupScreen(state: state),
        'shopSetup' => ShopSetupScreen(state: state),
        'vendorSetup' => VendorSetupScreen(state: state),
        'customerHome' => CustomerHomeScreen(state: state),
        'bills' => BillsScreen(state: state),
        'billDetail' => BillDetailScreen(state: state),
        'scan' => ScanBillScreen(state: state),
        'insights' => InsightsScreen(state: state),
        'nearbyShops' => NearbyShopsScreen(state: state),
        'shopDetails' => ShopDetailsScreen(state: state),
        'savedShops' => SavedShopsScreen(state: state),
        'customerProfile' => CustomerProfileScreen(state: state),
        'editProfile' => EditProfileScreen(state: state),
        'shopHome' => ShopHomeScreen(state: state),
        'createBill' => CreateBillScreen(state: state),
        'receipt' => ReceiptScreen(state: state),
        'billHistory' => BillHistoryScreen(state: state),
        'expenses' => ExpensesScreen(state: state),
        'expenseSaved' => ExpenseSavedScreen(state: state),
        'udhaar' => UdhaarScreen(state: state),
        'confirmSettlement' => ConfirmSettlementScreen(state: state),
        'salesReports' => SalesReportsScreen(state: state),
        'exportPreview' => ExportReportPreviewScreen(state: state),
        'customers' => CustomerDirectoryScreen(state: state),
        'printerSettings' => PrinterSettingsScreen(state: state),
        'printerTest' => PrinterTestScreen(state: state),
        'vendorHome' => VendorHomeScreen(state: state),
        'vendorBill' => CreateBillScreen(state: state, vendorMode: true),
        'vendorReceipt' => ReceiptScreen(state: state, vendorMode: true),
        'vendorSales' => VendorSalesScreen(state: state),
        'vendorProfile' => VendorProfileScreen(state: state),
        'settings' => SettingsScreen(state: state),
        'shopSettings' => ShopSettingsScreen(state: state),
        'notifications' => NotificationsScreen(state: state),
        'help' => HelpScreen(state: state),
        'faqs' => FaqScreen(state: state),
        'support' => SupportScreen(state: state),
        'supportSubmitted' => SupportSubmittedScreen(state: state),
        'shareReceipt' => ShareReceiptScreen(state: state),
        'sharePreview' => SharePreviewScreen(state: state),
        'logout' => LogoutScreen(state: state),
        'privacy' => PrivacyScreen(state: state),
        'deleteReview' => DeleteAccountReviewScreen(state: state),
        'deleteConfirm' => DeleteAccountConfirmScreen(state: state),
        'language' => LanguageScreen(state: state),
        'about' => AboutScreen(state: state),
        'search' => SearchScreen(state: state),
        _ => SplashScreen(state: state),
      };

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ParchiPocket',
        debugShowCheckedModeBanner: false,
        theme: buildPpTheme(),
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => _screenForCurrentPage(),
        ),
      );
}
